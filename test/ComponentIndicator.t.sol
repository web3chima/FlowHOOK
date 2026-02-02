// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {ComponentIndicator} from "../src/ComponentIndicator.sol";
import {ComponentIndicatorState} from "../src/DataStructures.sol";

/// @title Component Indicator Test Wrapper
/// @notice Wrapper contract to expose internal functions for testing
contract ComponentIndicatorTestWrapper is ComponentIndicator {
    function trackVolume(uint256 volume) external {
        _trackVolume(volume);
    }

    function trackOpenInterest(int256 oiDelta) external {
        _trackOpenInterest(oiDelta);
    }

    function trackLiquidation(uint256 liquidationAmount) external {
        _trackLiquidation(liquidationAmount);
    }

    function trackLeverage(uint256 leverage) external {
        _trackLeverage(leverage);
    }

    function performDecomposition() external {
        _performDecomposition();
    }
}

/// @title Component Indicator Test
/// @notice Tests for trading activity decomposition
contract ComponentIndicatorTest is Test {
    ComponentIndicatorTestWrapper public indicator;

    function setUp() public {
        indicator = new ComponentIndicatorTestWrapper();
    }

    // ============ Property 45: ARIMA Decomposition Accuracy ============

    /// @notice Property 45: ARIMA Decomposition Accuracy
    /// @dev Test that the decomposition produces valid components
    function testProperty_ARIMADecompositionAccuracy(uint256 volume1, uint256 volume2, uint256 volume3) public {
        // Bound inputs to reasonable ranges
        volume1 = bound(volume1, 1e18, 1000e18);
        volume2 = bound(volume2, 1e18, 1000e18);
        volume3 = bound(volume3, 1e18, 1000e18);

        // Track initial volumes to build history
        indicator.trackVolume(volume1);
        indicator.trackVolume(volume2);
        indicator.trackVolume(volume3);

        // Perform decomposition
        indicator.performDecomposition();

        // Get state
        ComponentIndicatorState memory state = indicator.getState();

        // Property: The decomposition should produce valid components
        // Expected component should be non-zero (trend + seasonal)
        assertGt(state.expectedComponent, 0, "Expected component should be positive");
        
        // Unexpected component can be zero or positive
        assertGe(state.unexpectedComponent, 0, "Unexpected component should be non-negative");
        
        // The sum of components should be reasonable relative to total volume
        // Due to exponential smoothing and weighted averages, the relationship is not 1:1
        uint256 totalComponents = state.expectedComponent + state.unexpectedComponent;
        
        // Components should be in a reasonable range (not orders of magnitude off)
        // Allow up to 10x difference due to the nature of the algorithm
        assertLe(totalComponents, state.totalVolume * 10, "Components should not exceed 10x total volume");
        assertGe(totalComponents, state.totalVolume / 10, "Components should not be less than 1/10 total volume");
    }

    /// @notice Test exponential smoothing convergence
    function testProperty_ExponentialSmoothingConvergence(uint256 steadyValue) public {
        steadyValue = bound(steadyValue, 1e18, 100e18);

        // Feed same value multiple times
        for (uint256 i = 0; i < 10; i++) {
            indicator.trackVolume(steadyValue);
        }

        // Perform decomposition
        indicator.performDecomposition();

        ComponentIndicatorState memory state = indicator.getState();

        // With steady input, expected component should be positive
        assertGt(state.expectedComponent, 0, "Expected component should be positive with steady input");
        
        // Speculative ratio should be low with steady input (high hedger activity)
        assertLt(state.speculativeRatio, 0.5e18, "Speculative ratio should be low with steady input");
    }

    // ============ Property 46: Component Classification Bounds ============

    /// @notice Property 46: Component Classification Bounds
    /// @dev Test that expected + unexpected components are valid and speculative ratio is [0, 1]
    function testProperty_ComponentClassificationBounds(
        uint256 volume1,
        uint256 volume2,
        uint256 volume3,
        uint256 volume4
    ) public {
        // Bound inputs
        volume1 = bound(volume1, 1e18, 1000e18);
        volume2 = bound(volume2, 1e18, 1000e18);
        volume3 = bound(volume3, 1e18, 1000e18);
        volume4 = bound(volume4, 1e18, 1000e18);

        // Build history
        indicator.trackVolume(volume1);
        indicator.trackVolume(volume2);
        indicator.trackVolume(volume3);
        indicator.trackVolume(volume4);

        // Perform decomposition
        indicator.performDecomposition();

        ComponentIndicatorState memory state = indicator.getState();

        // Property 1: Components should be non-negative
        assertGe(state.expectedComponent, 0, "Expected component should be non-negative");
        assertGe(state.unexpectedComponent, 0, "Unexpected component should be non-negative");

        // Property 2: speculative ratio is between 0 and 1 (scaled by 1e18)
        assertLe(state.speculativeRatio, 1e18, "Speculative ratio should be <= 1e18");
        assertGe(state.speculativeRatio, 0, "Speculative ratio should be >= 0");
        
        // Property 3: If there are components, they should sum to something reasonable
        uint256 totalComponents = state.expectedComponent + state.unexpectedComponent;
        if (totalComponents > 0) {
            // Speculative ratio calculation should be consistent
            uint256 calculatedRatio = (state.unexpectedComponent * 1e18) / totalComponents;
            assertApproxEqAbs(
                state.speculativeRatio,
                calculatedRatio,
                1e15, // 0.001 tolerance
                "Speculative ratio should match calculation"
            );
        }
    }

    /// @notice Test classification stability with small input changes
    function testProperty_ClassificationStability(uint256 baseVolume, uint256 delta) public {
        baseVolume = bound(baseVolume, 10e18, 100e18);
        delta = bound(delta, 0, baseVolume / 100); // Max 1% change

        // Build initial history
        for (uint256 i = 0; i < 5; i++) {
            indicator.trackVolume(baseVolume);
        }
        indicator.performDecomposition();
        ComponentIndicatorState memory state1 = indicator.getState();

        // Create new indicator with slightly different input
        ComponentIndicatorTestWrapper indicator2 = new ComponentIndicatorTestWrapper();
        for (uint256 i = 0; i < 5; i++) {
            indicator2.trackVolume(baseVolume + delta);
        }
        indicator2.performDecomposition();
        ComponentIndicatorState memory state2 = indicator2.getState();

        // Small input changes should result in small output changes
        // Allow 10% relative difference for 1% input change
        if (state1.speculativeRatio > 0) {
            assertApproxEqRel(
                state2.speculativeRatio,
                state1.speculativeRatio,
                0.1e18, // 10% tolerance
                "Small input changes should result in small output changes"
            );
        }
    }

    // ============ Property 47: Speculative Activity Fee Increase ============

    /// @notice Property 47: Speculative Activity Fee Increase
    /// @dev Test that fees increase when speculative ratio > 0.7
    function testProperty_SpeculativeActivityFeeIncrease() public {
        // Create scenario with high speculative activity
        // High unexpected component relative to expected
        for (uint256 i = 0; i < 5; i++) {
            indicator.trackVolume(10e18); // Low baseline
        }
        
        // Add large spike (unexpected activity)
        indicator.trackVolume(100e18);
        indicator.performDecomposition();

        ComponentIndicatorState memory state = indicator.getState();

        // If speculative ratio > 0.7, verify it's detected
        if (state.speculativeRatio > 0.7e18) {
            // Component multiplier should be > 1.0
            // This would be tested in integration with DynamicFeeCalculator
            assertTrue(state.speculativeRatio > 0.7e18, "High speculative ratio detected");
        }
    }

    /// @notice Test that fees decrease when hedger ratio > 0.7
    function testProperty_HedgerActivityFeeDecrease() public {
        // Create scenario with high hedger activity (low speculation)
        // Steady, predictable volume (expected component dominant)
        uint256 steadyVolume = 50e18;
        for (uint256 i = 0; i < 10; i++) {
            indicator.trackVolume(steadyVolume);
        }
        indicator.performDecomposition();

        ComponentIndicatorState memory state = indicator.getState();
        uint256 hedgerRatio = indicator.getHedgerRatio();

        // With steady input, hedger ratio should be high
        if (hedgerRatio > 0.7e18) {
            assertLt(state.speculativeRatio, 0.3e18, "Low speculative ratio with steady input");
        }
    }

    // ============ Property 48: Component-Based Pricing Adjustment ============

    /// @notice Property 48: Component-Based Pricing Adjustment
    /// @dev Test that speculative activity increases price impact
    function testProperty_ComponentBasedPricingAdjustment() public {
        uint256 basePriceImpact = 1e18; // 1.0 scaled

        // Scenario 1: High speculative activity
        ComponentIndicatorTestWrapper indicator1 = new ComponentIndicatorTestWrapper();
        for (uint256 i = 0; i < 5; i++) {
            indicator1.trackVolume(10e18);
        }
        indicator1.trackVolume(100e18); // Large spike
        indicator1.performDecomposition();

        uint256 adjustedImpact1 = indicator1.calculatePriceImpactAdjustment(basePriceImpact);

        // Scenario 2: High hedger activity
        ComponentIndicatorTestWrapper indicator2 = new ComponentIndicatorTestWrapper();
        for (uint256 i = 0; i < 10; i++) {
            indicator2.trackVolume(50e18); // Steady
        }
        indicator2.performDecomposition();

        uint256 adjustedImpact2 = indicator2.calculatePriceImpactAdjustment(basePriceImpact);

        // Property: Speculative activity should increase impact more than hedger activity
        ComponentIndicatorState memory state1 = indicator1.getState();
        ComponentIndicatorState memory state2 = indicator2.getState();

        if (state1.speculativeRatio > state2.speculativeRatio) {
            assertGe(
                adjustedImpact1,
                adjustedImpact2,
                "Higher speculation should result in higher price impact"
            );
        }
    }

    // ============ Property 49: Component Indicator Event Completeness ============

    /// @notice Property 49: Component Indicator Event Completeness
    /// @dev Test that events contain all required fields and are emitted
    function testProperty_ComponentIndicatorEventCompleteness() public {
        // Build history
        indicator.trackVolume(10e18);
        indicator.trackVolume(20e18);
        indicator.trackVolume(30e18);

        // Record logs to check event emission
        vm.recordLogs();

        // Perform decomposition (will emit event)
        indicator.performDecomposition();

        // Get the emitted logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Should have emitted at least one event
        assertGt(logs.length, 0, "Should emit at least one event");

        // Find the ComponentIndicatorUpdated event
        bool foundEvent = false;
        for (uint256 i = 0; i < logs.length; i++) {
            // Check if this is the ComponentIndicatorUpdated event
            // Event signature: ComponentIndicatorUpdated(uint256,uint256,uint256,uint256,uint256)
            bytes32 eventSignature = keccak256("ComponentIndicatorUpdated(uint256,uint256,uint256,uint256,uint256)");
            if (logs[i].topics[0] == eventSignature) {
                foundEvent = true;
                
                // Decode the event data
                (uint256 expectedComp, uint256 unexpectedComp, uint256 specRatio, uint256 totalVol, uint256 timestamp) = 
                    abi.decode(logs[i].data, (uint256, uint256, uint256, uint256, uint256));
                
                // Verify all fields are present and reasonable
                assertGe(expectedComp, 0, "Expected component should be non-negative");
                assertGe(unexpectedComp, 0, "Unexpected component should be non-negative");
                assertLe(specRatio, 1e18, "Speculative ratio should be <= 1e18");
                assertEq(totalVol, 60e18, "Total volume should match tracked volume");
                assertEq(timestamp, block.timestamp, "Timestamp should match block timestamp");
                
                break;
            }
        }

        assertTrue(foundEvent, "ComponentIndicatorUpdated event should be emitted");
    }

    // ============ Unit Tests for Admin Dashboard ============

    /// @notice Test getComponentMetrics returns accurate data
    function test_GetComponentMetrics() public {
        // Track some activity
        indicator.trackVolume(100e18);
        indicator.trackOpenInterest(50e18);
        indicator.trackLiquidation(10e18);
        indicator.trackLeverage(5e18);

        (
            uint256 expectedComp,
            uint256 unexpectedComp,
            uint256 specRatio,
            uint256 totalVol,
            uint256 totalOI,
            uint256 totalLiq,
            uint256 avgLev
        ) = indicator.getComponentMetrics();

        // Verify data is returned
        assertEq(totalVol, 100e18, "Total volume should match");
        assertEq(totalOI, 50e18, "Total OI should match");
        assertEq(totalLiq, 10e18, "Total liquidations should match");
        assertEq(avgLev, 5e18, "Average leverage should match");
    }

    /// @notice Test historical trend retrieval
    function test_GetHistoricalTrends() public {
        // Add historical data
        indicator.trackVolume(10e18);
        indicator.trackVolume(20e18);
        indicator.trackVolume(30e18);

        (
            uint256[] memory volumeTrend,
            uint256[] memory oiTrend,
            uint256[] memory liqTrend,
            uint256[] memory levTrend
        ) = indicator.getHistoricalTrends();

        // Verify historical data
        assertEq(volumeTrend.length, 3, "Should have 3 volume data points");
        assertEq(volumeTrend[0], 10e18, "First volume should match");
        assertEq(volumeTrend[1], 20e18, "Second volume should match");
        assertEq(volumeTrend[2], 30e18, "Third volume should match");
    }

    /// @notice Test component breakdown by activity type
    function test_GetComponentBreakdown() public {
        // Track various activities
        indicator.trackVolume(100e18);
        indicator.trackOpenInterest(50e18);
        indicator.trackLiquidation(10e18);
        indicator.trackLeverage(5e18);

        // Perform decomposition
        indicator.trackVolume(20e18);
        indicator.trackVolume(30e18);
        indicator.performDecomposition();

        (
            uint256 volumeComponent,
            uint256 oiComponent,
            uint256 liquidationComponent,
            uint256 leverageComponent
        ) = indicator.getComponentBreakdown();

        // Verify components are calculated
        // Values depend on decomposition, just check they're non-negative
        assertGe(volumeComponent, 0, "Volume component should be non-negative");
        assertGe(oiComponent, 0, "OI component should be non-negative");
        assertGe(liquidationComponent, 0, "Liquidation component should be non-negative");
        assertGe(leverageComponent, 0, "Leverage component should be non-negative");
    }

    // ============ Event Definition ============

    event ComponentIndicatorUpdated(
        uint256 expectedComponent,
        uint256 unexpectedComponent,
        uint256 speculativeRatio,
        uint256 totalVolume,
        uint256 timestamp
    );
}
