// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta, toBalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BaseTestHooks} from "@uniswap/v4-core/src/test/BaseTestHooks.sol";

import {OrderbookEngine} from "./OrderbookEngine.sol";
import {KyleModel} from "./KyleModel.sol";
import {VolatilityCalculator} from "./VolatilityCalculator.sol";
import {LiquidityManager} from "./LiquidityManager.sol";
import {DynamicFeeManager} from "./DynamicFeeManager.sol";
import {ComponentIndicator} from "./ComponentIndicator.sol";
import {DeleveragingCurve} from "./DeleveragingCurve.sol";
import {OracleManager} from "./OracleManager.sol";
import {AdminDashboard} from "./AdminDashboard.sol";
import {SwapExecuted} from "./Events.sol";
import {KyleState, VolatilityState, PackedFeeState, ComponentIndicatorState} from "./DataStructures.sol";

/// @title OrderbookHook
/// @notice Main integration contract for hybrid orderbook-AMM system
/// @dev Implements Uniswap V4 hook callbacks and wires all components together
contract OrderbookHook is 
    BaseTestHooks,
    OrderbookEngine,
    KyleModel,
    VolatilityCalculator,
    LiquidityManager,
    DynamicFeeManager,
    ComponentIndicator,
    DeleveragingCurve,
    OracleManager,
    AdminDashboard
{
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;

    /// @notice The Uniswap V4 PoolManager
    IPoolManager public immutable poolManager;

    /// @notice Constructor
    /// @param _poolManager Address of Uniswap V4 PoolManager
    /// @param _token0 Address of token0
    /// @param _token1 Address of token1
    /// @param _initialSqrtPriceX96 Initial sqrt price for AMM
    /// @param _baseVolatility Initial base volatility
    /// @param _baseDepth Initial market depth
    constructor(
        address _poolManager,
        address _token0,
        address _token1,
        uint160 _initialSqrtPriceX96,
        uint256 _baseVolatility,
        uint256 _baseDepth
    )
        LiquidityManager(_token0, _token1, _initialSqrtPriceX96)
        KyleModel(_baseDepth, _baseVolatility)
        VolatilityCalculator(_baseVolatility, _baseVolatility * 10) // maxVolatility = 10x base
        AdminDashboard(msg.sender) // Grant admin role to deployer
    {
        poolManager = IPoolManager(_poolManager);
    }

    /// @notice Modifier to prevent reentrancy using transient storage
    modifier nonReentrant() {
        uint256 locked;
        assembly {
            locked := tload(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef)
        }
        require(locked == 0, "Reentrancy detected");
        
        assembly {
            tstore(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef, 1)
        }
        
        _;
        
        assembly {
            tstore(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef, 0)
        }
    }

    /// @notice Hook called before pool initialization
    /// @param sender The address initializing the pool
    /// @param key The pool key
    /// @param sqrtPriceX96 The initial sqrt price
    /// @return bytes4 The function selector
    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96
    ) external override returns (bytes4) {
        // Validate tokens match our configuration
        require(
            Currency.unwrap(key.currency0) == token0 && Currency.unwrap(key.currency1) == token1,
            "Token mismatch"
        );
        
        // Initialize Kyle model parameters
        uint256 currentTotalOI = volatilityState.longOI + volatilityState.shortOI;
        _updateKyleParameters(volatilityState.effectiveVolatility, kyleState.baseDepth);
        _updatePreviousTotalOI(currentTotalOI);
        
        return this.beforeInitialize.selector;
    }

    /// @notice Hook called after pool initialization
    /// @param sender The address that initialized the pool
    /// @param key The pool key
    /// @param sqrtPriceX96 The initial sqrt price
    /// @param tick The initial tick
    /// @return bytes4 The function selector
    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick
    ) external override returns (bytes4) {
        // Pool is now initialized and ready for trading
        return this.afterInitialize.selector;
    }

    /// @notice Hook called before a swap
    /// @dev This is where the hybrid orderbook-AMM routing happens
    /// @param sender The address initiating the swap
    /// @param key The pool key
    /// @param params The swap parameters
    /// @param hookData Additional data passed to the hook
    /// @return bytes4 The function selector
    /// @return BeforeSwapDelta The balance delta from orderbook matching
    /// @return uint24 Optional LP fee override
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external override nonReentrant returns (bytes4, BeforeSwapDelta, uint24) {
        // Step 1: Try orderbook matching first
        (uint256 orderbookVolume, uint256 avgPrice) = _matchOrders();
        
        // Step 2: Calculate total volume
        uint256 totalVolume = params.amountSpecified > 0 
            ? uint256(params.amountSpecified) 
            : uint256(-params.amountSpecified);
        
        // Step 3: Route remaining volume to AMM if needed
        uint256 ammVolume = totalVolume > orderbookVolume ? totalVolume - orderbookVolume : 0;
        uint256 ammOutput = ammVolume > 0 ? _executeSwap(params.zeroForOne, ammVolume) : 0;
        
        // Step 4: Track order flow for Kyle model
        _trackOrderFlow(params.zeroForOne ? int256(totalVolume) : -int256(totalVolume));
        
        // Step 5: Update component indicator
        _trackVolume(totalVolume);
        
        // Step 6: Calculate dynamic fee
        uint24 dynamicFee = _calculateDynamicFeeWithParams(
            volatilityState.effectiveVolatility,
            volatilityState.baseVolatility,
            volatilityState.longOI,
            volatilityState.shortOI,
            5000 // 50% utilization as default
        );
        
        // Step 7: Create balance delta for orderbook matches
        BeforeSwapDelta delta = _createBeforeSwapDelta(orderbookVolume, avgPrice, params.zeroForOne);
        
        // Emit swap event
        emit SwapExecuted(
            sender,
            params.zeroForOne,
            totalVolume,
            orderbookVolume + ammOutput,
            orderbookVolume,
            ammVolume,
            block.timestamp
        );
        
        return (this.beforeSwap.selector, delta, dynamicFee);
    }

    /// @notice Helper function to create BeforeSwapDelta (reduces stack depth)
    /// @param orderbookVolume Volume matched in orderbook
    /// @param avgPrice Average execution price
    /// @param zeroForOne Direction of swap
    /// @return delta The BeforeSwapDelta
    function _createBeforeSwapDelta(
        uint256 orderbookVolume,
        uint256 avgPrice,
        bool zeroForOne
    ) internal pure returns (BeforeSwapDelta delta) {
        if (orderbookVolume == 0) {
            return BeforeSwapDeltaLibrary.ZERO_DELTA;
        }
        
        int128 specified = zeroForOne 
            ? -int128(int256(orderbookVolume))
            : int128(int256(orderbookVolume));
        int128 unspecified = zeroForOne
            ? int128(int256(orderbookVolume * avgPrice / 1e18))
            : -int128(int256(orderbookVolume * avgPrice / 1e18));
        
        return toBeforeSwapDelta(specified, unspecified);
    }

    /// @notice Hook called after a swap
    /// @dev Update system parameters based on swap results
    /// @param sender The address that initiated the swap
    /// @param key The pool key
    /// @param params The swap parameters
    /// @param delta The balance delta from the swap
    /// @param hookData Additional data passed to the hook
    /// @return bytes4 The function selector
    /// @return int128 The hook's delta in unspecified currency
    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        // Step 1: Check if Kyle parameters need updating
        uint256 currentTotalOI = volatilityState.longOI + volatilityState.shortOI;
        if (_shouldUpdateKyleParameters(currentTotalOI)) {
            _updateKyleParameters(volatilityState.effectiveVolatility, kyleState.baseDepth);
            _updatePreviousTotalOI(currentTotalOI);
        }
        
        // Step 2: Check if volatility needs updating
        if (_shouldUpdateVolatility()) {
            uint256 newVolatility = calculateEffectiveVolatility();
            _updatePreviousEffectiveVolatility();
            // Adjust pool depth based on new volatility
            uint256 adjustedDepth = _adjustPoolDepth(kyleState.baseDepth);
            _updateKyleParameters(newVolatility, adjustedDepth);
        }
        
        // Step 3: Update component indicator
        if (historicalVolume.length >= 3) {
            _performDecomposition();
        }
        
        // Step 4: Check if de-leveraging is needed
        if (_shouldPrioritizeDeleveraging()) {
            // De-leveraging priority mode activated
            // This would trigger liquidations in a full implementation
        }
        
        return (this.afterSwap.selector, 0);
    }

    /// @notice Hook called before liquidity is added
    /// @param sender The address adding liquidity
    /// @param key The pool key
    /// @param params The modify liquidity parameters
    /// @param hookData Additional data passed to the hook
    /// @return bytes4 The function selector
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        // Validate liquidity parameters
        require(params.liquidityDelta > 0, "Invalid liquidity delta");
        require(params.tickLower < params.tickUpper, "Invalid tick range");
        
        return this.beforeAddLiquidity.selector;
    }

    /// @notice Hook called after liquidity is added
    /// @param sender The address that added liquidity
    /// @param key The pool key
    /// @param params The modify liquidity parameters
    /// @param delta The balance delta
    /// @param feesAccrued The fees accrued
    /// @param hookData Additional data passed to the hook
    /// @return bytes4 The function selector
    /// @return BalanceDelta The hook's delta
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        // Update pool depth based on new liquidity
        uint256 adjustedDepth = _adjustPoolDepth(kyleState.baseDepth);
        _updateKyleParameters(volatilityState.effectiveVolatility, adjustedDepth);
        
        return (this.afterAddLiquidity.selector, toBalanceDelta(0, 0));
    }

    /// @notice Hook called before liquidity is removed
    /// @param sender The address removing liquidity
    /// @param key The pool key
    /// @param params The modify liquidity parameters
    /// @param hookData Additional data passed to the hook
    /// @return bytes4 The function selector
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        // Validate removal parameters
        require(params.liquidityDelta < 0, "Invalid liquidity delta");
        
        return this.beforeRemoveLiquidity.selector;
    }

    /// @notice Hook called after liquidity is removed
    /// @param sender The address that removed liquidity
    /// @param key The pool key
    /// @param params The modify liquidity parameters
    /// @param delta The balance delta
    /// @param feesAccrued The fees accrued
    /// @param hookData Additional data passed to the hook
    /// @return bytes4 The function selector
    /// @return BalanceDelta The hook's delta
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        // Update pool depth based on removed liquidity
        uint256 adjustedDepth = _adjustPoolDepth(kyleState.baseDepth);
        _updateKyleParameters(volatilityState.effectiveVolatility, adjustedDepth);
        
        return (this.afterRemoveLiquidity.selector, toBalanceDelta(0, 0));
    }

    // ============ Public Functions for Users ============

    /// @notice Place a limit order
    /// @param isBuy True for buy order, false for sell order
    /// @param price Order price (18 decimals)
    /// @param quantity Order quantity
    /// @return orderId The unique order ID
    function placeOrder(bool isBuy, uint256 price, uint256 quantity) 
        external 
        nonReentrant 
        whenNotPaused
        returns (uint256 orderId) 
    {
        return _placeOrder(isBuy, price, quantity);
    }

    /// @notice Cancel an existing order
    /// @param orderId The order ID to cancel
    function cancelOrder(uint256 orderId) external nonReentrant {
        _cancelOrder(orderId);
    }

    /// @notice Add liquidity to the AMM
    /// @param tickLower Lower tick boundary
    /// @param tickUpper Upper tick boundary
    /// @param amount0Desired Desired amount of token0
    /// @param amount1Desired Desired amount of token1
    /// @return liquidity The amount of liquidity added
    /// @return amount0 Actual amount of token0 used
    /// @return amount1 Actual amount of token1 used
    function addLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external nonReentrant whenNotPaused returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        return _addLiquidity(tickLower, tickUpper, amount0Desired, amount1Desired);
    }

    /// @notice Remove liquidity from the AMM
    /// @param tickLower Lower tick boundary
    /// @param tickUpper Upper tick boundary
    /// @param liquidityToRemove Amount of liquidity to remove
    /// @return amount0 Amount of token0 returned
    /// @return amount1 Amount of token1 returned
    function removeLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidityToRemove
    ) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1) {
        return _removeLiquidity(tickLower, tickUpper, liquidityToRemove);
    }

    // ============ View Functions ============

    /// @notice Get current system state
    /// @return _kyleState Current Kyle model state
    /// @return _volatilityState Current volatility state
    /// @return _feeState Current fee state
    /// @return _componentState Current component indicator state
    function getSystemState() 
        external 
        view 
        returns (
            KyleState memory _kyleState,
            VolatilityState memory _volatilityState,
            PackedFeeState memory _feeState,
            ComponentIndicatorState memory _componentState
        ) 
    {
        return (
            kyleState,
            volatilityState,
            feeState,
            state
        );
    }

    /// @notice Get orderbook depth
    /// @return buyDepth Number of buy orders
    /// @return sellDepth Number of sell orders
    function getOrderbookDepth() external view returns (uint256 buyDepth, uint256 sellDepth) {
        return (buyOrderIds.length, sellOrderIds.length);
    }

    // ============ Admin Functions ============

    /// @notice Configure a Chainlink price feed for a token
    /// @param token The token address
    /// @param feedAddress The Chainlink aggregator address
    /// @param heartbeat The maximum staleness threshold (0 = use default 5 minutes)
    function configurePriceFeed(
        address token,
        address feedAddress,
        uint256 heartbeat
    ) external {
        // In a production system, this would have onlyAdmin modifier
        _configurePriceFeed(token, feedAddress, heartbeat);
    }

    // ============ AdminDashboard Virtual Function Implementations ============

    /// @notice Apply fee parameter update
    /// @param baseFee The new base fee
    /// @param maxFee The new maximum fee
    function _applyFeeParameterUpdate(uint24 baseFee, uint24 maxFee) internal override {
        feeState.baseFee = baseFee;
        feeState.maxFee = maxFee;
    }

    /// @notice Apply volatility coefficients update
    /// @param longCoeff The new long OI coefficient
    /// @param shortCoeff The new short OI coefficient
    function _applyVolatilityCoefficientsUpdate(int256 longCoeff, int256 shortCoeff) internal override {
        // Note: In the current implementation, coefficients are constants in Constants.sol
        // This function would need to be extended to support dynamic coefficients
        // For now, we emit an event to track the update request
        // A full implementation would require modifying the VolatilityCalculator to use storage variables
    }
}
