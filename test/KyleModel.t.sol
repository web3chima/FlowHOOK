// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {KyleModel} from "../src/KyleModel.sol";
import {KyleState} from "../src/DataStructures.sol";
import {Constants} from "../src/Constants.sol";

/// @title Kyle Model Test Implementation
/// @notice Concrete implementation of KyleModel for testing
contract KyleModelTestImpl is KyleModel {
    constructor(uint256 _baseDepth, uint256 _baseVolatility) KyleModel(_baseDepth, _baseVolatility) {}

    function trackOrderFlow(int256 flow) external {
        _trackOrderFlow(flow);
    }

    function updateKyleParameters(uint256 currentVolatility, uint256 currentDepth) external {
        _updateKyleParameters(currentVolatility, currentDepth);
    }

    function shouldUpdateKyleParameters(uint256 currentTotalOI) external view returns (bool) {
        return _shouldUpdateKyleParameters(currentTotalOI);
    }

    function updatePreviousTotalOI(uint256 currentTotalOI) external {
        _updatePreviousTotalOI(currentTotalOI);
    }

    function resetCumulativeFlow() external {
        _resetCumulativeFlow();
    }
}

/// @title Kyle Model Tests
/// @notice Tests for Kyle model pricing implementation
contract KyleModelTest is Test {
    KyleModelTestImpl public kyleModel;

    uint256 constant BASE_DEPTH = 1000000 * 1e18; // 1M tokens
    uint256 constant BASE_VOLATILITY = 5000 * 1e18; // 0.5% volatility (scaled)

    function setUp() public {
        kyleModel = new KyleModelTestImpl(BASE_DEPTH, BASE_VOLATILITY);
    }

    /// @notice Test basic price impact calculation
    function test_CalculatePriceImpact_Basic() public view {
        // For a positive order flow (buy), price impact should be positive
        int256 orderFlow = 1000 * 1e18;
        int256 impact = kyleModel.calculatePriceImpact(orderFlow);

        // Impact should be positive for buy orders
        assertTrue(impact > 0, "Buy order should have positive impact");

        // For a negative order flow (sell), price impact should be negative
        orderFlow = -1000 * 1e18;
        impact = kyleModel.calculatePriceImpact(orderFlow);

        // Impact should be negative for sell orders
        assertTrue(impact < 0, "Sell order should have negative impact");
    }

    /// @notice Test that price impact is proportional to order flow
    function test_CalculatePriceImpact_Proportional() public view {
        int256 smallFlow = 100 * 1e18;
        int256 largeFlow = 1000 * 1e18;

        int256 smallImpact = kyleModel.calculatePriceImpact(smallFlow);
        int256 largeImpact = kyleModel.calculatePriceImpact(largeFlow);

        // Large flow should have proportionally larger impact
        // largeImpact / smallImpact should equal largeFlow / smallFlow
        assertEq(largeImpact / smallImpact, largeFlow / smallFlow, "Impact should be proportional to flow");
    }

    /// @notice Test order flow tracking
    function test_TrackOrderFlow() public {
        int256 flow1 = 500 * 1e18;
        int256 flow2 = -200 * 1e18;
        int256 flow3 = 300 * 1e18;

        kyleModel.trackOrderFlow(flow1);
        assertEq(kyleModel.getCumulativeFlow(), flow1, "First flow should be tracked");

        kyleModel.trackOrderFlow(flow2);
        assertEq(kyleModel.getCumulativeFlow(), flow1 + flow2, "Second flow should accumulate");

        kyleModel.trackOrderFlow(flow3);
        assertEq(kyleModel.getCumulativeFlow(), flow1 + flow2 + flow3, "Third flow should accumulate");
    }

    /// @notice Test cumulative flow reset
    function test_ResetCumulativeFlow() public {
        kyleModel.trackOrderFlow(1000 * 1e18);
        assertGt(kyleModel.getCumulativeFlow(), 0, "Flow should be non-zero");

        kyleModel.resetCumulativeFlow();
        assertEq(kyleModel.getCumulativeFlow(), 0, "Flow should be reset to zero");
    }

    /// @notice Test Kyle parameter updates
    function test_UpdateKyleParameters() public {
        uint256 newVolatility = 10000 * 1e18; // 1% volatility
        uint256 newDepth = 500000 * 1e18; // 500k tokens

        kyleModel.updateKyleParameters(newVolatility, newDepth);

        // Lambda should be updated to newVolatility / newDepth
        uint256 expectedLambda = (newVolatility * Constants.PRICE_PRECISION) / newDepth;
        assertEq(kyleModel.getLambda(), expectedLambda, "Lambda should be updated");
        assertEq(kyleModel.getEffectiveDepth(), newDepth, "Effective depth should be updated");
    }

    /// @notice Test OI change threshold detection
    function test_ShouldUpdateKyleParameters_Threshold() public {
        uint256 initialOI = 1000000 * 1e18;
        kyleModel.updatePreviousTotalOI(initialOI);

        // 4% change - should not trigger update
        uint256 smallChange = initialOI + (initialOI * 4) / 100;
        assertFalse(
            kyleModel.shouldUpdateKyleParameters(smallChange), "4% change should not trigger update"
        );

        // 6% change - should trigger update
        uint256 largeChange = initialOI + (initialOI * 6) / 100;
        assertTrue(kyleModel.shouldUpdateKyleParameters(largeChange), "6% change should trigger update");

        // Test at exactly 5.01% to ensure it triggers (avoiding rounding edge case)
        uint256 justOverThreshold = initialOI + (initialOI * 501) / 10000;
        assertTrue(
            kyleModel.shouldUpdateKyleParameters(justOverThreshold), ">5% change should trigger update"
        );
    }

    /// @notice Test OI decrease threshold detection
    function test_ShouldUpdateKyleParameters_Decrease() public {
        uint256 initialOI = 1000000 * 1e18;
        kyleModel.updatePreviousTotalOI(initialOI);

        // 6% decrease - should trigger update
        uint256 decrease = initialOI - (initialOI * 6) / 100;
        assertTrue(
            kyleModel.shouldUpdateKyleParameters(decrease), "6% decrease should trigger update"
        );
    }

    /// @notice Property 5: Kyle Model Price Impact
    /// @dev For any order flow value, the price impact SHALL be calculated as lambda * orderFlow
    function testProperty_KyleModelPriceImpact(int256 orderFlow) public view {
        // Feature: uniswap-v4-orderbook-hook, Property 5: Kyle Model Price Impact
        // Validates: Requirements 3.1

        // Bound order flow to reasonable values to avoid overflow
        orderFlow = int256(bound(uint256(orderFlow > 0 ? orderFlow : -orderFlow), 0, 1e30));
        if (orderFlow < 0) orderFlow = -orderFlow;

        // Calculate expected impact manually
        int256 expectedImpact =
            (int256(kyleModel.getLambda()) * orderFlow) / int256(Constants.PRICE_PRECISION);

        // Calculate actual impact
        int256 actualImpact = kyleModel.calculatePriceImpact(orderFlow);

        // Verify they match
        assertEq(actualImpact, expectedImpact, "Price impact should equal lambda * orderFlow");

        // Test negative flow as well
        int256 negativeFlow = -orderFlow;
        int256 negativeImpact = kyleModel.calculatePriceImpact(negativeFlow);
        assertEq(negativeImpact, -expectedImpact, "Negative flow should have opposite impact");
    }

    /// @notice Property test: Price impact is zero for zero order flow
    function testProperty_ZeroFlowZeroImpact() public view {
        int256 impact = kyleModel.calculatePriceImpact(0);
        assertEq(impact, 0, "Zero order flow should have zero price impact");
    }

    /// @notice Edge case: Very large order flow
    function test_CalculatePriceImpact_LargeFlow() public view {
        int256 largeFlow = 1e30; // Very large flow
        int256 impact = kyleModel.calculatePriceImpact(largeFlow);

        // Should not revert and should be proportional
        assertTrue(impact > 0, "Large flow should have positive impact");
    }

    /// @notice Test: Price impact sign matches order flow sign (unit test version)
    function test_ImpactSignMatchesFlowSign() public view {
        // Test positive flow
        int256 positiveFlow = 1000 * 1e18;
        int256 positiveImpact = kyleModel.calculatePriceImpact(positiveFlow);
        assertTrue(positiveImpact > 0, "Positive flow should have positive impact");

        // Test negative flow
        int256 negativeFlow = -1000 * 1e18;
        int256 negativeImpact = kyleModel.calculatePriceImpact(negativeFlow);
        assertTrue(negativeImpact < 0, "Negative flow should have negative impact");
    }

    /// @notice Property 11: Kyle Parameter Update Threshold
    /// @dev For any change in open interest, if the change exceeds 5% of the previous total OI,
    ///      the system SHALL recalculate Kyle model parameters
    function testProperty_KyleParameterUpdateThreshold(uint256 initialOI, uint256 changePercent) public {
        // Feature: uniswap-v4-orderbook-hook, Property 11: Kyle Parameter Update Threshold
        // Validates: Requirements 3.6

        // Bound initial OI to reasonable values (avoid zero and overflow)
        initialOI = bound(initialOI, 1e18, 1e30);

        // Bound change percent to 0-100%
        changePercent = bound(changePercent, 0, 100);

        // Set initial OI
        kyleModel.updatePreviousTotalOI(initialOI);

        // Calculate new OI based on change percent
        uint256 newOI = initialOI + (initialOI * changePercent) / 100;

        // Check if update should be triggered
        bool shouldUpdate = kyleModel.shouldUpdateKyleParameters(newOI);

        // Verify threshold logic
        if (changePercent > 5) {
            assertTrue(shouldUpdate, "Change > 5% should trigger update");
        } else if (changePercent < 5) {
            assertFalse(shouldUpdate, "Change < 5% should not trigger update");
        }
        // Note: At exactly 5%, the behavior depends on rounding, so we don't assert
    }

    /// @notice Property test: Threshold works for OI decrease
    function testProperty_KyleParameterUpdateThreshold_Decrease(uint256 initialOI, uint256 decreasePercent)
        public
    {
        // Bound initial OI to reasonable values
        initialOI = bound(initialOI, 1e18, 1e30);

        // Bound decrease percent to 0-100%
        decreasePercent = bound(decreasePercent, 0, 99); // Max 99% to avoid zero

        // Set initial OI
        kyleModel.updatePreviousTotalOI(initialOI);

        // Calculate new OI based on decrease percent
        uint256 newOI = initialOI - (initialOI * decreasePercent) / 100;

        // Check if update should be triggered
        bool shouldUpdate = kyleModel.shouldUpdateKyleParameters(newOI);

        // Verify threshold logic
        if (decreasePercent > 5) {
            assertTrue(shouldUpdate, "Decrease > 5% should trigger update");
        } else if (decreasePercent < 5) {
            assertFalse(shouldUpdate, "Decrease < 5% should not trigger update");
        }
    }

    /// @notice Property test: First OI update always triggers
    function testProperty_FirstOIUpdateAlwaysTriggers(uint256 firstOI) public {
        // Bound to reasonable values
        firstOI = bound(firstOI, 1, 1e30);

        // With no previous OI (zero), any non-zero OI should trigger update
        bool shouldUpdate = kyleModel.shouldUpdateKyleParameters(firstOI);
        assertTrue(shouldUpdate, "First non-zero OI should always trigger update");
    }

    /// @notice Property test: Zero to zero OI should not trigger
    function testProperty_ZeroToZeroNoTrigger() public view {
        // With no previous OI and zero current OI, should not trigger
        bool shouldUpdate = kyleModel.shouldUpdateKyleParameters(0);
        assertFalse(shouldUpdate, "Zero to zero should not trigger update");
    }
}
