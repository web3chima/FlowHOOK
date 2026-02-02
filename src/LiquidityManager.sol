// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LiquidityPosition} from "./DataStructures.sol";
import {InvalidInput, ZeroAmount, InsufficientBalance} from "./Errors.sol";
import {LiquidityModified} from "./Events.sol";
import {CustodyManager} from "./CustodyManager.sol";

/// @title Liquidity Manager
/// @notice Manages concentrated liquidity positions following Uniswap V3 mechanics
/// @dev Implements AMM component with tick-based liquidity tracking
abstract contract LiquidityManager is CustodyManager {
    /// @notice Mapping from position key to LiquidityPosition
    /// @dev Position key is keccak256(abi.encodePacked(provider, tickLower, tickUpper))
    mapping(bytes32 => LiquidityPosition) public positions;

    /// @notice Mapping from tick to total liquidity at that tick
    mapping(int24 => uint128) public tickLiquidity;

    /// @notice Current pool reserves
    uint256 public reserve0;
    uint256 public reserve1;

    /// @notice Current sqrt price (Q64.96 format)
    uint160 public sqrtPriceX96;

    /// @notice Current tick
    int24 public currentTick;

    /// @notice Total liquidity in the pool
    uint128 public totalLiquidity;

    /// @notice Fee growth global for token0
    uint256 public feeGrowthGlobal0;

    /// @notice Fee growth global for token1
    uint256 public feeGrowthGlobal1;

    /// @notice Initialize liquidity manager
    /// @param _token0 Address of token0
    /// @param _token1 Address of token1
    /// @param _initialSqrtPriceX96 Initial sqrt price
    constructor(address _token0, address _token1, uint160 _initialSqrtPriceX96) 
        CustodyManager(_token0, _token1) 
    {
        if (_initialSqrtPriceX96 == 0) revert InvalidInput("initialSqrtPriceX96");
        sqrtPriceX96 = _initialSqrtPriceX96;
        currentTick = _getTickAtSqrtRatio(_initialSqrtPriceX96);
    }

    /// @notice Generate position key from provider address and tick range
    /// @param provider The liquidity provider address
    /// @param tickLower The lower tick boundary
    /// @param tickUpper The upper tick boundary
    /// @return key The position key
    function _getPositionKey(address provider, int24 tickLower, int24 tickUpper) 
        internal 
        pure 
        returns (bytes32 key) 
    {
        key = keccak256(abi.encodePacked(provider, tickLower, tickUpper));
    }

    /// @notice Get position by key
    /// @param provider The liquidity provider address
    /// @param tickLower The lower tick boundary
    /// @param tickUpper The upper tick boundary
    /// @return position The liquidity position
    function getPosition(address provider, int24 tickLower, int24 tickUpper) 
        external 
        view 
        returns (LiquidityPosition memory) 
    {
        bytes32 key = _getPositionKey(provider, tickLower, tickUpper);
        return positions[key];
    }

    /// @notice Get liquidity at a specific tick
    /// @param tick The tick to query
    /// @return liquidity The liquidity at that tick
    function getLiquidityAtTick(int24 tick) external view returns (uint128) {
        return tickLiquidity[tick];
    }

    /// @notice Get current pool state
    /// @return _reserve0 Current reserve of token0
    /// @return _reserve1 Current reserve of token1
    /// @return _sqrtPriceX96 Current sqrt price
    /// @return _currentTick Current tick
    /// @return _totalLiquidity Total liquidity
    function getPoolState() 
        external 
        view 
        returns (
            uint256 _reserve0,
            uint256 _reserve1,
            uint160 _sqrtPriceX96,
            int24 _currentTick,
            uint128 _totalLiquidity
        ) 
    {
        return (reserve0, reserve1, sqrtPriceX96, currentTick, totalLiquidity);
    }

    /// @notice Calculate tick from sqrt price ratio
    /// @param _sqrtPriceX96 The sqrt price in Q64.96 format
    /// @return tick The corresponding tick
    function _getTickAtSqrtRatio(uint160 _sqrtPriceX96) internal pure returns (int24 tick) {
        // Simplified tick calculation
        // In production, use Uniswap V3's TickMath library
        // For now, approximate: tick ≈ log_1.0001(price) ≈ log(sqrtPrice^2) / log(1.0001)
        
        // This is a placeholder - actual implementation would use binary search
        // or the full TickMath library from Uniswap V3
        if (_sqrtPriceX96 >= 79228162514264337593543950336) {
            tick = 0; // Price = 1
        } else if (_sqrtPriceX96 < 79228162514264337593543950336) {
            tick = -1; // Price < 1
        } else {
            tick = 1; // Price > 1
        }
    }

    /// @notice Calculate sqrt price from tick
    /// @param tick The tick
    /// @return _sqrtPriceX96 The sqrt price in Q64.96 format
    function _getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 _sqrtPriceX96) {
        // Simplified sqrt price calculation
        // In production, use Uniswap V3's TickMath library
        
        // This is a placeholder - actual implementation would use the full
        // TickMath library from Uniswap V3
        if (tick == 0) {
            _sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) in Q64.96
        } else if (tick < 0) {
            _sqrtPriceX96 = 79228162514264337593543950336 / 2; // Approximate
        } else {
            _sqrtPriceX96 = 79228162514264337593543950336 * 2; // Approximate
        }
    }

    /// @notice Calculate swap price using Uniswap V3 concentrated liquidity formula
    /// @param zeroForOne True if swapping token0 for token1
    /// @param amountIn The input amount
    /// @return amountOut The output amount
    /// @return newSqrtPriceX96 The new sqrt price after swap
    function calculateSwapPrice(bool zeroForOne, uint256 amountIn) 
        public 
        view 
        returns (uint256 amountOut, uint160 newSqrtPriceX96) 
    {
        if (amountIn == 0) revert ZeroAmount();
        if (totalLiquidity == 0) revert InvalidInput("no liquidity");

        // Get current sqrt price
        uint160 sqrtPriceCurrent = sqrtPriceX96;
        uint128 liquidity = totalLiquidity;

        if (zeroForOne) {
            // Swapping token0 for token1
            // Adding token0 to pool, removing token1
            // Price (token1/token0) should DECREASE
            // Formula: Δx = L * (1/√P_new - 1/√P_current)
            // Rearranged: 1/√P_new = 1/√P_current + (Δx / L)
            
            // Calculate inverse sqrt prices to avoid division
            uint256 invSqrtPriceCurrent = (uint256(1) << 192) / uint256(sqrtPriceCurrent);
            uint256 invSqrtPriceDelta = (amountIn << 96) / uint256(liquidity);
            uint256 invSqrtPriceNew = invSqrtPriceCurrent + invSqrtPriceDelta;
            
            // Convert back to sqrt price
            if (invSqrtPriceNew == 0) {
                newSqrtPriceX96 = type(uint160).max;
            } else {
                uint256 sqrtPriceNew = (uint256(1) << 192) / invSqrtPriceNew;
                newSqrtPriceX96 = sqrtPriceNew > type(uint160).max ? type(uint160).max : uint160(sqrtPriceNew);
            }

            // Calculate output amount: Δy = L * (√P_current - √P_new)
            if (sqrtPriceCurrent > newSqrtPriceX96) {
                amountOut = (uint256(liquidity) * (sqrtPriceCurrent - newSqrtPriceX96)) >> 96;
            } else {
                amountOut = 0;
            }
        } else {
            // Swapping token1 for token0
            // Adding token1 to pool, removing token0
            // Price (token1/token0) should INCREASE
            // Formula: Δy = L * (√P_new - √P_current)
            // Rearranged: √P_new = √P_current + (Δy / L)
            
            // Calculate new sqrt price
            uint256 sqrtPriceDelta = (amountIn << 96) / uint256(liquidity);
            uint256 sqrtPriceNew = uint256(sqrtPriceCurrent) + sqrtPriceDelta;
            
            // Bound to uint160 max
            newSqrtPriceX96 = sqrtPriceNew > type(uint160).max ? type(uint160).max : uint160(sqrtPriceNew);

            // Calculate output amount: Δx = L * (1/√P_new - 1/√P_current)
            uint256 invSqrtPriceNew = (uint256(1) << 192) / uint256(newSqrtPriceX96);
            uint256 invSqrtPriceCurrent = (uint256(1) << 192) / uint256(sqrtPriceCurrent);
            
            if (invSqrtPriceNew > invSqrtPriceCurrent) {
                amountOut = (uint256(liquidity) * (invSqrtPriceNew - invSqrtPriceCurrent)) >> 96;
            } else {
                amountOut = 0;
            }
        }
    }

    /// @notice Calculate liquidity from token amounts and price range
    /// @param amount0 Amount of token0
    /// @param amount1 Amount of token1
    /// @param tickLower Lower tick boundary
    /// @param tickUpper Upper tick boundary
    /// @return liquidity The calculated liquidity
    function _calculateLiquidityFromAmounts(
        uint256 amount0,
        uint256 amount1,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint128 liquidity) {
        if (tickLower >= tickUpper) revert InvalidInput("tick range");
        if (amount0 == 0 && amount1 == 0) revert ZeroAmount();

        // Get sqrt prices at tick boundaries
        uint160 sqrtPriceLower = _getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpper = _getSqrtRatioAtTick(tickUpper);
        uint160 sqrtPriceCurrent = sqrtPriceX96;

        uint128 liquidity0;
        uint128 liquidity1;

        if (sqrtPriceCurrent <= sqrtPriceLower) {
            // Current price below range, only token0 needed
            // L = Δx * (√P_upper * √P_lower) / (√P_upper - √P_lower)
            liquidity0 = _getLiquidityForAmount0(sqrtPriceLower, sqrtPriceUpper, amount0);
            liquidity = liquidity0;
        } else if (sqrtPriceCurrent >= sqrtPriceUpper) {
            // Current price above range, only token1 needed
            // L = Δy / (√P_upper - √P_lower)
            liquidity1 = _getLiquidityForAmount1(sqrtPriceLower, sqrtPriceUpper, amount1);
            liquidity = liquidity1;
        } else {
            // Current price in range, both tokens needed
            liquidity0 = _getLiquidityForAmount0(sqrtPriceCurrent, sqrtPriceUpper, amount0);
            liquidity1 = _getLiquidityForAmount1(sqrtPriceLower, sqrtPriceCurrent, amount1);
            
            // Use minimum of both
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }
    }

    /// @notice Calculate liquidity from token0 amount
    /// @param sqrtPriceA Lower sqrt price
    /// @param sqrtPriceB Upper sqrt price
    /// @param amount0 Amount of token0
    /// @return liquidity The calculated liquidity
    function _getLiquidityForAmount0(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint256 amount0
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceA > sqrtPriceB) {
            (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        }
        
        // L = Δx * (√P_a * √P_b) / (√P_b - √P_a)
        uint256 intermediate = (uint256(sqrtPriceA) * uint256(sqrtPriceB)) >> 96;
        liquidity = uint128((amount0 * intermediate) / (sqrtPriceB - sqrtPriceA));
    }

    /// @notice Calculate liquidity from token1 amount
    /// @param sqrtPriceA Lower sqrt price
    /// @param sqrtPriceB Upper sqrt price
    /// @param amount1 Amount of token1
    /// @return liquidity The calculated liquidity
    function _getLiquidityForAmount1(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtPriceA > sqrtPriceB) {
            (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        }
        
        // L = Δy / (√P_b - √P_a)
        liquidity = uint128((amount1 << 96) / (sqrtPriceB - sqrtPriceA));
    }

    /// @notice Calculate token amounts from liquidity
    /// @param liquidity The liquidity amount
    /// @param tickLower Lower tick boundary
    /// @param tickUpper Upper tick boundary
    /// @return amount0 Amount of token0
    /// @return amount1 Amount of token1
    function _getAmountsForLiquidity(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (liquidity == 0) return (0, 0);

        uint160 sqrtPriceLower = _getSqrtRatioAtTick(tickLower);
        uint160 sqrtPriceUpper = _getSqrtRatioAtTick(tickUpper);
        uint160 sqrtPriceCurrent = sqrtPriceX96;

        if (sqrtPriceCurrent <= sqrtPriceLower) {
            // Current price below range, only token0
            amount0 = _getAmount0ForLiquidity(sqrtPriceLower, sqrtPriceUpper, liquidity);
            amount1 = 0;
        } else if (sqrtPriceCurrent >= sqrtPriceUpper) {
            // Current price above range, only token1
            amount0 = 0;
            amount1 = _getAmount1ForLiquidity(sqrtPriceLower, sqrtPriceUpper, liquidity);
        } else {
            // Current price in range, both tokens
            amount0 = _getAmount0ForLiquidity(sqrtPriceCurrent, sqrtPriceUpper, liquidity);
            amount1 = _getAmount1ForLiquidity(sqrtPriceLower, sqrtPriceCurrent, liquidity);
        }
    }

    /// @notice Calculate token0 amount from liquidity
    /// @param sqrtPriceA Lower sqrt price
    /// @param sqrtPriceB Upper sqrt price
    /// @param liquidity The liquidity amount
    /// @return amount0 Amount of token0
    function _getAmount0ForLiquidity(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint128 liquidity
    ) internal pure returns (uint256 amount0) {
        if (sqrtPriceA > sqrtPriceB) {
            (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        }
        
        // Δx = L * (√P_b - √P_a) / (√P_a * √P_b)
        uint256 numerator = uint256(liquidity) * (sqrtPriceB - sqrtPriceA);
        uint256 denominator = (uint256(sqrtPriceA) * uint256(sqrtPriceB)) >> 96;
        amount0 = numerator / denominator;
    }

    /// @notice Calculate token1 amount from liquidity
    /// @param sqrtPriceA Lower sqrt price
    /// @param sqrtPriceB Upper sqrt price
    /// @param liquidity The liquidity amount
    /// @return amount1 Amount of token1
    function _getAmount1ForLiquidity(
        uint160 sqrtPriceA,
        uint160 sqrtPriceB,
        uint128 liquidity
    ) internal pure returns (uint256 amount1) {
        if (sqrtPriceA > sqrtPriceB) {
            (sqrtPriceA, sqrtPriceB) = (sqrtPriceB, sqrtPriceA);
        }
        
        // Δy = L * (√P_b - √P_a)
        amount1 = (uint256(liquidity) * (sqrtPriceB - sqrtPriceA)) >> 96;
    }

    /// @notice Execute a swap atomically
    /// @param zeroForOne True if swapping token0 for token1
    /// @param amountIn The input amount
    /// @return amountOut The output amount
    function _executeSwap(bool zeroForOne, uint256 amountIn) 
        internal 
        returns (uint256 amountOut) 
    {
        if (amountIn == 0) revert ZeroAmount();
        if (totalLiquidity == 0) revert InvalidInput("no liquidity");

        // Calculate swap price and new sqrt price
        uint160 newSqrtPriceX96;
        (amountOut, newSqrtPriceX96) = calculateSwapPrice(zeroForOne, amountIn);

        // Validate output amount doesn't exceed reserves
        if (zeroForOne) {
            if (amountOut > reserve1) {
                amountOut = reserve1; // Cap to available reserves
            }
        } else {
            if (amountOut > reserve0) {
                amountOut = reserve0; // Cap to available reserves
            }
        }

        // Update reserves atomically
        if (zeroForOne) {
            // Swapping token0 for token1
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            // Swapping token1 for token0
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        // Update sqrt price and tick
        sqrtPriceX96 = newSqrtPriceX96;
        currentTick = _getTickAtSqrtRatio(newSqrtPriceX96);

        // Calculate and apply price impact (stored for external use)
        // Price impact = (newPrice - oldPrice) / oldPrice
        // This is informational and doesn't affect the swap execution
    }

    /// @notice Calculate price impact from a swap
    /// @param oldSqrtPrice The sqrt price before swap
    /// @param newSqrtPrice The sqrt price after swap
    /// @return impactBps The price impact in basis points
    function _calculatePriceImpact(uint160 oldSqrtPrice, uint160 newSqrtPrice) 
        internal 
        pure 
        returns (uint256 impactBps) 
    {
        if (oldSqrtPrice == 0) return 0;

        // Calculate price change percentage
        // impact = |newPrice - oldPrice| / oldPrice
        // Since price = sqrtPrice^2, we can use sqrtPrice directly for approximation
        
        uint256 priceDiff;
        if (newSqrtPrice > oldSqrtPrice) {
            priceDiff = newSqrtPrice - oldSqrtPrice;
        } else {
            priceDiff = oldSqrtPrice - newSqrtPrice;
        }

        // Convert to basis points (1 bp = 0.01%)
        impactBps = (priceDiff * 10000) / oldSqrtPrice;
    }

    /// @notice Get current price from sqrt price
    /// @return price The current price (token1/token0) with 18 decimals
    function getCurrentPrice() external view returns (uint256 price) {
        // price = (sqrtPriceX96 / 2^96)^2
        uint256 sqrtPrice = uint256(sqrtPriceX96);
        price = (sqrtPrice * sqrtPrice) >> 192; // Divide by 2^192 to get actual price
    }

    /// @notice Get reserves
    /// @return _reserve0 Reserve of token0
    /// @return _reserve1 Reserve of token1
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1) {
        return (reserve0, reserve1);
    }

    /// @notice Add liquidity to a position
    /// @param tickLower Lower tick boundary
    /// @param tickUpper Upper tick boundary
    /// @param amount0Desired Desired amount of token0
    /// @param amount1Desired Desired amount of token1
    /// @return liquidity The amount of liquidity added
    /// @return amount0 Actual amount of token0 used
    /// @return amount1 Actual amount of token1 used
    function _addLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        if (tickLower >= tickUpper) revert InvalidInput("tick range");
        if (amount0Desired == 0 && amount1Desired == 0) revert ZeroAmount();

        // Calculate liquidity from desired amounts
        liquidity = _calculateLiquidityFromAmounts(amount0Desired, amount1Desired, tickLower, tickUpper);

        if (liquidity == 0) revert ZeroAmount();

        // Calculate actual amounts needed for this liquidity
        (amount0, amount1) = _getAmountsForLiquidity(liquidity, tickLower, tickUpper);

        // Get or create position
        bytes32 positionKey = _getPositionKey(msg.sender, tickLower, tickUpper);
        LiquidityPosition storage position = positions[positionKey];

        if (position.liquidity == 0) {
            // New position
            position.provider = msg.sender;
            position.tickLower = tickLower;
            position.tickUpper = tickUpper;
            position.feeGrowthInside0 = feeGrowthGlobal0;
            position.feeGrowthInside1 = feeGrowthGlobal1;
        }

        // Update position liquidity
        position.liquidity += liquidity;

        // Update tick liquidity
        tickLiquidity[tickLower] += liquidity;
        tickLiquidity[tickUpper] += liquidity;

        // Update total liquidity if position is in range
        if (currentTick >= tickLower && currentTick < tickUpper) {
            totalLiquidity += liquidity;
        }

        // Update reserves
        reserve0 += amount0;
        reserve1 += amount1;

        // Lock tokens from provider
        if (amount0 > 0) {
            _lockForOrder(msg.sender, token0, amount0);
        }
        if (amount1 > 0) {
            _lockForOrder(msg.sender, token1, amount1);
        }

        emit LiquidityModified(msg.sender, int128(liquidity), tickLower, tickUpper, block.timestamp);
    }

    /// @notice Remove liquidity from a position
    /// @param tickLower Lower tick boundary
    /// @param tickUpper Upper tick boundary
    /// @param liquidityToRemove Amount of liquidity to remove
    /// @return amount0 Amount of token0 returned
    /// @return amount1 Amount of token1 returned
    function _removeLiquidity(int24 tickLower, int24 tickUpper, uint128 liquidityToRemove)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        if (liquidityToRemove == 0) revert ZeroAmount();

        bytes32 positionKey = _getPositionKey(msg.sender, tickLower, tickUpper);
        LiquidityPosition storage position = positions[positionKey];

        if (position.liquidity < liquidityToRemove) {
            revert InsufficientBalance(msg.sender, uint256(liquidityToRemove), uint256(position.liquidity));
        }

        // Calculate amounts to return
        (amount0, amount1) = _getAmountsForLiquidity(liquidityToRemove, tickLower, tickUpper);

        // Collect any accrued fees
        (uint256 fees0, uint256 fees1) = _collectFees(positionKey);
        amount0 += fees0;
        amount1 += fees1;

        // Update position liquidity
        position.liquidity -= liquidityToRemove;

        // Update tick liquidity
        tickLiquidity[tickLower] -= liquidityToRemove;
        tickLiquidity[tickUpper] -= liquidityToRemove;

        // Update total liquidity if position is in range
        if (currentTick >= tickLower && currentTick < tickUpper) {
            totalLiquidity -= liquidityToRemove;
        }

        // Update reserves
        if (amount0 > reserve0) amount0 = reserve0;
        if (amount1 > reserve1) amount1 = reserve1;

        reserve0 -= amount0;
        reserve1 -= amount1;

        // Unlock and return tokens to provider
        if (amount0 > 0) {
            _unlockFromOrder(msg.sender, token0, amount0);
        }
        if (amount1 > 0) {
            _unlockFromOrder(msg.sender, token1, amount1);
        }

        emit LiquidityModified(msg.sender, -int128(liquidityToRemove), tickLower, tickUpper, block.timestamp);
    }

    /// @notice Collect accrued fees for a position
    /// @param positionKey The position key
    /// @return fees0 Fees in token0
    /// @return fees1 Fees in token1
    function _collectFees(bytes32 positionKey) internal returns (uint256 fees0, uint256 fees1) {
        LiquidityPosition storage position = positions[positionKey];

        if (position.liquidity == 0) {
            return (0, 0);
        }

        // Calculate fees earned since last collection
        // fees = liquidity * (feeGrowthGlobal - feeGrowthInside)
        uint256 feeGrowthDelta0 = feeGrowthGlobal0 - position.feeGrowthInside0;
        uint256 feeGrowthDelta1 = feeGrowthGlobal1 - position.feeGrowthInside1;

        fees0 = (uint256(position.liquidity) * feeGrowthDelta0) >> 128;
        fees1 = (uint256(position.liquidity) * feeGrowthDelta1) >> 128;

        // Update position fee growth tracking
        position.feeGrowthInside0 = feeGrowthGlobal0;
        position.feeGrowthInside1 = feeGrowthGlobal1;
    }

    /// @notice Distribute trading fees to liquidity providers
    /// @param amount0 Fee amount in token0
    /// @param amount1 Fee amount in token1
    function _distributeFees(uint256 amount0, uint256 amount1) internal {
        if (totalLiquidity == 0) return;

        // Update global fee growth
        // feeGrowth = (fee * 2^128) / totalLiquidity
        if (amount0 > 0) {
            feeGrowthGlobal0 += (amount0 << 128) / totalLiquidity;
        }
        if (amount1 > 0) {
            feeGrowthGlobal1 += (amount1 << 128) / totalLiquidity;
        }
    }

    /// @notice Get uncollected fees for a position
    /// @param provider The liquidity provider address
    /// @param tickLower Lower tick boundary
    /// @param tickUpper Upper tick boundary
    /// @return fees0 Uncollected fees in token0
    /// @return fees1 Uncollected fees in token1
    function getUnclaimedFees(address provider, int24 tickLower, int24 tickUpper)
        external
        view
        returns (uint256 fees0, uint256 fees1)
    {
        bytes32 positionKey = _getPositionKey(provider, tickLower, tickUpper);
        LiquidityPosition storage position = positions[positionKey];

        if (position.liquidity == 0) {
            return (0, 0);
        }

        uint256 feeGrowthDelta0 = feeGrowthGlobal0 - position.feeGrowthInside0;
        uint256 feeGrowthDelta1 = feeGrowthGlobal1 - position.feeGrowthInside1;

        fees0 = (uint256(position.liquidity) * feeGrowthDelta0) >> 128;
        fees1 = (uint256(position.liquidity) * feeGrowthDelta1) >> 128;
    }
}
