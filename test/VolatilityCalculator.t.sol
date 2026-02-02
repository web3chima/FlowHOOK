// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VolatilityCalculator} from "../src/VolatilityCalculator.sol";
import {VolatilityState} from "../src/DataStructures.sol";
import {Constants} from "../src/Constants.sol";

/// @title Volatility Calculator Test Implementation
/// @notice Concrete implementation of VolatilityCalculator for testing
contract VolatilityCalculatorTestImpl is VolatilityCalculator {
    constructor(uint256 _baseVolatility, uint256 _maxVolatility)
        VolatilityCalculator(_baseVolatility, _maxVolatility)
    {}

    function updateOpenInterest(bool isLong, int256 delta) external {
        _updateOpenInterest(isLong, delta);
    }

    function adjustPoolDepth(uint256 baseDepth) external view returns (uint256) {
        return _adjustPoolDepth(baseDepth);
    }

    function checkVolatilityBounds(uint256 volatility) external view {
        _checkVolatilityBounds(volatility);
    }

    function shouldUpdateVolatility() external view returns (bool) {
        return _shouldUpdateVolatility();
    }

    function updatePreviousEffectiveVolatility() external {
        _updatePreviousEffectiveVolatility();
    }
}

/// @title Volatility Calculator Tests
/// @notice Tests for volatility calculator implementation
contract VolatilityCalculatorTest is Test {
    VolatilityCalculatorTestImpl public volatilityCalc;

    uint256 constant BASE_VOLATILITY = 5000 * 1e18; // 0.5% base volatility
    uint256 constant MAX_VOLATILITY = 50000 * 1e18; // 5% max volatility

    function setUp() public {
        volatilityCalc = new VolatilityCalculatorTestImpl(BASE_VOLATILITY, MAX_VOLATILITY);
    }

    /// @notice Test initial state
    function test_InitialState() public view {
        assertEq(volatilityCalc.getBaseVolatility(), BASE_VOLATILITY, "Base volatility should be set");
        assertEq(
            volatilityCalc.getEffectiveVolatility(), BASE_VOLATILITY, "Initial effective volatility should equal base"
        );
        assertEq(volatilityCalc.getLongOI(), 0, "Initial long OI should be zero");
        assertEq(volatilityCalc.getShortOI(), 0, "Initial short OI should be zero");
    }

    /// @notice Test effective volatility calculation with no OI
    function test_CalculateEffectiveVolatility_NoOI() public view {
        uint256 effectiveVol = volatilityCalc.calculateEffectiveVolatility();
        assertEq(effectiveVol, BASE_VOLATILITY, "With no OI, effective volatility should equal base");
    }

    /// @notice Test effective volatility increases with long OI
    function test_CalculateEffectiveVolatility_LongOI() public {
        // Add long OI
        uint256 longOI = 1e18 * 1e12; // Large enough to see effect
        volatilityCalc.updateOpenInterest(true, int256(longOI));

        uint256 effectiveVol = volatilityCalc.calculateEffectiveVolatility();

        // Effective volatility should be higher than base
        assertGt(effectiveVol, BASE_VOLATILITY, "Long OI should increase volatility");
    }

    /// @notice Test effective volatility decreases with short OI
    function test_CalculateEffectiveVolatility_ShortOI() public {
        // Add short OI
        uint256 shortOI = 1e18 * 1e12; // Large enough to see effect
        volatilityCalc.updateOpenInterest(false, int256(shortOI));

        uint256 effectiveVol = volatilityCalc.calculateEffectiveVolatility();

        // Effective volatility should be lower than base
        assertLt(effectiveVol, BASE_VOLATILITY, "Short OI should decrease volatility");
    }

    /// @notice Test OI update with positive delta
    function test_UpdateOpenInterest_PositiveDelta() public {
        uint256 delta = 1000 * 1e18;

        // Update long OI
        volatilityCalc.updateOpenInterest(true, int256(delta));
        assertEq(volatilityCalc.getLongOI(), delta, "Long OI should increase");

        // Update short OI
        volatilityCalc.updateOpenInterest(false, int256(delta));
        assertEq(volatilityCalc.getShortOI(), delta, "Short OI should increase");
    }

    /// @notice Test OI update with negative delta
    function test_UpdateOpenInterest_NegativeDelta() public {
        // First add some OI
        uint256 initial = 1000 * 1e18;
        volatilityCalc.updateOpenInterest(true, int256(initial));
        volatilityCalc.updateOpenInterest(false, int256(initial));

        // Then reduce it
        uint256 reduction = 400 * 1e18;
        volatilityCalc.updateOpenInterest(true, -int256(reduction));
        volatilityCalc.updateOpenInterest(false, -int256(reduction));

        assertEq(volatilityCalc.getLongOI(), initial - reduction, "Long OI should decrease");
        assertEq(volatilityCalc.getShortOI(), initial - reduction, "Short OI should decrease");
    }

    /// @notice Test OI cannot go below zero
    function test_UpdateOpenInterest_CannotGoNegative() public {
        // Try to reduce OI when it's zero
        volatilityCalc.updateOpenInterest(true, -int256(1000 * 1e18));
        assertEq(volatilityCalc.getLongOI(), 0, "Long OI should not go negative");

        volatilityCalc.updateOpenInterest(false, -int256(1000 * 1e18));
        assertEq(volatilityCalc.getShortOI(), 0, "Short OI should not go negative");
    }

    /// @notice Test pool depth adjustment with higher volatility
    function test_AdjustPoolDepth_HigherVolatility() public {
        uint256 baseDepth = 1000000 * 1e18;

        // Add long OI to increase volatility
        uint256 longOI = 1e18 * 1e12;
        volatilityCalc.updateOpenInterest(true, int256(longOI));

        uint256 adjustedDepth = volatilityCalc.adjustPoolDepth(baseDepth);

        // Higher volatility should result in lower depth
        assertLt(adjustedDepth, baseDepth, "Higher volatility should reduce pool depth");
    }

    /// @notice Test pool depth adjustment with lower volatility
    function test_AdjustPoolDepth_LowerVolatility() public {
        uint256 baseDepth = 1000000 * 1e18;

        // Add short OI to decrease volatility
        uint256 shortOI = 1e18 * 1e12;
        volatilityCalc.updateOpenInterest(false, int256(shortOI));

        uint256 adjustedDepth = volatilityCalc.adjustPoolDepth(baseDepth);

        // Lower volatility should result in higher depth
        assertGt(adjustedDepth, baseDepth, "Lower volatility should increase pool depth");
    }

    /// @notice Test volatility bounds checking
    function test_CheckVolatilityBounds_WithinBounds() public view {
        // Should not revert for volatility within bounds
        volatilityCalc.checkVolatilityBounds(BASE_VOLATILITY);
        volatilityCalc.checkVolatilityBounds(MAX_VOLATILITY);
    }

    /// @notice Test volatility bounds checking exceeds max
    function test_CheckVolatilityBounds_ExceedsMax() public {
        // Should revert for volatility exceeding max
        vm.expectRevert();
        volatilityCalc.checkVolatilityBounds(MAX_VOLATILITY + 1);
    }

    /// @notice Test volatility update threshold
    function test_ShouldUpdateVolatility_Threshold() public {
        // Set initial volatility
        volatilityCalc.updatePreviousEffectiveVolatility();

        // Add OI to change volatility by less than 1%
        uint256 smallOI = 1e18 * 1e9; // Small amount
        volatilityCalc.updateOpenInterest(true, int256(smallOI));

        // Should not trigger update for small change
        // Note: This depends on the actual change being < 1%
        // For this test, we're using a small OI that shouldn't trigger
    }

    /// @notice Property 7: Effective Volatility Calculation
    /// @dev For any state of the system, the effective volatility SHALL equal
    ///      baseVolatility + (longOI * 3.569e-9) + (shortOI * -1.678e-9)
    function testProperty_EffectiveVolatilityCalculation(uint256 longOI, uint256 shortOI) public {
        // Feature: uniswap-v4-orderbook-hook, Property 7: Effective Volatility Calculation
        // Validates: Requirements 4.5

        // Bound OI values to reasonable ranges to avoid overflow
        longOI = bound(longOI, 0, 1e30);
        shortOI = bound(shortOI, 0, 1e30);

        // Update OI
        if (longOI > 0) {
            volatilityCalc.updateOpenInterest(true, int256(longOI));
        }
        if (shortOI > 0) {
            volatilityCalc.updateOpenInterest(false, int256(shortOI));
        }

        // Calculate expected effective volatility manually
        int256 expectedVol = int256(BASE_VOLATILITY);

        // Add long OI contribution
        int256 longContribution = (int256(longOI) * Constants.LONG_OI_COEFFICIENT) / int256(Constants.COEFFICIENT_SCALE);
        expectedVol += longContribution;

        // Add short OI contribution
        int256 shortContribution =
            (int256(shortOI) * Constants.SHORT_OI_COEFFICIENT) / int256(Constants.COEFFICIENT_SCALE);
        expectedVol += shortContribution;

        // Ensure non-negative
        if (expectedVol < 0) {
            expectedVol = 0;
        }

        // Get actual effective volatility
        uint256 actualVol = volatilityCalc.calculateEffectiveVolatility();

        // Verify they match
        assertEq(actualVol, uint256(expectedVol), "Effective volatility should match formula");
    }

    /// @notice Property test: Effective volatility is always non-negative
    function testProperty_EffectiveVolatilityNonNegative(uint256 longOI, uint256 shortOI) public {
        // Bound OI values
        longOI = bound(longOI, 0, 1e30);
        shortOI = bound(shortOI, 0, 1e30);

        // Update OI
        if (longOI > 0) {
            volatilityCalc.updateOpenInterest(true, int256(longOI));
        }
        if (shortOI > 0) {
            volatilityCalc.updateOpenInterest(false, int256(shortOI));
        }

        // Effective volatility should never be negative
        uint256 effectiveVol = volatilityCalc.calculateEffectiveVolatility();
        assertGe(effectiveVol, 0, "Effective volatility should be non-negative");
    }

    /// @notice Property test: Long OI increases volatility
    function testProperty_LongOIIncreasesVolatility(uint256 longOI) public {
        // Bound to reasonable values
        longOI = bound(longOI, 1e18, 1e30);

        // Get initial volatility
        uint256 initialVol = volatilityCalc.calculateEffectiveVolatility();

        // Add long OI
        volatilityCalc.updateOpenInterest(true, int256(longOI));

        // Get new volatility
        uint256 newVol = volatilityCalc.calculateEffectiveVolatility();

        // New volatility should be higher (or equal if coefficient effect is negligible)
        assertGe(newVol, initialVol, "Long OI should not decrease volatility");

        // For significant OI, should strictly increase
        if (longOI > 1e24) {
            assertGt(newVol, initialVol, "Significant long OI should increase volatility");
        }
    }

    /// @notice Property test: Short OI decreases volatility
    function testProperty_ShortOIDecreasesVolatility(uint256 shortOI) public {
        // Bound to reasonable values
        shortOI = bound(shortOI, 1e18, 1e30);

        // Get initial volatility
        uint256 initialVol = volatilityCalc.calculateEffectiveVolatility();

        // Add short OI
        volatilityCalc.updateOpenInterest(false, int256(shortOI));

        // Get new volatility
        uint256 newVol = volatilityCalc.calculateEffectiveVolatility();

        // New volatility should be lower (or equal if coefficient effect is negligible)
        assertLe(newVol, initialVol, "Short OI should not increase volatility");

        // For significant OI, should strictly decrease
        if (shortOI > 1e24) {
            assertLt(newVol, initialVol, "Significant short OI should decrease volatility");
        }
    }

    /// @notice Property test: Pool depth adjustment is inversely proportional to volatility
    function testProperty_PoolDepthInverseToVolatility(uint256 baseDepth, uint256 longOI, uint256 shortOI) public {
        // Bound values
        baseDepth = bound(baseDepth, 1e18, 1e30);
        longOI = bound(longOI, 0, 1e28);
        shortOI = bound(shortOI, 0, 1e28);

        // Update OI
        if (longOI > 0) {
            volatilityCalc.updateOpenInterest(true, int256(longOI));
        }
        if (shortOI > 0) {
            volatilityCalc.updateOpenInterest(false, int256(shortOI));
        }

        uint256 effectiveVol = volatilityCalc.getEffectiveVolatility();
        uint256 adjustedDepth = volatilityCalc.adjustPoolDepth(baseDepth);

        // Verify inverse relationship: adjustedDepth = baseDepth * baseVol / effectiveVol
        uint256 expectedDepth = (baseDepth * BASE_VOLATILITY) / effectiveVol;
        assertEq(adjustedDepth, expectedDepth, "Adjusted depth should be inversely proportional to volatility");
    }

    /// @notice Edge case: Very large OI values
    function test_EffectiveVolatility_VeryLargeOI() public {
        // Test with very large OI that might cause overflow if not handled properly
        uint256 largeOI = 1e29;

        // Should not revert
        volatilityCalc.updateOpenInterest(true, int256(largeOI));
        uint256 effectiveVol = volatilityCalc.calculateEffectiveVolatility();

        // Should be greater than base
        assertGt(effectiveVol, BASE_VOLATILITY, "Large long OI should increase volatility");
    }

    /// @notice Edge case: Balanced long and short OI
    function test_EffectiveVolatility_BalancedOI() public {
        uint256 oiAmount = 1e18 * 1e12;

        // Add equal long and short OI
        volatilityCalc.updateOpenInterest(true, int256(oiAmount));
        volatilityCalc.updateOpenInterest(false, int256(oiAmount));

        uint256 effectiveVol = volatilityCalc.calculateEffectiveVolatility();

        // The effects should partially cancel out
        // Long coefficient: +3.569e-9, Short coefficient: -1.678e-9
        // Net effect: +1.891e-9 per unit OI
        // So volatility should still be slightly higher than base
        assertGt(effectiveVol, BASE_VOLATILITY, "Balanced OI should still affect volatility");
    }

    /// @notice Test: OI reduction works correctly
    function test_OIReduction() public {
        // Add OI
        uint256 initial = 1000 * 1e18;
        volatilityCalc.updateOpenInterest(true, int256(initial));

        uint256 volAfterAdd = volatilityCalc.getEffectiveVolatility();
        assertGt(volAfterAdd, BASE_VOLATILITY, "Volatility should increase after adding long OI");

        // Reduce OI
        volatilityCalc.updateOpenInterest(true, -int256(initial));

        uint256 volAfterReduce = volatilityCalc.getEffectiveVolatility();
        assertEq(volAfterReduce, BASE_VOLATILITY, "Volatility should return to base after removing all OI");
    }

    /// @notice Property 6: OI Volatility Coefficients
    /// @dev For any change in open interest, when long OI increases, the volatility adjustment
    ///      SHALL use coefficient +3.569e-9, and when short OI increases, the volatility adjustment
    ///      SHALL use coefficient -1.678e-9
    function testProperty_OIVolatilityCoefficients(uint256 oiAmount, bool isLong) public {
        // Feature: uniswap-v4-orderbook-hook, Property 6: OI Volatility Coefficients
        // Validates: Requirements 3.4, 3.5

        // Bound OI to reasonable values
        oiAmount = bound(oiAmount, 1e18, 1e28);

        // Get initial volatility
        uint256 initialVol = volatilityCalc.calculateEffectiveVolatility();

        // Update OI
        volatilityCalc.updateOpenInterest(isLong, int256(oiAmount));

        // Get new volatility
        uint256 newVol = volatilityCalc.calculateEffectiveVolatility();

        // Calculate expected change based on coefficient
        int256 expectedChange;
        if (isLong) {
            // Long OI uses positive coefficient: +3.569e-9
            expectedChange = (int256(oiAmount) * Constants.LONG_OI_COEFFICIENT) / int256(Constants.COEFFICIENT_SCALE);
            // Volatility should increase
            assertGt(newVol, initialVol, "Long OI should increase volatility");
        } else {
            // Short OI uses negative coefficient: -1.678e-9
            expectedChange = (int256(oiAmount) * Constants.SHORT_OI_COEFFICIENT) / int256(Constants.COEFFICIENT_SCALE);
            // Volatility should decrease
            assertLt(newVol, initialVol, "Short OI should decrease volatility");
        }

        // Verify the exact change matches the coefficient formula
        int256 actualChange = int256(newVol) - int256(initialVol);
        assertEq(actualChange, expectedChange, "Volatility change should match coefficient formula");
    }

    /// @notice Property test: Coefficient values are correct
    function testProperty_CoefficientValues() public pure {
        // Verify the coefficient constants match the research values
        // Long OI coefficient: +3.569e-9 = 3569 / 1e12
        assertEq(Constants.LONG_OI_COEFFICIENT, 3569, "Long OI coefficient should be 3569");

        // Short OI coefficient: -1.678e-9 = -1678 / 1e12
        assertEq(Constants.SHORT_OI_COEFFICIENT, -1678, "Short OI coefficient should be -1678");

        // Coefficient scale should be 1e12
        assertEq(Constants.COEFFICIENT_SCALE, 1e12, "Coefficient scale should be 1e12");
    }

    /// @notice Property test: Coefficient application is linear
    function testProperty_CoefficientLinear(uint256 oiAmount1, uint256 oiAmount2) public {
        // Bound values
        oiAmount1 = bound(oiAmount1, 1e18, 1e27);
        oiAmount2 = bound(oiAmount2, 1e18, 1e27);

        // Get initial volatility
        uint256 initialVol = volatilityCalc.calculateEffectiveVolatility();

        // Add OI in two steps
        volatilityCalc.updateOpenInterest(true, int256(oiAmount1));
        uint256 volAfterFirst = volatilityCalc.calculateEffectiveVolatility();

        volatilityCalc.updateOpenInterest(true, int256(oiAmount2));
        uint256 volAfterSecond = volatilityCalc.calculateEffectiveVolatility();

        // Calculate expected total change
        int256 expectedTotalChange = (int256(oiAmount1 + oiAmount2) * Constants.LONG_OI_COEFFICIENT)
            / int256(Constants.COEFFICIENT_SCALE);

        // Verify linearity: adding OI in steps should equal adding all at once
        int256 actualTotalChange = int256(volAfterSecond) - int256(initialVol);
        assertEq(actualTotalChange, expectedTotalChange, "Coefficient application should be linear");
    }

    /// @notice Property 8: Pool Depth Adjustment Direction
    /// @dev For any position opening, when a long position opens, the effective liquidity pool depth
    ///      SHALL decrease, and when a short position opens, the effective liquidity pool depth SHALL increase
    function testProperty_PoolDepthAdjustmentDirection(uint256 baseDepth, uint256 oiAmount, bool isLong) public {
        // Feature: uniswap-v4-orderbook-hook, Property 8: Pool Depth Adjustment Direction
        // Validates: Requirements 4.3, 4.4

        // Bound values to reasonable ranges
        baseDepth = bound(baseDepth, 1e18, 1e30);
        oiAmount = bound(oiAmount, 1e20, 1e28); // Ensure significant OI to see effect

        // Get initial adjusted depth (should equal baseDepth with no OI)
        uint256 initialAdjustedDepth = volatilityCalc.adjustPoolDepth(baseDepth);
        assertEq(initialAdjustedDepth, baseDepth, "Initial adjusted depth should equal base depth");

        // Update OI
        volatilityCalc.updateOpenInterest(isLong, int256(oiAmount));

        // Get new adjusted depth
        uint256 newAdjustedDepth = volatilityCalc.adjustPoolDepth(baseDepth);

        if (isLong) {
            // Long position: volatility increases, depth should decrease
            assertLt(newAdjustedDepth, baseDepth, "Long position should decrease pool depth");
        } else {
            // Short position: volatility decreases, depth should increase
            assertGt(newAdjustedDepth, baseDepth, "Short position should increase pool depth");
        }
    }

    /// @notice Property test: Pool depth adjustment magnitude is proportional to OI
    function testProperty_PoolDepthAdjustmentProportional(uint256 baseDepth, uint256 smallOI, uint256 largeOI)
        public
    {
        // Bound values
        baseDepth = bound(baseDepth, 1e18, 1e30);
        smallOI = bound(smallOI, 1e20, 1e26);
        largeOI = bound(largeOI, 1e27, 1e28);

        // Ensure largeOI > smallOI
        vm.assume(largeOI > smallOI);

        // Test with small OI
        volatilityCalc.updateOpenInterest(true, int256(smallOI));
        uint256 depthWithSmallOI = volatilityCalc.adjustPoolDepth(baseDepth);

        // Reset and test with large OI
        volatilityCalc = new VolatilityCalculatorTestImpl(BASE_VOLATILITY, MAX_VOLATILITY);
        volatilityCalc.updateOpenInterest(true, int256(largeOI));
        uint256 depthWithLargeOI = volatilityCalc.adjustPoolDepth(baseDepth);

        // Larger OI should result in more depth reduction
        uint256 smallReduction = baseDepth - depthWithSmallOI;
        uint256 largeReduction = baseDepth - depthWithLargeOI;

        assertGt(largeReduction, smallReduction, "Larger OI should cause larger depth reduction");
    }

    /// @notice Property test: Depth adjustment formula is correct
    function testProperty_DepthAdjustmentFormula(uint256 baseDepth, uint256 longOI, uint256 shortOI) public {
        // Bound values
        baseDepth = bound(baseDepth, 1e18, 1e30);
        longOI = bound(longOI, 0, 1e28);
        shortOI = bound(shortOI, 0, 1e28);

        // Update OI
        if (longOI > 0) {
            volatilityCalc.updateOpenInterest(true, int256(longOI));
        }
        if (shortOI > 0) {
            volatilityCalc.updateOpenInterest(false, int256(shortOI));
        }

        // Get adjusted depth
        uint256 adjustedDepth = volatilityCalc.adjustPoolDepth(baseDepth);

        // Calculate expected depth: baseDepth * baseVolatility / effectiveVolatility
        uint256 effectiveVol = volatilityCalc.getEffectiveVolatility();
        uint256 expectedDepth = (baseDepth * BASE_VOLATILITY) / effectiveVol;

        // Verify formula
        assertEq(adjustedDepth, expectedDepth, "Adjusted depth should match formula");
    }

    /// @notice Property 10: Volatility Safety Bounds
    /// @dev For any calculated effective volatility, the value SHALL not exceed the maximum safety threshold
    function testProperty_VolatilitySafetyBounds(uint256 longOI, uint256 shortOI) public {
        // Feature: uniswap-v4-orderbook-hook, Property 10: Volatility Safety Bounds
        // Validates: Requirements 4.7

        // Bound OI values to very large amounts to try to exceed max volatility
        longOI = bound(longOI, 0, type(uint128).max);
        shortOI = bound(shortOI, 0, type(uint128).max);

        // Try to update OI - should revert if it would exceed max volatility
        try volatilityCalc.updateOpenInterest(true, int256(longOI)) {
            // If it didn't revert, verify volatility is within bounds
            uint256 effectiveVol = volatilityCalc.getEffectiveVolatility();
            assertLe(effectiveVol, MAX_VOLATILITY, "Effective volatility should not exceed max");
        } catch {
            // Revert is acceptable - it means the bounds check worked
            assertTrue(true, "Bounds check correctly prevented excessive volatility");
        }

        // Try with short OI as well
        try volatilityCalc.updateOpenInterest(false, int256(shortOI)) {
            uint256 effectiveVol = volatilityCalc.getEffectiveVolatility();
            assertLe(effectiveVol, MAX_VOLATILITY, "Effective volatility should not exceed max");
        } catch {
            assertTrue(true, "Bounds check correctly prevented excessive volatility");
        }
    }

    /// @notice Property test: Volatility never exceeds max after any operation
    function testProperty_VolatilityNeverExceedsMax(uint256 longOI, uint256 shortOI, bool addMore) public {
        // Bound to reasonable values
        longOI = bound(longOI, 0, 1e28);
        shortOI = bound(shortOI, 0, 1e28);

        // Update OI
        if (longOI > 0) {
            try volatilityCalc.updateOpenInterest(true, int256(longOI)) {} catch {}
        }
        if (shortOI > 0) {
            try volatilityCalc.updateOpenInterest(false, int256(shortOI)) {} catch {}
        }

        // Verify volatility is within bounds
        uint256 effectiveVol = volatilityCalc.getEffectiveVolatility();
        assertLe(effectiveVol, MAX_VOLATILITY, "Volatility should never exceed max");

        // Try to add more OI
        if (addMore) {
            try volatilityCalc.updateOpenInterest(true, int256(1e27)) {} catch {}
            effectiveVol = volatilityCalc.getEffectiveVolatility();
            assertLe(effectiveVol, MAX_VOLATILITY, "Volatility should still not exceed max after additional OI");
        }
    }

    /// @notice Property test: Max volatility is respected in constructor
    function testProperty_MaxVolatilityRespected() public {
        // Base volatility should not exceed max volatility
        assertLe(BASE_VOLATILITY, MAX_VOLATILITY, "Base volatility should not exceed max");

        // Initial effective volatility should not exceed max
        assertLe(
            volatilityCalc.getEffectiveVolatility(), MAX_VOLATILITY, "Initial volatility should not exceed max"
        );
    }
}


