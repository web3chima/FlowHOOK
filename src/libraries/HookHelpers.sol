// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

/// @title HookHelpers
/// @notice Helper library to reduce OrderbookHook contract size
library HookHelpers {
    /// @notice Create BeforeSwapDelta from orderbook matching results
    /// @param orderbookVolume Volume matched in orderbook
    /// @param avgPrice Average execution price
    /// @param zeroForOne Direction of swap
    /// @return delta The BeforeSwapDelta
    function createBeforeSwapDelta(
        uint256 orderbookVolume,
        uint256 avgPrice,
        bool zeroForOne
    ) internal pure returns (BeforeSwapDelta delta) {
        if (orderbookVolume == 0) {
            return BeforeSwapDeltaLibrary.ZERO_DELTA;
        }
        
        int128 specified = zeroForOne 
            ? -int128(int256(orderbookVolume))
            : int128(int256(orderbookVolume));
        int128 unspecified = zeroForOne
            ? int128(int256(orderbookVolume * avgPrice / 1e18))
            : -int128(int256(orderbookVolume * avgPrice / 1e18));
        
        return toBeforeSwapDelta(specified, unspecified);
    }

    /// @notice Calculate total volume from swap params
    /// @param amountSpecified The amount specified in swap params
    /// @return totalVolume The absolute value of amount
    function calculateTotalVolume(int256 amountSpecified) internal pure returns (uint256 totalVolume) {
        return amountSpecified > 0 
            ? uint256(amountSpecified) 
            : uint256(-amountSpecified);
    }

    /// @notice Calculate AMM volume from total and orderbook volumes
    /// @param totalVolume Total swap volume
    /// @param orderbookVolume Volume matched in orderbook
    /// @return ammVolume Remaining volume for AMM
    function calculateAmmVolume(
        uint256 totalVolume,
        uint256 orderbookVolume
    ) internal pure returns (uint256 ammVolume) {
        return totalVolume > orderbookVolume ? totalVolume - orderbookVolume : 0;
    }
}
