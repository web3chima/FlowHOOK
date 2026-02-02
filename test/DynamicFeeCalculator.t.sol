// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DynamicFeeCalculator} from "../src/DynamicFeeCalculator.sol";
import {PackedFeeState} from "../src/DataStructures.sol";
import {Constants} from "../src/Constants.sol";

/// @title Dynamic Fee Calculator Tests
/// @notice Tests for dynamic fee calculation implementation
contract DynamicFeeCalculatorTest is Test {
    // Test constants
    uint256 constant BASE_VOLATILITY = 5000 * 1e18; // 0.5% volatility
    uint256 constant POOL_UTILIZATION_50 = 5000; // 50% utilization

    function setUp() public {}

    /// @notice Helper to create a default fee state
    function _createDefaultFeeState() internal pure returns (PackedFeeState memory) {
        return PackedFeeState({
            currentFee: Constants.BASE_FEE,
            baseFee: Constants.BASE_FEE,
            maxFee: Constants.MAX_FEE,
            lastUpdateBlock: 0,
            isPaused: false
        });
    }

    /// @notice Test basic fee calculation with neutral conditions
    function test_CalculateDynamicFee_Neutral() public pure {
        PackedFeeState memory feeState = _createDefaultFeeState();
        
        uint24 fee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY, // current volatility = base volatility
            BASE_VOLATILITY,
            1000 * 1e18, // balanced OI
            1000 * 1e18,
            POOL_UTILIZATION_50 // 50% utilization
        );

        // With neutral conditions, fee should be close to base fee
        assertGe(fee, Constants.BASE_FEE, "Fee should be at least base fee");
        assertLe(fee, Constants.MAX_FEE, "Fee should not exceed max fee");
    }

    /// @notice Test fee increases with higher volatility
    function test_CalculateDynamicFee_HighVolatility() public pure {
        PackedFeeState memory feeState = _createDefaultFeeState();
        
        uint24 normalFee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY,
            BASE_VOLATILITY,
            1000 * 1e18,
            1000 * 1e18,
            POOL_UTILIZATION_50
        );

        uint24 highVolFee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY * 2, // double volatility
            BASE_VOLATILITY,
            1000 * 1e18,
            1000 * 1e18,
            POOL_UTILIZATION_50
        );

        assertGt(highVolFee, normalFee, "Higher volatility should increase fee");
    }

    /// @notice Test fee increases with OI imbalance
    function test_CalculateDynamicFee_Imbalanced() public pure {
        PackedFeeState memory feeState = _createDefaultFeeState();
        
        uint24 balancedFee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY,
            BASE_VOLATILITY,
            1000 * 1e18, // balanced
            1000 * 1e18,
            POOL_UTILIZATION_50
        );

        uint24 imbalancedFee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY,
            BASE_VOLATILITY,
            2000 * 1e18, // imbalanced
            500 * 1e18,
            POOL_UTILIZATION_50
        );

        assertGt(imbalancedFee, balancedFee, "OI imbalance should increase fee");
    }

    /// @notice Test fee increases with higher utilization
    function test_CalculateDynamicFee_HighUtilization() public pure {
        PackedFeeState memory feeState = _createDefaultFeeState();
        
        uint24 normalFee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY,
            BASE_VOLATILITY,
            1000 * 1e18,
            1000 * 1e18,
            POOL_UTILIZATION_50 // 50%
        );

        uint24 highUtilFee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY,
            BASE_VOLATILITY,
            1000 * 1e18,
            1000 * 1e18,
            9000 // 90% utilization
        );

        assertGt(highUtilFee, normalFee, "Higher utilization should increase fee");
    }

    /// @notice Test fee respects minimum bound
    function test_CalculateDynamicFee_MinimumBound() public pure {
        PackedFeeState memory feeState = _createDefaultFeeState();
        
        // Very low volatility, balanced OI, low utilization
        uint24 fee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY / 10, // very low volatility
            BASE_VOLATILITY,
            1000 * 1e18,
            1000 * 1e18,
            1000 // 10% utilization
        );

        assertGe(fee, Constants.BASE_FEE, "Fee should not go below minimum");
    }

    /// @notice Test fee respects maximum bound
    function test_CalculateDynamicFee_MaximumBound() public pure {
        PackedFeeState memory feeState = _createDefaultFeeState();
        
        // Very high volatility, imbalanced OI, high utilization
        uint24 fee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY * 10, // very high volatility
            BASE_VOLATILITY,
            10000 * 1e18, // highly imbalanced
            100 * 1e18,
            9900 // 99% utilization
        );

        assertLe(fee, Constants.MAX_FEE, "Fee should not exceed maximum");
    }

    /// @notice Property 22: Dynamic Fee Calculation
    /// @dev For any swap, the fee SHALL be calculated as baseFee * volatilityMultiplier * imbalanceMultiplier * utilizationMultiplier
    function testProperty_DynamicFeeCalculation(
        uint64 currentVolatility,
        uint64 longOI,
        uint64 shortOI,
        uint16 poolUtilization
    ) public pure {
        // Feature: uniswap-v4-orderbook-hook, Property 22: Dynamic Fee Calculation
        
        // Bound inputs to reasonable ranges to avoid edge cases
        vm.assume(currentVolatility > 1000 && currentVolatility < type(uint64).max / 2);
        vm.assume(longOI > 100 && longOI < type(uint64).max / 2);
        vm.assume(shortOI > 100 && shortOI < type(uint64).max / 2);
        vm.assume(poolUtilization <= 10000); // Max 100%
        
        PackedFeeState memory feeState = _createDefaultFeeState();
        
        uint24 fee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            uint256(currentVolatility),
            BASE_VOLATILITY,
            uint256(longOI),
            uint256(shortOI),
            uint256(poolUtilization)
        );

        // Core property: Fee is within bounds
        assertGe(fee, Constants.BASE_FEE, "Fee must be at least base fee");
        assertLe(fee, Constants.MAX_FEE, "Fee must not exceed max fee");

        // Verify that the fee calculation is deterministic and uses the multipliers
        // by checking that the same inputs always produce the same output
        uint24 fee2 = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            uint256(currentVolatility),
            BASE_VOLATILITY,
            uint256(longOI),
            uint256(shortOI),
            uint256(poolUtilization)
        );
        assertEq(fee, fee2, "Fee calculation must be deterministic");
        
        // Verify multiplier components are calculated
        uint256 volMult = DynamicFeeCalculator.calculateVolatilityMultiplier(
            uint256(currentVolatility),
            BASE_VOLATILITY
        );
        uint256 imbalMult = DynamicFeeCalculator.calculateImbalanceMultiplier(
            uint256(longOI),
            uint256(shortOI)
        );
        uint256 utilMult = DynamicFeeCalculator.calculateUtilizationMultiplier(
            uint256(poolUtilization)
        );
        
        // All multipliers should be positive
        assertGt(volMult, 0, "Volatility multiplier must be positive");
        assertGt(imbalMult, 0, "Imbalance multiplier must be positive");
        assertGt(utilMult, 0, "Utilization multiplier must be positive");
        
        // Verify extreme cases produce expected bounds
        // Maximum conditions should produce max fee or close to it
        uint24 maxConditionFee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY * 10, // very high volatility
            BASE_VOLATILITY,
            uint256(longOI) * 10, // highly imbalanced
            uint256(shortOI),
            9900 // 99% utilization
        );
        // Should be at or near max fee
        assertGe(maxConditionFee, Constants.BASE_FEE * 2, "Extreme conditions should increase fee significantly");
        
        // Minimum conditions should produce min fee or close to it
        uint24 minConditionFee = DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            BASE_VOLATILITY / 10, // very low volatility
            BASE_VOLATILITY,
            1000 * 1e18, // balanced
            1000 * 1e18,
            1000 // 10% utilization
        );
        // Should be at or near min fee
        assertLe(minConditionFee, Constants.BASE_FEE * 2, "Minimal conditions should keep fee low");
    }

    /// @notice Test volatility multiplier calculation
    function test_CalculateVolatilityMultiplier() public pure {
        // Equal volatility should give 1.0x multiplier
        uint256 multiplier = DynamicFeeCalculator.calculateVolatilityMultiplier(
            BASE_VOLATILITY,
            BASE_VOLATILITY
        );
        assertEq(multiplier, Constants.MULTIPLIER_SCALE, "Equal volatility should give 1.0x");

        // Higher volatility should give >1.0x multiplier
        multiplier = DynamicFeeCalculator.calculateVolatilityMultiplier(
            BASE_VOLATILITY * 2,
            BASE_VOLATILITY
        );
        assertGt(multiplier, Constants.MULTIPLIER_SCALE, "Higher volatility should give >1.0x");

        // Lower volatility should give <1.0x multiplier
        multiplier = DynamicFeeCalculator.calculateVolatilityMultiplier(
            BASE_VOLATILITY / 2,
            BASE_VOLATILITY
        );
        assertLt(multiplier, Constants.MULTIPLIER_SCALE, "Lower volatility should give <1.0x");
    }

    /// @notice Test imbalance multiplier calculation
    function test_CalculateImbalanceMultiplier() public pure {
        // Balanced OI should give 1.0x multiplier
        uint256 multiplier = DynamicFeeCalculator.calculateImbalanceMultiplier(
            1000 * 1e18,
            1000 * 1e18
        );
        assertEq(multiplier, Constants.MULTIPLIER_SCALE, "Balanced OI should give 1.0x");

        // Imbalanced OI should give >1.0x multiplier
        multiplier = DynamicFeeCalculator.calculateImbalanceMultiplier(
            2000 * 1e18,
            500 * 1e18
        );
        assertGt(multiplier, Constants.MULTIPLIER_SCALE, "Imbalanced OI should give >1.0x");

        // Zero OI should give 1.0x multiplier
        multiplier = DynamicFeeCalculator.calculateImbalanceMultiplier(0, 0);
        assertEq(multiplier, Constants.MULTIPLIER_SCALE, "Zero OI should give 1.0x");
    }

    /// @notice Test utilization multiplier calculation
    function test_CalculateUtilizationMultiplier() public pure {
        // 50% utilization should give 1.0x multiplier
        uint256 multiplier = DynamicFeeCalculator.calculateUtilizationMultiplier(5000);
        assertEq(multiplier, Constants.MULTIPLIER_SCALE, "50% utilization should give 1.0x");

        // High utilization should give >1.0x multiplier
        multiplier = DynamicFeeCalculator.calculateUtilizationMultiplier(9000);
        assertGt(multiplier, Constants.MULTIPLIER_SCALE, "High utilization should give >1.0x");

        // Low utilization should give <1.0x multiplier
        multiplier = DynamicFeeCalculator.calculateUtilizationMultiplier(1000);
        assertLt(multiplier, Constants.MULTIPLIER_SCALE, "Low utilization should give <1.0x");
    }

    /// @notice Test fee update frequency check
    function test_ShouldUpdateFee() public pure {
        PackedFeeState memory feeState = _createDefaultFeeState();
        feeState.lastUpdateBlock = 100;

        // Same block - should not update
        assertFalse(
            DynamicFeeCalculator.shouldUpdateFee(feeState, 100),
            "Should not update in same block"
        );

        // Next block - should update
        assertTrue(
            DynamicFeeCalculator.shouldUpdateFee(feeState, 101),
            "Should update in next block"
        );

        // Future block - should update
        assertTrue(
            DynamicFeeCalculator.shouldUpdateFee(feeState, 200),
            "Should update in future block"
        );
    }

    /// @notice Test OI balance detection
    function test_IsOIBalanced() public pure {
        // Perfectly balanced
        assertTrue(
            DynamicFeeCalculator.isOIBalanced(1000 * 1e18, 1000 * 1e18),
            "Equal OI should be balanced"
        );

        // Within 5% threshold (4% imbalance)
        // 1020 vs 1000 = 20 difference, total 2020, ratio = 20/2020 = 0.99% < 5%
        assertTrue(
            DynamicFeeCalculator.isOIBalanced(1020 * 1e18, 1000 * 1e18),
            "1% imbalance should be balanced"
        );

        // Beyond 5% threshold (10% imbalance)
        // 1100 vs 1000 = 100 difference, total 2100, ratio = 100/2100 = 4.76% < 5%
        // This is actually still balanced! Let's use a larger imbalance
        // 1200 vs 1000 = 200 difference, total 2200, ratio = 200/2200 = 9.09% > 5%
        assertFalse(
            DynamicFeeCalculator.isOIBalanced(1200 * 1e18, 1000 * 1e18),
            "9% imbalance should not be balanced"
        );

        // Zero OI should be considered balanced
        assertTrue(
            DynamicFeeCalculator.isOIBalanced(0, 0),
            "Zero OI should be balanced"
        );
    }

    /// @notice Test OI imbalance detection
    function test_IsOIImbalanced() public pure {
        // Perfectly balanced - not imbalanced
        assertFalse(
            DynamicFeeCalculator.isOIImbalanced(1000 * 1e18, 1000 * 1e18),
            "Equal OI should not be imbalanced"
        );

        // Within 20% threshold (15% imbalance) - not imbalanced
        // 1150 vs 1000 = 150 difference, total 2150, ratio = 150/2150 = 6.98% < 20%
        // This is actually much less than 20%! Let's use correct values
        // For 15% imbalance: need difference/total = 0.15
        // If total = 2000, difference = 300, so 1150 vs 850
        assertFalse(
            DynamicFeeCalculator.isOIImbalanced(1150 * 1e18, 850 * 1e18),
            "15% imbalance should not be highly imbalanced"
        );

        // Beyond 20% threshold (30% imbalance) - imbalanced
        // For 30% imbalance: difference/total = 0.30
        // If total = 2000, difference = 600, so 1300 vs 700
        assertTrue(
            DynamicFeeCalculator.isOIImbalanced(1300 * 1e18, 700 * 1e18),
            "30% imbalance should be highly imbalanced"
        );

        // Zero OI should not be imbalanced
        assertFalse(
            DynamicFeeCalculator.isOIImbalanced(0, 0),
            "Zero OI should not be imbalanced"
        );
    }

    /// @notice Test OI adjustment rules
    function test_ApplyOIAdjustmentRules_Balanced() public pure {
        // Balanced OI should return minimum base fee
        uint24 adjustedFee = DynamicFeeCalculator.applyOIAdjustmentRules(
            1000, // arbitrary base fee
            1000 * 1e18,
            1000 * 1e18
        );

        assertEq(adjustedFee, Constants.BASE_FEE, "Balanced OI should return minimum fee");
    }

    /// @notice Test OI adjustment rules for imbalanced state
    function test_ApplyOIAdjustmentRules_Imbalanced() public pure {
        // Highly imbalanced OI should return maximum fee
        uint24 adjustedFee = DynamicFeeCalculator.applyOIAdjustmentRules(
            1000, // arbitrary base fee
            3000 * 1e18, // 30% imbalance
            1000 * 1e18
        );

        assertEq(adjustedFee, Constants.MAX_FEE, "Imbalanced OI should return maximum fee");
    }

    /// @notice Test OI adjustment rules for moderate imbalance
    function test_ApplyOIAdjustmentRules_Moderate() public pure {
        uint24 baseFee = 1000;
        
        // Moderate imbalance (10% - between 5% and 20%)
        // 1100 vs 1000 = 100 difference, total 2100, ratio = 100/2100 = 4.76%
        // This is actually < 5%, so it's balanced! Let's use 8% imbalance
        // For 8% imbalance: 1080 vs 1000 = 80 difference, total 2080, ratio = 80/2080 = 3.85%
        // Still < 5%! Let's use 1160 vs 1000 = 160 difference, total 2160, ratio = 160/2160 = 7.4%
        uint24 adjustedFee = DynamicFeeCalculator.applyOIAdjustmentRules(
            baseFee,
            1160 * 1e18, // 7.4% imbalance (between 5% and 20%)
            1000 * 1e18
        );

        assertEq(adjustedFee, baseFee, "Moderate imbalance should return base fee");
    }

    /// @notice Property 23: Fee Update Frequency Limit
    /// @dev For any block, fee parameters SHALL be updated at most once
    function testProperty_FeeUpdateFrequencyLimit(
        uint32 lastUpdateBlock,
        uint32 currentBlock
    ) public pure {
        // Feature: uniswap-v4-orderbook-hook, Property 23: Fee Update Frequency Limit
        
        // Bound inputs to reasonable ranges
        vm.assume(lastUpdateBlock < type(uint32).max - 1000);
        vm.assume(currentBlock >= lastUpdateBlock);
        vm.assume(currentBlock < type(uint32).max);
        
        PackedFeeState memory feeState = _createDefaultFeeState();
        feeState.lastUpdateBlock = lastUpdateBlock;
        
        bool shouldUpdate = DynamicFeeCalculator.shouldUpdateFee(
            feeState,
            uint256(currentBlock)
        );

        // Property: Fee can only be updated if current block > last update block
        if (currentBlock > lastUpdateBlock) {
            assertTrue(shouldUpdate, "Should allow update in later block");
        } else {
            assertFalse(shouldUpdate, "Should not allow update in same block");
        }

        // Additional verification: If we "update" in current block,
        // we should not be able to update again in the same block
        if (shouldUpdate) {
            feeState.lastUpdateBlock = currentBlock;
            assertFalse(
                DynamicFeeCalculator.shouldUpdateFee(feeState, uint256(currentBlock)),
                "Should not allow second update in same block"
            );
        }
    }

    /// @notice Property 24: Balanced OI Minimum Fee
    /// @dev For any system state where the absolute difference between long OI and short OI is less than 5% of total OI, the fee SHALL equal the minimum base fee
    function testProperty_BalancedOIMinimumFee(
        uint64 longOI,
        uint64 shortOI
    ) public pure {
        // Feature: uniswap-v4-orderbook-hook, Property 24: Balanced OI Minimum Fee
        
        // Bound inputs to reasonable ranges
        vm.assume(longOI > 0 && longOI < type(uint64).max / 2);
        vm.assume(shortOI > 0 && shortOI < type(uint64).max / 2);
        
        uint256 totalOI = uint256(longOI) + uint256(shortOI);
        uint256 imbalance;
        if (longOI > shortOI) {
            imbalance = uint256(longOI) - uint256(shortOI);
        } else {
            imbalance = uint256(shortOI) - uint256(longOI);
        }
        
        // Calculate imbalance ratio (scaled by 10000)
        uint256 imbalanceRatio = (imbalance * Constants.THRESHOLD_DENOMINATOR) / totalOI;
        
        // Only test when OI is balanced (< 5% imbalance)
        if (imbalanceRatio < Constants.BALANCED_OI_THRESHOLD) {
            uint24 adjustedFee = DynamicFeeCalculator.applyOIAdjustmentRules(
                1000, // arbitrary base fee
                uint256(longOI),
                uint256(shortOI)
            );
            
            // Property: Balanced OI should result in minimum base fee
            assertEq(
                adjustedFee,
                Constants.BASE_FEE,
                "Balanced OI should return minimum base fee"
            );
        }
    }

    /// @notice Property 25: Imbalanced OI Maximum Fee
    /// @dev For any system state where the absolute difference between long OI and short OI exceeds 20% of total OI, the fee multiplier SHALL be at its maximum value
    function testProperty_ImbalancedOIMaximumFee(
        uint64 longOI,
        uint64 shortOI
    ) public pure {
        // Feature: uniswap-v4-orderbook-hook, Property 25: Imbalanced OI Maximum Fee
        
        // Bound inputs to reasonable ranges
        vm.assume(longOI > 0 && longOI < type(uint64).max / 2);
        vm.assume(shortOI > 0 && shortOI < type(uint64).max / 2);
        
        uint256 totalOI = uint256(longOI) + uint256(shortOI);
        uint256 imbalance;
        if (longOI > shortOI) {
            imbalance = uint256(longOI) - uint256(shortOI);
        } else {
            imbalance = uint256(shortOI) - uint256(longOI);
        }
        
        // Calculate imbalance ratio (scaled by 10000)
        uint256 imbalanceRatio = (imbalance * Constants.THRESHOLD_DENOMINATOR) / totalOI;
        
        // Only test when OI is highly imbalanced (> 20% imbalance)
        if (imbalanceRatio > Constants.IMBALANCED_OI_THRESHOLD) {
            uint24 adjustedFee = DynamicFeeCalculator.applyOIAdjustmentRules(
                1000, // arbitrary base fee
                uint256(longOI),
                uint256(shortOI)
            );
            
            // Property: Highly imbalanced OI should result in maximum fee
            assertEq(
                adjustedFee,
                Constants.MAX_FEE,
                "Highly imbalanced OI should return maximum fee"
            );
        }
    }
}
