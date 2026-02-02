// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PropertyTestHelper} from "./helpers/PropertyTestHelper.sol";
import {LiquidityManager} from "../src/LiquidityManager.sol";
import {LiquidityPosition} from "../src/DataStructures.sol";
import {InvalidInput, ZeroAmount} from "../src/Errors.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/// @title Liquidity Manager Test Contract
/// @notice Concrete implementation of LiquidityManager for testing
contract LiquidityManagerTestContract is LiquidityManager {
    constructor(address _token0, address _token1, uint160 _initialSqrtPriceX96)
        LiquidityManager(_token0, _token1, _initialSqrtPriceX96)
    {}

    function setReserves(uint256 _reserve0, uint256 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function setSqrtPrice(uint160 _sqrtPriceX96) external {
        sqrtPriceX96 = _sqrtPriceX96;
        currentTick = _getTickAtSqrtRatio(_sqrtPriceX96);
    }

    function setTotalLiquidity(uint128 _liquidity) external {
        totalLiquidity = _liquidity;
    }

    function executeSwap(bool zeroForOne, uint256 amountIn) external returns (uint256 amountOut) {
        return _executeSwap(zeroForOne, amountIn);
    }

    function addLiquidity(int24 tickLower, int24 tickUpper, uint256 amount0Desired, uint256 amount1Desired)
        external
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        return _addLiquidity(tickLower, tickUpper, amount0Desired, amount1Desired);
    }

    function removeLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidityToRemove)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        return _removeLiquidity(tickLower, tickUpper, liquidityToRemove);
    }

    function distributeFees(uint256 amount0, uint256 amount1) external {
        _distributeFees(amount0, amount1);
    }

    function addLiquidityForTest(
        address provider,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) external {
        bytes32 key = _getPositionKey(provider, tickLower, tickUpper);
        positions[key] = LiquidityPosition({
            provider: provider,
            liquidity: liquidity,
            tickLower: tickLower,
            tickUpper: tickUpper,
            feeGrowthInside0: 0,
            feeGrowthInside1: 0
        });

        tickLiquidity[tickLower] += liquidity;
        tickLiquidity[tickUpper] += liquidity;
        totalLiquidity += liquidity;
    }

    function calculateLiquidityFromAmounts(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (uint128) {
        return _calculateLiquidityFromAmounts(amount0, amount1, tickLower, tickUpper);
    }

    function getAmountsForLiquidity(uint128 liquidity, int24 tickLower, int24 tickUpper)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return _getAmountsForLiquidity(liquidity, tickLower, tickUpper);
    }
}

