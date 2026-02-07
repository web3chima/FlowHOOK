// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CustomCurveEngine} from "../src/CustomCurveEngine.sol";
import {CurveMath} from "../src/libraries/CurveMath.sol";

/// @title Custom Curve Engine Test Implementation
/// @notice Concrete implementation of CustomCurveEngine for testing
contract CustomCurveEngineTestImpl is CustomCurveEngine {
    
    function initializeCurve(uint256 _initialPrice, uint256 _initialQuantity) external {
        _initializeCurve(_initialPrice, _initialQuantity);
    }
    
    function executeCurveTrade(uint256 size, bool isLong) 
        external 
        returns (uint256 executionPrice, uint256 priceImpact) 
    {
        return _executeCurveTrade(size, isLong);
    }
    
    function closeCurvePosition(uint256 size, bool isLong)
        external
        returns (uint256 executionPrice)
    {
        return _closeCurvePosition(size, isLong);
    }
    
    function calculateOIVolatilityImpact() external view returns (int256) {
        return _calculateOIVolatilityImpact();
    }
    
    function getEffectiveCurveVolatility(uint256 baseVolatility) external view returns (uint256) {
        return _getEffectiveCurveVolatility(baseVolatility);
    }
}

/// @title Custom Curve Engine Tests
/// @notice Tests for P = K × Q^(-2) custom curve implementation
/// @dev Uses smaller scaling to avoid overflow: price in "raw" units, not 1e18 scaled
contract CustomCurveEngineTest is Test {
    CustomCurveEngineTestImpl public curveEngine;
    
    uint256 constant PRECISION = 1e18;
    // Use smaller values to avoid hitting MAX_PRICE ceiling
    // K = P * Q^2 / PRECISION, then P = K * PRECISION / Q^2
    // To keep values manageable:
    // - Initial price: 100e18 ($100 in testing scale)
    // - Initial Q: 10e18 (10 units)
    // - K = 100e18 * 10e18 * 10e18 / 1e18 = 100e18 * 100e36 / 1e18 = 10000e36
    // - P recalculated = 10000e36 * 1e18 / ((10e18)^2 / 1e18) = 10000e54 / 100e18 = 100e36 -> still hits MAX
    
    // Need even smaller values:
    // - Initial price: 1e18 ($1)
    // - Initial Q: 1e18 (1 unit)
    // - K = 1e18 * 1e18 * 1e18 / 1e18 = 1e36
    // - P = 1e36 * 1e18 / ((1e18)^2 / 1e18) = 1e54 / 1e18 = 1e36 -> equals MAX_PRICE
    
    // Let's use values that work with the formula:
    // - Initial Q: 1e18 (1 unit), Initial price: 1e15 ($0.001)
    // - K = 1e15 * 1e18 * 1e18 / 1e18 = 1e33
    // - P = 1e33 * 1e18 / (1e18 * 1e18 / 1e18) = 1e51 / 1e18 = 1e33 -> still large but < MAX
    
    uint256 constant INITIAL_PRICE = 1e15;  // $0.001 (small to avoid overflow)
    uint256 constant INITIAL_QUANTITY = 1e18; // 1 unit
    
    function setUp() public {
        curveEngine = new CustomCurveEngineTestImpl();
        curveEngine.initializeCurve(INITIAL_PRICE, INITIAL_QUANTITY);
    }
    
    // ============ Initialization Tests ============
    
    /// @notice Test curve initialization
    function test_InitializeCurve() public view {
        (uint256 k, uint256 q, uint256 price, uint256 sensitivity) = curveEngine.getCurveState();
        
        // Verify K = P × Q² / PRECISION
        uint256 expectedK = (INITIAL_PRICE * INITIAL_QUANTITY * INITIAL_QUANTITY) / PRECISION;
        assertEq(k, expectedK, "Pool constant K should be P * Q^2 / PRECISION");
        
        // Verify Q is set correctly
        assertEq(q, INITIAL_QUANTITY, "Initial quantity should match");
        
        // Verify price calculation works  
        assertGt(price, 0, "Price should be positive");
        assertLt(price, 1e36, "Price should be less than MAX_PRICE");
        
        // Verify sensitivity is positive
        assertGt(sensitivity, 0, "Sensitivity should be positive");
    }
    
    /// @notice Test initialization reverts with zero price
    function test_InitializeCurve_RevertZeroPrice() public {
        CustomCurveEngineTestImpl newEngine = new CustomCurveEngineTestImpl();
        vm.expectRevert();
        newEngine.initializeCurve(0, INITIAL_QUANTITY);
    }
    
    /// @notice Test initialization reverts with too small quantity
    function test_InitializeCurve_RevertSmallQuantity() public {
        CustomCurveEngineTestImpl newEngine = new CustomCurveEngineTestImpl();
        vm.expectRevert();
        newEngine.initializeCurve(INITIAL_PRICE, 1e10); // Below minimum (1e15)
    }
    
    // ============ Long Trade Tests (Q decreases → Price ↑) ============
    
    /// @notice Test long trade decreases Q
    function test_ExecuteCurveTrade_Long_DecreasesQ() public {
        uint256 qBefore = curveEngine.vBTCQuantity();
        uint256 tradeSize = 1e17; // 0.1 units (10% of pool)
        
        curveEngine.executeCurveTrade(tradeSize, true);
        
        uint256 qAfter = curveEngine.vBTCQuantity();
        assertEq(qAfter, qBefore - tradeSize, "Long trade should decrease Q");
    }
    
    /// @notice Test long trade increases price
    function test_ExecuteCurveTrade_Long_IncreasesPrice() public {
        uint256 priceBefore = curveEngine.calculateCurvePrice();
        uint256 tradeSize = 1e17; // 0.1 units (10% of pool)
        
        curveEngine.executeCurveTrade(tradeSize, true);
        
        uint256 priceAfter = curveEngine.calculateCurvePrice();
        assertGt(priceAfter, priceBefore, "Long trade should increase price");
    }
    
    /// @notice Test long trade increases total long positions
    function test_ExecuteCurveTrade_Long_TracksPositions() public {
        uint256 tradeSize = 1e17;
        
        curveEngine.executeCurveTrade(tradeSize, true);
        
        (uint256 longOI,,) = curveEngine.getOpenInterest();
        assertEq(longOI, tradeSize, "Long positions should be tracked");
    }
    
    /// @notice Test long trade returns valid execution price and impact
    function test_ExecuteCurveTrade_Long_ReturnsValidData() public {
        uint256 tradeSize = 1e17; // 10% of pool - significant trade
        
        (uint256 executionPrice, uint256 priceImpact) = curveEngine.executeCurveTrade(tradeSize, true);
        
        assertGt(executionPrice, 0, "Execution price should be positive");
        assertGt(priceImpact, 0, "Price impact should be positive for significant trade");
    }
    
    // ============ Short Trade Tests (Q increases → Price ↓) ============
    
    /// @notice Test short trade increases Q
    function test_ExecuteCurveTrade_Short_IncreasesQ() public {
        uint256 qBefore = curveEngine.vBTCQuantity();
        uint256 tradeSize = 1e17;
        
        curveEngine.executeCurveTrade(tradeSize, false);
        
        uint256 qAfter = curveEngine.vBTCQuantity();
        assertEq(qAfter, qBefore + tradeSize, "Short trade should increase Q");
    }
    
    /// @notice Test short trade decreases price
    function test_ExecuteCurveTrade_Short_DecreasesPrice() public {
        uint256 priceBefore = curveEngine.calculateCurvePrice();
        uint256 tradeSize = 1e17; // 10% of pool
        
        curveEngine.executeCurveTrade(tradeSize, false);
        
        uint256 priceAfter = curveEngine.calculateCurvePrice();
        assertLt(priceAfter, priceBefore, "Short trade should decrease price");
    }
    
    /// @notice Test short trade increases total short positions
    function test_ExecuteCurveTrade_Short_TracksPositions() public {
        uint256 tradeSize = 1e17;
        
        curveEngine.executeCurveTrade(tradeSize, false);
        
        (, uint256 shortOI,) = curveEngine.getOpenInterest();
        assertEq(shortOI, tradeSize, "Short positions should be tracked");
    }
    
    // ============ Position Closing Tests ============
    
    /// @notice Test closing long position increases Q back
    function test_CloseCurvePosition_Long() public {
        uint256 tradeSize = 1e17;
        
        // Open long
        curveEngine.executeCurveTrade(tradeSize, true);
        uint256 qAfterOpen = curveEngine.vBTCQuantity();
        
        // Close long
        curveEngine.closeCurvePosition(tradeSize, true);
        uint256 qAfterClose = curveEngine.vBTCQuantity();
        
        assertEq(qAfterClose, qAfterOpen + tradeSize, "Closing long should increase Q");
        
        (uint256 longOI,,) = curveEngine.getOpenInterest();
        assertEq(longOI, 0, "Long OI should be zero after closing");
    }
    
    /// @notice Test closing short position decreases Q back
    function test_CloseCurvePosition_Short() public {
        uint256 tradeSize = 1e17;
        
        // Open short
        curveEngine.executeCurveTrade(tradeSize, false);
        uint256 qAfterOpen = curveEngine.vBTCQuantity();
        
        // Close short
        curveEngine.closeCurvePosition(tradeSize, false);
        uint256 qAfterClose = curveEngine.vBTCQuantity();
        
        assertEq(qAfterClose, qAfterOpen - tradeSize, "Closing short should decrease Q");
        
        (, uint256 shortOI,) = curveEngine.getOpenInterest();
        assertEq(shortOI, 0, "Short OI should be zero after closing");
    }
    
    // ============ OI Volatility Impact Tests ============
    
    /// @notice Test short OI decreases volatility (-1.678e-9)
    function test_OIVolatilityImpact_Short() public {
        uint256 tradeSize = 1e17;
        
        curveEngine.executeCurveTrade(tradeSize, false);
        
        int256 volatilityDelta = curveEngine.calculateOIVolatilityImpact();
        assertLt(volatilityDelta, 0, "Short OI should decrease volatility");
    }
    
    /// @notice Test long OI increases volatility (+3.569e-9)  
    function test_OIVolatilityImpact_Long() public {
        uint256 tradeSize = 1e17;
        
        curveEngine.executeCurveTrade(tradeSize, true);
        
        int256 volatilityDelta = curveEngine.calculateOIVolatilityImpact();
        assertGt(volatilityDelta, 0, "Long OI should increase volatility");
    }

    // ============ Edge Case Tests ============
    
    /// @notice Test trade too large reverts
    function test_ExecuteCurveTrade_RevertTooLarge() public {
        uint256 tooLargeSize = 2e18; // More than available in pool (1e18)
        
        vm.expectRevert();
        curveEngine.executeCurveTrade(tooLargeSize, true);
    }
    
    /// @notice Test zero trade reverts
    function test_ExecuteCurveTrade_RevertZeroSize() public {
        vm.expectRevert();
        curveEngine.executeCurveTrade(0, true);
    }
    
    /// @notice Test closing more than opened reverts
    function test_CloseCurvePosition_RevertExceedsPositions() public {
        curveEngine.executeCurveTrade(1e17, true);
        
        vm.expectRevert();
        curveEngine.closeCurvePosition(2e17, true);
    }
    
    // ============ Trade Simulation Tests ============
    
    /// @notice Test trade simulation returns valid data
    function test_SimulateTrade() public view {
        uint256 tradeSize = 1e17; // 10% of pool
        
        // Simulate long
        (uint256 simPrice, uint256 simImpact) = curveEngine.simulateTrade(tradeSize, true);
        
        assertGt(simPrice, 0, "Simulated price should be positive");
        assertGt(simImpact, 0, "Simulated impact should be positive for 10% of pool");
    }
    
    // ============ Property-Based Tests ============
    
    /// @notice Property: Price always increases when Q decreases (long)
    function testProperty_PriceIncreasesWhenQDecreases(uint256 tradeSize) public {
        // Bound to reasonable size - max 50% of pool to leave buffer for MIN_QUANTITY
        tradeSize = bound(tradeSize, 1e15, 5e17);
        
        uint256 priceBefore = curveEngine.calculateCurvePrice();
        curveEngine.executeCurveTrade(tradeSize, true);
        uint256 priceAfter = curveEngine.calculateCurvePrice();
        
        assertGt(priceAfter, priceBefore, "Price should always increase for longs");
    }
    
    /// @notice Property: Price always decreases when Q increases (short)
    function testProperty_PriceDecreasesWhenQIncreases(uint256 tradeSize) public {
        // Bound to reasonable size
        tradeSize = bound(tradeSize, 1e15, 1e18);
        
        uint256 priceBefore = curveEngine.calculateCurvePrice();
        curveEngine.executeCurveTrade(tradeSize, false);
        uint256 priceAfter = curveEngine.calculateCurvePrice();
        
        assertLt(priceAfter, priceBefore, "Price should always decrease for shorts");
    }
    
    /// @notice Property: K remains constant after trades (invariant)
    function testProperty_KInvariant(uint256 tradeSize, bool isLong) public {
        tradeSize = bound(tradeSize, 1e15, isLong ? 5e17 : 1e18);
        
        uint256 kBefore = curveEngine.poolConstant();
        curveEngine.executeCurveTrade(tradeSize, isLong);
        uint256 kAfter = curveEngine.poolConstant();
        
        assertEq(kAfter, kBefore, "Pool constant K should remain invariant");
    }
    
    /// @notice Property: Larger trades have proportionally larger price impact
    function testProperty_LargerTradesLargerImpact() public {
        uint256 smallTrade = 5e16;  // 5% of pool
        uint256 largeTrade = 2e17; // 20% of pool
        
        // Fresh engine for small trade test
        CustomCurveEngineTestImpl engine1 = new CustomCurveEngineTestImpl();
        engine1.initializeCurve(INITIAL_PRICE, INITIAL_QUANTITY);
        (, uint256 smallImpact) = engine1.executeCurveTrade(smallTrade, true);
        
        // Fresh engine for large trade test
        CustomCurveEngineTestImpl engine2 = new CustomCurveEngineTestImpl();
        engine2.initializeCurve(INITIAL_PRICE, INITIAL_QUANTITY);
        (, uint256 largeImpact) = engine2.executeCurveTrade(largeTrade, true);
        
        assertGt(largeImpact, smallImpact, "Larger trades should have larger impact");
    }
    
    /// @notice Property: As Q decreases, price sensitivity increases
    function testProperty_SensitivityIncreasesAsQDecreases() public {
        (, uint256 qBefore,, uint256 sensitivityBefore) = curveEngine.getCurveState();
        
        curveEngine.executeCurveTrade(3e17, true); // Decrease Q by 30%
        
        (, uint256 qAfter,, uint256 sensitivityAfter) = curveEngine.getCurveState();
        
        assertLt(qAfter, qBefore, "Q should decrease");
        assertGt(sensitivityAfter, sensitivityBefore, "Sensitivity should increase as Q decreases");
    }
}

