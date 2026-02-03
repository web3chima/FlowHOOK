// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VolatilityState} from "./DataStructures.sol";
import {Constants} from "./Constants.sol";
import {InvalidInput, ExcessiveVolatility} from "./Errors.sol";
import {VolatilityMath} from "./libraries/VolatilityMath.sol";
import "./Events.sol";

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
        return VolatilityMath.calculateEffectiveVolatility(
            volatilityState.baseVolatility,
            volatilityState.longOI,
            volatilityState.shortOI
        );
    }

    /// @notice Update open interest tracking
    /// @param isLong True if updating long OI, false for short OI
    /// @param delta The change in OI (can be positive or negative)
    function _updateOpenInterest(bool isLong, int256 delta) internal {
        if (isLong) {
            volatilityState.longOI = VolatilityMath.updateOI(volatilityState.longOI, delta);
        } else {
            volatilityState.shortOI = VolatilityMath.updateOI(volatilityState.shortOI, delta);
        }

        // Recalculate effective volatility
        uint256 newEffectiveVolatility = calculateEffectiveVolatility();
        
        // Check volatility bounds
        _checkVolatilityBounds(newEffectiveVolatility);
        
        volatilityState.effectiveVolatility = newEffectiveVolatility;
        
        // Emit volatility update event (Requirement 13.6)
        emit VolatilityUpdated(
            newEffectiveVolatility,
            volatilityState.longOI,
            volatilityState.shortOI,
            _adjustPoolDepth(1e18), // Use 1e18 as base to get effective depth ratio
            block.timestamp
        );
    }

    /// @notice Adjust pool depth based on volatility changes
    /// @dev Higher volatility = thinner pools, lower volatility = deeper pools
    /// @param baseDepth The base pool depth
    /// @return adjustedDepth The adjusted pool depth
    function _adjustPoolDepth(uint256 baseDepth) internal view returns (uint256 adjustedDepth) {
        adjustedDepth = VolatilityMath.adjustPoolDepth(
            baseDepth,
            volatilityState.effectiveVolatility,
            volatilityState.baseVolatility
        );
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
        shouldUpdate = VolatilityMath.shouldUpdateForVolatilityChange(
            currentEffectiveVolatility,
            previousEffectiveVolatility
        );
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
