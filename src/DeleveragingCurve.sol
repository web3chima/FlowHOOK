// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TWAPState} from "./DataStructures.sol";
import {Constants} from "./Constants.sol";
import {PriceOutOfBounds} from "./Errors.sol";
import {DeLeveragingExecuted} from "./Events.sol";

/// @title Deleveraging Curve
/// @notice Implements TWAP tracking and de-leveraging price calculation
/// @dev Uses 10-block rolling average for TWAP calculation
abstract contract DeleveragingCurve {
    /// @notice TWAP state for price tracking
    TWAPState internal twapState;

    /// @notice Current volatility for de-leveraging calculations
    uint256 internal currentVolatility;

    /// @notice Current pool utilization (scaled by 10000, e.g., 9000 = 90%)
    uint256 internal poolUtilization;

    /// @notice Constructor initializes TWAP state
    constructor() {
        // Initialize TWAP state with zeros
        twapState.currentIndex = 0;
        twapState.sum = 0;
        currentVolatility = 5000 * 1e18; // Default 0.5% volatility
        poolUtilization = 0;
    }

    /// @notice Updates the TWAP with a new price observation
    /// @dev Maintains a 10-block rolling average
    /// @param newPrice The new price to add to the TWAP
    function _updateTWAP(uint256 newPrice) internal {
        // Remove the oldest price from the sum
        twapState.sum = twapState.sum - twapState.priceHistory[twapState.currentIndex] + newPrice;
        
        // Store the new price
        twapState.priceHistory[twapState.currentIndex] = newPrice;
        
        // Move to next index (circular buffer)
        twapState.currentIndex = (twapState.currentIndex + 1) % Constants.TWAP_BLOCKS;
    }

    /// @notice Gets the current TWAP value
    /// @dev Returns the average of the last 10 price observations
    /// @return The TWAP value
    function _getTWAP() internal view returns (uint256) {
        // Return average of all stored prices
        return twapState.sum / Constants.TWAP_BLOCKS;
    }

    /// @notice Calculates de-leveraging price with TWAP and oracle bounds
    /// @dev Price is more favorable than standard AMM and limited to 5% deviation from oracle
    /// @param isBuy True if buying (closing shorts), false if selling (closing longs)
    /// @param quantity The quantity to de-leverage
    /// @param oraclePrice The oracle reference price
    /// @return The calculated de-leveraging price
    function _calculateDeleveragePrice(bool isBuy, uint256 quantity, uint256 oraclePrice)
        internal
        view
        returns (uint256)
    {
        // Get TWAP as base price
        uint256 twapPrice = _getTWAP();
        
        // If TWAP is zero (not enough data), use oracle price
        if (twapPrice == 0) {
            twapPrice = oraclePrice;
        }

        // Calculate maximum allowed deviation (5% from oracle or 0.5 * volatility, whichever is smaller)
        uint256 maxDeviation = (oraclePrice * Constants.MAX_PRICE_DEVIATION) / Constants.THRESHOLD_DENOMINATOR;
        uint256 volatilityBasedDeviation = (oraclePrice * currentVolatility) / (2 * Constants.VOLATILITY_PRECISION);
        
        if (volatilityBasedDeviation < maxDeviation) {
            maxDeviation = volatilityBasedDeviation;
        }

        // Calculate favorable price based on direction
        // Use a smaller deviation to ensure favorability compared to standard AMM
        uint256 favorableDeviation = maxDeviation / 2; // Use half the max deviation for better pricing
        
        uint256 deleveragePrice;
        if (isBuy) {
            // For buying (closing shorts), offer price closer to TWAP (lower than standard AMM)
            // This makes it favorable for the liquidated position
            deleveragePrice = twapPrice + (twapPrice * favorableDeviation) / oraclePrice;
        } else {
            // For selling (closing longs), offer price closer to TWAP (higher than standard AMM)
            // This makes it favorable for the liquidated position
            deleveragePrice = twapPrice - (twapPrice * favorableDeviation) / oraclePrice;
        }

        // Ensure price stays within oracle bounds (5% deviation)
        uint256 minPrice = oraclePrice - (oraclePrice * Constants.MAX_PRICE_DEVIATION) / Constants.THRESHOLD_DENOMINATOR;
        uint256 maxPrice = oraclePrice + (oraclePrice * Constants.MAX_PRICE_DEVIATION) / Constants.THRESHOLD_DENOMINATOR;

        if (deleveragePrice < minPrice) {
            deleveragePrice = minPrice;
        } else if (deleveragePrice > maxPrice) {
            deleveragePrice = maxPrice;
        }

        // Ensure price is reasonable
        if (deleveragePrice == 0) {
            revert PriceOutOfBounds(deleveragePrice, minPrice, maxPrice);
        }

        return deleveragePrice;
    }

    /// @notice Executes a de-leveraging operation
    /// @dev Emits DeLeveragingExecuted event
    /// @param position The position address being liquidated
    /// @param quantity The quantity to de-leverage
    /// @param isBuy True if buying (closing shorts), false if selling (closing longs)
    /// @param oraclePrice The oracle reference price
    /// @return executionPrice The price at which the de-leveraging was executed
    function _executeDeleveraging(address position, uint256 quantity, bool isBuy, uint256 oraclePrice)
        internal
        returns (uint256 executionPrice)
    {
        // Calculate de-leveraging price
        executionPrice = _calculateDeleveragePrice(isBuy, quantity, oraclePrice);

        // Get TWAP for event emission
        uint256 twapPrice = _getTWAP();

        // Emit event
        emit DeLeveragingExecuted(position, quantity, executionPrice, twapPrice, block.timestamp);

        return executionPrice;
    }

    /// @notice Checks if de-leveraging should be prioritized
    /// @dev Returns true when pool utilization exceeds 90%
    /// @return True if de-leveraging should be prioritized
    function _shouldPrioritizeDeleveraging() internal view returns (bool) {
        return poolUtilization > Constants.DELEVERAGING_PRIORITY_THRESHOLD;
    }

    /// @notice Sets the current pool utilization
    /// @param _utilization The new utilization value (scaled by 10000)
    function _setPoolUtilization(uint256 _utilization) internal {
        poolUtilization = _utilization;
    }

    /// @notice Sets the current volatility for de-leveraging calculations
    /// @param _volatility The new volatility value
    function _setVolatility(uint256 _volatility) internal {
        currentVolatility = _volatility;
    }

    /// @notice Gets the TWAP state for external viewing
    /// @return The current TWAP state
    function getTWAPState() external view returns (TWAPState memory) {
        return twapState;
    }

    /// @notice Gets the current TWAP value (external view)
    /// @return The TWAP value
    function getTWAP() external view returns (uint256) {
        return _getTWAP();
    }

    /// @notice Gets the current volatility
    /// @return The current volatility value
    function getCurrentVolatility() external view returns (uint256) {
        return currentVolatility;
    }

    /// @notice Gets the current pool utilization
    /// @return The current pool utilization value
    function getPoolUtilization() external view returns (uint256) {
        return poolUtilization;
    }

    /// @notice Checks if de-leveraging should be prioritized (external view)
    /// @return True if de-leveraging should be prioritized
    function shouldPrioritizeDeleveraging() external view returns (bool) {
        return _shouldPrioritizeDeleveraging();
    }
}
