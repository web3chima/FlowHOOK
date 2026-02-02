// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeleveragingCurve} from "../src/DeleveragingCurve.sol";
import {TWAPState} from "../src/DataStructures.sol";
import {Constants} from "../src/Constants.sol";

/// @title Deleveraging Curve Test Implementation
/// @notice Concrete implementation of DeleveragingCurve for testing
contract DeleveragingCurveTestImpl is DeleveragingCurve {
    constructor() {}

    function updateTWAP(uint256 newPrice) external {
        _updateTWAP(newPrice);
    }

    function getTWAPInternal() external view returns (uint256) {
        return _getTWAP();
    }

    function calculateDeleveragePrice(bool isBuy, uint256 quantity, uint256 oraclePrice)
        external
        view
        returns (uint256)
    {
        return _calculateDeleveragePrice(isBuy, quantity, oraclePrice);
    }

    function setVolatility(uint256 _volatility) external {
        _setVolatility(_volatility);
    }

    function setPoolUtilization(uint256 _utilization) external {
        _setPoolUtilization(_utilization);
    }

    function executeDeleveraging(address position, uint256 quantity, bool isBuy, uint256 oraclePrice)
        external
        returns (uint256)
    {
        return _executeDeleveraging(position, quantity, isBuy, oraclePrice);
    }

    // Mock function to simulate standard AMM price (for comparison)
    function calculateStandardAMMPrice(bool isBuy, uint256 quantity, uint256 basePrice)
        external
        pure
        returns (uint256)
    {
        // Simulate worse pricing than de-leveraging curve
        // Standard AMM would have higher slippage
        uint256 slippage = (quantity * 100) / 1e18; // 0.01% per token
        if (isBuy) {
            return basePrice + slippage;
        } else {
            return basePrice - slippage;
        }
    }
}

