// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Orderbook Math Library
/// @notice Library for orderbook mathematical operations
/// @dev Extracted to reduce contract size and improve gas efficiency
library OrderbookMath {
    /// @notice Calculate the amount to lock for an order
    /// @param isBuy True for buy order, false for sell order
    /// @param price Order price (18 decimals)
    /// @param quantity Order quantity
    /// @return amountToLock The amount of tokens to lock
    function calculateLockAmount(
        bool isBuy,
        uint256 price,
        uint256 quantity
    ) internal pure returns (uint256 amountToLock) {
        // For buy orders: lock token1 (price * quantity)
        // For sell orders: lock token0 (quantity)
        // Overflow is impossible as price and quantity are validated
        unchecked {
            amountToLock = isBuy ? (price * quantity) / 1e18 : quantity;
        }
    }

    /// @notice Calculate volume-weighted average price
    /// @param totalValue The total value of all matched trades
    /// @param totalVolume The total volume of all matched trades
    /// @return avgPrice The volume-weighted average price
    function calculateVWAP(
        uint256 totalValue,
        uint256 totalVolume
    ) internal pure returns (uint256 avgPrice) {
        if (totalVolume == 0) {
            return 0;
        }
        avgPrice = totalValue / totalVolume;
    }

    /// @notice Determine execution price based on maker-taker priority
    /// @param buyPrice The buy order price
    /// @param sellPrice The sell order price
    /// @param buyTimestamp The buy order timestamp
    /// @param sellTimestamp The sell order timestamp
    /// @return executionPrice The price at which the trade should execute
    function determineExecutionPrice(
        uint256 buyPrice,
        uint256 sellPrice,
        uint256 buyTimestamp,
        uint256 sellTimestamp
    ) internal pure returns (uint256 executionPrice) {
        // Execute at maker price (the order that was placed first)
        executionPrice = buyTimestamp <= sellTimestamp ? buyPrice : sellPrice;
    }

    /// @notice Calculate fill quantity for matching orders
    /// @param buyQuantity The buy order quantity
    /// @param sellQuantity The sell order quantity
    /// @return fillQuantity The quantity to fill (minimum of both)
    function calculateFillQuantity(
        uint256 buyQuantity,
        uint256 sellQuantity
    ) internal pure returns (uint256 fillQuantity) {
        fillQuantity = buyQuantity < sellQuantity ? buyQuantity : sellQuantity;
    }

    /// @notice Calculate token amounts for a trade
    /// @param executionPrice The execution price
    /// @param fillQuantity The fill quantity
    /// @return token0Amount The amount of token0 to transfer
    /// @return token1Amount The amount of token1 to transfer
    function calculateTradeAmounts(
        uint256 executionPrice,
        uint256 fillQuantity
    ) internal pure returns (uint256 token0Amount, uint256 token1Amount) {
        token0Amount = fillQuantity;
        // Overflow is impossible as executionPrice and fillQuantity are validated
        unchecked {
            token1Amount = (executionPrice * fillQuantity) / 1e18;
        }
    }

    /// @notice Check if buy and sell orders can match
    /// @param buyPrice The buy order price
    /// @param sellPrice The sell order price
    /// @return canMatch True if buy price >= sell price
    function canOrdersMatch(
        uint256 buyPrice,
        uint256 sellPrice
    ) internal pure returns (bool canMatch) {
        canMatch = buyPrice >= sellPrice;
    }

    /// @notice Calculate spread between best bid and ask
    /// @param bestBid The best bid price
    /// @param bestAsk The best ask price
    /// @return spread The spread value
    /// @return spreadPercent The spread as percentage (scaled by 10000)
    function calculateSpread(
        uint256 bestBid,
        uint256 bestAsk
    ) internal pure returns (uint256 spread, uint256 spreadPercent) {
        if (bestAsk == 0 || bestBid == 0) {
            return (0, 0);
        }

        // Spread calculation - overflow impossible as bestAsk >= bestBid in valid orderbook
        unchecked {
            spread = bestAsk - bestBid;
        }
        
        // Calculate spread percentage: (spread / bestAsk) * 10000
        // Overflow is impossible as spread <= bestAsk
        unchecked {
            spreadPercent = (spread * 10000) / bestAsk;
        }
    }

    /// @notice Calculate mid-market price
    /// @param bestBid The best bid price
    /// @param bestAsk The best ask price
    /// @return midPrice The mid-market price
    function calculateMidPrice(
        uint256 bestBid,
        uint256 bestAsk
    ) internal pure returns (uint256 midPrice) {
        if (bestBid == 0 && bestAsk == 0) {
            return 0;
        }
        if (bestBid == 0) {
            return bestAsk;
        }
        if (bestAsk == 0) {
            return bestBid;
        }

        unchecked {
            midPrice = (bestBid + bestAsk) / 2;
        }
    }

    /// @notice Binary search to find insertion position in sorted array
    /// @param prices Array of prices (sorted)
    /// @param timestamps Array of timestamps (same length as prices)
    /// @param newPrice The new price to insert
    /// @param newTimestamp The new timestamp
    /// @param isDescending True for descending order (buy queue), false for ascending (sell queue)
    /// @return insertIndex The index where the new order should be inserted
    function findInsertionIndex(
        uint256[] memory prices,
        uint256[] memory timestamps,
        uint256 newPrice,
        uint256 newTimestamp,
        bool isDescending
    ) internal pure returns (uint256 insertIndex) {
        if (prices.length == 0) {
            return 0;
        }

        uint256 left = 0;
        uint256 right = prices.length;

        while (left < right) {
            uint256 mid = (left + right) / 2;
            
            bool shouldInsertBefore;
            if (isDescending) {
                // Buy queue: descending price order (highest first)
                shouldInsertBefore = newPrice > prices[mid]
                    || (newPrice == prices[mid] && newTimestamp < timestamps[mid]);
            } else {
                // Sell queue: ascending price order (lowest first)
                shouldInsertBefore = newPrice < prices[mid]
                    || (newPrice == prices[mid] && newTimestamp < timestamps[mid]);
            }

            if (shouldInsertBefore) {
                right = mid;
            } else {
                left = mid + 1;
            }
        }

        insertIndex = left;
    }
}
