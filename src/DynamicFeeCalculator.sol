// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Constants} from "./Constants.sol";
import {PackedFeeState} from "./DataStructures.sol";

/// @title Dynamic Fee Calculator
/// @notice Calculates swap fees dynamically based on market conditions
/// @dev Implements fee calculation with volatility, imbalance, and utilization multipliers
library DynamicFeeCalculator {
    /// @notice Calculate dynamic fee based on current market conditions
    /// @param feeState The current fee state
    /// @param currentVolatility The current effective volatility
    /// @param baseVolatility The base volatility
    /// @param longOI The current long open interest
    /// @param shortOI The current short open interest
    /// @param poolUtilization The current pool utilization (scaled by 10000)
    /// @return fee The calculated dynamic fee (in basis points, max 1000000)
    function calculateDynamicFee(
        PackedFeeState memory feeState,
        uint256 currentVolatility,
        uint256 baseVolatility,
        uint256 longOI,
        uint256 shortOI,
        uint256 poolUtilization
    ) internal pure returns (uint24 fee) {
        // Start with base fee
        uint256 calculatedFee = feeState.baseFee;

        // Calculate volatility multiplier
        uint256 volatilityMultiplier = calculateVolatilityMultiplier(
            currentVolatility,
            baseVolatility
        );

        // Calculate imbalance multiplier
        uint256 imbalanceMultiplier = calculateImbalanceMultiplier(
            longOI,
            shortOI
        );

        // Calculate utilization multiplier
        uint256 utilizationMultiplier = calculateUtilizationMultiplier(
            poolUtilization
        );

        // Apply multipliers
        calculatedFee = (calculatedFee * volatilityMultiplier) / Constants.MULTIPLIER_SCALE;
        calculatedFee = (calculatedFee * imbalanceMultiplier) / Constants.MULTIPLIER_SCALE;
        calculatedFee = (calculatedFee * utilizationMultiplier) / Constants.MULTIPLIER_SCALE;

        // Apply bounds: min 0.05% (500), max 1.0% (10000)
        if (calculatedFee < Constants.BASE_FEE) {
            calculatedFee = Constants.BASE_FEE;
        }
        if (calculatedFee > Constants.MAX_FEE) {
            calculatedFee = Constants.MAX_FEE;
        }

        fee = uint24(calculatedFee);
    }

    /// @notice Calculate volatility multiplier
    /// @param currentVolatility The current effective volatility
    /// @param baseVolatility The base volatility
    /// @return multiplier The volatility multiplier (scaled by MULTIPLIER_SCALE)
    function calculateVolatilityMultiplier(
        uint256 currentVolatility,
        uint256 baseVolatility
    ) internal pure returns (uint256 multiplier) {
        if (baseVolatility == 0) {
            return Constants.MULTIPLIER_SCALE; // 1.0x multiplier
        }

        // volatilityMultiplier = 1 + (currentVolatility / baseVolatility - 1) * 0.1
        // = 1 + (currentVolatility - baseVolatility) / baseVolatility * 0.1
        // = 1 + (currentVolatility - baseVolatility) * 0.1 / baseVolatility
        
        if (currentVolatility > baseVolatility) {
            uint256 volDiff = currentVolatility - baseVolatility;
            uint256 adjustment = (volDiff * Constants.VOLATILITY_MULTIPLIER_FACTOR) / baseVolatility;
            multiplier = Constants.MULTIPLIER_SCALE + adjustment;
        } else {
            uint256 volDiff = baseVolatility - currentVolatility;
            uint256 adjustment = (volDiff * Constants.VOLATILITY_MULTIPLIER_FACTOR) / baseVolatility;
            // Ensure we don't go below 0
            if (adjustment > Constants.MULTIPLIER_SCALE) {
                multiplier = 0;
            } else {
                multiplier = Constants.MULTIPLIER_SCALE - adjustment;
            }
        }
    }

    /// @notice Calculate imbalance multiplier based on OI composition
    /// @param longOI The current long open interest
    /// @param shortOI The current short open interest
    /// @return multiplier The imbalance multiplier (scaled by MULTIPLIER_SCALE)
    function calculateImbalanceMultiplier(
        uint256 longOI,
        uint256 shortOI
    ) internal pure returns (uint256 multiplier) {
        uint256 totalOI = longOI + shortOI;
        
        if (totalOI == 0) {
            return Constants.MULTIPLIER_SCALE; // 1.0x multiplier
        }

        // Calculate absolute imbalance
        uint256 imbalance;
        if (longOI > shortOI) {
            imbalance = longOI - shortOI;
        } else {
            imbalance = shortOI - longOI;
        }

        // imbalanceMultiplier = 1 + abs(longOI - shortOI) / (longOI + shortOI) * 0.2
        uint256 imbalanceRatio = (imbalance * Constants.MULTIPLIER_SCALE) / totalOI;
        uint256 adjustment = (imbalanceRatio * Constants.IMBALANCE_MULTIPLIER_FACTOR) / Constants.MULTIPLIER_SCALE;
        
        multiplier = Constants.MULTIPLIER_SCALE + adjustment;
    }

    /// @notice Calculate utilization multiplier based on pool usage
    /// @param poolUtilization The current pool utilization (scaled by 10000, e.g., 5000 = 50%)
    /// @return multiplier The utilization multiplier (scaled by MULTIPLIER_SCALE)
    function calculateUtilizationMultiplier(
        uint256 poolUtilization
    ) internal pure returns (uint256 multiplier) {
        // utilizationMultiplier = 1 + (poolUtilization - 0.5) * 0.3
        // poolUtilization is scaled by 10000, so 0.5 = 5000
        
        if (poolUtilization > 5000) {
            // Above 50% utilization, increase fees
            uint256 utilizationDiff = poolUtilization - 5000;
            uint256 adjustment = (utilizationDiff * Constants.UTILIZATION_MULTIPLIER_FACTOR) / 10000;
            multiplier = Constants.MULTIPLIER_SCALE + adjustment;
        } else {
            // Below 50% utilization, decrease fees
            uint256 utilizationDiff = 5000 - poolUtilization;
            uint256 adjustment = (utilizationDiff * Constants.UTILIZATION_MULTIPLIER_FACTOR) / 10000;
            // Ensure we don't go below 0
            if (adjustment > Constants.MULTIPLIER_SCALE) {
                multiplier = 0;
            } else {
                multiplier = Constants.MULTIPLIER_SCALE - adjustment;
            }
        }
    }

    /// @notice Check if fee should be updated based on block number
    /// @param feeState The current fee state
    /// @param currentBlock The current block number
    /// @return shouldUpdate True if fee can be updated
    function shouldUpdateFee(
        PackedFeeState memory feeState,
        uint256 currentBlock
    ) internal pure returns (bool shouldUpdate) {
        // Fee can only be updated once per block
        shouldUpdate = currentBlock > feeState.lastUpdateBlock;
    }

    /// @notice Check if OI is balanced (within 5% threshold)
    /// @param longOI The current long open interest
    /// @param shortOI The current short open interest
    /// @return isBalanced True if OI is balanced
    function isOIBalanced(
        uint256 longOI,
        uint256 shortOI
    ) internal pure returns (bool isBalanced) {
        uint256 totalOI = longOI + shortOI;
        
        if (totalOI == 0) {
            return true; // Consider balanced if no OI
        }

        uint256 imbalance;
        if (longOI > shortOI) {
            imbalance = longOI - shortOI;
        } else {
            imbalance = shortOI - longOI;
        }

        // Check if imbalance is less than 5% of total OI
        uint256 imbalanceRatio = (imbalance * Constants.THRESHOLD_DENOMINATOR) / totalOI;
        isBalanced = imbalanceRatio < Constants.BALANCED_OI_THRESHOLD;
    }

    /// @notice Check if OI is highly imbalanced (beyond 20% threshold)
    /// @param longOI The current long open interest
    /// @param shortOI The current short open interest
    /// @return isImbalanced True if OI is highly imbalanced
    function isOIImbalanced(
        uint256 longOI,
        uint256 shortOI
    ) internal pure returns (bool isImbalanced) {
        uint256 totalOI = longOI + shortOI;
        
        if (totalOI == 0) {
            return false; // Not imbalanced if no OI
        }

        uint256 imbalance;
        if (longOI > shortOI) {
            imbalance = longOI - shortOI;
        } else {
            imbalance = shortOI - longOI;
        }

        // Check if imbalance is greater than 20% of total OI
        uint256 imbalanceRatio = (imbalance * Constants.THRESHOLD_DENOMINATOR) / totalOI;
        isImbalanced = imbalanceRatio > Constants.IMBALANCED_OI_THRESHOLD;
    }

    /// @notice Apply fee adjustment rules based on OI balance
    /// @param baseFee The base fee
    /// @param longOI The current long open interest
    /// @param shortOI The current short open interest
    /// @return adjustedFee The fee after applying adjustment rules
    function applyOIAdjustmentRules(
        uint24 baseFee,
        uint256 longOI,
        uint256 shortOI
    ) internal pure returns (uint24 adjustedFee) {
        if (isOIBalanced(longOI, shortOI)) {
            // Balanced OI: use minimum base fee
            return Constants.BASE_FEE;
        } else if (isOIImbalanced(longOI, shortOI)) {
            // Highly imbalanced OI: use maximum fee
            return Constants.MAX_FEE;
        } else {
            // Moderate imbalance: use provided base fee
            return baseFee;
        }
    }

    /// @notice Calculate component-based fee multiplier
    /// @param speculativeRatio The speculative ratio from component indicator (scaled by 1e18)
    /// @return multiplier The component multiplier (scaled by MULTIPLIER_SCALE)
    function calculateComponentMultiplier(
        uint256 speculativeRatio
    ) internal pure returns (uint256 multiplier) {
        // Speculative ratio is scaled by 1e18, need to convert to MULTIPLIER_SCALE
        uint256 scaledRatio = (speculativeRatio * Constants.MULTIPLIER_SCALE) / 1e18;
        
        // When speculative ratio > 0.7 (70%), increase fees
        // When hedger ratio > 0.7 (speculative < 0.3), reduce fees
        uint256 threshold70 = (70 * Constants.MULTIPLIER_SCALE) / 100; // 0.7 scaled
        uint256 threshold30 = (30 * Constants.MULTIPLIER_SCALE) / 100; // 0.3 scaled
        
        if (scaledRatio > threshold70) {
            // High speculative activity: increase fees by up to 50%
            // multiplier = 1.0 + (ratio - 0.7) / 0.3 * 0.5
            uint256 excessRatio = scaledRatio - threshold70;
            uint256 maxExcess = Constants.MULTIPLIER_SCALE - threshold70; // 0.3 scaled
            uint256 adjustment = (excessRatio * Constants.MULTIPLIER_SCALE / 2) / maxExcess;
            multiplier = Constants.MULTIPLIER_SCALE + adjustment;
        } else if (scaledRatio < threshold30) {
            // High hedger activity: reduce fees by up to 30%
            // multiplier = 1.0 - (0.3 - ratio) / 0.3 * 0.3
            uint256 belowThreshold = threshold30 - scaledRatio;
            uint256 adjustment = (belowThreshold * (Constants.MULTIPLIER_SCALE * 3 / 10)) / threshold30;
            if (adjustment > Constants.MULTIPLIER_SCALE) {
                multiplier = 0;
            } else {
                multiplier = Constants.MULTIPLIER_SCALE - adjustment;
            }
        } else {
            // Moderate activity: neutral multiplier
            multiplier = Constants.MULTIPLIER_SCALE;
        }
    }

    /// @notice Calculate dynamic fee with component indicator integration
    /// @param feeState The current fee state
    /// @param currentVolatility The current effective volatility
    /// @param baseVolatility The base volatility
    /// @param longOI The current long open interest
    /// @param shortOI The current short open interest
    /// @param poolUtilization The current pool utilization (scaled by 10000)
    /// @param speculativeRatio The speculative ratio from component indicator (scaled by 1e18)
    /// @return fee The calculated dynamic fee (in basis points, max 1000000)
    function calculateDynamicFeeWithComponents(
        PackedFeeState memory feeState,
        uint256 currentVolatility,
        uint256 baseVolatility,
        uint256 longOI,
        uint256 shortOI,
        uint256 poolUtilization,
        uint256 speculativeRatio
    ) internal pure returns (uint24 fee) {
        // Start with base fee
        uint256 calculatedFee = feeState.baseFee;

        // Calculate volatility multiplier
        uint256 volatilityMultiplier = calculateVolatilityMultiplier(
            currentVolatility,
            baseVolatility
        );

        // Calculate imbalance multiplier
        uint256 imbalanceMultiplier = calculateImbalanceMultiplier(
            longOI,
            shortOI
        );

        // Calculate utilization multiplier
        uint256 utilizationMultiplier = calculateUtilizationMultiplier(
            poolUtilization
        );

        // Calculate component multiplier
        uint256 componentMultiplier = calculateComponentMultiplier(
            speculativeRatio
        );

        // Apply all multipliers
        calculatedFee = (calculatedFee * volatilityMultiplier) / Constants.MULTIPLIER_SCALE;
        calculatedFee = (calculatedFee * imbalanceMultiplier) / Constants.MULTIPLIER_SCALE;
        calculatedFee = (calculatedFee * utilizationMultiplier) / Constants.MULTIPLIER_SCALE;
        calculatedFee = (calculatedFee * componentMultiplier) / Constants.MULTIPLIER_SCALE;

        // Apply bounds: min 0.05% (500), max 1.0% (10000)
        if (calculatedFee < Constants.BASE_FEE) {
            calculatedFee = Constants.BASE_FEE;
        }
        if (calculatedFee > Constants.MAX_FEE) {
            calculatedFee = Constants.MAX_FEE;
        }

        fee = uint24(calculatedFee);
    }
}
