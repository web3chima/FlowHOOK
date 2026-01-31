// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Event Definitions
/// @notice Events emitted by the FlowHook system

/// @notice Emitted when a new order is placed
/// @param orderId The unique order identifier
/// @param trader The address of the trader
/// @param isBuy True if buy order, false if sell order
/// @param price The order price
/// @param quantity The order quantity
/// @param timestamp The block timestamp
event OrderPlaced(
    uint256 indexed orderId,
    address indexed trader,
    bool isBuy,
    uint256 price,
    uint256 quantity,
    uint256 timestamp
);

/// @notice Emitted when orders are matched
/// @param buyOrderId The buy order ID
/// @param sellOrderId The sell order ID
/// @param price The execution price
/// @param quantity The matched quantity
/// @param timestamp The block timestamp
event OrderMatched(
    uint256 indexed buyOrderId,
    uint256 indexed sellOrderId,
    uint256 price,
    uint256 quantity,
    uint256 timestamp
);

/// @notice Emitted when an order is cancelled
/// @param orderId The order ID
/// @param trader The trader address
/// @param refundAmount The amount refunded
/// @param timestamp The block timestamp
event OrderCancelled(
    uint256 indexed orderId,
    address indexed trader,
    uint256 refundAmount,
    uint256 timestamp
);

/// @notice Emitted when a swap is executed
/// @param trader The trader address
/// @param zeroForOne True if swapping token0 for token1
/// @param amountIn The input amount
/// @param amountOut The output amount
/// @param orderbookVolume Volume matched through orderbook
/// @param ammVolume Volume routed to AMM
/// @param timestamp The block timestamp
event SwapExecuted(
    address indexed trader,
    bool zeroForOne,
    uint256 amountIn,
    uint256 amountOut,
    uint256 orderbookVolume,
    uint256 ammVolume,
    uint256 timestamp
);

/// @notice Emitted when liquidity is modified
/// @param provider The liquidity provider address
/// @param liquidityDelta The change in liquidity
/// @param tickLower The lower tick
/// @param tickUpper The upper tick
/// @param timestamp The block timestamp
event LiquidityModified(
    address indexed provider,
    int128 liquidityDelta,
    int24 tickLower,
    int24 tickUpper,
    uint256 timestamp
);

/// @notice Emitted when volatility parameters are updated
/// @param newVolatility The new effective volatility
/// @param longOI The current long open interest
/// @param shortOI The current short open interest
/// @param effectiveDepth The new effective depth
/// @param timestamp The block timestamp
event VolatilityUpdated(
    uint256 newVolatility,
    uint256 longOI,
    uint256 shortOI,
    uint256 effectiveDepth,
    uint256 timestamp
);

/// @notice Emitted when fee parameters are updated
/// @param newFee The new fee value
/// @param volatilityMult The volatility multiplier
/// @param imbalanceMult The imbalance multiplier
/// @param utilizationMult The utilization multiplier
/// @param timestamp The block timestamp
event FeeUpdated(
    uint24 newFee,
    uint256 volatilityMult,
    uint256 imbalanceMult,
    uint256 utilizationMult,
    uint256 timestamp
);

/// @notice Emitted when a de-leveraging operation is executed
/// @param position The position address
/// @param quantity The liquidated quantity
/// @param price The execution price
/// @param twapPrice The TWAP reference price
/// @param timestamp The block timestamp
event DeLeveragingExecuted(
    address indexed position,
    uint256 quantity,
    uint256 price,
    uint256 twapPrice,
    uint256 timestamp
);

/// @notice Emitted when internal price deviates significantly from oracle
/// @param token The token address
/// @param internalPrice The internal price
/// @param oraclePrice The oracle price
/// @param deviation The deviation percentage
/// @param timestamp The block timestamp
event PriceDeviationAlert(
    address indexed token,
    uint256 internalPrice,
    uint256 oraclePrice,
    uint256 deviation,
    uint256 timestamp
);

/// @notice Emitted when an admin action is executed
/// @param admin The admin address
/// @param action The action description
/// @param params The action parameters
/// @param timestamp The block timestamp
event AdminActionExecuted(
    address indexed admin,
    string action,
    bytes params,
    uint256 timestamp
);
