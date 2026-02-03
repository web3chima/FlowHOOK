// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Constants} from "../Constants.sol";

/// @title Volatility Math Library
/// @notice Library for volatility calculation operations
/// @dev Extracted to reduce contract size and improve gas efficiency
library VolatilityMath {
    /// @notice Calculate effective volatility using OI coefficients
    /// @dev Formula: baseVolatility + (longOI * 3.569e-9) + (shortOI * -1.678e-9)
    /// @param baseVolatility The base volatility value
    /// @param longOI The total long open interest
    /// @param shortOI The total short open interest
    /// @return effectiveVolatility The calculated effective volatility
    function calculateEffectiveVolatility(
        uint256 baseVolatility,
        uint256 longOI,
        uint256 shortOI
    ) internal pure returns (uint256 effectiveVolatility) {
        // Start with base volatility
        int256 effectiveVol = int256(baseVolatility);

        // Add long OI contribution (positive coefficient)
        // longOI * 3.569e-9 = (longOI * 3569) / 1e12
        int256 longContribution;
        unchecked {
            longContribution = (int256(longOI) * Constants.LONG_OI_COEFFICIENT) / 
                              int256(Constants.COEFFICIENT_SCALE);
        }
        effectiveVol += longContribution;

        // Add short OI contribution (negative coefficient)
        // shortOI * -1.678e-9 = (shortOI * -1678) / 1e12
        int256 shortContribution;
        unchecked {
            shortContribution = (int256(shortOI) * Constants.SHORT_OI_COEFFICIENT) / 
                               int256(Constants.COEFFICIENT_SCALE);
        }
        effectiveVol += shortContribution;

        // Ensure volatility is non-negative
        if (effectiveVol < 0) {
            return 0;
        }

        effectiveVolatility = uint256(effectiveVol);
    }

    /// @notice Adjust pool depth based on volatility ratio
    /// @dev Higher volatility = thinner pools, lower volatility = deeper pools
    /// @param baseDepth The base pool depth
    /// @param effectiveVolatility The current effective volatility
    /// @param baseVolatility The base volatility
    /// @return adjustedDepth The adjusted pool depth
    function adjustPoolDepth(
        uint256 baseDepth,
        uint256 effectiveVolatility,
        uint256 baseVolatility
    ) internal pure returns (uint256 adjustedDepth) {
        if (baseVolatility == 0 || effectiveVolatility == 0) {
            return baseDepth;
        }

        // adjustedDepth = baseDepth * (baseVolatility / effectiveVolatility)
        // This ensures: higher volatility -> lower depth, lower volatility -> higher depth
        // Overflow is impossible as we're multiplying then dividing
        unchecked {
            adjustedDepth = (baseDepth * baseVolatility) / effectiveVolatility;
        }
    }

    /// @notice Check if volatility change exceeds threshold for update
    /// @param currentVolatility The current effective volatility
    /// @param previousVolatility The previous effective volatility
    /// @return shouldUpdate True if change exceeds 1% threshold
    function shouldUpdateForVolatilityChange(
        uint256 currentVolatility,
        uint256 previousVolatility
    ) internal pure returns (bool shouldUpdate) {
        if (previousVolatility == 0) {
            return currentVolatility > 0;
        }

        // Calculate absolute change
        uint256 change;
        unchecked {
            if (currentVolatility > previousVolatility) {
                change = currentVolatility - previousVolatility;
            } else {
                change = previousVolatility - currentVolatility;
            }
        }

        // Check if change exceeds 1% threshold
        // change / previousVolatility > 0.01
        // change * 10000 > previousVolatility * 100
        shouldUpdate = (change * Constants.THRESHOLD_DENOMINATOR) > 
                       (previousVolatility * Constants.VOLATILITY_UPDATE_THRESHOLD);
    }

    /// @notice Update open interest value safely
    /// @param currentOI The current open interest value
    /// @param delta The change in OI (can be positive or negative)
    /// @return newOI The updated open interest value
    function updateOI(uint256 currentOI, int256 delta) internal pure returns (uint256 newOI) {
        if (delta >= 0) {
            newOI = currentOI + uint256(delta);
        } else {
            uint256 decrease = uint256(-delta);
            if (decrease > currentOI) {
                newOI = 0;
            } else {
                unchecked {
                    newOI = currentOI - decrease;
                }
            }
        }
    }

    /// @notice Calculate OI imbalance ratio
    /// @param longOI The total long open interest
    /// @param shortOI The total short open interest
    /// @return imbalanceRatio The imbalance ratio (scaled by PRICE_PRECISION)
    function calculateOIImbalance(
        uint256 longOI,
        uint256 shortOI
    ) internal pure returns (uint256 imbalanceRatio) {
        uint256 totalOI;
        unchecked {
            totalOI = longOI + shortOI;
        }
        
        if (totalOI == 0) {
            return 0;
        }

        uint256 imbalance;
        unchecked {
            if (longOI > shortOI) {
                imbalance = longOI - shortOI;
            } else {
                imbalance = shortOI - longOI;
            }
        }

        // Return imbalance as ratio (scaled by PRICE_PRECISION)
        // Overflow is impossible as imbalance <= totalOI
        unchecked {
            imbalanceRatio = (imbalance * Constants.PRICE_PRECISION) / totalOI;
        }
    }
}
