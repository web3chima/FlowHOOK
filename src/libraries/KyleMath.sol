// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Constants} from "../Constants.sol";

/// @title Kyle Math Library
/// @notice Library for Kyle model mathematical operations
/// @dev Extracted to reduce contract size and improve gas efficiency
library KyleMath {
    /// @notice Calculate price impact using Kyle model formula: lambda * orderFlow
    /// @param lambda The Kyle lambda parameter (with PRICE_PRECISION scaling)
    /// @param orderFlow The net order flow (positive for buys, negative for sells)
    /// @return impact The calculated price impact (can be positive or negative)
    function calculatePriceImpact(uint256 lambda, int256 orderFlow) internal pure returns (int256 impact) {
        // Price impact = lambda * orderFlow
        // Lambda is stored with PRICE_PRECISION, so we need to scale down
        // Overflow is impossible as lambda and orderFlow are bounded by realistic market values
        unchecked {
            impact = (int256(lambda) * orderFlow) / int256(Constants.PRICE_PRECISION);
        }
    }

    /// @notice Calculate lambda parameter: volatility / effectiveDepth
    /// @param volatility The current effective volatility
    /// @param effectiveDepth The current effective market depth
    /// @return lambda The calculated lambda value (with PRICE_PRECISION scaling)
    function calculateLambda(uint256 volatility, uint256 effectiveDepth) internal pure returns (uint256 lambda) {
        require(effectiveDepth > 0, "KyleMath: zero depth");
        // Overflow is impossible as volatility and depth are bounded
        unchecked {
            lambda = (volatility * Constants.PRICE_PRECISION) / effectiveDepth;
        }
    }

    /// @notice Check if OI change exceeds threshold for parameter update
    /// @param currentTotalOI The current total open interest
    /// @param previousTotalOI The previous total open interest
    /// @return shouldUpdate True if change exceeds 5% threshold
    function shouldUpdateForOIChange(
        uint256 currentTotalOI,
        uint256 previousTotalOI
    ) internal pure returns (bool shouldUpdate) {
        if (previousTotalOI == 0) {
            return currentTotalOI > 0;
        }

        // Calculate absolute change
        uint256 change;
        unchecked {
            if (currentTotalOI > previousTotalOI) {
                change = currentTotalOI - previousTotalOI;
            } else {
                change = previousTotalOI - currentTotalOI;
            }
        }

        // Check if change exceeds 5% threshold
        // change / previousTotalOI > 0.05
        // change * 10000 > previousTotalOI * 500
        shouldUpdate = (change * Constants.THRESHOLD_DENOMINATOR) > 
                       (previousTotalOI * Constants.OI_UPDATE_THRESHOLD);
    }

    /// @notice Calculate percentage change between two values
    /// @param current The current value
    /// @param previous The previous value
    /// @return changePercent The percentage change (scaled by THRESHOLD_DENOMINATOR)
    function calculatePercentageChange(
        uint256 current,
        uint256 previous
    ) internal pure returns (uint256 changePercent) {
        if (previous == 0) {
            return current > 0 ? type(uint256).max : 0;
        }

        uint256 change;
        unchecked {
            if (current > previous) {
                change = current - previous;
            } else {
                change = previous - current;
            }
        }

        // Return change as percentage (scaled by THRESHOLD_DENOMINATOR)
        // Overflow is impossible as change <= max(current, previous)
        unchecked {
            changePercent = (change * Constants.THRESHOLD_DENOMINATOR) / previous;
        }
    }
}
