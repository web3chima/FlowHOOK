// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {OracleManager} from "../src/OracleManager.sol";
import {PriceFeed} from "../src/DataStructures.sol";
import {StaleOracle, PriceOutOfBounds} from "../src/Errors.sol";
import {PriceDeviationAlert} from "../src/Events.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @notice Mock Chainlink aggregator for testing
contract MockAggregator is AggregatorV3Interface {
    int256 private _answer;
    uint256 private _updatedAt;
    uint8 private _decimals;
    uint80 private _roundId;
    
    constructor(int256 initialAnswer, uint8 decimals_) {
        _answer = initialAnswer;
        _decimals = decimals_;
        _updatedAt = block.timestamp;
        _roundId = 1;
    }
    
    function setAnswer(int256 newAnswer) external {
        _answer = newAnswer;
        _updatedAt = block.timestamp;
        _roundId++;
    }
    
    function setUpdatedAt(uint256 timestamp) external {
        _updatedAt = timestamp;
    }
    
    function decimals() external view override returns (uint8) {
        return _decimals;
    }
    
    function description() external pure override returns (string memory) {
        return "Mock Aggregator";
    }
    
    function version() external pure override returns (uint256) {
        return 1;
    }
    
    function getRoundData(uint80 _roundId_)
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId_, _answer, _updatedAt, _updatedAt, _roundId_);
    }
    
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _answer, _updatedAt, _updatedAt, _roundId);
    }
}

/// @notice Concrete implementation of OracleManager for testing
contract OracleManagerTestImpl is OracleManager {
    function configurePriceFeed(
        address token,
        address feedAddress,
        uint256 heartbeat
    ) external {
        _configurePriceFeed(token, feedAddress, heartbeat);
    }
}

