// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Constants} from "./Constants.sol";
import {InvalidInput, ZeroAmount} from "./Errors.sol";

/// @title Custom Curve Engine
/// @notice Implements P = K × Q^(-2) pricing formula for VAMM mode
/// @dev Integrates with Kyle model and volatility coefficients for unified pricing
///
/// The Process of Causation:
/// 1. Trader opens long (buys vBTC)
/// 2. Clearing house sweeps vUSDC into pool, withdraws vBTC out
/// 3. vBTC quantity (Q) in pool decreases
/// 4. Price follows P = K × Q^(-2)
/// 5. Smaller Q = larger price movement = higher volatility
///
/// Volatility Coefficients:
/// - Long OI: +3.569e-9 (volatility increases)
/// - Short OI: -1.678e-9 (volatility decreases)
abstract contract CustomCurveEngine {
    // ============ Constants ============
    
    /// @notice Precision for price calculations (18 decimals)
    uint256 constant CURVE_PRECISION = 1e18;
    
    /// @notice Minimum Q to prevent division by zero / price explosion
    uint256 constant MIN_QUANTITY = 1e15; // 0.001 tokens minimum
    
    /// @notice Maximum price to prevent overflow
    uint256 constant MAX_PRICE = 1e36;

    // ============ State Variables ============
    
    /// @notice Pool constant K for the curve formula
    /// @dev K = P × Q² (invariant maintained during swaps)
    uint256 public poolConstant;
    
    /// @notice Virtual BTC quantity in pool (Q_vBTC)
    uint256 public vBTCQuantity;
    
    /// @notice Virtual USDC reserve in pool
    uint256 public vUSDCReserve;
    
    /// @notice Last calculated price from the curve
    uint256 public lastCurvePrice;
    
    /// @notice Total open long positions
    uint256 public totalLongPositions;
    
    /// @notice Total open short positions  
    uint256 public totalShortPositions;
    
    /// @notice Block number of last curve update
    uint256 public lastCurveUpdateBlock;

    // ============ Events ============
    
    event CurveInitialized(uint256 initialK, uint256 initialQ, uint256 initialPrice);
    event CurvePriceUpdated(uint256 newPrice, uint256 newQ, uint256 priceImpact, bool isLong);
    event PositionOpened(address indexed trader, bool isLong, uint256 size, uint256 entryPrice);
    event PositionClosed(address indexed trader, bool isLong, uint256 size, uint256 exitPrice);
    
    // ============ Initialization ============
    
    /// @notice Initialize the custom curve with starting parameters
    /// @param _initialPrice The initial price (scaled by CURVE_PRECISION)
    /// @param _initialQuantity The initial vBTC quantity in pool
    function _initializeCurve(uint256 _initialPrice, uint256 _initialQuantity) internal {
        if (_initialPrice == 0) revert InvalidInput("initialPrice");
        if (_initialQuantity < MIN_QUANTITY) revert InvalidInput("initialQuantity too small");
        
        vBTCQuantity = _initialQuantity;
        lastCurvePrice = _initialPrice;
        
        // Calculate K from initial conditions: K = P × Q²
        poolConstant = (_initialPrice * _initialQuantity * _initialQuantity) / CURVE_PRECISION;
        
        // Initialize vUSDC reserve (K = vUSDC × vBTC implies vUSDC = K / vBTC)
        vUSDCReserve = (poolConstant * CURVE_PRECISION) / _initialQuantity;
        
        lastCurveUpdateBlock = block.number;
        
        emit CurveInitialized(poolConstant, _initialQuantity, _initialPrice);
    }
    
    // ============ Core Pricing Formula ============
    
    /// @notice Calculate price using P = K × Q^(-2) = K / Q²
    /// @return price The calculated price (scaled by CURVE_PRECISION)
    function calculateCurvePrice() public view returns (uint256 price) {
        if (vBTCQuantity < MIN_QUANTITY) {
            return MAX_PRICE; // Prevent division by near-zero
        }
        
        // P = K / Q²
        // To maintain precision: P = (K × PRECISION) / (Q × Q)
        price = (poolConstant * CURVE_PRECISION) / (vBTCQuantity * vBTCQuantity / CURVE_PRECISION);
        
        // Bound to max price
        if (price > MAX_PRICE) {
            price = MAX_PRICE;
        }
    }
    
    /// @notice Calculate price sensitivity (dP/dQ)
    /// @dev Derivative of P = K × Q^(-2) is dP/dQ = -2K × Q^(-3)
    /// @return sensitivity The absolute price sensitivity (always positive)
    function calculatePriceSensitivity() public view returns (uint256 sensitivity) {
        if (vBTCQuantity < MIN_QUANTITY) {
            return MAX_PRICE;
        }
        
        // |dP/dQ| = 2K / Q³
        uint256 qCubed = (vBTCQuantity * vBTCQuantity / CURVE_PRECISION) * vBTCQuantity / CURVE_PRECISION;
        if (qCubed == 0) {
            return MAX_PRICE;
        }
        
        sensitivity = (2 * poolConstant * CURVE_PRECISION) / qCubed;
    }
    
    // ============ Trade Execution ============
    
    /// @notice Execute a trade on the custom curve (VAMM mode)
    /// @param size The trade size in vBTC terms
    /// @param isLong True if opening/adding to long, false for short
    /// @return executionPrice The price at which the trade executed
    /// @return priceImpact The price impact of this trade
    function _executeCurveTrade(uint256 size, bool isLong) 
        internal 
        returns (uint256 executionPrice, uint256 priceImpact) 
    {
        if (size == 0) revert ZeroAmount();
        
        uint256 priceBefore = calculateCurvePrice();
        
        if (isLong) {
            // Long: Trader buys vBTC → vBTC withdrawn from pool → Q decreases
            // Clearing house sweeps vUSDC in, withdraws vBTC out
            
            // Ensure we don't go below minimum quantity
            if (vBTCQuantity <= size + MIN_QUANTITY) {
                revert InvalidInput("trade too large");
            }
            
            vBTCQuantity -= size;
            totalLongPositions += size;
            
            // Update vUSDC reserve to maintain K
            // K = vUSDC × vBTC → vUSDC = K / vBTC
            vUSDCReserve = (poolConstant * CURVE_PRECISION) / vBTCQuantity;
            
        } else {
            // Short: Trader sells vBTC → vBTC added to pool → Q increases
            // Clearing house sweeps vBTC in, withdraws vUSDC out
            
            vBTCQuantity += size;
            totalShortPositions += size;
            
            // Update vUSDC reserve
            vUSDCReserve = (poolConstant * CURVE_PRECISION) / vBTCQuantity;
        }
        
        uint256 priceAfter = calculateCurvePrice();
        lastCurvePrice = priceAfter;
        lastCurveUpdateBlock = block.number;
        
        // Calculate execution price as average of before/after
        executionPrice = (priceBefore + priceAfter) / 2;
        
        // Calculate price impact
        if (priceAfter > priceBefore) {
            priceImpact = ((priceAfter - priceBefore) * CURVE_PRECISION) / priceBefore;
        } else {
            priceImpact = ((priceBefore - priceAfter) * CURVE_PRECISION) / priceBefore;
        }
        
        emit CurvePriceUpdated(priceAfter, vBTCQuantity, priceImpact, isLong);
    }
    
    /// @notice Close a position on the custom curve
    /// @param size The position size to close
    /// @param isLong True if closing a long, false for short
    /// @return executionPrice The price at which the position closed
    function _closeCurvePosition(uint256 size, bool isLong)
        internal
        returns (uint256 executionPrice)
    {
        if (size == 0) revert ZeroAmount();
        
        if (isLong) {
            // Closing long: Sell vBTC back → Q increases
            if (size > totalLongPositions) {
                revert InvalidInput("size exceeds positions");
            }
            
            vBTCQuantity += size;
            totalLongPositions -= size;
            
        } else {
            // Closing short: Buy vBTC back → Q decreases
            if (size > totalShortPositions) {
                revert InvalidInput("size exceeds positions");
            }
            
            if (vBTCQuantity <= size + MIN_QUANTITY) {
                revert InvalidInput("insufficient pool quantity");
            }
            
            vBTCQuantity -= size;
            totalShortPositions -= size;
        }
        
        // Update vUSDC reserve
        vUSDCReserve = (poolConstant * CURVE_PRECISION) / vBTCQuantity;
        
        executionPrice = calculateCurvePrice();
        lastCurvePrice = executionPrice;
        lastCurveUpdateBlock = block.number;
    }
    
    // ============ Volatility Integration ============
    
    /// @notice Calculate volatility adjustment based on OI composition
    /// @dev Long OI: +3.569e-9, Short OI: -1.678e-9
    /// @return volatilityDelta The volatility change (can be positive or negative)
    function _calculateOIVolatilityImpact() internal view returns (int256 volatilityDelta) {
        // Coefficients scaled by 1e18 for precision
        // +3.569e-9 = 3569 (scaled by 1e12 relative to 1e18)
        // -1.678e-9 = -1678 (scaled by 1e12 relative to 1e18)
        
        int256 longImpact = int256((totalLongPositions * 3569) / 1e12);
        int256 shortImpact = -int256((totalShortPositions * 1678) / 1e12);
        
        volatilityDelta = longImpact + shortImpact;
    }
    
    /// @notice Get effective volatility combining base + OI impact
    /// @param baseVolatility The base volatility level
    /// @return effectiveVolatility The adjusted volatility
    function _getEffectiveCurveVolatility(uint256 baseVolatility) 
        internal 
        view 
        returns (uint256 effectiveVolatility) 
    {
        int256 oiImpact = _calculateOIVolatilityImpact();
        
        if (oiImpact >= 0) {
            effectiveVolatility = baseVolatility + uint256(oiImpact);
        } else {
            uint256 absImpact = uint256(-oiImpact);
            if (absImpact >= baseVolatility) {
                effectiveVolatility = baseVolatility / 10; // Floor at 10% of base
            } else {
                effectiveVolatility = baseVolatility - absImpact;
            }
        }
    }
    
    // ============ View Functions ============
    
    /// @notice Get current curve state
    /// @return k Pool constant
    /// @return q Current vBTC quantity
    /// @return price Current price
    /// @return sensitivity Current price sensitivity
    function getCurveState() 
        external 
        view 
        returns (
            uint256 k,
            uint256 q, 
            uint256 price,
            uint256 sensitivity
        ) 
    {
        k = poolConstant;
        q = vBTCQuantity;
        price = calculateCurvePrice();
        sensitivity = calculatePriceSensitivity();
    }
    
    /// @notice Get open interest breakdown
    /// @return longOI Total long open interest
    /// @return shortOI Total short open interest
    /// @return netOI Net OI (long - short)
    function getOpenInterest()
        external
        view
        returns (uint256 longOI, uint256 shortOI, int256 netOI)
    {
        longOI = totalLongPositions;
        shortOI = totalShortPositions;
        netOI = int256(longOI) - int256(shortOI);
    }
    
    /// @notice Simulate a trade to get expected price impact
    /// @param size The trade size
    /// @param isLong True for long, false for short
    /// @return expectedPrice The expected execution price
    /// @return expectedImpact The expected price impact
    function simulateTrade(uint256 size, bool isLong)
        external
        view
        returns (uint256 expectedPrice, uint256 expectedImpact)
    {
        uint256 priceBefore = calculateCurvePrice();
        
        uint256 newQ;
        if (isLong) {
            if (vBTCQuantity <= size + MIN_QUANTITY) {
                return (MAX_PRICE, CURVE_PRECISION); // 100% impact
            }
            newQ = vBTCQuantity - size;
        } else {
            newQ = vBTCQuantity + size;
        }
        
        // P = K / Q²
        uint256 priceAfter = (poolConstant * CURVE_PRECISION) / (newQ * newQ / CURVE_PRECISION);
        if (priceAfter > MAX_PRICE) {
            priceAfter = MAX_PRICE;
        }
        
        expectedPrice = (priceBefore + priceAfter) / 2;
        
        if (priceAfter > priceBefore) {
            expectedImpact = ((priceAfter - priceBefore) * CURVE_PRECISION) / priceBefore;
        } else {
            expectedImpact = ((priceBefore - priceAfter) * CURVE_PRECISION) / priceBefore;
        }
    }
}
