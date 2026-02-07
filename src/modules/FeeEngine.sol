// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IFeeEngine} from "./Interfaces.sol";

/// @title Fee Engine
/// @notice Calculates dynamic fees based on volatility and open interest
/// @dev Extracted from DynamicFeeManager for modular deployment
contract FeeEngine is IFeeEngine {
    
    // ============ Constants ============
    
    uint24 public constant MIN_FEE = 100;      // 0.01% minimum
    uint24 public constant MAX_FEE = 10000;    // 1% maximum
    uint24 public constant DEFAULT_FEE = 3000; // 0.3% default
    
    uint256 public constant PRECISION = 1e18;
    
    // ============ State Variables ============
    
    /// @notice Base fee in basis points
    uint24 public baseFee;
    
    /// @notice Volatility multiplier (scales fee with volatility)
    uint256 public volatilityMultiplier;
    
    /// @notice OI imbalance multiplier
    uint256 public oiImbalanceMultiplier;
    
    /// @notice Admin address
    address public admin;
    
    // ============ Events ============
    
    event BaseFeeUpdated(uint24 oldFee, uint24 newFee);
    event MultipliersUpdated(uint256 volatilityMult, uint256 oiMult);
    
    // ============ Errors ============
    
    error Unauthorized();
    error InvalidFee();
    
    // ============ Modifiers ============
    
    modifier onlyAdmin() {
        if (msg.sender != admin) revert Unauthorized();
        _;
    }
    
    // ============ Constructor ============
    
    constructor(uint24 _baseFee) {
        admin = msg.sender;
        baseFee = _baseFee > 0 ? _baseFee : DEFAULT_FEE;
        volatilityMultiplier = 1e16;  // 1% fee increase per 1% volatility
        oiImbalanceMultiplier = 5e15; // 0.5% fee increase per 100% OI imbalance
    }
    
    // ============ Interface Implementation ============
    
    /// @inheritdoc IFeeEngine
    function calculateFee(
        uint256 volume,
        uint256 volatility,
        uint256 longOI,
        uint256 shortOI
    ) external view override returns (uint24 fee) {
        // Start with base fee
        uint256 calculatedFee = uint256(baseFee);
        
        // Add volatility component
        if (volatility > 0) {
            uint256 volatilityFee = (volatility * volatilityMultiplier) / PRECISION;
            calculatedFee += volatilityFee;
        }
        
        // Add OI imbalance component
        uint256 totalOI = longOI + shortOI;
        if (totalOI > 0) {
            uint256 imbalance;
            if (longOI > shortOI) {
                imbalance = ((longOI - shortOI) * PRECISION) / totalOI;
            } else {
                imbalance = ((shortOI - longOI) * PRECISION) / totalOI;
            }
            uint256 imbalanceFee = (imbalance * oiImbalanceMultiplier) / PRECISION;
            calculatedFee += imbalanceFee;
        }
        
        // Add volume-based fee for large trades
        if (volume > 100 * PRECISION) { // > 100 units
            uint256 volumeFee = (volume * 10) / (1000 * PRECISION); // 0.01% per 100 units
            calculatedFee += volumeFee;
        }
        
        // Clamp to bounds
        if (calculatedFee < MIN_FEE) {
            fee = MIN_FEE;
        } else if (calculatedFee > MAX_FEE) {
            fee = MAX_FEE;
        } else {
            fee = uint24(calculatedFee);
        }
    }
    
    /// @inheritdoc IFeeEngine
    function getBaseFee() external view override returns (uint24) {
        return baseFee;
    }
    
    /// @inheritdoc IFeeEngine
    function setBaseFee(uint24 newBaseFee) external override onlyAdmin {
        if (newBaseFee < MIN_FEE || newBaseFee > MAX_FEE) revert InvalidFee();
        
        uint24 oldFee = baseFee;
        baseFee = newBaseFee;
        
        emit BaseFeeUpdated(oldFee, newBaseFee);
    }
    
    // ============ Admin Functions ============
    
    /// @notice Update fee multipliers
    function setMultipliers(
        uint256 _volatilityMultiplier,
        uint256 _oiImbalanceMultiplier
    ) external onlyAdmin {
        volatilityMultiplier = _volatilityMultiplier;
        oiImbalanceMultiplier = _oiImbalanceMultiplier;
        
        emit MultipliersUpdated(_volatilityMultiplier, _oiImbalanceMultiplier);
    }
    
    /// @notice Transfer admin role
    function transferAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }
}