/// @title Liquidity Manager Tests
/// @notice Property-based and unit tests for FlowHook liquidity manager
contract LiquidityManagerTest is PropertyTestHelper {
    LiquidityManagerTestContract public liquidityManager;
    ERC20Mock public token0;
    ERC20Mock public token1;

    address public alice = address(0x1);
    address public bob = address(0x2);

    uint256 constant INITIAL_MINT = 1000000e18;
    uint160 constant INITIAL_SQRT_PRICE = 79228162514264337593543950336; // sqrt(1) in Q64.96

    function setUp() public {
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();

        liquidityManager = new LiquidityManagerTestContract(address(token0), address(token1), INITIAL_SQRT_PRICE);

        token0.mint(alice, INITIAL_MINT);
        token1.mint(alice, INITIAL_MINT);
        token0.mint(bob, INITIAL_MINT);
        token1.mint(bob, INITIAL_MINT);

        vm.prank(alice);
        token0.approve(address(liquidityManager), type(uint256).max);
        vm.prank(alice);
        token1.approve(address(liquidityManager), type(uint256).max);
        vm.prank(bob);
        token0.approve(address(liquidityManager), type(uint256).max);
        vm.prank(bob);
        token1.approve(address(liquidityManager), type(uint256).max);
    }

    /// @notice Property 18: Concentrated Liquidity Pricing
    /// @dev For any AMM swap, the price calculation SHALL follow the Uniswap V3
    ///      concentrated liquidity formula: L = √(x * y) within the active tick range
    /// Feature: flowhook, Property 18: Concentrated Liquidity Pricing
    /// Validates: Requirements 7.1, 7.2
    function testProperty_ConcentratedLiquidityPricing(
        uint128 liquidityAmount,
        uint256 swapAmount,
        bool zeroForOne
    ) public {
        // Bound inputs to reasonable ranges to avoid precision issues
        liquidityAmount = uint128(bound(liquidityAmount, 1e18, 100000e18));
        // Swap amount should be proportional to liquidity to avoid zero outputs
        swapAmount = bound(swapAmount, liquidityAmount / 1000, liquidityAmount / 10);

        // Set up initial liquidity
        liquidityManager.setTotalLiquidity(liquidityAmount);

        // Calculate initial reserves based on L = √(x * y)
        // At price = 1 (sqrtPrice = 1), x = y = L
        uint256 initialReserve0 = uint256(liquidityAmount);
        uint256 initialReserve1 = uint256(liquidityAmount);
        liquidityManager.setReserves(initialReserve0, initialReserve1);

        // Get initial state
        (uint256 reserve0Before, uint256 reserve1Before, uint160 sqrtPriceBefore,,) =
            liquidityManager.getPoolState();

        // Calculate swap price
        (uint256 amountOut, uint160 newSqrtPrice) = liquidityManager.calculateSwapPrice(zeroForOne, swapAmount);

        // Verify output amount is reasonable
        if (amountOut > 0) {
            // Verify price moved in correct direction
            if (zeroForOne) {
                // Swapping token0 for token1, price should decrease
                assertLe(newSqrtPrice, sqrtPriceBefore, "Price should decrease when swapping token0 for token1");
            } else {
                // Swapping token1 for token0, price should increase
                assertGe(newSqrtPrice, sqrtPriceBefore, "Price should increase when swapping token1 for token0");
            }

            // Verify output amount doesn't exceed reserves
            assertLt(amountOut, zeroForOne ? reserve1Before : reserve0Before, "Output exceeds reserves");

            // Verify liquidity invariant approximately holds
            // L = √(x * y) should remain constant (with some tolerance for rounding)
            uint256 newReserve0 = zeroForOne ? reserve0Before + swapAmount : reserve0Before - amountOut;
            uint256 newReserve1 = zeroForOne ? reserve1Before - amountOut : reserve1Before + swapAmount;

            // Calculate L before and after
            uint256 liquidityBefore = _sqrt(reserve0Before * reserve1Before);
            uint256 liquidityAfter = _sqrt(newReserve0 * newReserve1);

            // Allow 5% tolerance for rounding errors in concentrated liquidity
            uint256 tolerance = liquidityBefore / 20;
            assertApproxEqAbs(
                liquidityAfter, liquidityBefore, tolerance, "Liquidity invariant violated beyond tolerance"
            );
        }
    }

    /// @notice Test calculateSwapPrice with zero liquidity reverts
    function test_CalculateSwapPrice_ZeroLiquidity_Reverts() public {
        liquidityManager.setTotalLiquidity(0);

        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "no liquidity"));
        liquidityManager.calculateSwapPrice(true, 1e18);
    }

    /// @notice Test calculateSwapPrice with zero amount reverts
    function test_CalculateSwapPrice_ZeroAmount_Reverts() public {
        liquidityManager.setTotalLiquidity(1000e18);

        vm.expectRevert(ZeroAmount.selector);
        liquidityManager.calculateSwapPrice(true, 0);
    }

    /// @notice Test liquidity calculation from amounts
    function test_CalculateLiquidityFromAmounts_Success() public {
        uint256 amount0 = 100e18;
        uint256 amount1 = 100e18;
        int24 tickLower = -10;
        int24 tickUpper = 10;

        uint128 liquidity = liquidityManager.calculateLiquidityFromAmounts(amount0, amount1, tickLower, tickUpper);

        assertGt(liquidity, 0, "Liquidity should be positive");
    }

    /// @notice Test liquidity calculation with invalid tick range reverts
    function test_CalculateLiquidityFromAmounts_InvalidTickRange_Reverts() public {
        uint256 amount0 = 100e18;
        uint256 amount1 = 100e18;
        int24 tickLower = 10;
        int24 tickUpper = -10; // Invalid: lower > upper

        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "tick range"));
        liquidityManager.calculateLiquidityFromAmounts(amount0, amount1, tickLower, tickUpper);
    }

    /// @notice Test liquidity calculation with zero amounts reverts
    function test_CalculateLiquidityFromAmounts_ZeroAmounts_Reverts() public {
        int24 tickLower = -10;
        int24 tickUpper = 10;

        vm.expectRevert(ZeroAmount.selector);
        liquidityManager.calculateLiquidityFromAmounts(0, 0, tickLower, tickUpper);
    }

    /// @notice Test amounts calculation from liquidity
    function test_GetAmountsForLiquidity_Success() public {
        uint128 liquidity = 1000e18;
        int24 tickLower = -10;
        int24 tickUpper = 10;

        (uint256 amount0, uint256 amount1) = liquidityManager.getAmountsForLiquidity(liquidity, tickLower, tickUpper);

        // At least one amount should be positive
        assertTrue(amount0 > 0 || amount1 > 0, "At least one amount should be positive");
    }

    /// @notice Test amounts calculation with zero liquidity
    function test_GetAmountsForLiquidity_ZeroLiquidity() public {
        int24 tickLower = -10;
        int24 tickUpper = 10;

        (uint256 amount0, uint256 amount1) = liquidityManager.getAmountsForLiquidity(0, tickLower, tickUpper);

        assertEq(amount0, 0, "Amount0 should be zero");
        assertEq(amount1, 0, "Amount1 should be zero");
    }

    /// @notice Test position storage and retrieval
    function test_PositionStorageAndRetrieval_Success() public {
        uint128 liquidity = 1000e18;
        int24 tickLower = -10;
        int24 tickUpper = 10;

        liquidityManager.addLiquidityForTest(alice, liquidity, tickLower, tickUpper);

        LiquidityPosition memory position = liquidityManager.getPosition(alice, tickLower, tickUpper);

        assertEq(position.provider, alice, "Provider incorrect");
        assertEq(position.liquidity, liquidity, "Liquidity incorrect");
        assertEq(position.tickLower, tickLower, "TickLower incorrect");
        assertEq(position.tickUpper, tickUpper, "TickUpper incorrect");
    }

    /// @notice Test tick liquidity tracking
    function test_TickLiquidityTracking_Success() public {
        uint128 liquidity1 = 1000e18;
        uint128 liquidity2 = 500e18;
        int24 tickLower = -10;
        int24 tickUpper = 10;

        liquidityManager.addLiquidityForTest(alice, liquidity1, tickLower, tickUpper);
        liquidityManager.addLiquidityForTest(bob, liquidity2, tickLower, tickUpper);

        uint128 tickLiquidityLower = liquidityManager.getLiquidityAtTick(tickLower);
        uint128 tickLiquidityUpper = liquidityManager.getLiquidityAtTick(tickUpper);

        assertEq(tickLiquidityLower, liquidity1 + liquidity2, "Tick lower liquidity incorrect");
        assertEq(tickLiquidityUpper, liquidity1 + liquidity2, "Tick upper liquidity incorrect");
    }

    /// @notice Test pool state retrieval
    function test_GetPoolState_Success() public {
        uint256 testReserve0 = 1000e18;
        uint256 testReserve1 = 2000e18;
        uint128 testLiquidity = 1500e18;

        liquidityManager.setReserves(testReserve0, testReserve1);
        liquidityManager.setTotalLiquidity(testLiquidity);

        (uint256 reserve0, uint256 reserve1, uint160 sqrtPrice, int24 tick, uint128 liquidity) =
            liquidityManager.getPoolState();

        assertEq(reserve0, testReserve0, "Reserve0 incorrect");
        assertEq(reserve1, testReserve1, "Reserve1 incorrect");
        assertEq(sqrtPrice, INITIAL_SQRT_PRICE, "SqrtPrice incorrect");
        assertEq(liquidity, testLiquidity, "Liquidity incorrect");
    }

    /// @notice Property 19: Atomic Reserve Updates
    /// @dev For any AMM trade execution, the pool reserve updates SHALL occur
    ///      atomically within the same transaction as the trade
    /// Feature: flowhook, Property 19: Atomic Reserve Updates
    /// Validates: Requirements 7.3
    function testProperty_AtomicReserveUpdates(
        uint128 liquidityAmount,
        uint256 swapAmount,
        bool zeroForOne
    ) public {
        // Bound inputs to reasonable ranges to avoid underflow
        liquidityAmount = uint128(bound(liquidityAmount, 1e18, 100000e18));
        // Swap amount should be proportional to liquidity
        swapAmount = bound(swapAmount, liquidityAmount / 1000, liquidityAmount / 10);

        // Set up initial state
        liquidityManager.setTotalLiquidity(liquidityAmount);
        uint256 initialReserve0 = uint256(liquidityAmount);
        uint256 initialReserve1 = uint256(liquidityAmount);
        liquidityManager.setReserves(initialReserve0, initialReserve1);

        // Get state before swap
        (uint256 reserve0Before, uint256 reserve1Before,,,) = liquidityManager.getPoolState();

        // Execute swap
        uint256 amountOut = liquidityManager.executeSwap(zeroForOne, swapAmount);

        // Get state after swap
        (uint256 reserve0After, uint256 reserve1After,,,) = liquidityManager.getPoolState();

        // Verify reserves updated atomically
        if (zeroForOne) {
            // Swapping token0 for token1
            assertEq(reserve0After, reserve0Before + swapAmount, "Reserve0 not updated correctly");
            // amountOut might be capped to available reserves
            assertLe(reserve1After, reserve1Before, "Reserve1 should decrease or stay same");
            assertEq(reserve1After, reserve1Before - amountOut, "Reserve1 not updated correctly");
        } else {
            // Swapping token1 for token0
            assertEq(reserve1After, reserve1Before + swapAmount, "Reserve1 not updated correctly");
            // amountOut might be capped to available reserves
            assertLe(reserve0After, reserve0Before, "Reserve0 should decrease or stay same");
            assertEq(reserve0After, reserve0Before - amountOut, "Reserve0 not updated correctly");
        }

        // Verify no intermediate state was observable (implicit in single transaction)
        // If reserves are updated, they must both be updated
        assertTrue(
            (reserve0After != reserve0Before) || (reserve1After != reserve1Before),
            "At least one reserve should have changed"
        );
    }

    /// @notice Property 41: Pool Reserve Invariant
    /// @dev For any swap execution, the pool reserves after the swap SHALL match
    ///      the expected values calculated from the constant product formula
    ///      adjusted for concentrated liquidity
    /// Feature: flowhook, Property 41: Pool Reserve Invariant
    /// Validates: Requirements 16.5
    function testProperty_PoolReserveInvariant(
        uint128 liquidityAmount,
        uint256 swapAmount,
        bool zeroForOne
    ) public {
        // Bound inputs to reasonable ranges
        liquidityAmount = uint128(bound(liquidityAmount, 1e18, 100000e18));
        // Swap amount should be proportional to liquidity
        swapAmount = bound(swapAmount, liquidityAmount / 1000, liquidityAmount / 10);

        // Set up initial state
        liquidityManager.setTotalLiquidity(liquidityAmount);
        uint256 initialReserve0 = uint256(liquidityAmount);
        uint256 initialReserve1 = uint256(liquidityAmount);
        liquidityManager.setReserves(initialReserve0, initialReserve1);

        // Get state before swap
        (uint256 reserve0Before, uint256 reserve1Before,,,) = liquidityManager.getPoolState();

        // Calculate expected liquidity before swap: L = √(x * y)
        uint256 liquidityBefore = _sqrt(reserve0Before * reserve1Before);

        // Execute swap
        uint256 amountOut = liquidityManager.executeSwap(zeroForOne, swapAmount);

        // Get state after swap
        (uint256 reserve0After, uint256 reserve1After,,,) = liquidityManager.getPoolState();

        // Calculate expected reserves based on swap
        uint256 expectedReserve0;
        uint256 expectedReserve1;

        if (zeroForOne) {
            expectedReserve0 = reserve0Before + swapAmount;
            expectedReserve1 = reserve1Before - amountOut;
        } else {
            expectedReserve1 = reserve1Before + swapAmount;
            expectedReserve0 = reserve0Before - amountOut;
        }

        // Verify reserves match expected values
        assertEq(reserve0After, expectedReserve0, "Reserve0 doesn't match expected");
        assertEq(reserve1After, expectedReserve1, "Reserve1 doesn't match expected");

        // Verify liquidity invariant approximately holds (with tolerance for rounding)
        // Note: In concentrated liquidity, the invariant is L = constant within a tick range
        // but can change slightly due to the discrete nature of ticks
        uint256 liquidityAfter = _sqrt(reserve0After * reserve1After);
        
        // Allow 5% tolerance for concentrated liquidity rounding
        uint256 tolerance = liquidityBefore / 20;

        assertApproxEqAbs(
            liquidityAfter,
            liquidityBefore,
            tolerance,
            "Liquidity invariant violated beyond tolerance"
        );
    }

    /// @notice Property 21: Proportional Fee Distribution
    /// @dev For any trading fees collected, the distribution to liquidity providers
    ///      SHALL be proportional to their share of liquidity in the active range
    /// Feature: flowhook, Property 21: Proportional Fee Distribution
    /// Validates: Requirements 7.7
    function testProperty_ProportionalFeeDistribution(
        uint128 liquidity1,
        uint128 liquidity2,
        uint256 feeAmount0,
        uint256 feeAmount1
    ) public {
        // Bound inputs to reasonable ranges
        liquidity1 = uint128(bound(liquidity1, 1e18, 100000e18));
        liquidity2 = uint128(bound(liquidity2, 1e18, 100000e18));
        feeAmount0 = bound(feeAmount0, 1e15, 10e18);
        feeAmount1 = bound(feeAmount1, 1e15, 10e18);

        int24 tickLower = -10;
        int24 tickUpper = 10;

        // Set up initial liquidity for two providers
        liquidityManager.setTotalLiquidity(0);

        // Deposit tokens for alice
        vm.startPrank(alice);
        liquidityManager.deposit(address(token0), 1000000e18);
        liquidityManager.deposit(address(token1), 1000000e18);
        vm.stopPrank();

        // Deposit tokens for bob
        vm.startPrank(bob);
        liquidityManager.deposit(address(token0), 1000000e18);
        liquidityManager.deposit(address(token1), 1000000e18);
        vm.stopPrank();

        // Add liquidity for alice
        liquidityManager.addLiquidityForTest(alice, liquidity1, tickLower, tickUpper);

        // Add liquidity for bob
        liquidityManager.addLiquidityForTest(bob, liquidity2, tickLower, tickUpper);

        // Get total liquidity
        uint128 totalLiquidity = liquidity1 + liquidity2;
        liquidityManager.setTotalLiquidity(totalLiquidity);

        // Distribute fees
        liquidityManager.distributeFees(feeAmount0, feeAmount1);

        // Get unclaimed fees for both providers
        (uint256 aliceFees0, uint256 aliceFees1) = liquidityManager.getUnclaimedFees(alice, tickLower, tickUpper);
        (uint256 bobFees0, uint256 bobFees1) = liquidityManager.getUnclaimedFees(bob, tickLower, tickUpper);

        // Calculate expected proportions and verify
        {
            uint256 aliceShare = (uint256(liquidity1) * 1e18) / uint256(totalLiquidity);
            uint256 expectedAliceFees0 = (feeAmount0 * aliceShare) / 1e18;
            uint256 expectedAliceFees1 = (feeAmount1 * aliceShare) / 1e18;

            // Allow 1% tolerance for rounding
            assertApproxEqAbs(aliceFees0, expectedAliceFees0, feeAmount0 / 100, "Alice fees0 not proportional");
            assertApproxEqAbs(aliceFees1, expectedAliceFees1, feeAmount1 / 100, "Alice fees1 not proportional");
        }

        {
            uint256 bobShare = (uint256(liquidity2) * 1e18) / uint256(totalLiquidity);
            uint256 expectedBobFees0 = (feeAmount0 * bobShare) / 1e18;
            uint256 expectedBobFees1 = (feeAmount1 * bobShare) / 1e18;

            // Allow 1% tolerance for rounding
            assertApproxEqAbs(bobFees0, expectedBobFees0, feeAmount0 / 100, "Bob fees0 not proportional");
            assertApproxEqAbs(bobFees1, expectedBobFees1, feeAmount1 / 100, "Bob fees1 not proportional");
        }

        // Verify total fees distributed equals fees collected (with tolerance)
        assertApproxEqAbs(aliceFees0 + bobFees0, feeAmount0, feeAmount0 / 100, "Total fees0 mismatch");
        assertApproxEqAbs(aliceFees1 + bobFees1, feeAmount1, feeAmount1 / 100, "Total fees1 mismatch");
    }

    /// @notice Helper function to calculate square root
    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