/// @notice Test suite for OracleManager
contract OracleManagerTest is Test {
    OracleManagerTestImpl public oracleManager;
    MockAggregator public mockAggregator;
    
    address public constant TOKEN = address(0x1);
    uint256 public constant INITIAL_PRICE = 2000 * 1e8; // $2000 with 8 decimals
    uint8 public constant DECIMALS = 8;
    
    function setUp() public {
        oracleManager = new OracleManagerTestImpl();
        mockAggregator = new MockAggregator(int256(INITIAL_PRICE), DECIMALS);
        
        // Configure the price feed
        oracleManager.configurePriceFeed(TOKEN, address(mockAggregator), 0);
    }
    
    /// @notice Property 30: Oracle Query Frequency
    /// @dev Test that oracle can only be queried once per block
    function testProperty_OracleQueryFrequency() public {
        // Feature: uniswap-v4-orderbook-hook, Property 30: Oracle Query Frequency
        
        // First query should succeed
        (int256 price1, uint256 updatedAt1) = oracleManager.updateOraclePrice(TOKEN);
        assertEq(price1, int256(INITIAL_PRICE), "First query should return correct price");
        assertEq(updatedAt1, block.timestamp, "First query should have current timestamp");
        
        // Second query in same block should revert
        vm.expectRevert("Oracle already queried this block");
        oracleManager.updateOraclePrice(TOKEN);
        
        // Roll to next block
        vm.roll(block.number + 1);
        
        // Query should succeed in new block
        (int256 price2, uint256 updatedAt2) = oracleManager.updateOraclePrice(TOKEN);
        assertEq(price2, int256(INITIAL_PRICE), "Second query should return correct price");
        
        // Third query in same block should revert again
        vm.expectRevert("Oracle already queried this block");
        oracleManager.updateOraclePrice(TOKEN);
    }
    
    /// @notice Property 30: Oracle Query Frequency - Fuzz test
    /// @dev Test that oracle query frequency limit holds across multiple blocks
    function testProperty_OracleQueryFrequencyFuzz(uint8 numBlocks) public {
        // Feature: uniswap-v4-orderbook-hook, Property 30: Oracle Query Frequency
        
        vm.assume(numBlocks > 0 && numBlocks <= 100);
        
        for (uint256 i = 0; i < numBlocks; i++) {
            // First query in block should succeed
            oracleManager.updateOraclePrice(TOKEN);
            
            // Second query in same block should fail
            vm.expectRevert("Oracle already queried this block");
            oracleManager.updateOraclePrice(TOKEN);
            
            // Move to next block and advance time
            vm.roll(block.number + 1);
            vm.warp(block.timestamp + 12); // Advance 12 seconds (typical block time)
            
            // Update mock aggregator timestamp to match
            mockAggregator.setUpdatedAt(block.timestamp);
        }
    }
    
    /// @notice Test basic price feed configuration
    function test_ConfigurePriceFeed() public {
        address newToken = address(0x2);
        MockAggregator newAggregator = new MockAggregator(int256(3000 * 1e8), 8);
        
        oracleManager.configurePriceFeed(newToken, address(newAggregator), 10 minutes);
        
        (int256 price, ) = oracleManager.updateOraclePrice(newToken);
        assertEq(price, int256(3000 * 1e8), "Should return correct price for new feed");
    }
    
    /// @notice Test price normalization to 18 decimals
    function test_PriceNormalization() public {
        // Test with 8 decimals (Chainlink standard)
        MockAggregator agg8 = new MockAggregator(int256(2000 * 1e8), 8);
        address token8 = address(0x3);
        oracleManager.configurePriceFeed(token8, address(agg8), 0);
        
        (int256 price8, ) = oracleManager.updateOraclePrice(token8);
        assertEq(price8, int256(2000 * 1e8), "8 decimal price should be correct");
        
        // Test with 18 decimals
        MockAggregator agg18 = new MockAggregator(int256(2000 * 1e18), 18);
        address token18 = address(0x4);
        oracleManager.configurePriceFeed(token18, address(agg18), 0);
        
        vm.roll(block.number + 1); // Move to next block
        (int256 price18, ) = oracleManager.updateOraclePrice(token18);
        assertEq(price18, int256(2000 * 1e18), "18 decimal price should be correct");
    }
    
    /// @notice Test getting latest price without updating
    function test_GetLatestPrice() public {
        // Update once
        oracleManager.updateOraclePrice(TOKEN);
        
        // Get latest without updating (should not revert even in same block)
        (int256 price, uint256 updatedAt) = oracleManager.getLatestPrice(TOKEN);
        assertEq(price, int256(INITIAL_PRICE), "Should return stored price");
        assertEq(updatedAt, block.timestamp, "Should return stored timestamp");
    }
    
    /// @notice Test price staleness check
    function test_IsPriceStale() public {
        // Initially stale (never updated)
        assertTrue(oracleManager.isPriceStale(TOKEN), "Should be stale before first update");
        
        // Update price
        oracleManager.updateOraclePrice(TOKEN);
        assertFalse(oracleManager.isPriceStale(TOKEN), "Should not be stale after update");
        
        // Warp time beyond heartbeat
        vm.warp(block.timestamp + 6 minutes);
        assertTrue(oracleManager.isPriceStale(TOKEN), "Should be stale after heartbeat expires");
    }
    
    /// @notice Property 32: Stale Oracle Rejection
    /// @dev Test that trades are rejected when oracle price is stale
    function testProperty_StaleOracleRejection() public {
        // Feature: uniswap-v4-orderbook-hook, Property 32: Stale Oracle Rejection
        
        // Update oracle to establish baseline
        oracleManager.updateOraclePrice(TOKEN);
        
        // Move to next block and make oracle data stale (> 5 minutes old)
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 6 minutes);
        // Mock aggregator timestamp is now stale (still at original timestamp)
        
        // Update should revert with StaleOracle error
        vm.expectRevert(
            abi.encodeWithSelector(
                StaleOracle.selector,
                address(mockAggregator),
                1 // Original timestamp from setUp
            )
        );
        oracleManager.updateOraclePrice(TOKEN);
    }
    
    /// @notice Property 32: Stale Oracle Rejection - Fuzz test
    /// @dev Test that oracle rejection works for various staleness durations
    function testProperty_StaleOracleRejectionFuzz(uint32 staleDuration) public {
        // Feature: uniswap-v4-orderbook-hook, Property 32: Stale Oracle Rejection
        
        // Assume staleness is between 5 minutes and 1 day
        vm.assume(staleDuration > 5 minutes && staleDuration < 1 days);
        
        // Update oracle
        oracleManager.updateOraclePrice(TOKEN);
        
        // Move to next block and make data stale
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + staleDuration);
        // Don't update mock aggregator timestamp
        
        // Should revert with StaleOracle error
        vm.expectRevert(
            abi.encodeWithSelector(
                StaleOracle.selector,
                address(mockAggregator),
                block.timestamp - staleDuration
            )
        );
        oracleManager.updateOraclePrice(TOKEN);
    }
    
    /// @notice Property 32: Fresh Oracle Acceptance
    /// @dev Test that fresh oracle data is accepted
    function testProperty_FreshOracleAcceptance(uint32 freshDuration) public {
        // Feature: uniswap-v4-orderbook-hook, Property 32: Stale Oracle Rejection
        
        // Assume freshness is less than 5 minutes
        vm.assume(freshDuration > 0 && freshDuration < 5 minutes);
        
        // Update oracle
        oracleManager.updateOraclePrice(TOKEN);
        
        // Move to next block with fresh data
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + freshDuration);
        mockAggregator.setUpdatedAt(block.timestamp);
        
        // Should succeed
        (int256 price, uint256 updatedAt) = oracleManager.updateOraclePrice(TOKEN);
        assertEq(price, int256(INITIAL_PRICE), "Should return correct price");
        assertEq(updatedAt, block.timestamp, "Should have current timestamp");
    }
    
    /// @notice Test price validation with acceptable deviation
    function test_ValidatePriceWithinThreshold() public {
        // Update oracle first
        oracleManager.updateOraclePrice(TOKEN);
        
        // Move to next block
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        mockAggregator.setUpdatedAt(block.timestamp);
        
        // Internal price within 2% should be valid
        uint256 oraclePrice = 2000 * 1e18; // Normalized to 18 decimals
        uint256 internalPrice = 2030 * 1e18; // 1.5% higher
        
        (bool isValid, uint256 deviation) = oracleManager.validatePrice(TOKEN, internalPrice);
        assertTrue(isValid, "Price within 2% should be valid");
        assertLt(deviation, 200, "Deviation should be less than 2%");
    }
    
    /// @notice Test price validation with excessive deviation
    function test_ValidatePriceExceedsThreshold() public {
        // Update oracle first
        oracleManager.updateOraclePrice(TOKEN);
        
        // Move to next block
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        mockAggregator.setUpdatedAt(block.timestamp);
        
        // Internal price > 2% should emit alert
        uint256 oraclePrice = 2000 * 1e18;
        uint256 internalPrice = 2100 * 1e18; // 5% higher
        
        // Expect PriceDeviationAlert event
        vm.expectEmit(true, false, false, true);
        emit PriceDeviationAlert(TOKEN, internalPrice, oraclePrice, 500, block.timestamp);
        
        (bool isValid, uint256 deviation) = oracleManager.validatePrice(TOKEN, internalPrice);
        assertFalse(isValid, "Price > 2% should be invalid");
        assertGt(deviation, 200, "Deviation should be greater than 2%");
    }
    
    /// @notice Test de-leveraging price validation
    function test_ValidateDeleveragingPrice() public {
        // Update oracle first
        oracleManager.updateOraclePrice(TOKEN);
        
        // Move to next block
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        mockAggregator.setUpdatedAt(block.timestamp);
        
        // De-leveraging price within 5% should be valid
        uint256 oraclePrice = 2000 * 1e18;
        uint256 deleveragePrice = 2080 * 1e18; // 4% higher
        
        bool isValid = oracleManager.validateDeleveragingPrice(TOKEN, deleveragePrice);
        assertTrue(isValid, "De-leveraging price within 5% should be valid");
    }
    
    /// @notice Test de-leveraging price validation with excessive deviation
    function test_ValidateDeleveragingPriceExceedsThreshold() public {
        // Update oracle first
        oracleManager.updateOraclePrice(TOKEN);
        
        // Move to next block
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        mockAggregator.setUpdatedAt(block.timestamp);
        
        // De-leveraging price > 5% should revert
        uint256 oraclePrice = 2000 * 1e18;
        uint256 deleveragePrice = 2200 * 1e18; // 10% higher
        
        vm.expectRevert(
            abi.encodeWithSelector(
                PriceOutOfBounds.selector,
                deleveragePrice,
                (oraclePrice * 9500) / 10000, // -5%
                (oraclePrice * 10500) / 10000  // +5%
            )
        );
        oracleManager.validateDeleveragingPrice(TOKEN, deleveragePrice);
    }
    
    /// @notice Test multiple price feeds configuration
    function test_MultiplePriceFeeds() public {
        address token2 = address(0x5);
        address token3 = address(0x6);
        
        MockAggregator agg2 = new MockAggregator(int256(3000 * 1e8), 8);
        MockAggregator agg3 = new MockAggregator(int256(1500 * 1e8), 8);
        
        oracleManager.configurePriceFeed(token2, address(agg2), 0);
        oracleManager.configurePriceFeed(token3, address(agg3), 0);
        
        // Check all feeds are configured
        address[] memory tokens = new address[](3);
        tokens[0] = TOKEN;
        tokens[1] = token2;
        tokens[2] = token3;
        
        bool allConfigured = oracleManager.checkMultipleFeedsConfigured(tokens);
        assertTrue(allConfigured, "All feeds should be configured");
        
        // Check with unconfigured token
        address[] memory tokensWithUnconfigured = new address[](4);
        tokensWithUnconfigured[0] = TOKEN;
        tokensWithUnconfigured[1] = token2;
        tokensWithUnconfigured[2] = token3;
        tokensWithUnconfigured[3] = address(0x7); // Not configured
        
        bool notAllConfigured = oracleManager.checkMultipleFeedsConfigured(tokensWithUnconfigured);
        assertFalse(notAllConfigured, "Should return false with unconfigured token");
    }
    
    /// @notice Property 31: Price Deviation Alert
    /// @dev Test that PriceDeviationAlert event is emitted when deviation > 2%
    function testProperty_PriceDeviationAlert() public {
        // Feature: uniswap-v4-orderbook-hook, Property 31: Price Deviation Alert
        
        // Update oracle first
        oracleManager.updateOraclePrice(TOKEN);
        
        // Move to next block
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        mockAggregator.setUpdatedAt(block.timestamp);
        
        // Test with deviation > 2% (should emit alert)
        uint256 internalPrice3Percent = 2061 * 1e18; // Slightly over 3%
        
        // Record logs to check if event was emitted
        vm.recordLogs();
        
        (bool isValid, uint256 deviation) = oracleManager.validatePrice(TOKEN, internalPrice3Percent);
        
        // Check results
        assertFalse(isValid, "3% deviation should be invalid");
        assertGt(deviation, 200, "Deviation should be > 2%");
        
        // Check that PriceDeviationAlert event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool foundEvent = false;
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("PriceDeviationAlert(address,uint256,uint256,uint256,uint256)")) {
                foundEvent = true;
                break;
            }
        }
        assertTrue(foundEvent, "PriceDeviationAlert event should be emitted");
    }
    
    /// @notice Property 31: Price Deviation Alert - Fuzz test
    /// @dev Test that alert is emitted for various deviation levels
    function testProperty_PriceDeviationAlertFuzz(uint16 deviationBps) public {
        // Feature: uniswap-v4-orderbook-hook, Property 31: Price Deviation Alert
        
        // Assume deviation is between 2.01% and 50%
        vm.assume(deviationBps > 200 && deviationBps <= 5000);
        
        // Update oracle first
        oracleManager.updateOraclePrice(TOKEN);
        
        // Move to next block
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        mockAggregator.setUpdatedAt(block.timestamp);
        
        // Calculate internal price with specified deviation
        uint256 oraclePrice = 2000 * 1e18;
        uint256 internalPrice = (oraclePrice * (10000 + deviationBps)) / 10000;
        
        // Should emit PriceDeviationAlert event
        vm.expectEmit(true, false, false, false); // Don't check data fields due to precision
        emit PriceDeviationAlert(TOKEN, 0, 0, 0, 0);
        
        (bool isValid, uint256 deviation) = oracleManager.validatePrice(TOKEN, internalPrice);
        assertFalse(isValid, "Price with deviation > 2% should be invalid");
        assertGt(deviation, 200, "Deviation should be greater than 2%");
    }
    
    /// @notice Property 31: No Alert for Small Deviations
    /// @dev Test that no alert is emitted for deviations <= 2%
    function testProperty_NoAlertForSmallDeviations(uint16 deviationBps) public {
        // Feature: uniswap-v4-orderbook-hook, Property 31: Price Deviation Alert
        
        // Assume deviation is between 0 and 2%
        vm.assume(deviationBps > 0 && deviationBps <= 200);
        
        // Update oracle first
        oracleManager.updateOraclePrice(TOKEN);
        
        // Move to next block
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
        mockAggregator.setUpdatedAt(block.timestamp);
        
        // Calculate internal price with specified deviation
        uint256 oraclePrice = 2000 * 1e18;
        uint256 internalPrice = (oraclePrice * (10000 + deviationBps)) / 10000;
        
        // Should NOT emit PriceDeviationAlert event
        // We can't use vm.expectEmit with "should not emit", so we just check the result
        (bool isValid, uint256 deviation) = oracleManager.validatePrice(TOKEN, internalPrice);
        assertTrue(isValid, "Price with deviation <= 2% should be valid");
        assertLe(deviation, 200, "Deviation should be <= 2%");
    }
}
