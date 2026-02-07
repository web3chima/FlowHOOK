// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Curve Math Library
/// @notice Math operations for custom curve P = K × Q^(-2)
/// @dev Extracted for gas optimization and contract size reduction
library CurveMath {
    /// @notice Precision constant
    uint256 constant PRECISION = 1e18;
    

    /// @notice Calculate price from curve: P = K / Q²
    /// @param k The pool constant (54 decimals)
    /// @param q The vBTC quantity in pool (18 decimals)
    /// @return price The calculated price (18 decimals)
    function calculatePrice(uint256 k, uint256 q) internal pure returns (uint256 price) {
        require(q > 0, "CurveMath: zero quantity");
        
        // P = K / Q²
        // K has 54 decimals (18+18+18)
        // Q² has 36 decimals
        // Result has 18 decimals
        price = k / (q * q);
    }
    
    /// @notice Calculate price sensitivity: |dP/dQ| = 2K / Q³
    /// @param k The pool constant (54 decimals)
    /// @param q The vBTC quantity in pool (18 decimals)
    /// @return sensitivity The price sensitivity (18 decimals)
    function calculateSensitivity(uint256 k, uint256 q) internal pure returns (uint256 sensitivity) {
        require(q > 0, "CurveMath: zero quantity");
        
        // |dP/dQ| = 2K / Q³
        // K has 54 decimals
        // Q³ has 54 decimals
        // Base result is 0 decimals. Multiply by PRECISION to get 18 decimals.
        // Check for overflow: q < 1e25 guarantees q³ < 1e76, fits in uint256 (1e77)
        uint256 numerator = 2 * k * PRECISION;
        uint256 denominator = q * q * q;
        
        if (denominator == 0) return type(uint256).max;
        sensitivity = numerator / denominator;
    }
    
    /// @notice Calculate K from price and quantity: K = P × Q²
    /// @param price The current price (18 decimals)
    /// @param q The vBTC quantity (18 decimals)
    /// @return k The pool constant (54 decimals)
    function calculateK(uint256 price, uint256 q) internal pure returns (uint256 k) {
        // K = P × Q²
        // 18 + 36 = 54 decimals
        k = price * q * q;
    }
    
    /// @notice Calculate new Q after trade
    /// @param currentQ Current quantity
    /// @param tradeSize Trade size
    /// @param isLong True if long (Q decreases), false if short (Q increases)
    /// @param minQ Minimum allowed quantity
    /// @return newQ The new quantity after trade
    function calculateNewQuantity(
        uint256 currentQ,
        uint256 tradeSize,
        bool isLong,
        uint256 minQ
    ) internal pure returns (uint256 newQ) {
        if (isLong) {
            // Long: Q decreases
            require(currentQ > tradeSize + minQ, "CurveMath: trade too large");
            newQ = currentQ - tradeSize;
        } else {
            // Short: Q increases
            newQ = currentQ + tradeSize;
        }
    }
    
    /// @notice Calculate price impact of a trade
    /// @param priceBefore Price before trade
    /// @param priceAfter Price after trade
    /// @return impact Price impact (scaled by PRECISION)
    function calculatePriceImpact(
        uint256 priceBefore,
        uint256 priceAfter
    ) internal pure returns (uint256 impact) {
        if (priceBefore == 0) return 0;
        
        if (priceAfter > priceBefore) {
            impact = ((priceAfter - priceBefore) * PRECISION) / priceBefore;
        } else {
            impact = ((priceBefore - priceAfter) * PRECISION) / priceBefore;
        }
    }
    
    /// @notice Calculate volatility impact from OI
    /// @param longOI Long open interest
    /// @param shortOI Short open interest
    /// @return delta Volatility delta (can be negative via int256)
    /// @dev Long: +3.569e-9, Short: -1.678e-9
    function calculateOIVolatilityDelta(
        uint256 longOI,
        uint256 shortOI
    ) internal pure returns (int256 delta) {
        // Coefficients: +3.569e-9 = 3569/1e12, -1.678e-9 = -1678/1e12
        int256 longImpact = int256((longOI * 3569) / 1e12);
        int256 shortImpact = -int256((shortOI * 1678) / 1e12);
        
        delta = longImpact + shortImpact;
    }
    
    /// @notice Calculate execution price (midpoint of before/after)
    /// @param priceBefore Price before trade
    /// @param priceAfter Price after trade
    /// @return executionPrice The execution price
    function calculateExecutionPrice(
        uint256 priceBefore,
        uint256 priceAfter
    ) internal pure returns (uint256 executionPrice) {
        executionPrice = (priceBefore + priceAfter) / 2;
    }
}
