// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Unauthorized, InvalidInput, TradingPaused} from "./Errors.sol";
import {AdminActionExecuted} from "./Events.sol";

/// @title AdminDashboard
/// @notice Admin controls with transient storage for gas-efficient parameter management
/// @dev Uses EIP-1153 transient storage (TSTORE/TLOAD) for temporary state
abstract contract AdminDashboard {
    // ============ Transient Storage Slot Constants ============
    
    /// @notice Slot for admin action tracking
    uint256 private constant ADMIN_ACTION_SLOT = uint256(keccak256("admin.action.slot"));
    
    /// @notice Slot for parameter update tracking
    uint256 private constant PARAM_UPDATE_SLOT = uint256(keccak256("param.update.slot"));
    
    /// @notice Slot for pause state tracking
    uint256 private constant PAUSE_STATE_SLOT = uint256(keccak256("pause.state.slot"));
    
    /// @notice Slot for reentrancy lock
    uint256 private constant REENTRANCY_LOCK_SLOT = uint256(keccak256("reentrancy.lock.slot"));
    
    // ============ Storage Variables ============
    
    /// @notice Admin role identifier
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /// @notice Mapping of addresses to their roles
    mapping(address => mapping(bytes32 => bool)) public hasRole;
    
    /// @notice Whether trading is currently paused
    bool public isPaused;
    
    // ============ Constructor ============
    
    /// @notice Initialize admin dashboard with initial admin
    /// @param initialAdmin The address to grant admin role
    constructor(address initialAdmin) {
        _grantRole(ADMIN_ROLE, initialAdmin);
    }
    
    // ============ Modifiers ============
    
    /// @notice Restricts function access to admin role
    modifier onlyAdmin() {
        if (!hasRole[msg.sender][ADMIN_ROLE]) {
            revert Unauthorized(msg.sender);
        }
        _;
    }
    
    /// @notice Prevents execution when trading is paused
    modifier whenNotPaused() {
        if (isPaused) {
            revert TradingPaused();
        }
        _;
    }
    
    /// @notice Prevents reentrancy using transient storage
    modifier nonReentrantAdmin() {
        uint256 locked = getTransient(REENTRANCY_LOCK_SLOT);
        require(locked == 0, "Reentrancy detected");
        
        setTransient(REENTRANCY_LOCK_SLOT, 1);
        _;
        setTransient(REENTRANCY_LOCK_SLOT, 0);
    }
    
    // ============ Transient Storage Helpers ============
    
    /// @notice Set a value in transient storage
    /// @param slot The storage slot
    /// @param value The value to store
    function setTransient(uint256 slot, uint256 value) internal {
        assembly {
            tstore(slot, value)
        }
    }
    
    /// @notice Get a value from transient storage
    /// @param slot The storage slot
    /// @return value The stored value
    function getTransient(uint256 slot) internal view returns (uint256 value) {
        assembly {
            value := tload(slot)
        }
    }
    
    // ============ Access Control Functions ============
    
    /// @notice Grant a role to an address
    /// @param role The role identifier
    /// @param account The address to grant the role to
    function _grantRole(bytes32 role, address account) internal {
        hasRole[account][role] = true;
    }
    
    /// @notice Revoke a role from an address
    /// @param role The role identifier
    /// @param account The address to revoke the role from
    function _revokeRole(bytes32 role, address account) internal {
        hasRole[account][role] = false;
    }
    
    /// @notice Grant admin role to an address
    /// @param account The address to grant admin role
    function grantAdminRole(address account) external onlyAdmin nonReentrantAdmin {
        // Validate address
        if (account == address(0)) {
            revert InvalidInput("account cannot be zero address");
        }
        
        _grantRole(ADMIN_ROLE, account);
        emit AdminActionExecuted(
            msg.sender,
            "grantAdminRole",
            abi.encode(account),
            block.timestamp
        );
    }
    
    /// @notice Revoke admin role from an address
    /// @param account The address to revoke admin role from
    function revokeAdminRole(address account) external onlyAdmin nonReentrantAdmin {
        // Validate address
        if (account == address(0)) {
            revert InvalidInput("account cannot be zero address");
        }
        
        // Prevent revoking own admin role
        if (account == msg.sender) {
            revert InvalidInput("cannot revoke own admin role");
        }
        
        _revokeRole(ADMIN_ROLE, account);
        emit AdminActionExecuted(
            msg.sender,
            "revokeAdminRole",
            abi.encode(account),
            block.timestamp
        );
    }
    
    // ============ Pause/Unpause Functions ============
    
    /// @notice Pause trading operations
    /// @dev Withdrawals and order cancellations remain allowed when paused
    function pauseTrading() external onlyAdmin nonReentrantAdmin {
        isPaused = true;
        
        // Track pause action in transient storage
        setTransient(PAUSE_STATE_SLOT, 1);
        
        emit AdminActionExecuted(
            msg.sender,
            "pauseTrading",
            "",
            block.timestamp
        );
    }
    
    /// @notice Unpause trading operations
    function unpauseTrading() external onlyAdmin nonReentrantAdmin {
        isPaused = false;
        
        // Track unpause action in transient storage
        setTransient(PAUSE_STATE_SLOT, 0);
        
        emit AdminActionExecuted(
            msg.sender,
            "unpauseTrading",
            "",
            block.timestamp
        );
    }
    
    // ============ Parameter Update Functions ============
    
    /// @notice Update fee parameters
    /// @param baseFee The new base fee (in basis points)
    /// @param maxFee The new maximum fee (in basis points)
    function updateFeeParameters(uint24 baseFee, uint24 maxFee) external onlyAdmin nonReentrantAdmin {
        // Validate parameter bounds
        // Base fee: min 0.01% (100), max 0.5% (5000)
        validateParameterBounds("baseFee", baseFee, 100, 5000);
        
        // Max fee: min 0.5% (5000), max 2.0% (20000)
        validateParameterBounds("maxFee", maxFee, 5000, 20000);
        
        // Ensure baseFee <= maxFee
        if (baseFee > maxFee) {
            revert InvalidInput("baseFee > maxFee");
        }
        
        // Track parameter update in transient storage
        setTransient(PARAM_UPDATE_SLOT, 1);
        
        // Apply updates (to be implemented by child contract)
        _applyFeeParameterUpdate(baseFee, maxFee);
        
        emit AdminActionExecuted(
            msg.sender,
            "updateFeeParameters",
            abi.encode(baseFee, maxFee),
            block.timestamp
        );
    }
    
    /// @notice Update volatility coefficients
    /// @param longCoeff The coefficient for long OI impact on volatility (scaled by 1e12)
    /// @param shortCoeff The coefficient for short OI impact on volatility (scaled by 1e12)
    function updateVolatilityCoefficients(int256 longCoeff, int256 shortCoeff) external onlyAdmin nonReentrantAdmin {
        // Validate coefficient bounds
        // Long coefficient: min 0, max 10000 (10000e-9 = 1e-5)
        if (longCoeff < 0 || longCoeff > 10000) {
            revert InvalidInput("longCoeff");
        }
        
        // Short coefficient: min -10000, max 0 (should be negative)
        if (shortCoeff > 0 || shortCoeff < -10000) {
            revert InvalidInput("shortCoeff");
        }
        
        // Track parameter update in transient storage
        setTransient(PARAM_UPDATE_SLOT, 2);
        
        // Apply updates (to be implemented by child contract)
        _applyVolatilityCoefficientsUpdate(longCoeff, shortCoeff);
        
        emit AdminActionExecuted(
            msg.sender,
            "updateVolatilityCoefficients",
            abi.encode(longCoeff, shortCoeff),
            block.timestamp
        );
    }
    
    /// @notice Validate parameter bounds
    /// @param paramName The parameter name
    /// @param value The parameter value
    /// @param minValue The minimum allowed value
    /// @param maxValue The maximum allowed value
    function validateParameterBounds(
        string memory paramName,
        uint256 value,
        uint256 minValue,
        uint256 maxValue
    ) internal pure {
        if (value < minValue || value > maxValue) {
            revert InvalidInput(paramName);
        }
    }
    
    // ============ Internal Functions (to be implemented by child contracts) ============
    
    /// @notice Apply fee parameter update
    /// @param baseFee The new base fee
    /// @param maxFee The new maximum fee
    function _applyFeeParameterUpdate(uint24 baseFee, uint24 maxFee) internal virtual;
    
    /// @notice Apply volatility coefficients update
    /// @param longCoeff The new long OI coefficient
    /// @param shortCoeff The new short OI coefficient
    function _applyVolatilityCoefficientsUpdate(int256 longCoeff, int256 shortCoeff) internal virtual;
}
