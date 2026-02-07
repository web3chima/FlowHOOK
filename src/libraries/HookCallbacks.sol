// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {HookHelpers} from "./HookHelpers.sol";

/// @title HookCallbacks
/// @notice Library containing logic for Uniswap V4 hook callbacks
/// @dev Extracted to reduce main contract size
library HookCallbacks {
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;

    /// @notice Process beforeSwap callback logic
    /// @param params The swap parameters
    /// @param orderbookVolume Volume matched in orderbook
    /// @param avgPrice Average execution price from orderbook
    /// @param ammOutput Output from AMM swap
    /// @return delta The before swap delta
    /// @return totalVolume The total swap volume
    /// @return ammVolume The volume routed to AMM
    function processBeforeSwap(
        SwapParams calldata params,
        uint256 orderbookVolume,
        uint256 avgPrice,
        uint256 ammOutput
    ) internal pure returns (BeforeSwapDelta delta, uint256 totalVolume, uint256 ammVolume) {
        // Calculate volumes
        totalVolume = HookHelpers.calculateTotalVolume(params.amountSpecified);
        ammVolume = HookHelpers.calculateAmmVolume(totalVolume, orderbookVolume);
        
        // Create balance delta
        delta = HookHelpers.createBeforeSwapDelta(orderbookVolume, avgPrice, params.zeroForOne);
        
        return (delta, totalVolume, ammVolume);
    }

    /// @notice Validate liquidity modification parameters
    /// @param params The modify liquidity parameters
    /// @param isAdd Whether this is adding liquidity (true) or removing (false)
    function validateLiquidityParams(
        ModifyLiquidityParams calldata params,
        bool isAdd
    ) internal pure {
        if (isAdd) {
            require(params.liquidityDelta > 0, "Invalid liquidity delta");
        } else {
            require(params.liquidityDelta < 0, "Invalid liquidity delta");
        }
        require(params.tickLower < params.tickUpper, "Invalid tick range");
    }

    /// @notice Validate pool initialization parameters
    /// @param key The pool key
    /// @param token0 Expected token0 address
    /// @param token1 Expected token1 address
    function validateInitialization(
        PoolKey calldata key,
        address token0,
        address token1
    ) internal pure {
        require(
            Currency.unwrap(key.currency0) == token0 && Currency.unwrap(key.currency1) == token1,
            "Token mismatch"
        );
    }
}
