// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Core Data Structures for FlowHook
/// @notice Defines all core data structures used throughout the system

/// @notice Curve pricing mode - determines market mechanics
/// @dev LOB = Limit Order Book (Binance style), HYBRID = Orderbook+AMM (dYdX style)
/// @dev VAMM = Virtual AMM (Perpetual style), ORACLE = Oracle-based (GMX/GNS style)
enum CurveMode { LOB, HYBRID, VAMM, ORACLE }

/// @notice Configuration state for curve mode
struct CurveModeState {
    CurveMode activeMode;       // Current pricing mode
    address oracleFeed;         // Chainlink oracle (ORACLE mode)
    bool useOrderbook;          // Enable orderbook matching (LOB/HYBRID)
    bool usePool;               // Enable AMM pool routing (HYBRID/VAMM)
    uint256 lastModeChange;     // Block when mode was last changed
}

/// @notice Represents a limit order in the orderbook
struct Order {
    uint256 orderId;
    address trader;
    bool isBuy;
    uint256 price;
    uint256 quantity;
    uint256 timestamp;
    uint256 lockedAmount;
}

/// @notice Kyle model state for price impact calculation
struct KyleState {
    uint256 lambda;
    int256 cumulativeFlow;
    uint256 lastUpdateBlock;
    uint256 baseDepth;
    uint256 effectiveDepth;
}

/// @notice Volatility state tracking open interest effects
struct VolatilityState {
    uint256 baseVolatility;
    uint256 longOI;
    uint256 shortOI;
    uint256 effectiveVolatility;
    uint256 lastUpdateBlock;
}

/// @notice User balance tracking for custody
struct UserBalance {
    uint256 token0Available;
    uint256 token1Available;
    uint256 token0Locked;
    uint256 token1Locked;
}

/// @notice Liquidity position for concentrated liquidity
struct LiquidityPosition {
    address provider;
    uint128 liquidity;
    int24 tickLower;
    int24 tickUpper;
    uint256 feeGrowthInside0;
    uint256 feeGrowthInside1;
}

/// @notice Price feed data from Chainlink
struct PriceFeed {
    address feedAddress;
    uint256 heartbeat;
    uint256 lastUpdate;
    int256 lastPrice;
}

/// @notice TWAP state for de-leveraging
struct TWAPState {
    uint256[10] priceHistory;
    uint256 currentIndex;
    uint256 sum;
}

/// @notice Packed storage for gas optimization - Kyle state
struct PackedKyleState {
    uint64 lambda;
    int64 cumulativeFlow;
    uint64 baseDepth;
    uint64 effectiveDepth;
}

/// @notice Packed storage for gas optimization - Volatility state
struct PackedVolatilityState {
    uint64 baseVolatility;
    uint64 longOI;
    uint64 shortOI;
    uint64 effectiveVolatility;
}

/// @notice Packed storage for gas optimization - Fee state
struct PackedFeeState {
    uint24 currentFee;
    uint24 baseFee;
    uint24 maxFee;
    uint32 lastUpdateBlock;
    bool isPaused;
}

/// @notice Component indicator state for trading activity decomposition
struct ComponentIndicatorState {
    uint256 expectedComponent;      // Hedger/informed trader activity
    uint256 unexpectedComponent;    // Speculative trader activity
    uint256 speculativeRatio;       // Ratio of speculative to total (scaled by 1e18)
    uint256 totalVolume;            // Total trading volume tracked
    uint256 totalOpenInterest;      // Total OI tracked
    uint256 totalLiquidations;      // Total liquidations tracked
    uint256 averageLeverage;        // Average leverage (scaled by 1e18)
    uint256 lastUpdateBlock;        // Last update block number
}
