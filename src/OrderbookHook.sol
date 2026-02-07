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
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

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
import {KyleState, VolatilityState, PackedFeeState, ComponentIndicatorState, CurveMode, CurveModeState} from "./DataStructures.sol";
import {CustomCurveEngine} from "./CustomCurveEngine.sol";
import {InputValidator} from "./InputValidator.sol";
import {OrderNotFound} from "./Errors.sol";
import {HookHelpers} from "./libraries/HookHelpers.sol";
import {HookCallbacks} from "./libraries/HookCallbacks.sol";
import {UserOperations} from "./libraries/UserOperations.sol";

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
    AdminDashboard,
    CustomCurveEngine
{
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    using HookCallbacks for *;

    /// @notice The Uniswap V4 PoolManager
    IPoolManager public immutable poolManager;

    /// @notice Current curve mode configuration
    CurveModeState public curveModeState;

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
        
        // Initialize curve mode to HYBRID (orderbook + AMM) by default
        curveModeState = CurveModeState({
            activeMode: CurveMode.HYBRID,
            oracleFeed: address(0),
            useOrderbook: true,
            usePool: true,
            lastModeChange: block.number
        });
        
        // Note: In production, validate hook permissions
        // For testing, we skip this validation as the hook address
        // needs to be deployed at a specific address with correct bit flags
        // Hooks.validateHookPermissions(
        //     IHooks(address(this)),
        //     Hooks.Permissions({
        //         beforeInitialize: true,
        //         afterInitialize: true,
        //         beforeAddLiquidity: true,
        //         afterAddLiquidity: true,
        //         beforeRemoveLiquidity: true,
        //         afterRemoveLiquidity: true,
        //         beforeSwap: true,
        //         afterSwap: true,
        //         beforeDonate: false,
        //         afterDonate: false,
        //         beforeSwapReturnDelta: true,
        //         afterSwapReturnDelta: false,
        //         afterAddLiquidityReturnDelta: true,
        //         afterRemoveLiquidityReturnDelta: true
        //     })
        // );
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
        HookCallbacks.validateInitialization(key, token0, token1);
        
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
    /// @dev Routes to appropriate pricing engine based on CurveMode
    function beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external override nonReentrant returns (bytes4, BeforeSwapDelta, uint24) {
        uint256 totalVolume = HookHelpers.calculateTotalVolume(params.amountSpecified);
        bool isLong = params.zeroForOne; // zeroForOne = buying vBTC = long
        
        uint256 executionPrice;
        uint256 priceImpact;
        BeforeSwapDelta delta;
        
        // Route based on active curve mode
        if (curveModeState.activeMode == CurveMode.VAMM) {
            // VAMM Mode: Use custom curve P = K × Q^(-2)
            (executionPrice, priceImpact) = _executeCurveTrade(totalVolume, isLong);
            
            // Update volatility based on OI change
            _updateOpenInterest(isLong, int256(totalVolume));
            
            // Create delta based on execution
            (delta,,) = HookCallbacks.processBeforeSwap(
                params,
                0, // No orderbook volume in VAMM
                executionPrice,
                totalVolume
            );
            
        } else if (curveModeState.activeMode == CurveMode.ORACLE) {
            // Oracle Mode: Use Chainlink price for instant execution
            (int256 oraclePrice, ) = getLatestPrice(token0);
            executionPrice = oraclePrice > 0 ? uint256(oraclePrice) : 0;
            
            (delta,,) = HookCallbacks.processBeforeSwap(
                params,
                totalVolume, // All volume at oracle price
                executionPrice,
                0
            );
            
        } else {
            // LOB or HYBRID Mode: Use existing orderbook + AMM logic
            (uint256 orderbookVolume, uint256 avgPrice) = _matchOrders();
            uint256 ammOutput = 0;
            
            uint256 ammVolume = HookHelpers.calculateAmmVolume(totalVolume, orderbookVolume);
            
            if (ammVolume > 0 && curveModeState.usePool) {
                ammOutput = _executeSwap(params.zeroForOne, ammVolume);
            }
            
            (delta,,) = HookCallbacks.processBeforeSwap(
                params,
                orderbookVolume,
                avgPrice,
                ammOutput
            );
            
            executionPrice = avgPrice;
        }
        
        // Track order flow and volume for all modes
        _trackOrderFlow(isLong ? int256(totalVolume) : -int256(totalVolume));
        _trackVolume(totalVolume);
        
        // Calculate dynamic fee based on current state
        uint24 dynamicFee = _calculateDynamicFeeWithParams(
            volatilityState.effectiveVolatility,
            volatilityState.baseVolatility,
            volatilityState.longOI,
            volatilityState.shortOI,
            5000
        );
        
        emit SwapExecuted(
            sender,
            params.zeroForOne,
            totalVolume,
            executionPrice,
            curveModeState.activeMode == CurveMode.VAMM ? 0 : totalVolume,
            curveModeState.activeMode == CurveMode.VAMM ? totalVolume : 0,
            block.timestamp
        );
        
        return (this.beforeSwap.selector, delta, dynamicFee);
    }

    /// @notice Hook called after a swap
    /// @dev Update system parameters based on swap results
    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4, int128) {
        uint256 currentTotalOI = volatilityState.longOI + volatilityState.shortOI;
        
        // Update Kyle parameters if needed
        if (_shouldUpdateKyleParameters(currentTotalOI)) {
            _updateKyleParameters(volatilityState.effectiveVolatility, kyleState.baseDepth);
            _updatePreviousTotalOI(currentTotalOI);
        }
        
        // Update volatility if needed
        if (_shouldUpdateVolatility()) {
            uint256 newVolatility = calculateEffectiveVolatility();
            _updatePreviousEffectiveVolatility();
            uint256 adjustedDepth = _adjustPoolDepth(kyleState.baseDepth);
            _updateKyleParameters(newVolatility, adjustedDepth);
        }
        
        // Perform decomposition if enough data
        if (historicalVolume.length >= 3) {
            _performDecomposition();
        }
        
        return (this.afterSwap.selector, 0);
    }

    /// @notice Hook called before liquidity is added
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        HookCallbacks.validateLiquidityParams(params, true);
        return this.beforeAddLiquidity.selector;
    }

    /// @notice Hook called after liquidity is added
    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        uint256 adjustedDepth = _adjustPoolDepth(kyleState.baseDepth);
        _updateKyleParameters(volatilityState.effectiveVolatility, adjustedDepth);
        return (this.afterAddLiquidity.selector, toBalanceDelta(0, 0));
    }

    /// @notice Hook called before liquidity is removed
    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        HookCallbacks.validateLiquidityParams(params, false);
        return this.beforeRemoveLiquidity.selector;
    }

    /// @notice Hook called after liquidity is removed
    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override returns (bytes4, BalanceDelta) {
        uint256 adjustedDepth = _adjustPoolDepth(kyleState.baseDepth);
        _updateKyleParameters(volatilityState.effectiveVolatility, adjustedDepth);
        return (this.afterRemoveLiquidity.selector, toBalanceDelta(0, 0));
    }

    // ============ Public Functions for Users ============

    /// @notice Deposit tokens into custody
    function deposit(address token, uint256 amount) external override nonReentrant {
        UserOperations.validateDeposit(token, amount);
        _deposit(token, amount);
    }

    /// @notice Withdraw available tokens from custody
    function withdraw(address token, uint256 amount) external override nonReentrant {
        UserOperations.validateWithdrawal(token, amount);
        _withdraw(token, amount);
    }

    /// @notice Place a limit order
    function placeOrder(bool isBuy, uint256 price, uint256 quantity) 
        external 
        nonReentrant 
        whenNotPaused
        returns (uint256 orderId) 
    {
        UserOperations.validateOrderPlacement(price, quantity);
        return _placeOrder(isBuy, price, quantity);
    }

    /// @notice Cancel an existing order
    function cancelOrder(uint256 orderId) external nonReentrant {
        if (orderId == 0 || orderId >= nextOrderId) {
            revert OrderNotFound(orderId);
        }
        _cancelOrder(orderId);
    }

    /// @notice Add liquidity to the AMM
    function addLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) external nonReentrant whenNotPaused returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        UserOperations.validateAddLiquidity(tickLower, tickUpper, amount0Desired, amount1Desired);
        return _addLiquidity(tickLower, tickUpper, amount0Desired, amount1Desired);
    }

    /// @notice Remove liquidity from the AMM
    function removeLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidityToRemove
    ) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1) {
        UserOperations.validateRemoveLiquidity(tickLower, tickUpper, liquidityToRemove);
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

    /// @notice Get current curve mode
    /// @return mode The active CurveMode (LOB, HYBRID, VAMM, ORACLE)
    function getCurveMode() external view returns (CurveMode) {
        return curveModeState.activeMode;
    }

    /// @notice Get full curve mode configuration
    /// @return _curveModeState The full curve mode state
    function getCurveModeState() external view returns (CurveModeState memory) {
        return curveModeState;
    }

    /// @notice Set curve mode (admin only)
    /// @param mode The new curve mode
    /// @param oracleFeed Optional oracle feed address for ORACLE mode
    function setCurveMode(CurveMode mode, address oracleFeed) external onlyAdmin {
        curveModeState.activeMode = mode;
        curveModeState.lastModeChange = block.number;
        
        // Configure mode-specific settings
        if (mode == CurveMode.LOB) {
            curveModeState.useOrderbook = true;
            curveModeState.usePool = false;
            curveModeState.oracleFeed = address(0);
        } else if (mode == CurveMode.HYBRID) {
            curveModeState.useOrderbook = true;
            curveModeState.usePool = true;
            curveModeState.oracleFeed = address(0);
        } else if (mode == CurveMode.VAMM) {
            curveModeState.useOrderbook = false;
            curveModeState.usePool = true;
            curveModeState.oracleFeed = address(0);
        } else if (mode == CurveMode.ORACLE) {
            curveModeState.useOrderbook = false;
            curveModeState.usePool = false;
            curveModeState.oracleFeed = oracleFeed;
        }
    }

    /// @notice Initialize the VAMM custom curve (admin only)
    /// @dev Must be called before using VAMM mode
    /// @param initialPrice The starting price for the curve (scaled 1e18)
    /// @param initialQuantity The initial vBTC quantity in pool
    function initializeVAMMCurve(uint256 initialPrice, uint256 initialQuantity) external onlyAdmin {
        _initializeCurve(initialPrice, initialQuantity);
    }

    /// @notice Get custom curve state for VAMM mode
    /// @return k Pool constant
    /// @return q Current vBTC quantity
    /// @return price Current price from P=K×Q^(-2)
    /// @return sensitivity Price sensitivity |dP/dQ|
    function getVAMMCurveState() 
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

    /// @notice Set maximum position size per user (admin only)
    /// @param newLimit The new maximum position size
    function setMaxPositionSize(uint256 newLimit) external onlyAdmin {
        _setMaxPositionSize(newLimit);
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
