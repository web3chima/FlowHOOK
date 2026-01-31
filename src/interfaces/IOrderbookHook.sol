// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

/// @title IOrderbookHook Interface
/// @notice Interface for FlowHook implementing Uniswap V4 callbacks
interface IOrderbookHook {
    /// @notice Called before a swap is executed
    /// @param sender The address initiating the swap
    /// @param key The pool key
    /// @param params The swap parameters
    /// @param hookData Additional data passed to the hook
    /// @return selector The function selector
    /// @return delta The balance delta from orderbook matching
    /// @return lpFeeOverride Optional LP fee override
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4 selector, BeforeSwapDelta delta, uint24 lpFeeOverride);

    /// @notice Called after a swap is executed
    /// @param sender The address that initiated the swap
    /// @param key The pool key
    /// @param params The swap parameters
    /// @param delta The balance delta from the swap
    /// @param hookData Additional data passed to the hook
    /// @return selector The function selector
    /// @return hookDelta The balance delta from hook operations
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4 selector, int128 hookDelta);

    /// @notice Called before liquidity is modified
    /// @param sender The address modifying liquidity
    /// @param key The pool key
    /// @param params The modify liquidity parameters
    /// @param hookData Additional data passed to the hook
    /// @return selector The function selector
    function beforeModifyLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4 selector);

    /// @notice Called after liquidity is modified
    /// @param sender The address that modified liquidity
    /// @param key The pool key
    /// @param params The modify liquidity parameters
    /// @param delta The balance delta from liquidity modification
    /// @param hookData Additional data passed to the hook
    /// @return selector The function selector
    /// @return hookDelta The balance delta from hook operations
    function afterModifyLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4 selector, BalanceDelta hookDelta);

    /// @notice Called before a pool is initialized
    /// @param sender The address initializing the pool
    /// @param key The pool key
    /// @param sqrtPriceX96 The initial sqrt price
    /// @return selector The function selector
    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96
    ) external returns (bytes4 selector);

    /// @notice Called after a pool is initialized
    /// @param sender The address that initialized the pool
    /// @param key The pool key
    /// @param sqrtPriceX96 The initial sqrt price
    /// @param tick The initial tick
    /// @return selector The function selector
    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick
    ) external returns (bytes4 selector);
}

/// @notice Minimal IPoolManager interface for type definitions
interface IPoolManager {
    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    struct ModifyLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
    }
}
