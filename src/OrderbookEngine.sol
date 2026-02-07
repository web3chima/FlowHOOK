// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Order} from "./DataStructures.sol";
import {OrderNotFound, UnauthorizedCancellation, InvalidInput, ZeroAmount, PositionSizeExceeded} from "./Errors.sol";
import {OrderPlaced, OrderMatched, OrderCancelled} from "./Events.sol";
import {CustodyManager} from "./CustodyManager.sol";
import {Constants} from "./Constants.sol";
import {OrderbookMath} from "./libraries/OrderbookMath.sol";

/// @title Orderbook Engine
/// @notice Manages limit orders with price-time priority matching
/// @dev Implements traditional orderbook matching with separate buy/sell queues
abstract contract OrderbookEngine is CustodyManager {
    /// @notice Mapping from order ID to Order struct
    mapping(uint256 => Order) public orders;

    /// @notice Array of buy order IDs sorted in descending price order (highest first)
    uint256[] public buyOrderIds;

    /// @notice Array of sell order IDs sorted in ascending price order (lowest first)
    uint256[] public sellOrderIds;

    /// @notice Counter for generating unique order IDs
    uint256 public nextOrderId;

    /// @notice Mapping from user address to their current position size (in token0)
    mapping(address => uint256) public userPositionSize;

    /// @notice Maximum position size per user (configurable by admin)
    uint256 public maxPositionSizePerUser;

    /// @notice Initialize orderbook engine
    /// @dev Constructor removed - initialization happens in derived contract
    constructor() {
        nextOrderId = 1; // Start from 1, 0 is reserved for "no order"
        maxPositionSizePerUser = Constants.DEFAULT_MAX_POSITION_SIZE;
    }

    /// @notice Get all buy order IDs
    /// @return Array of buy order IDs
    function getBuyOrderIds() external view returns (uint256[] memory) {
        return buyOrderIds;
    }

    /// @notice Get all sell order IDs
    /// @return Array of sell order IDs
    function getSellOrderIds() external view returns (uint256[] memory) {
        return sellOrderIds;
    }

    /// @notice Get order details by ID
    /// @param orderId The order ID
    /// @return The order struct
    function getOrder(uint256 orderId) external view returns (Order memory) {
        if (orders[orderId].orderId == 0) {
            revert OrderNotFound(orderId);
        }
        return orders[orderId];
    }

    /// @notice Get the number of buy orders
    /// @return The count of buy orders
    function getBuyOrderCount() external view returns (uint256) {
        return buyOrderIds.length;
    }

    /// @notice Get the number of sell orders
    /// @return The count of sell orders
    function getSellOrderCount() external view returns (uint256) {
        return sellOrderIds.length;
    }

    /// @notice Place a new limit order
    /// @param isBuy True for buy order, false for sell order
    /// @param price Order price (18 decimals)
    /// @param quantity Order quantity
    /// @return orderId The unique order ID
    function _placeOrder(bool isBuy, uint256 price, uint256 quantity) internal returns (uint256 orderId) {
        if (price == 0) revert InvalidInput("price");
        if (quantity == 0) revert ZeroAmount();

        // Check position size limits
        uint256 currentPositionSize = userPositionSize[msg.sender];
        uint256 newPositionSize = currentPositionSize + quantity;
        
        if (newPositionSize > maxPositionSizePerUser) {
            revert PositionSizeExceeded(
                msg.sender,
                currentPositionSize,
                newPositionSize,
                maxPositionSizePerUser
            );
        }

        // Determine which token to lock
        address tokenToLock = isBuy ? token1 : token0;
        uint256 amountToLock = OrderbookMath.calculateLockAmount(isBuy, price, quantity);

        // Lock the required assets
        _lockForOrder(msg.sender, tokenToLock, amountToLock);

        // Update user position size
        userPositionSize[msg.sender] = newPositionSize;

        // Create the order
        orderId = nextOrderId++;
        orders[orderId] = Order({
            orderId: orderId,
            trader: msg.sender,
            isBuy: isBuy,
            price: price,
            quantity: quantity,
            timestamp: block.timestamp,
            lockedAmount: amountToLock
        });

        // Insert into appropriate queue
        _insertOrder(orderId, isBuy);

        emit OrderPlaced(orderId, msg.sender, isBuy, price, quantity, block.timestamp);
    }

    /// @notice Insert order into sorted queue using binary search
    /// @param orderId The order ID to insert
    /// @param isBuy True for buy queue, false for sell queue
    function _insertOrder(uint256 orderId, bool isBuy) internal {
        Order storage newOrder = orders[orderId];
        uint256[] storage queue = isBuy ? buyOrderIds : sellOrderIds;

        // If queue is empty, just add the order
        if (queue.length == 0) {
            queue.push(orderId);
            return;
        }

        // Binary search to find insertion position
        uint256 left = 0;
        uint256 right = queue.length;

        while (left < right) {
            uint256 mid = (left + right) / 2;
            Order storage midOrder = orders[queue[mid]];

            bool shouldInsertBefore;
            if (isBuy) {
                // Buy queue: descending price order (highest first)
                // If prices equal, earlier timestamp comes first
                shouldInsertBefore = newOrder.price > midOrder.price
                    || (newOrder.price == midOrder.price && newOrder.timestamp < midOrder.timestamp);
            } else {
                // Sell queue: ascending price order (lowest first)
                // If prices equal, earlier timestamp comes first
                shouldInsertBefore = newOrder.price < midOrder.price
                    || (newOrder.price == midOrder.price && newOrder.timestamp < midOrder.timestamp);
            }

            if (shouldInsertBefore) {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        // Insert at position 'left'
        queue.push(0); // Expand array
        for (uint256 i = queue.length - 1; i > left; i--) {
            queue[i] = queue[i - 1];
        }
        queue[left] = orderId;
    }

    /// @notice Match orders in the orderbook
    /// @return matchedVolume Total volume matched
    /// @return avgPrice Volume-weighted average execution price
    function _matchOrders() internal returns (uint256 matchedVolume, uint256 avgPrice) {
        if (buyOrderIds.length == 0 || sellOrderIds.length == 0) {
            return (0, 0);
        }

        uint256 totalValue = 0;
        matchedVolume = 0;

        // Keep matching while there are compatible orders
        while (buyOrderIds.length > 0 && sellOrderIds.length > 0) {
            Order storage buyOrder = orders[buyOrderIds[0]];
            Order storage sellOrder = orders[sellOrderIds[0]];

            // Check if orders can match using library
            if (!OrderbookMath.canOrdersMatch(buyOrder.price, sellOrder.price)) {
                break;
            }

            // Execute at maker price using library
            uint256 executionPrice = OrderbookMath.determineExecutionPrice(
                buyOrder.price,
                sellOrder.price,
                buyOrder.timestamp,
                sellOrder.timestamp
            );

            // Determine fill quantity using library
            uint256 fillQuantity = OrderbookMath.calculateFillQuantity(
                buyOrder.quantity,
                sellOrder.quantity
            );

            // Calculate value for VWAP
            unchecked {
                totalValue += executionPrice * fillQuantity;
                matchedVolume += fillQuantity;
            }

            // Calculate actual amounts to transfer using library
            (uint256 token0Amount, uint256 token1Amount) = OrderbookMath.calculateTradeAmounts(
                executionPrice,
                fillQuantity
            );

            // Transfer token0 from seller to buyer
            _transferBetweenUsers(sellOrder.trader, buyOrder.trader, token0, token0Amount);

            // Transfer token1 from buyer to seller
            _transferBetweenUsers(buyOrder.trader, sellOrder.trader, token1, token1Amount);

            // Update order quantities
            unchecked {
                buyOrder.quantity -= fillQuantity;
                sellOrder.quantity -= fillQuantity;

                // Update locked amounts
                buyOrder.lockedAmount -= token1Amount;
                sellOrder.lockedAmount -= token0Amount;

                // Update position sizes (reduce as orders are filled)
                userPositionSize[buyOrder.trader] -= fillQuantity;
                userPositionSize[sellOrder.trader] -= fillQuantity;
            }

            // Emit match event
            emit OrderMatched(buyOrder.orderId, sellOrder.orderId, executionPrice, fillQuantity, block.timestamp);

            // Remove filled orders
            if (buyOrder.quantity == 0) {
                _removeOrderFromQueue(0, true);
            }
            if (sellOrder.quantity == 0) {
                _removeOrderFromQueue(0, false);
            }
        }

        // Calculate volume-weighted average price using library
        avgPrice = OrderbookMath.calculateVWAP(totalValue, matchedVolume);
    }

    /// @notice Remove order from queue by index
    /// @param index Index in the queue
    /// @param isBuy True for buy queue, false for sell queue
    function _removeOrderFromQueue(uint256 index, bool isBuy) internal {
        uint256[] storage queue = isBuy ? buyOrderIds : sellOrderIds;

        require(index < queue.length, "Index out of bounds");

        // Shift elements left
        for (uint256 i = index; i < queue.length - 1; i++) {
            queue[i] = queue[i + 1];
        }
        queue.pop();
    }

    /// @notice Cancel an existing order
    /// @param orderId The order ID to cancel
    function _cancelOrder(uint256 orderId) internal {
        // Check if order exists
        if (orders[orderId].orderId == 0) {
            revert OrderNotFound(orderId);
        }

        Order storage order = orders[orderId];

        // Check authorization - only the trader who placed the order can cancel it
        if (order.trader != msg.sender) {
            revert UnauthorizedCancellation(msg.sender, orderId);
        }

        // Remove order from queue
        _removeOrder(orderId, order.isBuy);

        // Unlock the assets
        address tokenToUnlock = order.isBuy ? token1 : token0;
        _unlockFromOrder(order.trader, tokenToUnlock, order.lockedAmount);

        // Reduce user position size
        unchecked {
            userPositionSize[order.trader] -= order.quantity;
        }

        // Emit cancellation event
        emit OrderCancelled(orderId, order.trader, order.lockedAmount, block.timestamp);

        // Delete the order from storage
        delete orders[orderId];
    }

    /// @notice Remove order from queue by order ID
    /// @param orderId The order ID to remove
    /// @param isBuy True for buy queue, false for sell queue
    function _removeOrder(uint256 orderId, bool isBuy) internal {
        uint256[] storage queue = isBuy ? buyOrderIds : sellOrderIds;

        // Find the order in the queue
        for (uint256 i = 0; i < queue.length; i++) {
            if (queue[i] == orderId) {
                _removeOrderFromQueue(i, isBuy);
                return;
            }
        }

        // If we reach here, order was not found in queue
        revert OrderNotFound(orderId);
    }

    /// @notice Get user's current position size
    /// @param user The user address
    /// @return The current position size
    function getUserPositionSize(address user) external view returns (uint256) {
        return userPositionSize[user];
    }

    /// @notice Get the maximum position size limit
    /// @return The maximum position size per user
    function getMaxPositionSize() external view returns (uint256) {
        return maxPositionSizePerUser;
    }

    /// @notice Set maximum position size per user (admin only)
    /// @param newLimit The new maximum position size
    function _setMaxPositionSize(uint256 newLimit) internal {
        require(
            newLimit >= Constants.MIN_POSITION_SIZE_LIMIT,
            "Position size limit too low"
        );
        maxPositionSizePerUser = newLimit;
    }
}
