// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Error Definitions
/// @notice Custom errors for the FlowHook system

/// @notice Insufficient balance for the requested operation
/// @param user The user address
/// @param required The required amount
/// @param available The available amount
error InsufficientBalance(address user, uint256 required, uint256 available);

/// @notice Order not found in the orderbook
/// @param orderId The order ID that was not found
error OrderNotFound(uint256 orderId);

/// @notice Unauthorized attempt to cancel an order
/// @param caller The address attempting cancellation
/// @param orderId The order ID
error UnauthorizedCancellation(address caller, uint256 orderId);

/// @notice Price is out of acceptable bounds
/// @param price The provided price
/// @param minPrice The minimum acceptable price
/// @param maxPrice The maximum acceptable price
error PriceOutOfBounds(uint256 price, uint256 minPrice, uint256 maxPrice);

/// @notice Oracle price data is stale
/// @param feed The oracle feed address
/// @param lastUpdate The timestamp of last update
error StaleOracle(address feed, uint256 lastUpdate);

/// @notice Trading is currently paused
error TradingPaused();

/// @notice Volatility exceeds safety limits
/// @param current The current volatility
/// @param maximum The maximum allowed volatility
error ExcessiveVolatility(uint256 current, uint256 maximum);

/// @notice Invalid hook callback
/// @param selector The function selector that was invalid
error InvalidHookCallback(bytes4 selector);

/// @notice Reentrancy attempt detected
error ReentrancyDetected();

/// @notice Invalid input parameter
/// @param parameter The parameter name
error InvalidInput(string parameter);

/// @notice Operation would exceed position size limit
/// @param user The user address
/// @param currentSize The current position size
/// @param attemptedSize The attempted position size
/// @param limit The maximum allowed position size
error PositionSizeExceeded(address user, uint256 currentSize, uint256 attemptedSize, uint256 limit);

/// @notice Flash loan attack detected
error FlashLoanDetected();

/// @notice Zero amount not allowed for this operation
error ZeroAmount();

/// @notice Unauthorized access to admin function
/// @param caller The address attempting access
error Unauthorized(address caller);
