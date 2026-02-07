// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {InputValidator} from "../InputValidator.sol";

/// @title UserOperations
/// @notice Library for user-facing operations validation
/// @dev Extracted to reduce main contract size
library UserOperations {
    /// @notice Validate deposit parameters
    /// @param token The token address
    /// @param amount The deposit amount
    function validateDeposit(address token, uint256 amount) internal pure {
        InputValidator.validateAddress(token, "token");
        InputValidator.validateNonZeroAmount(amount);
    }

    /// @notice Validate withdrawal parameters
    /// @param token The token address
    /// @param amount The withdrawal amount
    function validateWithdrawal(address token, uint256 amount) internal pure {
        InputValidator.validateAddress(token, "token");
        InputValidator.validateNonZeroAmount(amount);
    }

    /// @notice Validate order placement parameters
    /// @param price The order price
    /// @param quantity The order quantity
    function validateOrderPlacement(uint256 price, uint256 quantity) internal pure {
        InputValidator.validateNonZeroAmount(price);
        InputValidator.validateNonZeroAmount(quantity);
        InputValidator.validatePriceRange(price, 1, 1e30);
        InputValidator.validateQuantityRange(quantity, 1, 1e30);
    }

    /// @notice Validate liquidity addition parameters
    /// @param tickLower The lower tick
    /// @param tickUpper The upper tick
    /// @param amount0Desired The desired amount of token0
    /// @param amount1Desired The desired amount of token1
    function validateAddLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Desired,
        uint256 amount1Desired
    ) internal pure {
        InputValidator.validateTickRange(tickLower, tickUpper);
        InputValidator.validateNonZeroAmount(amount0Desired);
        InputValidator.validateNonZeroAmount(amount1Desired);
    }

    /// @notice Validate liquidity removal parameters
    /// @param tickLower The lower tick
    /// @param tickUpper The upper tick
    /// @param liquidityToRemove The amount of liquidity to remove
    function validateRemoveLiquidity(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidityToRemove
    ) internal pure {
        InputValidator.validateTickRange(tickLower, tickUpper);
        InputValidator.validateNonZeroAmount(liquidityToRemove);
    }
}
