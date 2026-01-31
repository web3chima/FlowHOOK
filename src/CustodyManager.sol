// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UserBalance} from "./DataStructures.sol";
import {InsufficientBalance, ZeroAmount, InvalidInput} from "./Errors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Custody Manager
/// @notice Manages user asset custody for FlowHook
/// @dev Implements decentralized custody with locked/available balance tracking
abstract contract CustodyManager {
    using SafeERC20 for IERC20;

    mapping(address => UserBalance) internal balances;

    address internal immutable token0;

    address internal immutable token1;

    /// @notice Initialize custody manager with token addresses
    /// @param _token0 Address of token0
    /// @param _token1 Address of token1
    constructor(address _token0, address _token1) {
        if (_token0 == address(0) || _token1 == address(0)) {
            revert InvalidInput("token address");
        }
        token0 = _token0;
        token1 = _token1;
    }

    /// @notice Deposit tokens into custody
    /// @param token Address of the token to deposit
    /// @param amount Amount to deposit
    function deposit(address token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (token != token0 && token != token1) {
            revert InvalidInput("token");
        }

        UserBalance storage balance = balances[msg.sender];

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        if (token == token0) {
            balance.token0Available += amount;
        } else {
            balance.token1Available += amount;
        }
    }

    /// @notice Withdraw available tokens from custody
    /// @param token Address of the token to withdraw
    /// @param amount Amount to withdraw
    function withdraw(address token, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (token != token0 && token != token1) {
            revert InvalidInput("token");
        }

        UserBalance storage balance = balances[msg.sender];

        uint256 available = token == token0 ? balance.token0Available : balance.token1Available;
        if (available < amount) {
            revert InsufficientBalance(msg.sender, amount, available);
        }

        if (token == token0) {
            balance.token0Available -= amount;
        } else {
            balance.token1Available -= amount;
        }

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /// @notice Lock tokens for an order
    /// @param user Address of the user
    /// @param token Address of the token to lock
    /// @param amount Amount to lock
    function _lockForOrder(address user, address token, uint256 amount) internal {
        if (amount == 0) revert ZeroAmount();

        UserBalance storage balance = balances[user];

        if (token == token0) {
            if (balance.token0Available < amount) {
                revert InsufficientBalance(user, amount, balance.token0Available);
            }
            balance.token0Available -= amount;
            balance.token0Locked += amount;
        } else if (token == token1) {
            if (balance.token1Available < amount) {
                revert InsufficientBalance(user, amount, balance.token1Available);
            }
            balance.token1Available -= amount;
            balance.token1Locked += amount;
        } else {
            revert InvalidInput("token");
        }
    }

    /// @notice Unlock tokens from an order
    /// @param user Address of the user
    /// @param token Address of the token to unlock
    /// @param amount Amount to unlock
    function _unlockFromOrder(address user, address token, uint256 amount) internal {
        if (amount == 0) return;

        UserBalance storage balance = balances[user];

        if (token == token0) {
            if (balance.token0Locked < amount) {
                revert InsufficientBalance(user, amount, balance.token0Locked);
            }
            balance.token0Locked -= amount;
            balance.token0Available += amount;
        } else if (token == token1) {
            if (balance.token1Locked < amount) {
                revert InsufficientBalance(user, amount, balance.token1Locked);
            }
            balance.token1Locked -= amount;
            balance.token1Available += amount;
        } else {
            revert InvalidInput("token");
        }
    }

    /// @notice Transfer tokens between users for trade settlement
    /// @param from Address to transfer from (locked balance)
    /// @param to Address to transfer to (available balance)
    /// @param token Address of the token to transfer
    /// @param amount Amount to transfer
    function _transferBetweenUsers(address from, address to, address token, uint256 amount) internal {
        if (amount == 0) return;

        UserBalance storage fromBalance = balances[from];
        UserBalance storage toBalance = balances[to];

        if (token == token0) {
            if (fromBalance.token0Locked < amount) {
                revert InsufficientBalance(from, amount, fromBalance.token0Locked);
            }
            fromBalance.token0Locked -= amount;
            toBalance.token0Available += amount;
        } else if (token == token1) {
            if (fromBalance.token1Locked < amount) {
                revert InsufficientBalance(from, amount, fromBalance.token1Locked);
            }
            fromBalance.token1Locked -= amount;
            toBalance.token1Available += amount;
        } else {
            revert InvalidInput("token");
        }
    }

    /// @notice Get user balance information
    /// @param user Address of the user
    /// @return balance The user's balance state
    function getUserBalance(address user) external view returns (UserBalance memory) {
        return balances[user];
    }

    /// @notice Get total balance (available + locked) for a user and token
    /// @param user Address of the user
    /// @param token Address of the token
    /// @return total The total balance
    function getTotalBalance(address user, address token) external view returns (uint256) {
        UserBalance storage balance = balances[user];
        if (token == token0) {
            return balance.token0Available + balance.token0Locked;
        } else if (token == token1) {
            return balance.token1Available + balance.token1Locked;
        } else {
            revert InvalidInput("token");
        }
    }

    /// @notice Get available balance for a user and token
    /// @param user Address of the user
    /// @param token Address of the token
    /// @return available The available balance
    function getAvailableBalance(address user, address token) external view returns (uint256) {
        UserBalance storage balance = balances[user];
        if (token == token0) {
            return balance.token0Available;
        } else if (token == token1) {
            return balance.token1Available;
        } else {
            revert InvalidInput("token");
        }
    }

    /// @notice Get locked balance for a user and token
    /// @param user Address of the user
    /// @param token Address of the token
    /// @return locked The locked balance
    function getLockedBalance(address user, address token) external view returns (uint256) {
        UserBalance storage balance = balances[user];
        if (token == token0) {
            return balance.token0Locked;
        } else if (token == token1) {
            return balance.token1Locked;
        } else {
            revert InvalidInput("token");
        }
    }
}
