// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILOBEngine} from "./Interfaces.sol";

/// @title Orderbook Engine
/// @notice Simple LOB implementation for FlowHook demo
contract OrderbookEngine is ILOBEngine {
    
    // State
    uint256 public nextOrderId = 1;
    LOBOrder[] public orders; // Use mapping + tracking array for efficiency in real prod, array for demo simplicity
    uint256 public lastTradePrice;

    // Events
    event OrderPlaced(uint256 indexed id, uint256 price, uint256 quantity, bool isBuy, address indexed trader);
    event OrderCancelled(uint256 indexed id);
    event OrderMatched(uint256 indexed id, uint256 price, uint256 quantity);

    // ============ IFlowHookEngine Implementation ============

    /// @notice Execute a Market Order (match against book)
    function executeTrade(uint256 size, bool isLong) external override returns (uint256 executionPrice, uint256 priceImpact) {
        uint256 remaining = size;
        uint256 totalCost = 0;

        // Iterate through orders (inefficient but works for small demo)
        for (uint i = 0; i < orders.length; i++) {
            if (orders[i].active && orders[i].isBuy != isLong) { // Match opposite side
                if (remaining == 0) break;
                
                uint256 tradeSize = remaining > orders[i].quantity ? orders[i].quantity : remaining;
                orders[i].quantity -= tradeSize;
                remaining -= tradeSize;
                totalCost += tradeSize * orders[i].price;
                
                if (orders[i].quantity == 0) {
                    orders[i].active = false;
                }
                
                // Update last trade price on every fill chunk (simplified)
                lastTradePrice = orders[i].price;
                emit OrderMatched(orders[i].id, orders[i].price, tradeSize);
            }
        }

        if (size > remaining) {
            uint256 matched = size - remaining;
            executionPrice = totalCost / matched; // Avg price
        } else {
            // No match found - REVERT (No Mocking)
            revert("Orderbook: Insufficient liquidity");
        }
        
        return (executionPrice, 0);
    }

    function getPrice() external view override returns (uint256) {
        // Return last traded price or 0 if uninitialized
        return lastTradePrice;
    }

    function isInitialized() external pure override returns (bool) {
        return true;
    }

    // ============ ILOBEngine Implementation ============

    function placeOrder(uint256 price, uint256 quantity, bool isBuy) external override returns (uint256 orderId) {
        orderId = nextOrderId++;
        
        orders.push(LOBOrder({
            id: orderId,
            price: price,
            quantity: quantity,
            isBuy: isBuy,
            trader: tx.origin, // Simplified for demo
            active: true
        }));

        // If this is the first order and no price is set, use it as initial reference
        if (lastTradePrice == 0) {
            lastTradePrice = price;
        }

        emit OrderPlaced(orderId, price, quantity, isBuy, tx.origin);
        return orderId;
    }

    function cancelOrder(uint256 orderId) external override {
        for (uint i = 0; i < orders.length; i++) {
            if (orders[i].id == orderId) {
                orders[i].active = false;
                emit OrderCancelled(orderId);
                return;
            }
        }
    }

    function matchOrders() external override returns (uint256 matchedVolume, uint256 avgPrice) {
        return (0, 0);
    }

    /// @notice Get orderbook depth
    function getDepth() external view override returns (uint256 bidDepth, uint256 askDepth) {
        for (uint i = 0; i < orders.length; i++) {
            if (orders[i].active) {
                if (orders[i].isBuy) bidDepth += orders[i].quantity;
                else askDepth += orders[i].quantity;
            }
        }
    }

    /// @notice Get all orders for the UI
    function getOrders() external view override returns (LOBOrder[] memory) {
        return orders;
    }
}
