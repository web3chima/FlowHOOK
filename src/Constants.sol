// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title System Constants
/// @notice Defines all constants used throughout the system

library Constants {
    // OI Volatility Coefficients
    int256 internal constant LONG_OI_COEFFICIENT = 3569;
    int256 internal constant SHORT_OI_COEFFICIENT = -1678;
    uint256 internal constant COEFFICIENT_SCALE = 1e12;

    // Fee Parameters
    uint24 internal constant BASE_FEE = 500;
    uint24 internal constant MAX_FEE = 10000;
    uint24 internal constant FEE_DENOMINATOR = 1000000;

    // Update Thresholds
    uint256 internal constant VOLATILITY_UPDATE_THRESHOLD = 100;
    uint256 internal constant OI_UPDATE_THRESHOLD = 500;
    uint256 internal constant THRESHOLD_DENOMINATOR = 10000;

    // Oracle Parameters
    uint256 internal constant ORACLE_HEARTBEAT = 5 minutes;
    uint256 internal constant PRICE_DEVIATION_THRESHOLD = 200;
    uint256 internal constant MAX_PRICE_DEVIATION = 500;

    // De-Leveraging Parameters
    uint256 internal constant TWAP_BLOCKS = 10;
    uint256 internal constant DELEVERAGING_PRIORITY_THRESHOLD = 9000;

    // Fee Multiplier Parameters
    uint256 internal constant VOLATILITY_MULTIPLIER_FACTOR = 1000;
    uint256 internal constant IMBALANCE_MULTIPLIER_FACTOR = 2000;
    uint256 internal constant UTILIZATION_MULTIPLIER_FACTOR = 3000;
    uint256 internal constant MULTIPLIER_SCALE = 10000;

    // OI Balance Thresholds
    uint256 internal constant BALANCED_OI_THRESHOLD = 500;
    uint256 internal constant IMBALANCED_OI_THRESHOLD = 2000;

    // Gas Optimization Targets
    uint256 internal constant SIMPLE_SWAP_GAS_TARGET = 150000;
    uint256 internal constant COMPLEX_MATCH_GAS_TARGET = 250000;

    // Contract Size Limit
    uint256 internal constant MAX_CONTRACT_SIZE = 24576;

    // Transient Storage Slots (EIP-1153)
    uint256 internal constant ADMIN_ACTION_SLOT = 0;
    uint256 internal constant PARAM_UPDATE_SLOT = 1;
    uint256 internal constant PAUSE_STATE_SLOT = 2;
    uint256 internal constant REENTRANCY_LOCK_SLOT = 3;

    // Access Control Roles
    bytes32 internal constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Precision Constants
    uint256 internal constant PRICE_PRECISION = 1e18;
    uint256 internal constant VOLATILITY_PRECISION = 1e18;
    uint256 internal constant DEPTH_PRECISION = 1e18;

    // Position Size Limits
    uint256 internal constant DEFAULT_MAX_POSITION_SIZE = 1000000 * 1e18; // 1 million tokens default
    uint256 internal constant MIN_POSITION_SIZE_LIMIT = 1000 * 1e18; // Minimum 1000 tokens
    uint256 internal constant MAX_POSITION_SIZE_LIMIT = type(uint256).max; // No upper bound for admin config
}
