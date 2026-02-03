// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {InvalidInput, ZeroAmount} from "./Errors.sol";

/// @title Input Validator
/// @notice Library for validating user inputs
library InputValidator {
    /// @notice Validate that an address is not zero
    /// @param addr The address to validate
    /// @param paramName The parameter name for error messages
    function validateAddress(address addr, string memory paramName) internal pure {
        if (addr == address(0)) {
            revert InvalidInput(paramName);
        }
    }
    
    /// @notice Validate that an amount is not zero
    /// @param amount The amount to validate
    function validateNonZeroAmount(uint256 amount) internal pure {
        if (amount == 0) {
            revert ZeroAmount();
        }
    }
    
    /// @notice Validate that a price is within acceptable bounds
    /// @param price The price to validate
    /// @param minPrice The minimum acceptable price
    /// @param maxPrice The maximum acceptable price
    function validatePriceRange(uint256 price, uint256 minPrice, uint256 maxPrice) internal pure {
        if (price == 0) {
            revert InvalidInput("price cannot be zero");
        }
        if (price < minPrice || price > maxPrice) {
            revert InvalidInput("price out of bounds");
        }
    }
    
    /// @notice Validate that a quantity is within acceptable bounds
    /// @param quantity The quantity to validate
    /// @param minQuantity The minimum acceptable quantity
    /// @param maxQuantity The maximum acceptable quantity
    function validateQuantityRange(uint256 quantity, uint256 minQuantity, uint256 maxQuantity) internal pure {
        if (quantity == 0) {
            revert ZeroAmount();
        }
        if (quantity < minQuantity || quantity > maxQuantity) {
            revert InvalidInput("quantity out of bounds");
        }
    }
    
    /// @notice Validate tick range for liquidity positions
    /// @param tickLower The lower tick
    /// @param tickUpper The upper tick
    function validateTickRange(int24 tickLower, int24 tickUpper) internal pure {
        if (tickLower >= tickUpper) {
            revert InvalidInput("invalid tick range");
        }
        // Uniswap V3 tick range: -887272 to 887272
        if (tickLower < -887272 || tickUpper > 887272) {
            revert InvalidInput("tick out of bounds");
        }
    }
    
    /// @notice Validate that a percentage is within 0-100%
    /// @param percentage The percentage to validate (scaled by 1e18)
    function validatePercentage(uint256 percentage) internal pure {
        if (percentage > 1e18) {
            revert InvalidInput("percentage > 100%");
        }
    }
    
    /// @notice Validate that a fee is within acceptable bounds
    /// @param fee The fee to validate (in basis points)
    /// @param maxFee The maximum acceptable fee
    function validateFee(uint24 fee, uint24 maxFee) internal pure {
        if (fee > maxFee) {
            revert InvalidInput("fee exceeds maximum");
        }
    }
    
    /// @notice Validate that a timestamp is not in the future
    /// @param timestamp The timestamp to validate
    function validateTimestamp(uint256 timestamp) internal view {
        if (timestamp > block.timestamp) {
            revert InvalidInput("timestamp in future");
        }
    }
    
    /// @notice Validate that a value is within a range
    /// @param value The value to validate
    /// @param min The minimum acceptable value
    /// @param max The maximum acceptable value
    /// @param paramName The parameter name for error messages
    function validateRange(uint256 value, uint256 min, uint256 max, string memory paramName) internal pure {
        if (value < min || value > max) {
            revert InvalidInput(paramName);
        }
    }
    
    /// @notice Validate that an order ID is valid
    /// @param orderId The order ID to validate
    /// @param maxOrderId The maximum valid order ID
    function validateOrderId(uint256 orderId, uint256 maxOrderId) internal pure {
        if (orderId == 0) {
            revert InvalidInput("orderId cannot be zero");
        }
        if (orderId >= maxOrderId) {
            revert InvalidInput("orderId out of range");
        }
    }
    
    /// @notice Validate that a ratio is within 0-100% (scaled by 1e18)
    /// @param ratio The ratio to validate
    function validateRatio(uint256 ratio) internal pure {
        if (ratio > 1e18) {
            revert InvalidInput("ratio > 100%");
        }
    }
    
    /// @notice Validate that a coefficient is within acceptable bounds
    /// @param coefficient The coefficient to validate
    /// @param minCoeff The minimum acceptable coefficient
    /// @param maxCoeff The maximum acceptable coefficient
    /// @param paramName The parameter name for error messages
    function validateCoefficient(int256 coefficient, int256 minCoeff, int256 maxCoeff, string memory paramName) internal pure {
        if (coefficient < minCoeff || coefficient > maxCoeff) {
            revert InvalidInput(paramName);
        }
    }
    
    /// @notice Validate that a block number is not in the future
    /// @param blockNumber The block number to validate
    function validateBlockNumber(uint256 blockNumber) internal view {
        if (blockNumber > block.number) {
            revert InvalidInput("block number in future");
        }
    }
    
    /// @notice Validate that an array is not empty
    /// @param length The array length to validate
    /// @param paramName The parameter name for error messages
    function validateNonEmptyArray(uint256 length, string memory paramName) internal pure {
        if (length == 0) {
            revert InvalidInput(paramName);
        }
    }
    
    /// @notice Validate that two values are not equal
    /// @param value1 The first value
    /// @param value2 The second value
    /// @param paramName The parameter name for error messages
    function validateNotEqual(uint256 value1, uint256 value2, string memory paramName) internal pure {
        if (value1 == value2) {
            revert InvalidInput(paramName);
        }
    }
    
    /// @notice Validate that a value is greater than another
    /// @param value The value to validate
    /// @param threshold The threshold value
    /// @param paramName The parameter name for error messages
    function validateGreaterThan(uint256 value, uint256 threshold, string memory paramName) internal pure {
        if (value <= threshold) {
            revert InvalidInput(paramName);
        }
    }
    
    /// @notice Validate that a value is less than another
    /// @param value The value to validate
    /// @param threshold The threshold value
    /// @param paramName The parameter name for error messages
    function validateLessThan(uint256 value, uint256 threshold, string memory paramName) internal pure {
        if (value >= threshold) {
            revert InvalidInput(paramName);
        }
    }
}