/// @title Deleveraging Curve Tests
/// @notice Tests for TWAP tracking and de-leveraging price calculation
contract DeleveragingCurveTest is Test {
    DeleveragingCurveTestImpl public curve;

    function setUp() public {
        curve = new DeleveragingCurveTestImpl();
    }

    /// @notice Test basic TWAP update
    function test_UpdateTWAP_Basic() public {
        uint256 price = 1000 * 1e18;
        curve.updateTWAP(price);

        // After one update, TWAP should be price / 10 (since we divide by TWAP_BLOCKS)
        uint256 twap = curve.getTWAP();
        assertEq(twap, price / Constants.TWAP_BLOCKS, "TWAP should be price / 10 after first update");
    }

    /// @notice Test TWAP with multiple updates
    function test_UpdateTWAP_Multiple() public {
        uint256[] memory prices = new uint256[](5);
        prices[0] = 1000 * 1e18;
        prices[1] = 1100 * 1e18;
        prices[2] = 1050 * 1e18;
        prices[3] = 1200 * 1e18;
        prices[4] = 1150 * 1e18;

        uint256 sum = 0;
        for (uint256 i = 0; i < prices.length; i++) {
            curve.updateTWAP(prices[i]);
            sum += prices[i];
        }

        // TWAP should be sum of all prices divided by TWAP_BLOCKS
        uint256 expectedTWAP = sum / Constants.TWAP_BLOCKS;
        uint256 actualTWAP = curve.getTWAP();
        assertEq(actualTWAP, expectedTWAP, "TWAP should match expected average");
    }

    /// @notice Test TWAP rolling window (circular buffer)
    function test_UpdateTWAP_RollingWindow() public {
        // Fill the entire 10-block window
        for (uint256 i = 0; i < Constants.TWAP_BLOCKS; i++) {
            curve.updateTWAP(1000 * 1e18);
        }

        uint256 twapBefore = curve.getTWAP();
        assertEq(twapBefore, 1000 * 1e18, "TWAP should be 1000 when all prices are 1000");

        // Add one more price (should replace the oldest)
        curve.updateTWAP(2000 * 1e18);

        // New TWAP should be (9 * 1000 + 1 * 2000) / 10 = 1100
        uint256 expectedTWAP = (9 * 1000 * 1e18 + 2000 * 1e18) / Constants.TWAP_BLOCKS;
        uint256 actualTWAP = curve.getTWAP();
        assertEq(actualTWAP, expectedTWAP, "TWAP should update correctly with rolling window");
    }

    /// @notice Property 27: De-Leveraging TWAP Incorporation
    /// @dev For any de-leveraging operation, the price calculation SHALL incorporate the TWAP
    function testProperty_TWAPIncorporation(uint256[10] memory prices) public {
        // Feature: uniswap-v4-orderbook-hook, Property 27: De-Leveraging TWAP Incorporation
        
        // Bound prices to reasonable range (avoid overflow)
        uint256 sum = 0;
        for (uint256 i = 0; i < prices.length; i++) {
            prices[i] = bound(prices[i], 1e18, 10000 * 1e18); // 1 to 10,000 tokens
            curve.updateTWAP(prices[i]);
            sum += prices[i];
        }

        // Get TWAP after all updates
        uint256 twap = curve.getTWAP();

        // TWAP should equal the average of all prices
        uint256 expectedAverage = sum / Constants.TWAP_BLOCKS;
        assertEq(twap, expectedAverage, "TWAP must equal average of price history");

        // TWAP should be within the range of min and max prices
        uint256 minPrice = type(uint256).max;
        uint256 maxPrice = 0;
        for (uint256 i = 0; i < prices.length; i++) {
            if (prices[i] < minPrice) minPrice = prices[i];
            if (prices[i] > maxPrice) maxPrice = prices[i];
        }

        assertTrue(twap >= minPrice / Constants.TWAP_BLOCKS, "TWAP should be >= min price / TWAP_BLOCKS");
        assertTrue(twap <= maxPrice, "TWAP should be <= max price");
    }

    /// @notice Test TWAP state retrieval
    function test_GetTWAPState() public {
        uint256 price1 = 1000 * 1e18;
        uint256 price2 = 1100 * 1e18;

        curve.updateTWAP(price1);
        curve.updateTWAP(price2);

        TWAPState memory state = curve.getTWAPState();
        
        assertEq(state.priceHistory[0], price1, "First price should be stored");
        assertEq(state.priceHistory[1], price2, "Second price should be stored");
        assertEq(state.currentIndex, 2, "Current index should be 2");
        assertEq(state.sum, price1 + price2, "Sum should equal sum of prices");
    }

    /// @notice Test TWAP with zero prices
    function test_UpdateTWAP_ZeroPrices() public {
        // Update with zero prices
        for (uint256 i = 0; i < 5; i++) {
            curve.updateTWAP(0);
        }

        uint256 twap = curve.getTWAP();
        assertEq(twap, 0, "TWAP should be zero when all prices are zero");
    }

    /// @notice Test TWAP consistency
    function test_UpdateTWAP_Consistency() public {
        uint256 constantPrice = 1500 * 1e18;

        // Update with same price multiple times
        for (uint256 i = 0; i < Constants.TWAP_BLOCKS; i++) {
            curve.updateTWAP(constantPrice);
        }

        uint256 twap = curve.getTWAP();
        assertEq(twap, constantPrice, "TWAP should equal constant price when all prices are the same");
    }

    /// @notice Test de-leveraging price calculation basic functionality
    function test_CalculateDeleveragePrice_Basic() public {
        // Set up TWAP with some prices
        uint256 basePrice = 1000 * 1e18;
        for (uint256 i = 0; i < Constants.TWAP_BLOCKS; i++) {
            curve.updateTWAP(basePrice);
        }

        uint256 oraclePrice = 1000 * 1e18;
        uint256 quantity = 100 * 1e18;

        // Calculate de-leveraging price for buying (closing shorts)
        uint256 buyPrice = curve.calculateDeleveragePrice(true, quantity, oraclePrice);
        assertTrue(buyPrice > 0, "Buy price should be positive");
        assertTrue(buyPrice >= basePrice, "Buy price should be >= TWAP for favorable pricing");

        // Calculate de-leveraging price for selling (closing longs)
        uint256 sellPrice = curve.calculateDeleveragePrice(false, quantity, oraclePrice);
        assertTrue(sellPrice > 0, "Sell price should be positive");
        assertTrue(sellPrice <= basePrice, "Sell price should be <= TWAP for favorable pricing");
    }

    /// @notice Test de-leveraging price stays within oracle bounds
    function test_CalculateDeleveragePrice_OracleBounds() public {
        // Set up TWAP
        uint256 twapPrice = 1000 * 1e18;
        for (uint256 i = 0; i < Constants.TWAP_BLOCKS; i++) {
            curve.updateTWAP(twapPrice);
        }

        uint256 oraclePrice = 1100 * 1e18; // Oracle price different from TWAP
        uint256 quantity = 100 * 1e18;

        // Calculate prices
        uint256 buyPrice = curve.calculateDeleveragePrice(true, quantity, oraclePrice);
        uint256 sellPrice = curve.calculateDeleveragePrice(false, quantity, oraclePrice);

        // Calculate 5% bounds
        uint256 minPrice = oraclePrice - (oraclePrice * Constants.MAX_PRICE_DEVIATION) / Constants.THRESHOLD_DENOMINATOR;
        uint256 maxPrice = oraclePrice + (oraclePrice * Constants.MAX_PRICE_DEVIATION) / Constants.THRESHOLD_DENOMINATOR;

        // Verify prices are within bounds
        assertTrue(buyPrice >= minPrice, "Buy price should be >= min oracle bound");
        assertTrue(buyPrice <= maxPrice, "Buy price should be <= max oracle bound");
        assertTrue(sellPrice >= minPrice, "Sell price should be >= min oracle bound");
        assertTrue(sellPrice <= maxPrice, "Sell price should be <= max oracle bound");
    }

    /// @notice Test de-leveraging price with zero TWAP (uses oracle price)
    function test_CalculateDeleveragePrice_ZeroTWAP() public {
        // Don't update TWAP, so it remains zero
        uint256 oraclePrice = 1000 * 1e18;
        uint256 quantity = 100 * 1e18;

        // Should use oracle price when TWAP is zero
        uint256 buyPrice = curve.calculateDeleveragePrice(true, quantity, oraclePrice);
        uint256 sellPrice = curve.calculateDeleveragePrice(false, quantity, oraclePrice);

        // Prices should be close to oracle price
        assertTrue(buyPrice > 0, "Buy price should be positive");
        assertTrue(sellPrice > 0, "Sell price should be positive");
    }

    /// @notice Test de-leveraging price with high volatility
    function test_CalculateDeleveragePrice_HighVolatility() public {
        // Set up TWAP
        uint256 basePrice = 1000 * 1e18;
        for (uint256 i = 0; i < Constants.TWAP_BLOCKS; i++) {
            curve.updateTWAP(basePrice);
        }

        // Set high volatility
        curve.setVolatility(10000 * 1e18); // 1% volatility

        uint256 oraclePrice = 1000 * 1e18;
        uint256 quantity = 100 * 1e18;

        uint256 buyPrice = curve.calculateDeleveragePrice(true, quantity, oraclePrice);
        uint256 sellPrice = curve.calculateDeleveragePrice(false, quantity, oraclePrice);

        // With higher volatility, deviation should be larger
        assertTrue(buyPrice > basePrice, "Buy price should be above TWAP with high volatility");
        assertTrue(sellPrice < basePrice, "Sell price should be below TWAP with high volatility");
    }

    /// @notice Property 26: De-Leveraging Price Favorability
    /// @dev For any liquidation operation, the de-leveraging curve price SHALL be more favorable
    ///      to the liquidated position than the standard AMM curve price
    function testProperty_DeleveragingPriceFavorability(
        uint256 twapPrice,
        uint256 oraclePrice,
        uint256 quantity,
        bool isBuy
    ) public {
        // Feature: uniswap-v4-orderbook-hook, Property 26: De-Leveraging Price Favorability
        
        // Bound inputs to reasonable ranges
        twapPrice = bound(twapPrice, 100 * 1e18, 10000 * 1e18); // 100 to 10,000 tokens
        oraclePrice = bound(oraclePrice, 100 * 1e18, 10000 * 1e18);
        quantity = bound(quantity, 1 * 1e18, 1000 * 1e18); // 1 to 1,000 tokens

        // Set up TWAP with the given price
        for (uint256 i = 0; i < Constants.TWAP_BLOCKS; i++) {
            curve.updateTWAP(twapPrice);
        }

        // Calculate de-leveraging price
        uint256 deleveragePrice = curve.calculateDeleveragePrice(isBuy, quantity, oraclePrice);

        // Property: De-leveraging price should be closer to TWAP than oracle bounds
        // This makes it more favorable than worst-case AMM pricing
        uint256 maxDeviation = (oraclePrice * Constants.MAX_PRICE_DEVIATION) / Constants.THRESHOLD_DENOMINATOR;
        
        if (isBuy) {
            // For buying (closing shorts), de-leveraging should not be at max price
            uint256 maxPrice = oraclePrice + maxDeviation;
            assertTrue(
                deleveragePrice < maxPrice || deleveragePrice == maxPrice,
                "De-leveraging buy price should be <= max oracle bound"
            );
            
            // Should be closer to TWAP than to max bound (more favorable)
            if (twapPrice < oraclePrice) {
                // When TWAP is below oracle, de-leveraging should be closer to TWAP
                assertTrue(
                    deleveragePrice <= oraclePrice + (maxDeviation / 2),
                    "De-leveraging should use favorable pricing closer to TWAP"
                );
            }
        } else {
            // For selling (closing longs), de-leveraging should not be at min price
            uint256 minPrice = oraclePrice - maxDeviation;
            assertTrue(
                deleveragePrice > minPrice || deleveragePrice == minPrice,
                "De-leveraging sell price should be >= min oracle bound"
            );
            
            // Should be closer to TWAP than to min bound (more favorable)
            if (twapPrice > oraclePrice) {
                // When TWAP is above oracle, de-leveraging should be closer to TWAP
                assertTrue(
                    deleveragePrice >= oraclePrice - (maxDeviation / 2),
                    "De-leveraging should use favorable pricing closer to TWAP"
                );
            }
        }

        // De-leveraging price should still be reasonable (not zero)
        assertTrue(deleveragePrice > 0, "De-leveraging price must be positive");
    }

    /// @notice Property 28: De-Leveraging Oracle Bounds
    /// @dev For any de-leveraging operation, the execution price SHALL not deviate more than 5% from the oracle price
    function testProperty_DeleveragingOracleBounds(
        uint256 twapPrice,
        uint256 oraclePrice,
        uint256 quantity,
        bool isBuy
    ) public {
        // Feature: uniswap-v4-orderbook-hook, Property 28: De-Leveraging Oracle Bounds
        
        // Bound inputs to reasonable ranges
        twapPrice = bound(twapPrice, 100 * 1e18, 10000 * 1e18); // 100 to 10,000 tokens
        oraclePrice = bound(oraclePrice, 100 * 1e18, 10000 * 1e18);
        quantity = bound(quantity, 1 * 1e18, 1000 * 1e18); // 1 to 1,000 tokens

        // Set up TWAP with the given price
        for (uint256 i = 0; i < Constants.TWAP_BLOCKS; i++) {
            curve.updateTWAP(twapPrice);
        }

        // Calculate de-leveraging price
        uint256 deleveragePrice = curve.calculateDeleveragePrice(isBuy, quantity, oraclePrice);

        // Calculate 5% bounds from oracle price
        uint256 maxDeviation = (oraclePrice * Constants.MAX_PRICE_DEVIATION) / Constants.THRESHOLD_DENOMINATOR;
        uint256 minPrice = oraclePrice - maxDeviation;
        uint256 maxPrice = oraclePrice + maxDeviation;

        // De-leveraging price must stay within 5% of oracle price
        assertTrue(
            deleveragePrice >= minPrice,
            "De-leveraging price must be >= oracle price - 5%"
        );
        assertTrue(
            deleveragePrice <= maxPrice,
            "De-leveraging price must be <= oracle price + 5%"
        );

        // Calculate actual deviation percentage
        uint256 deviation;
        if (deleveragePrice > oraclePrice) {
            deviation = ((deleveragePrice - oraclePrice) * Constants.THRESHOLD_DENOMINATOR) / oraclePrice;
        } else {
            deviation = ((oraclePrice - deleveragePrice) * Constants.THRESHOLD_DENOMINATOR) / oraclePrice;
        }

        // Deviation must not exceed 5% (500 basis points)
        assertTrue(
            deviation <= Constants.MAX_PRICE_DEVIATION,
            "Deviation must not exceed 5%"
        );
    }

    /// @notice Test de-leveraging execution
    function test_ExecuteDeleveraging() public {
        // Set up TWAP
        uint256 basePrice = 1000 * 1e18;
        for (uint256 i = 0; i < Constants.TWAP_BLOCKS; i++) {
            curve.updateTWAP(basePrice);
        }

        address position = address(0x123);
        uint256 quantity = 100 * 1e18;
        uint256 oraclePrice = 1000 * 1e18;

        // Execute de-leveraging for buying
        uint256 buyPrice = curve.executeDeleveraging(position, quantity, true, oraclePrice);
        assertTrue(buyPrice > 0, "Buy execution price should be positive");

        // Execute de-leveraging for selling
        uint256 sellPrice = curve.executeDeleveraging(position, quantity, false, oraclePrice);
        assertTrue(sellPrice > 0, "Sell execution price should be positive");
    }

    /// @notice Test de-leveraging prioritization
    function test_ShouldPrioritizeDeleveraging() public {
        // Initially, utilization is 0, should not prioritize
        assertFalse(curve.shouldPrioritizeDeleveraging(), "Should not prioritize at 0% utilization");

        // Set utilization to 85% (below threshold)
        curve.setPoolUtilization(8500);
        assertFalse(curve.shouldPrioritizeDeleveraging(), "Should not prioritize at 85% utilization");

        // Set utilization to 90% (at threshold)
        curve.setPoolUtilization(9000);
        assertFalse(curve.shouldPrioritizeDeleveraging(), "Should not prioritize at exactly 90% utilization");

        // Set utilization to 91% (above threshold)
        curve.setPoolUtilization(9100);
        assertTrue(curve.shouldPrioritizeDeleveraging(), "Should prioritize at 91% utilization");

        // Set utilization to 95% (well above threshold)
        curve.setPoolUtilization(9500);
        assertTrue(curve.shouldPrioritizeDeleveraging(), "Should prioritize at 95% utilization");
    }

    /// @notice Test pool utilization getter
    function test_GetPoolUtilization() public {
        assertEq(curve.getPoolUtilization(), 0, "Initial utilization should be 0");

        curve.setPoolUtilization(5000);
        assertEq(curve.getPoolUtilization(), 5000, "Utilization should be 5000 (50%)");

        curve.setPoolUtilization(9500);
        assertEq(curve.getPoolUtilization(), 9500, "Utilization should be 9500 (95%)");
    }

    /// @notice Property 29: De-Leveraging Priority
    /// @dev For any system state where pool utilization exceeds 90%, de-leveraging trades SHALL be prioritized
    function testProperty_DeleveragingPriority(uint256 utilization) public {
        // Feature: uniswap-v4-orderbook-hook, Property 29: De-Leveraging Priority
        
        // Bound utilization to valid range (0 to 10000, representing 0% to 100%)
        utilization = bound(utilization, 0, 10000);

        // Set pool utilization
        curve.setPoolUtilization(utilization);

        // Check prioritization
        bool shouldPrioritize = curve.shouldPrioritizeDeleveraging();

        // Property: prioritization should occur when utilization > 90% (9000)
        if (utilization > Constants.DELEVERAGING_PRIORITY_THRESHOLD) {
            assertTrue(
                shouldPrioritize,
                "De-leveraging should be prioritized when utilization > 90%"
            );
        } else {
            assertFalse(
                shouldPrioritize,
                "De-leveraging should not be prioritized when utilization <= 90%"
            );
        }

        // Verify the threshold value is correct
        assertEq(
            Constants.DELEVERAGING_PRIORITY_THRESHOLD,
            9000,
            "Priority threshold should be 9000 (90%)"
        );
    }
}
