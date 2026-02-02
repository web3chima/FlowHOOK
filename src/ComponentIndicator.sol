// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./DataStructures.sol";
import "./Events.sol";

/// @title Component Indicator for Trading Activity Decomposition
/// @notice Decomposes trading activity into expected (hedger/informed) and unexpected (speculative) components
/// @dev Uses on-chain ARIMA approximation with exponential smoothing
contract ComponentIndicator {
    // ============ State Variables ============

    /// @notice Current component indicator state
    ComponentIndicatorState public state;

    /// @notice Historical activity data for ARIMA window (minimum 20 observations)
    uint256[] public historicalVolume;
    uint256[] public historicalOI;
    uint256[] public historicalLiquidations;
    uint256[] public historicalLeverage;

    /// @notice Maximum history length for ARIMA window
    uint256 public constant MAX_HISTORY_LENGTH = 20;

    /// @notice Exponential smoothing alpha parameter (scaled by 1e18)
    /// @dev Alpha = 0.3 means 30% weight to new data, 70% to historical trend
    uint256 public constant ALPHA = 3e17; // 0.3 * 1e18

    /// @notice Scaling factor for ratios and percentages
    uint256 public constant SCALE = 1e18;

    /// @notice Trend component for exponential smoothing
    uint256 public trendComponent;

    /// @notice Seasonal baseline (moving average)
    uint256 public seasonalBaseline;

    // ============ Constructor ============

    constructor() {
        // Initialize with zero state
        state.lastUpdateBlock = block.number;
    }

    // ============ Activity Tracking Functions ============

    /// @notice Track trading volume
    /// @param volume The volume to add to tracking
    function _trackVolume(uint256 volume) internal {
        state.totalVolume += volume;
        _addToHistory(historicalVolume, volume);
    }

    /// @notice Track open interest changes
    /// @param oiDelta The change in open interest (can be positive or negative)
    function _trackOpenInterest(int256 oiDelta) internal {
        if (oiDelta > 0) {
            state.totalOpenInterest += uint256(oiDelta);
        } else if (oiDelta < 0) {
            uint256 decrease = uint256(-oiDelta);
            if (decrease > state.totalOpenInterest) {
                state.totalOpenInterest = 0;
            } else {
                state.totalOpenInterest -= decrease;
            }
        }
        _addToHistory(historicalOI, state.totalOpenInterest);
    }

    /// @notice Track liquidation events
    /// @param liquidationAmount The amount liquidated
    function _trackLiquidation(uint256 liquidationAmount) internal {
        state.totalLiquidations += liquidationAmount;
        _addToHistory(historicalLiquidations, liquidationAmount);
    }

    /// @notice Track leverage usage
    /// @param leverage The leverage value (scaled by 1e18)
    function _trackLeverage(uint256 leverage) internal {
        // Calculate running average of leverage
        if (state.averageLeverage == 0) {
            state.averageLeverage = leverage;
        } else {
            // Exponential moving average
            state.averageLeverage = (state.averageLeverage * 9 + leverage) / 10;
        }
        _addToHistory(historicalLeverage, leverage);
    }

    // ============ Internal Helper Functions ============

    /// @notice Add data point to historical array, maintaining max length
    /// @param history The historical array to update
    /// @param value The value to add
    function _addToHistory(uint256[] storage history, uint256 value) internal {
        if (history.length >= MAX_HISTORY_LENGTH) {
            // Shift array left and replace last element
            for (uint256 i = 0; i < MAX_HISTORY_LENGTH - 1; i++) {
                history[i] = history[i + 1];
            }
            history[MAX_HISTORY_LENGTH - 1] = value;
        } else {
            history.push(value);
        }
    }

    // ============ ARIMA Decomposition Functions ============

    /// @notice Calculate exponential smoothing for trend component
    /// @param currentValue The current observed value
    /// @return The smoothed trend value
    function _calculateTrend(uint256 currentValue) internal returns (uint256) {
        if (trendComponent == 0) {
            // Initialize trend with first value
            trendComponent = currentValue;
            return currentValue;
        }

        // Exponential smoothing: trend = alpha * current + (1 - alpha) * previous_trend
        // Using scaled arithmetic: trend = (alpha * current + (SCALE - alpha) * previous) / SCALE
        trendComponent = (ALPHA * currentValue + (SCALE - ALPHA) * trendComponent) / SCALE;
        return trendComponent;
    }

    /// @notice Calculate moving average for seasonal baseline
    /// @param history The historical data array
    /// @return The moving average value
    function _calculateSeasonalBaseline(uint256[] storage history) internal view returns (uint256) {
        if (history.length == 0) {
            return 0;
        }

        uint256 sum = 0;
        uint256 weightedSum = 0;
        uint256 totalWeight = 0;

        // Calculate weighted moving average (recent data weighted higher)
        for (uint256 i = 0; i < history.length; i++) {
            // Weight increases linearly: older data gets weight (i+1), newer data gets higher weight
            uint256 weight = i + 1;
            weightedSum += history[i] * weight;
            totalWeight += weight;
        }

        if (totalWeight == 0) {
            return 0;
        }

        return weightedSum / totalWeight;
    }

    /// @notice Compute residuals as unexpected component
    /// @param observed The observed value
    /// @param trend The trend component
    /// @param seasonal The seasonal component
    /// @return The residual (unexpected) component
    function _calculateResidual(uint256 observed, uint256 trend, uint256 seasonal) internal pure returns (uint256) {
        uint256 expected = trend + seasonal;
        
        if (observed > expected) {
            return observed - expected;
        } else {
            // If observed is less than expected, residual is 0 (no unexpected activity)
            return 0;
        }
    }

    /// @notice Perform ARIMA decomposition on current activity
    /// @dev Decomposes activity into trend + seasonal + residual components
    function _performDecomposition() internal {
        require(historicalVolume.length >= 3, "Insufficient historical data");

        // Get current total activity (combining volume, OI, liquidations)
        uint256 currentActivity = state.totalVolume;

        // Calculate trend component using exponential smoothing
        uint256 trend = _calculateTrend(currentActivity);

        // Calculate seasonal baseline using weighted moving average
        uint256 seasonal = _calculateSeasonalBaseline(historicalVolume);

        // Calculate residual (unexpected component)
        uint256 residual = _calculateResidual(currentActivity, trend, seasonal);

        // Expected component = trend + seasonal (hedger/informed activity)
        state.expectedComponent = trend + seasonal;

        // Unexpected component = residual (speculative activity)
        state.unexpectedComponent = residual;

        // Update seasonal baseline for next iteration
        seasonalBaseline = seasonal;

        // Classify components and calculate speculative ratio
        _classifyComponents();

        // Update last update block
        state.lastUpdateBlock = block.number;

        // Emit event for component update
        emit ComponentIndicatorUpdated(
            state.expectedComponent,
            state.unexpectedComponent,
            state.speculativeRatio,
            state.totalVolume,
            block.timestamp
        );
    }

    // ============ Component Classification Functions ============

    /// @notice Classify components into expected/unexpected and calculate speculative ratio
    /// @dev Expected = trend + seasonal (hedger/informed), Unexpected = residuals (speculative)
    function _classifyComponents() internal {
        // Expected component is already set (trend + seasonal)
        // Unexpected component is already set (residuals)

        // Calculate total activity
        uint256 totalActivity = state.expectedComponent + state.unexpectedComponent;

        // Calculate speculative ratio = unexpected / total activity (scaled by 1e18)
        if (totalActivity > 0) {
            state.speculativeRatio = (state.unexpectedComponent * SCALE) / totalActivity;
        } else {
            state.speculativeRatio = 0;
        }

        // Ensure ratio is bounded [0, 1e18]
        if (state.speculativeRatio > SCALE) {
            state.speculativeRatio = SCALE;
        }
    }

    /// @notice Get hedger ratio (complement of speculative ratio)
    /// @return The hedger ratio (scaled by 1e18)
    function getHedgerRatio() external view returns (uint256) {
        if (state.speculativeRatio >= SCALE) {
            return 0;
        }
        return SCALE - state.speculativeRatio;
    }

    // ============ View Functions ============

    /// @notice Get current component indicator state
    /// @return The current ComponentIndicatorState
    function getState() external view returns (ComponentIndicatorState memory) {
        return state;
    }

    /// @notice Get historical volume data
    /// @return Array of historical volume values
    function getHistoricalVolume() external view returns (uint256[] memory) {
        return historicalVolume;
    }

    /// @notice Get historical OI data
    /// @return Array of historical OI values
    function getHistoricalOI() external view returns (uint256[] memory) {
        return historicalOI;
    }

    /// @notice Get historical liquidations data
    /// @return Array of historical liquidation values
    function getHistoricalLiquidations() external view returns (uint256[] memory) {
        return historicalLiquidations;
    }

    /// @notice Get historical leverage data
    /// @return Array of historical leverage values
    function getHistoricalLeverage() external view returns (uint256[] memory) {
        return historicalLeverage;
    }

    // ============ Admin Dashboard Functions ============

    /// @notice Get comprehensive component metrics for admin dashboard
    /// @return expectedComp The expected component value
    /// @return unexpectedComp The unexpected component value
    /// @return specRatio The speculative ratio
    /// @return totalVol The total volume
    /// @return totalOI The total open interest
    /// @return totalLiq The total liquidations
    /// @return avgLev The average leverage
    function getComponentMetrics() external view returns (
        uint256 expectedComp,
        uint256 unexpectedComp,
        uint256 specRatio,
        uint256 totalVol,
        uint256 totalOI,
        uint256 totalLiq,
        uint256 avgLev
    ) {
        return (
            state.expectedComponent,
            state.unexpectedComponent,
            state.speculativeRatio,
            state.totalVolume,
            state.totalOpenInterest,
            state.totalLiquidations,
            state.averageLeverage
        );
    }

    /// @notice Get component breakdown by activity type
    /// @return volumeComponent Volume contribution to expected component
    /// @return oiComponent OI contribution to expected component
    /// @return liquidationComponent Liquidation contribution to unexpected component
    /// @return leverageComponent Leverage contribution to speculative ratio
    function getComponentBreakdown() external view returns (
        uint256 volumeComponent,
        uint256 oiComponent,
        uint256 liquidationComponent,
        uint256 leverageComponent
    ) {
        // Calculate proportional contributions
        uint256 totalActivity = state.expectedComponent + state.unexpectedComponent;
        
        if (totalActivity > 0) {
            // Volume typically contributes to expected component
            volumeComponent = (state.totalVolume * state.expectedComponent) / totalActivity;
            
            // OI contributes to expected component (hedgers)
            oiComponent = (state.totalOpenInterest * state.expectedComponent) / totalActivity;
            
            // Liquidations contribute to unexpected component (forced activity)
            liquidationComponent = (state.totalLiquidations * state.unexpectedComponent) / totalActivity;
            
            // Leverage amplifies speculative behavior
            leverageComponent = (state.averageLeverage * state.speculativeRatio) / SCALE;
        }
        
        return (volumeComponent, oiComponent, liquidationComponent, leverageComponent);
    }

    /// @notice Get historical trend data for dashboard charts
    /// @return volumeTrend Historical volume array
    /// @return oiTrend Historical OI array
    /// @return liqTrend Historical liquidations array
    /// @return levTrend Historical leverage array
    function getHistoricalTrends() external view returns (
        uint256[] memory volumeTrend,
        uint256[] memory oiTrend,
        uint256[] memory liqTrend,
        uint256[] memory levTrend
    ) {
        return (
            historicalVolume,
            historicalOI,
            historicalLiquidations,
            historicalLeverage
        );
    }

    // ============ Pricing Integration Functions ============

    /// @notice Calculate price impact adjustment based on component composition
    /// @param basePriceImpact The base price impact
    /// @return adjustedImpact The adjusted price impact
    /// @dev Speculative activity increases price impact, hedger activity reduces it
    function calculatePriceImpactAdjustment(uint256 basePriceImpact) external view returns (uint256 adjustedImpact) {
        // If no activity data, return base impact
        if (state.expectedComponent + state.unexpectedComponent == 0) {
            return basePriceImpact;
        }

        // Calculate adjustment multiplier based on speculative ratio
        // High speculative ratio (>0.7) increases impact by up to 30%
        // High hedger ratio (<0.3 speculative) reduces impact by up to 20%
        uint256 threshold70 = (70 * SCALE) / 100; // 0.7 scaled
        uint256 threshold30 = (30 * SCALE) / 100; // 0.3 scaled

        if (state.speculativeRatio > threshold70) {
            // High speculative activity: increase price impact
            uint256 excessRatio = state.speculativeRatio - threshold70;
            uint256 maxExcess = SCALE - threshold70; // 0.3 scaled
            uint256 adjustment = (excessRatio * (SCALE * 3 / 10)) / maxExcess; // Up to 30% increase
            adjustedImpact = basePriceImpact + (basePriceImpact * adjustment) / SCALE;
        } else if (state.speculativeRatio < threshold30) {
            // High hedger activity: reduce price impact
            uint256 belowThreshold = threshold30 - state.speculativeRatio;
            uint256 adjustment = (belowThreshold * (SCALE * 2 / 10)) / threshold30; // Up to 20% reduction
            if (adjustment > SCALE) {
                adjustedImpact = 0;
            } else {
                adjustedImpact = basePriceImpact - (basePriceImpact * adjustment) / SCALE;
            }
        } else {
            // Moderate activity: neutral adjustment
            adjustedImpact = basePriceImpact;
        }
    }

    /// @notice Get component-based pricing multiplier for de-leveraging curve
    /// @return multiplier The pricing multiplier (scaled by 1e18)
    /// @dev Used by de-leveraging curve to adjust pricing based on activity composition
    function getPricingMultiplier() external view returns (uint256 multiplier) {
        // Base multiplier is 1.0
        multiplier = SCALE;

        // Adjust based on speculative ratio
        // High speculation increases multiplier (less favorable pricing for liquidations)
        // High hedger activity decreases multiplier (more favorable pricing)
        if (state.speculativeRatio > (70 * SCALE) / 100) {
            // Increase multiplier by up to 15% for high speculation
            uint256 adjustment = ((state.speculativeRatio - (70 * SCALE) / 100) * (SCALE * 15 / 100)) / ((30 * SCALE) / 100);
            multiplier = SCALE + adjustment;
        } else if (state.speculativeRatio < (30 * SCALE) / 100) {
            // Decrease multiplier by up to 10% for high hedger activity
            uint256 adjustment = (((30 * SCALE) / 100 - state.speculativeRatio) * (SCALE * 10 / 100)) / ((30 * SCALE) / 100);
            multiplier = SCALE - adjustment;
        }
    }
}
