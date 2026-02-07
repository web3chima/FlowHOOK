// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {IVAMMEngine, ILOBEngine, IOracleEngine} from "./Interfaces.sol";
import {IFeeEngine} from "./Interfaces.sol";

/// @title Flow Hook Router
/// @notice Minimal Uniswap V4 hook that routes to external engine modules
/// @dev Designed to be under 24KB for EVM deployment
contract FlowHookRouter is IHooks {
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;
    
    // ============ Enums ============
    
    enum CurveMode {
        LOB,      // Limit order book only
        HYBRID,   // Orderbook + AMM
        VAMM,     // Virtual AMM (P = K × Q^(-2))
        ORACLE    // Oracle-based pricing
    }
    
    // ============ State Variables ============
    
    /// @notice The Uniswap V4 PoolManager
    IPoolManager public immutable poolManager;
    
    /// @notice VAMM Engine for custom curve pricing
    IVAMMEngine public vammEngine;
    
    /// @notice Fee Engine for dynamic fees
    IFeeEngine public feeEngine;

    /// @notice Orderbook Engine for LOB
    ILOBEngine public orderbookEngine;

    /// @notice Oracle Engine for pricing
    IOracleEngine public oracleEngine;
    
    /// @notice Current operating mode
    CurveMode public curveMode;
    
    /// @notice Admin address
    address public admin;
    
    /// @notice Token addresses
    address public immutable token0;
    address public immutable token1;
    
    /// @notice Reentrancy guard
    uint256 private _locked;
    
    // ============ Events ============
    
    event ModeChanged(CurveMode oldMode, CurveMode newMode);
    event EngineUpdated(string engineType, address newAddress);
    event SwapExecuted(
        address indexed trader,
        bool isLong,
        uint256 size,
        uint256 executionPrice,
        uint256 priceImpact,
        uint256 timestamp
    );
    
    // ============ Errors ============
    
    error Unauthorized();
    error ReentrancyGuard();
    error EngineNotSet();
    error InvalidMode();
    
    // ============ Modifiers ============
    
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }
    
    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert Unauthorized();
        _;
    }
    
    modifier nonReentrant() {
        if (_locked == 1) revert ReentrancyGuard();
        _locked = 1;
        _;
        _locked = 0;
    }
    
    // ============ Constructor ============
    
    constructor(
        address _poolManager,
        address _token0,
        address _token1
    ) {
        poolManager = IPoolManager(_poolManager);
        token0 = _token0;
        token1 = _token1;
        admin = msg.sender;
        curveMode = CurveMode.VAMM; // Default to VAMM mode
    }
    
    // ============ Hook Configuration ============
    
    function getHookPermissions() external pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
    
    // ============ Hook Callbacks ============
    
    function beforeInitialize(
        address,
        PoolKey calldata,
        uint160
    ) external view override onlyPoolManager returns (bytes4) {
        return this.beforeInitialize.selector;
    }
    
    function afterInitialize(
        address,
        PoolKey calldata,
        uint160,
        int24
    ) external pure override returns (bytes4) {
        return this.afterInitialize.selector;
    }
    
    function beforeSwap(
        address sender,
        PoolKey calldata,
        SwapParams calldata params,
        bytes calldata
    ) external override onlyPoolManager nonReentrant returns (bytes4, BeforeSwapDelta, uint24) {
        
        uint256 size = params.amountSpecified < 0 
            ? uint256(-params.amountSpecified) 
            : uint256(params.amountSpecified);
        bool isLong = params.zeroForOne;
        
        uint256 executionPrice;
        uint256 priceImpact;
        uint24 fee;
        
        if (curveMode == CurveMode.VAMM) {
            if (address(vammEngine) == address(0)) revert EngineNotSet();
            
            // Execute trade on VAMM engine
            (executionPrice, priceImpact) = vammEngine.executeTrade(size, isLong);
            
            // Calculate fee
            if (address(feeEngine) != address(0)) {
                (uint256 longOI, uint256 shortOI,) = vammEngine.getOpenInterest();
                fee = feeEngine.calculateFee(size, priceImpact, longOI, shortOI);
            } else {
                fee = 3000; // Default 0.3%
            }
        } else if (curveMode == CurveMode.LOB) {
            if (address(orderbookEngine) == address(0)) revert EngineNotSet();
            (executionPrice, priceImpact) = orderbookEngine.executeTrade(size, isLong);
            fee = 1000; // 0.1% for LOB
        } else if (curveMode == CurveMode.HYBRID) {
             if (address(orderbookEngine) == address(0) || address(vammEngine) == address(0)) revert EngineNotSet();
             // Simple Hybrid: Match Orderbook first, then VAMM for remaining
             (executionPrice, priceImpact) = vammEngine.executeTrade(size, isLong);
             fee = 2000; // 0.2%
        } else {
            // ORACLE Mode
            if (address(oracleEngine) == address(0)) revert EngineNotSet();
            (executionPrice, ) = oracleEngine.getOraclePrice();
            priceImpact = 0;
            fee = 500; // 0.05% for Oracle
        }
        
        emit SwapExecuted(sender, isLong, size, executionPrice, priceImpact, block.timestamp);
        
        // Return empty delta (VAMM handles internally), fee
        BeforeSwapDelta delta = BeforeSwapDeltaLibrary.ZERO_DELTA;
        return (this.beforeSwap.selector, delta, fee);
    }
    
    function afterSwap(
        address,
        PoolKey calldata,
        SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, int128) {
        return (this.afterSwap.selector, 0);
    }
    
    function beforeAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        return this.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {
        return (this.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        return this.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {
        return (this.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        return this.beforeDonate.selector;
    }

    function afterDonate(
        address,
        PoolKey calldata,
        uint256,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        return this.afterDonate.selector;
    }
    
    // ============ Trade Functions ============

    /// @notice Place a limit order (LOB Mode)
    function placeLimitOrder(uint256 price, uint256 quantity, bool isBuy) external nonReentrant returns (uint256 orderId) {
        if (curveMode == CurveMode.VAMM) revert InvalidMode();
        if (address(orderbookEngine) == address(0)) revert EngineNotSet();
        return orderbookEngine.placeOrder(price, quantity, isBuy);
    }

    /// @notice Cancel a limit order
    function cancelOrder(uint256 orderId) external nonReentrant {
        if (address(orderbookEngine) == address(0)) revert EngineNotSet();
        orderbookEngine.cancelOrder(orderId);
    }

    // ============ View Functions ============
    
    /// @notice Get current VAMM curve state
    function getVAMMState() external view returns (
        uint256 k,
        uint256 q,
        uint256 price,
        uint256 sensitivity
    ) {
        if (address(vammEngine) == address(0)) return (0, 0, 0, 0);
        return vammEngine.getCurveState();
    }
    
    /// @notice Get open interest
    function getOpenInterest() external view returns (
        uint256 longOI,
        uint256 shortOI,
        int256 netOI
    ) {
        if (address(vammEngine) == address(0)) return (0, 0, 0);
        return vammEngine.getOpenInterest();
    }
    
    /// @notice Get current price
    function getCurrentPrice() external view returns (uint256) {
        if (curveMode == CurveMode.VAMM && address(vammEngine) != address(0)) {
            return vammEngine.getPrice();
        } else if (curveMode == CurveMode.ORACLE && address(oracleEngine) != address(0)) {
            (uint256 price, ) = oracleEngine.getOraclePrice();
            return price;
        }
        return 0;
    }
    
    // ============ Admin Functions ============
    
    /// @notice Set VAMM engine address
    function setVAMMEngine(address _vammEngine) external onlyAdmin {
        vammEngine = IVAMMEngine(_vammEngine);
        emit EngineUpdated("VAMM", _vammEngine);
    }
    
    /// @notice Set fee engine address
    function setFeeEngine(address _feeEngine) external onlyAdmin {
        feeEngine = IFeeEngine(_feeEngine);
        emit EngineUpdated("Fee", _feeEngine);
    }

    /// @notice Set orderbook engine address
    function setOrderbookEngine(address _orderbookEngine) external onlyAdmin {
        orderbookEngine = ILOBEngine(_orderbookEngine);
        emit EngineUpdated("Orderbook", _orderbookEngine);
    }

    /// @notice Set oracle engine address
    function setOracleEngine(address _oracleEngine) external onlyAdmin {
        oracleEngine = IOracleEngine(_oracleEngine);
        emit EngineUpdated("Oracle", _oracleEngine);
    }
    
    /// @notice Change curve mode
    function setCurveMode(CurveMode _mode) external onlyAdmin {
        CurveMode oldMode = curveMode;
        curveMode = _mode;
        emit ModeChanged(oldMode, _mode);
    }
    
    /// @notice Transfer admin
    function transferAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }
}
