// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {KyleState} from "./DataStructures.sol";
import {Constants} from "./Constants.sol";
import {InvalidInput} from "./Errors.sol";

/// @title Kyle Model Pricing
/// @notice Implements Kyle model mechanics for price impact calculation
/// @dev Calculates price impact based on order flow and market depth
abstract contract KyleModel {
    /// @notice Kyle model state
    KyleState public kyleState;

    /// @notice Previous total open interest for threshold checking
    uint256 internal previousTotalOI;

    /// @notice Initialize Kyle model with default parameters
    /// @param _baseDepth Initial base market depth
    /// @param _baseVolatility Initial base volatility for lambda calculation
    constructor(uint256 _baseDepth, uint256 _baseVolatility) {
        if (_baseDepth == 0) revert InvalidInput("baseDepth");
        if (_baseVolatility == 0) revert InvalidInput("baseVolatility");

        kyleState = KyleState({
            lambda: (_baseVolatility * Constants.PRICE_PRECISION) / _baseDepth,
            cumulativeFlow: 0,
            lastUpdateBlock: block.number,
            baseDepth: _baseDepth,
            effectiveDepth: _baseDepth
        });

        previousTotalOI = 0;
    }

    /// @notice Calculate price impact using Kyle model formula: lambda * orderFlow
    /// @param orderFlow The net order flow (positive for buys, negative for sells)
    /// @return impact The calculated price impact (can be positive or negative)
    function calculatePriceImpact(int256 orderFlow) public view returns (int256 impact) {
        // Price impact = lambda * orderFlow
        // Lambda is stored with PRICE_PRECISION, so we need to scale down
        impact = (int256(kyleState.lambda) * orderFlow) / int256(Constants.PRICE_PRECISION);
    }

    /// @notice Track cumulative order flow for informed trading detection
    /// @param flow The order flow to add (positive for buys, negative for sells)
    function _trackOrderFlow(int256 flow) internal {
        kyleState.cumulativeFlow += flow;
    }

    /// @notice Update Kyle model parameters based on current volatility and depth
    /// @param currentVolatility The current effective volatility
    /// @param currentDepth The current effective depth
    function _updateKyleParameters(uint256 currentVolatility, uint256 currentDepth) internal {
        if (currentDepth == 0) revert InvalidInput("currentDepth");

        // Calculate new lambda: volatility / effectiveDepth
        kyleState.lambda = (currentVolatility * Constants.PRICE_PRECISION) / currentDepth;
        kyleState.effectiveDepth = currentDepth;
        kyleState.lastUpdateBlock = block.number;
    }

    /// @notice Check if Kyle parameters should be updated based on OI change threshold
    /// @param currentTotalOI The current total open interest (long + short)
    /// @return shouldUpdate True if OI changed by more than 5%
    function _shouldUpdateKyleParameters(uint256 currentTotalOI) internal view returns (bool shouldUpdate) {
        if (previousTotalOI == 0) {
            return currentTotalOI > 0;
        }

        // Calculate percentage change
        uint256 change;
        if (currentTotalOI > previousTotalOI) {
            change = currentTotalOI - previousTotalOI;
        } else {
            change = previousTotalOI - currentTotalOI;
        }

        // Check if change exceeds 5% threshold
        // change / previousTotalOI > 0.05
        // change * 10000 > previousTotalOI * 500
        shouldUpdate = (change * Constants.THRESHOLD_DENOMINATOR) > (previousTotalOI * Constants.OI_UPDATE_THRESHOLD);
    }

    /// @notice Update the previous total OI for threshold tracking
    /// @param currentTotalOI The current total open interest
    function _updatePreviousTotalOI(uint256 currentTotalOI) internal {
        previousTotalOI = currentTotalOI;
    }

    /// @notice Reset cumulative flow (can be called periodically to prevent drift)
    function _resetCumulativeFlow() internal {
        kyleState.cumulativeFlow = 0;
    }

    /// @notice Get current Kyle model state
    /// @return The current Kyle state
    function getKyleState() external view returns (KyleState memory) {
        return kyleState;
    }

    /// @notice Get current lambda parameter
    /// @return The current lambda value
    function getLambda() external view returns (uint256) {
        return kyleState.lambda;
    }

    /// @notice Get cumulative order flow
    /// @return The cumulative flow value
    function getCumulativeFlow() external view returns (int256) {
        return kyleState.cumulativeFlow;
    }

    /// @notice Get effective market depth
    /// @return The effective depth value
    function getEffectiveDepth() external view returns (uint256) {
        return kyleState.effectiveDepth;
    }
}
