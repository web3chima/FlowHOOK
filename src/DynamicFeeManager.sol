// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DynamicFeeCalculator} from "./DynamicFeeCalculator.sol";
import {PackedFeeState} from "./DataStructures.sol";
import {Constants} from "./Constants.sol";

/// @title Dynamic Fee Manager
/// @notice Contract wrapper for DynamicFeeCalculator library
/// @dev Manages fee state and provides interface for fee calculations
abstract contract DynamicFeeManager {
    using DynamicFeeCalculator for PackedFeeState;

    /// @notice Current fee state
    PackedFeeState public feeState;

    /// @notice Initialize fee manager with default parameters
    constructor() {
        feeState = PackedFeeState({
            currentFee: Constants.BASE_FEE,
            baseFee: Constants.BASE_FEE,
            maxFee: Constants.MAX_FEE,
            lastUpdateBlock: 0,
            isPaused: false
        });
    }

    /// @notice Calculate dynamic fee based on current market conditions
    /// @return fee The calculated dynamic fee
    function _calculateDynamicFee() internal view returns (uint24 fee) {
        // This will be overridden by the main contract to provide actual values
        return feeState.currentFee;
    }

    /// @notice Calculate dynamic fee with specific parameters
    /// @param currentVolatility Current effective volatility
    /// @param baseVolatility Base volatility
    /// @param longOI Long open interest
    /// @param shortOI Short open interest
    /// @param poolUtilization Pool utilization percentage
    /// @return fee The calculated dynamic fee
    function _calculateDynamicFeeWithParams(
        uint256 currentVolatility,
        uint256 baseVolatility,
        uint256 longOI,
        uint256 shortOI,
        uint256 poolUtilization
    ) internal view returns (uint24 fee) {
        return DynamicFeeCalculator.calculateDynamicFee(
            feeState,
            currentVolatility,
            baseVolatility,
            longOI,
            shortOI,
            poolUtilization
        );
    }

    /// @notice Check if fee should be updated
    /// @return shouldUpdate True if fee can be updated
    function _shouldUpdateFee() internal view returns (bool shouldUpdate) {
        return DynamicFeeCalculator.shouldUpdateFee(feeState, block.number);
    }

    /// @notice Update fee state with new calculated fee
    /// @param newFee The new fee to set
    function _updateFeeState(uint24 newFee) internal {
        feeState.currentFee = newFee;
        feeState.lastUpdateBlock = uint32(block.number);
    }
}