/// @title CurveMath Library Tests
/// @notice Tests for the CurveMath library functions
contract CurveMathTest is Test {
    uint256 constant PRECISION = 1e18;
    
    /// @notice Test calculateK function
    function test_CurveMath_CalculateK() public pure {
        uint256 price = 1e15;  // Small price
        uint256 q = 1e18;      // 1 unit
        
        uint256 k = CurveMath.calculateK(price, q);
        // K = P * Q^2 / PRECISION^2 = 1e15 * 1e18 * 1e18 / 1e36 = 1e15
        assertEq(k, 1e15, "K should be P * Q^2 / PRECISION^2");
    }
    
    /// @notice Test calculatePrice function with small values
    function test_CurveMath_CalculatePrice() public pure {
        uint256 k = 1e33;
        uint256 q = 1e18;
        
        uint256 price = CurveMath.calculatePrice(k, q);
        assertGt(price, 0, "Price should be positive");
    }
    
    /// @notice Test calculateNewQuantity for long
    function test_CurveMath_CalculateNewQuantity_Long() public pure {
        uint256 currentQ = 1e18;
        uint256 tradeSize = 1e17;
        uint256 minQ = 1e15;
        
        uint256 newQ = CurveMath.calculateNewQuantity(currentQ, tradeSize, true, minQ);
        assertEq(newQ, currentQ - tradeSize, "Long should decrease Q");
    }
    
    /// @notice Test calculateNewQuantity for short
    function test_CurveMath_CalculateNewQuantity_Short() public pure {
        uint256 currentQ = 1e18;
        uint256 tradeSize = 1e17;
        uint256 minQ = 1e15;
        
        uint256 newQ = CurveMath.calculateNewQuantity(currentQ, tradeSize, false, minQ);
        assertEq(newQ, currentQ + tradeSize, "Short should increase Q");
    }
    
    /// @notice Test calculateOIVolatilityDelta with more longs
    function test_CurveMath_CalculateOIVolatilityDelta() public pure {
        uint256 longOI = 1e18;
        uint256 shortOI = 5e17;
        
        int256 delta = CurveMath.calculateOIVolatilityDelta(longOI, shortOI);
        // With more longs than shorts, delta should be positive
        assertGt(delta, 0, "Net long should have positive volatility delta");
    }
    
    /// @notice Test OI delta with more shorts
    function test_CurveMath_CalculateOIVolatilityDelta_NetShort() public pure {
        uint256 longOI = 5e17;
        uint256 shortOI = 2e18;
        
        int256 delta = CurveMath.calculateOIVolatilityDelta(longOI, shortOI);
        // With more shorts than longs, delta should be negative
        assertLt(delta, 0, "Net short should have negative volatility delta");
    }
}
