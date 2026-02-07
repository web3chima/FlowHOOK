// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVAMMEngine} from "./Interfaces.sol";
import {CurveMath} from "../libraries/CurveMath.sol";

/// @title VAMM Engine (Enhanced)
/// @notice Implements the custom curve P = K × Q^(-2) with Kyle model and volatility integration
/// @dev Integrates Kyle model, volatility calculation, and TSTORE/TLOAD for transient storage
contract VAMMEngine is IVAMMEngine {
    
    // ============ Constants ============
    
    uint256 public constant CURVE_PRECISION = 1e18;
    uint256 public constant MIN_QUANTITY = 1e15;
    uint256 public constant MAX_PRICE = 1e36;
    uint256 public constant PRICE_PRECISION = 1e18;
    
    /// @notice Transient storage slot for mid-swap state (EIP-1153)
    bytes32 private constant TRANSIENT_SWAP_SLOT = 
        keccak256("flowhook.vamm.swap.transient");
    
    /// @notice Transient storage slot for reentrancy lock
    bytes32 private constant TRANSIENT_LOCK_SLOT = 
        keccak256("flowhook.vamm.lock.transient");
    
    // ============ State Variables ============
    
    /// @notice Pool constant K (determines curve steepness)
    uint256 public poolConstant;
    
    /// @notice Virtual BTC quantity in pool
    uint256 public vBTCQuantity;
    
    /// @notice Virtual USDC reserve
    uint256 public vUSDCReserve;
    
    /// @notice Last calculated curve price
    uint256 public lastCurvePrice;
    
    /// @notice Total long open interest
    uint256 public totalLongPositions;
    
    /// @notice Total short open interest
    uint256 public totalShortPositions;
    
    /// @notice Initialization flag
    bool private _initialized;
    
    /// @notice Admin address
    address public admin;
    
    // ============ Kyle Model State ============
    
    /// @notice Kyle lambda parameter (price impact coefficient)
    uint256 public kyleLambda;
    
    /// @notice Cumulative order flow
    int256 public cumulativeFlow;
    
    /// @notice Base market depth
    uint256 public baseDepth;
    
    /// @notice Effective market depth
    uint256 public effectiveDepth;
    
    /// @notice Kyle last update block
    uint256 public kyleLastUpdateBlock;
    
    // ============ Volatility State ============
    
    /// @notice Base volatility
    uint256 public baseVolatility;
    
    /// @notice Effective volatility
    uint256 public effectiveVolatility;
    
    /// @notice Maximum volatility
    uint256 public maxVolatility;
    
    /// @notice Volatility long OI
    uint256 public volatilityLongOI;
    
    /// @notice Volatility short OI
    uint256 public volatilityShortOI;
    
    /// @notice Previous total OI for threshold checking
    uint256 private previousTotalOI;
    
    // ============ Events ============
    
    event CurveInitialized(uint256 poolConstant, uint256 quantity, uint256 price);
    event CurveTradeExecuted(
        bool isLong, 
        uint256 size, 
        uint256 executionPrice, 
        uint256 priceImpact,
        uint256 kyleLambda,
        uint256 effectiveVolatility
    );
    event PositionClosed(bool isLong, uint256 size, uint256 closePrice);
    event TransientStateStored(bytes32 slot, uint256 value);
    event VolatilityUpdated(uint256 newVolatility, uint256 longOI, uint256 shortOI);
    event KyleParametersUpdated(uint256 lambda, uint256 depth);
    
    // ============ Errors ============
    
    error NotInitialized();
    error AlreadyInitialized();
    error InvalidInput(string reason);
    error Unauthorized();
    error ReentrancyGuard();
    
    // ============ Modifiers ============
    
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }
    
    modifier whenInitialized() {
        if (!_initialized) revert NotInitialized();
        _;
    }
    
    /// @notice Transient reentrancy guard using TSTORE/TLOAD
    modifier nonReentrantTransient() {
        // Check lock using TLOAD
        uint256 locked;
        bytes32 slot = TRANSIENT_LOCK_SLOT;
        assembly {
            locked := tload(slot)
        }
        if (locked != 0) revert ReentrancyGuard();
        
        // Set lock using TSTORE
        assembly {
            tstore(slot, 1)
        }
        
        _;
        
        // Clear lock using TSTORE
        assembly {
            tstore(slot, 0)
        }
    }
    
    // ============ Constructor ============
    
    /// @notice Initialize with Kyle model and Volatility parameters
    /// @param _baseDepth Initial market depth for Kyle model
    /// @param _baseVolatility Initial base volatility
    /// @param _maxVolatility Maximum allowed volatility
    constructor(
        uint256 _baseDepth,
        uint256 _baseVolatility,
        uint256 _maxVolatility
    ) {
        if (_baseDepth == 0) revert InvalidInput("baseDepth");
        if (_baseVolatility == 0) revert InvalidInput("baseVolatility");
        if (_maxVolatility == 0) revert InvalidInput("maxVolatility");
        
        admin = msg.sender;
        
        // Initialize Kyle model
        baseDepth = _baseDepth;
        effectiveDepth = _baseDepth;
        kyleLambda = (_baseVolatility * PRICE_PRECISION) / _baseDepth;
        kyleLastUpdateBlock = block.number;
        
        // Initialize volatility
        baseVolatility = _baseVolatility;
        effectiveVolatility = _baseVolatility;
        maxVolatility = _maxVolatility;
    }
    
    // ============ Initialization ============
    
    /// @inheritdoc IVAMMEngine
    function initialize(uint256 initialPrice, uint256 initialQuantity) external onlyAdmin {
        if (_initialized) revert AlreadyInitialized();
        if (initialPrice == 0) revert InvalidInput("initialPrice");
        if (initialQuantity < MIN_QUANTITY) revert InvalidInput("initialQuantity too small");
        
        vBTCQuantity = initialQuantity;
        lastCurvePrice = initialPrice;
        
        // K = P × Q² (1e54 scaled)
        poolConstant = initialPrice * initialQuantity * initialQuantity;
        
        // vUSDC = K / vBTC
        vUSDCReserve = poolConstant / initialQuantity;
        
        _initialized = true;
        
        emit CurveInitialized(poolConstant, initialQuantity, initialPrice);
    }
    
    // ============ Core Interface Implementation ============
    
    /// @notice Execute trade with Kyle model and volatility updates
    function executeTrade(uint256 size, bool isLong) 
        external 
        override
        whenInitialized
        nonReentrantTransient
        returns (uint256 executionPrice, uint256 priceImpact) 
    {
        return _executeCurveTrade(size, isLong);
    }
    
    /// @notice Get current curve price
    function getPrice() external view override returns (uint256 price) {
        return calculateCurvePrice();
    }
    
    /// @notice Check if initialized
    function isInitialized() external view override returns (bool) {
        return _initialized;
    }
    
    // ============ VAMM-Specific Interface ============
    
    /// @inheritdoc IVAMMEngine
    function getCurveState() external view override returns (
        uint256 k,
        uint256 q,
        uint256 price,
        uint256 sensitivity
    ) {
        k = poolConstant;
        q = vBTCQuantity;
        price = calculateCurvePrice();
        sensitivity = calculatePriceSensitivity();
    }
    
    /// @inheritdoc IVAMMEngine
    function getOpenInterest() external view override returns (
        uint256 longOI,
        uint256 shortOI,
        int256 netOI
    ) {
        longOI = totalLongPositions;
        shortOI = totalShortPositions;
        netOI = int256(longOI) - int256(shortOI);
    }
    
    /// @inheritdoc IVAMMEngine
    function simulateTrade(uint256 size, bool isLong) 
        external view 
        override
        returns (uint256 price, uint256 impact) 
    {
        if (size == 0) return (calculateCurvePrice(), 0);
        
        uint256 priceBefore = calculateCurvePrice();
        uint256 newQ;
        
        if (isLong) {
            if (size >= vBTCQuantity - MIN_QUANTITY) {
                return (MAX_PRICE, MAX_PRICE);
            }
            newQ = vBTCQuantity - size;
        } else {
            newQ = vBTCQuantity + size;
        }
        
        uint256 priceAfter = CurveMath.calculatePrice(poolConstant, newQ);
        
        // Add Kyle model price impact
        int256 kyleImpact = _calculateKylePriceImpact(isLong ? int256(size) : -int256(size));
        uint256 adjustedPriceAfter = kyleImpact >= 0 
            ? priceAfter + uint256(kyleImpact)
            : priceAfter - uint256(-kyleImpact);
        
        price = (priceBefore + adjustedPriceAfter) / 2;
        impact = CurveMath.calculatePriceImpact(priceBefore, adjustedPriceAfter);
    }
    
    /// @inheritdoc IVAMMEngine
    function closePosition(uint256 size, bool isLong) 
        external 
        override
        whenInitialized
        nonReentrantTransient
        returns (uint256 executionPrice) 
    {
        return _closeCurvePosition(size, isLong);
    }
    
    // ============ Public View Functions ============
    
    /// @notice Calculate price using P = K × Q^(-2) = K / Q²
    function calculateCurvePrice() public view returns (uint256 price) {
        if (vBTCQuantity < MIN_QUANTITY) {
            return MAX_PRICE;
        }
        
        // P = K / Q²
        // K has 54 decimals (from initialize: P(18) * Q(18) * Q(18))
        // Q² has 36 decimals
        // Result has 18 decimals (54 - 36)
        price = poolConstant / (vBTCQuantity * vBTCQuantity);
        
        if (price > MAX_PRICE) {
            price = MAX_PRICE;
        }
    }
    
    /// @notice Calculate price sensitivity |dP/dQ| = 2K / Q³
    function calculatePriceSensitivity() public view returns (uint256 sensitivity) {
        if (vBTCQuantity < MIN_QUANTITY) {
            return MAX_PRICE;
        }
        
        uint256 qCubed = vBTCQuantity * vBTCQuantity / CURVE_PRECISION * vBTCQuantity / CURVE_PRECISION;
        if (qCubed == 0) {
            return MAX_PRICE;
        }
        
        sensitivity = 2 * poolConstant / qCubed;
    }
    
    /// @notice Get Kyle model state
    function getKyleModelState() external view returns (
        uint256 lambda,
        int256 flow,
        uint256 depth
    ) {
        lambda = kyleLambda;
        flow = cumulativeFlow;
        depth = effectiveDepth;
    }
    
    /// @notice Get volatility state
    function getVolatilityInfo() external view returns (
        uint256 baseVol,
        uint256 effectiveVol,
        uint256 longOI,
        uint256 shortOI
    ) {
        baseVol = baseVolatility;
        effectiveVol = effectiveVolatility;
        longOI = volatilityLongOI;
        shortOI = volatilityShortOI;
    }
    
    // ============ Internal Functions ============
    
    function _executeCurveTrade(uint256 size, bool isLong) 
        internal 
        returns (uint256 executionPrice, uint256 priceImpact) 
    {
        if (size == 0) revert InvalidInput("zero size");
        
        // === TSTORE: Store transient swap context ===
        _storeTransientSwapState(size, isLong);
        
        uint256 priceBefore = calculateCurvePrice();
        uint256 newQ;
        
        if (isLong) {
            if (size >= vBTCQuantity - MIN_QUANTITY) {
                revert InvalidInput("trade too large");
            }
            newQ = vBTCQuantity - size;
            totalLongPositions += size;
        } else {
            newQ = vBTCQuantity + size;
            totalShortPositions += size;
        }
        
        vBTCQuantity = newQ;
        
        uint256 priceAfter = calculateCurvePrice();
        
        // === Apply Kyle Model Price Impact ===
        int256 orderFlow = isLong ? int256(size) : -int256(size);
        int256 kyleImpact = _calculateKylePriceImpact(orderFlow);
        
        // Track order flow
        cumulativeFlow += orderFlow;
        
        // Adjust price with Kyle impact
        if (kyleImpact >= 0) {
            priceAfter = priceAfter + uint256(kyleImpact) / CURVE_PRECISION;
        } else {
            uint256 reduction = uint256(-kyleImpact) / CURVE_PRECISION;
            if (reduction < priceAfter) {
                priceAfter = priceAfter - reduction;
            }
        }
        
        lastCurvePrice = priceAfter;
        
        executionPrice = (priceBefore + priceAfter) / 2;
        priceImpact = CurveMath.calculatePriceImpact(priceBefore, priceAfter);
        
        // Update vUSDC reserve
        vUSDCReserve = poolConstant / vBTCQuantity;
        
        // === Update Volatility based on OI change ===
        _updateVolatility(isLong, size);
        
        // === Update Kyle parameters if OI changed significantly ===
        uint256 totalOI = totalLongPositions + totalShortPositions;
        if (_shouldUpdateKyle(totalOI)) {
            _updateKyleParameters();
            previousTotalOI = totalOI;
        }
        
        emit CurveTradeExecuted(
            isLong, 
            size, 
            executionPrice, 
            priceImpact,
            kyleLambda,
            effectiveVolatility
        );
    }
    
    function _closeCurvePosition(uint256 size, bool isLong) 
        internal 
        returns (uint256 executionPrice) 
    {
        _storeTransientSwapState(size, isLong);
        
        if (isLong) {
            if (size > totalLongPositions) revert InvalidInput("exceeds long positions");
            totalLongPositions -= size;
            vBTCQuantity += size;
        } else {
            if (size > totalShortPositions) revert InvalidInput("exceeds short positions");
            totalShortPositions -= size;
            if (size >= vBTCQuantity - MIN_QUANTITY) revert InvalidInput("close too large");
            vBTCQuantity -= size;
        }
        
        executionPrice = calculateCurvePrice();
        lastCurvePrice = executionPrice;
        vUSDCReserve = poolConstant / vBTCQuantity;
        
        // Track reverse flow
        int256 orderFlow = isLong ? -int256(size) : int256(size);
        cumulativeFlow += orderFlow;
        
        emit PositionClosed(isLong, size, executionPrice);
    }
    
    // ============ Kyle Model Functions ============
    
    /// @notice Calculate price impact using Kyle model: λ × orderFlow
    function _calculateKylePriceImpact(int256 orderFlow) internal view returns (int256) {
        return (int256(kyleLambda) * orderFlow) / int256(PRICE_PRECISION);
    }
    
    /// @notice Check if Kyle parameters should update (5% OI threshold)
    function _shouldUpdateKyle(uint256 currentTotalOI) internal view returns (bool) {
        if (previousTotalOI == 0) return currentTotalOI > 0;
        uint256 change = currentTotalOI > previousTotalOI 
            ? currentTotalOI - previousTotalOI 
            : previousTotalOI - currentTotalOI;
        return (change * 100) / previousTotalOI >= 5;
    }
    
    /// @notice Update Kyle model parameters
    function _updateKyleParameters() internal {
        if (effectiveDepth == 0) return;
        kyleLambda = (effectiveVolatility * PRICE_PRECISION) / effectiveDepth;
        kyleLastUpdateBlock = block.number;
        emit KyleParametersUpdated(kyleLambda, effectiveDepth);
    }
    
    // ============ Volatility Functions ============
    
    /// @notice Update volatility based on OI change
    function _updateVolatility(bool isLong, uint256 size) internal {
        if (isLong) {
            volatilityLongOI += size;
        } else {
            volatilityShortOI += size;
        }
        
        // Calculate new effective volatility
        // Formula: baseVol + (longOI × 3.569e-9) - (shortOI × 1.678e-9)
        int256 longImpact = int256((volatilityLongOI * 3569) / 1e12);
        int256 shortImpact = int256((volatilityShortOI * 1678) / 1e12);
        
        int256 volDelta = longImpact - shortImpact;
        
        if (volDelta >= 0) {
            effectiveVolatility = baseVolatility + uint256(volDelta);
        } else {
            uint256 reduction = uint256(-volDelta);
            effectiveVolatility = reduction >= baseVolatility 
                ? baseVolatility / 2 
                : baseVolatility - reduction;
        }
        
        // Cap at max
        if (effectiveVolatility > maxVolatility) {
            effectiveVolatility = maxVolatility;
        }
        
        // Adjust depth based on volatility
        effectiveDepth = (baseDepth * baseVolatility) / effectiveVolatility;
        
        emit VolatilityUpdated(effectiveVolatility, volatilityLongOI, volatilityShortOI);
    }
    
    // ============ Transient Storage Functions ============
    
    /// @notice Store transient swap state using TSTORE (EIP-1153)
    function _storeTransientSwapState(uint256 size, bool isLong) internal {
        bytes32 slot = TRANSIENT_SWAP_SLOT;
        uint256 packed = (isLong ? 1 : 0) << 255 | size;
        
        assembly {
            tstore(slot, packed)
        }
        
        emit TransientStateStored(slot, packed);
    }
    
    /// @notice Read transient swap state using TLOAD
    function _loadTransientSwapState() internal view returns (uint256 size, bool isLong) {
        bytes32 slot = TRANSIENT_SWAP_SLOT;
        uint256 packed;
        
        assembly {
            packed := tload(slot)
        }
        
        isLong = (packed >> 255) == 1;
        size = packed & ((1 << 255) - 1);
    }
    
    // ============ Admin Functions ============
    
    function transferAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }
}
