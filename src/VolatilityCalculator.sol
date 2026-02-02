// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VolatilityState} from "./DataStructures.sol";
import {Constants} from "./Constants.sol";
import {InvalidInput, ExcessiveVolatility} from "./Errors.sol";

/// @title Volatility Calculator
/// @notice Dynamically adjusts effective volatility based on open interest composition
/// @dev Implements OI-volatility relationship: short OI reduces volatility, long OI increases it
abstract contract VolatilityCalculator {
    /// @notice Volatility state tracking
    VolatilityState public volatilityState;

    /// @notice Maximum allowed volatility for safety
    uint256 public maxVolatility;

    /// @notice Previous effective volatility for threshold checking
    uint256 internal previousEffectiveVolatility;

    /// @notice Initialize volatility calculator with base parameters
    /// @param _baseVolatility Initial base volatility
    /// @param _maxVolatility Maximum allowed volatility
    constructor(uint256 _baseVolatility, uint256 _maxVolatility) {
        if (_baseVolatility == 0) revert InvalidInput("baseVolatility");
        if (_maxVolatility == 0) revert InvalidInput("maxVolatility");
        if (_baseVolatility > _maxVolatility) revert InvalidInput("baseVolatility > maxVolatility");

        volatilityState = VolatilityState({
            baseVolatility: _baseVolatility,
            longOI: 0,
            shortOI: 0,
            effectiveVolatility: _baseVolatility,
            lastUpdateBlock: block.number
        });

        maxVolatility = _maxVolatility;
        previousEffectiveVolatility = _baseVolatility;
    }

    /// @notice Calculate effective volatility using OI coefficients
    /// @dev Formula: baseVolatility + (longOI * 3.569e-9) + (shortOI * -1.678e-9)
    /// @return The calculated effective volatility
    function calculateEffectiveVolatility() public view returns (uint256) {
        // Start with base volatility
        int256 effectiveVol = int256(volatilityState.baseVolatility);

        // Add long OI contribution (positive coefficient)
        // longOI * 3.569e-9 = (longOI * 3569) / 1e12
        int256 longContribution = (int256(volatilityState.longOI) * Constants.LONG_OI_COEFFICIENT) / 
                                  int256(Constants.COEFFICIENT_SCALE);
        effectiveVol += longContribution;

        // Add short OI contribution (negative coefficient)
        // shortOI * -1.678e-9 = (shortOI * -1678) / 1e12
        int256 shortContribution = (int256(volatilityState.shortOI) * Constants.SHORT_OI_COEFFICIENT) / 
                                   int256(Constants.COEFFICIENT_SCALE);
        effectiveVol += shortContribution;

        // Ensure volatility is non-negative
        if (effectiveVol < 0) {
            return 0;
        }

        return uint256(effectiveVol);
    }

    /// @notice Update open interest tracking
    /// @param isLong True if updating long OI, false for short OI
    /// @param delta The change in OI (can be positive or negative)
    function _updateOpenInterest(bool isLong, int256 delta) internal {
        if (isLong) {
            // Update long OI
            if (delta >= 0) {
                volatilityState.longOI += uint256(delta);
            } else {
                uint256 decrease = uint256(-delta);
                if (decrease > volatilityState.longOI) {
                    volatilityState.longOI = 0;
                } else {
                    volatilityState.longOI -= decrease;
                }
            }
        } else {
            // Update short OI
            if (delta >= 0) {
                volatilityState.shortOI += uint256(delta);
            } else {
                uint256 decrease = uint256(-delta);
                if (decrease > volatilityState.shortOI) {
                    volatilityState.shortOI = 0;
                } else {
                    volatilityState.shortOI -= decrease;
                }
            }
        }

        // Recalculate effective volatility
        uint256 newEffectiveVolatility = calculateEffectiveVolatility();
        
        // Check volatility bounds
        _checkVolatilityBounds(newEffectiveVolatility);
        
        volatilityState.effectiveVolatility = newEffectiveVolatility;
    }

    /// @notice Adjust pool depth based on volatility changes
    /// @dev Higher volatility = thinner pools, lower volatility = deeper pools
    /// @param baseDepth The base pool depth
    /// @return adjustedDepth The adjusted pool depth
    function _adjustPoolDepth(uint256 baseDepth) internal view returns (uint256 adjustedDepth) {
        // Calculate depth adjustment factor based on volatility ratio
        // If effectiveVolatility > baseVolatility, reduce depth (thinner pool)
        // If effectiveVolatility < baseVolatility, increase depth (deeper pool)
        
        uint256 effectiveVol = volatilityState.effectiveVolatility;
        uint256 baseVol = volatilityState.baseVolatility;

        if (baseVol == 0) {
            return baseDepth;
        }

        // adjustedDepth = baseDepth * (baseVolatility / effectiveVolatility)
        // This ensures: higher volatility -> lower depth, lower volatility -> higher depth
        adjustedDepth = (baseDepth * baseVol) / effectiveVol;
    }

    /// @notice Check if volatility is within safety bounds
    /// @param volatility The volatility value to check
    function _checkVolatilityBounds(uint256 volatility) internal view {
        if (volatility > maxVolatility) {
            revert ExcessiveVolatility(volatility, maxVolatility);
        }
    }

    /// @notice Check if volatility should be updated based on 1% threshold
    /// @return shouldUpdate True if volatility changed by more than 1%
    function _shouldUpdateVolatility() internal view returns (bool shouldUpdate) {
        uint256 currentEffectiveVolatility = calculateEffectiveVolatility();
        
        if (previousEffectiveVolatility == 0) {
            return currentEffectiveVolatility > 0;
        }

        // Calculate percentage change
        uint256 change;
        if (currentEffectiveVolatility > previousEffectiveVolatility) {
            change = currentEffectiveVolatility - previousEffectiveVolatility;
        } else {
            change = previousEffectiveVolatility - currentEffectiveVolatility;
        }

        // Check if change exceeds 1% threshold
        // change / previousEffectiveVolatility > 0.01
        // change * 10000 > previousEffectiveVolatility * 100
        shouldUpdate = (change * Constants.THRESHOLD_DENOMINATOR) > 
                       (previousEffectiveVolatility * Constants.VOLATILITY_UPDATE_THRESHOLD);
    }

    /// @notice Update the previous effective volatility for threshold tracking
    function _updatePreviousEffectiveVolatility() internal {
        previousEffectiveVolatility = volatilityState.effectiveVolatility;
        volatilityState.lastUpdateBlock = block.number;
    }

    /// @notice Get current volatility state
    /// @return The current volatility state
    function getVolatilityState() external view returns (VolatilityState memory) {
        return volatilityState;
    }

    /// @notice Get current effective volatility
    /// @return The current effective volatility
    function getEffectiveVolatility() external view returns (uint256) {
        return volatilityState.effectiveVolatility;
    }

    /// @notice Get current long open interest
    /// @return The current long OI
    function getLongOI() external view returns (uint256) {
        return volatilityState.longOI;
    }

    /// @notice Get current short open interest
    /// @return The current short OI
    function getShortOI() external view returns (uint256) {
        return volatilityState.shortOI;
    }

    /// @notice Get base volatility
    /// @return The base volatility
    function getBaseVolatility() external view returns (uint256) {
        return volatilityState.baseVolatility;
    }
}
