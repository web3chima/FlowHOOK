// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PropertyTestHelper} from "./helpers/PropertyTestHelper.sol";
import {CustodyManager} from "../src/CustodyManager.sol";
import {UserBalance} from "../src/DataStructures.sol";
import {InsufficientBalance, ZeroAmount, InvalidInput} from "../src/Errors.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/// @title Custody Manager Test Contract
/// @notice Concrete implementation of CustodyManager for testing
contract CustodyManagerTestContract is CustodyManager {
    constructor(address _token0, address _token1) CustodyManager(_token0, _token1) {}

    function lockForOrder(address user, address token, uint256 amount) external {
        _lockForOrder(user, token, amount);
    }

    function unlockFromOrder(address user, address token, uint256 amount) external {
        _unlockFromOrder(user, token, amount);
    }

    function transferBetweenUsers(address from, address to, address token, uint256 amount) external {
        _transferBetweenUsers(from, to, token, amount);
    }

    function getBalance(address user) external view returns (UserBalance memory) {
        return balances[user];
    }
}

/// @title Custody Manager Tests
/// @notice Property-based and unit tests for FlowHook custody manager
contract CustodyManagerTest is PropertyTestHelper {
    CustodyManagerTestContract public custody;
    ERC20Mock public token0;
    ERC20Mock public token1;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    uint256 constant INITIAL_MINT = 1000000e18;

    function setUp() public {
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();

        custody = new CustodyManagerTestContract(address(token0), address(token1));

        token0.mint(alice, INITIAL_MINT);
        token1.mint(alice, INITIAL_MINT);
        token0.mint(bob, INITIAL_MINT);
        token1.mint(bob, INITIAL_MINT);
        token0.mint(charlie, INITIAL_MINT);
        token1.mint(charlie, INITIAL_MINT);

        vm.prank(alice);
        token0.approve(address(custody), type(uint256).max);
        vm.prank(alice);
        token1.approve(address(custody), type(uint256).max);
        vm.prank(bob);
        token0.approve(address(custody), type(uint256).max);
        vm.prank(bob);
        token1.approve(address(custody), type(uint256).max);
        vm.prank(charlie);
        token0.approve(address(custody), type(uint256).max);
        vm.prank(charlie);
        token1.approve(address(custody), type(uint256).max);
    }

    /// @notice Property 40: Custody Invariant
    /// @dev For any point in time, the sum of all users' locked and available balances
    ///      SHALL equal the total assets held by the custody manager
    /// Feature: flowhook, Property 40: Custody Invariant
    /// Validates: Requirements 16.4
    function testProperty_CustodyInvariant(
        uint256 depositAmount1,
        uint256 depositAmount2,
        uint256 lockAmount1,
        uint256 lockAmount2
    ) public {
        depositAmount1 = bound(depositAmount1, 1e18, 100000e18);
        depositAmount2 = bound(depositAmount2, 1e18, 100000e18);
        lockAmount1 = bound(lockAmount1, 0, depositAmount1);
        lockAmount2 = bound(lockAmount2, 0, depositAmount2);

        vm.prank(alice);
        custody.deposit(address(token0), depositAmount1);

        vm.prank(bob);
        custody.deposit(address(token1), depositAmount2);

        _verifyCustodyInvariant();

        if (lockAmount1 > 0) {
            custody.lockForOrder(alice, address(token0), lockAmount1);
        }

        _verifyCustodyInvariant();

        if (lockAmount2 > 0) {
            custody.lockForOrder(bob, address(token1), lockAmount2);
        }

        _verifyCustodyInvariant();

        if (lockAmount1 > 0) {
            custody.unlockFromOrder(alice, address(token0), lockAmount1);
        }

        _verifyCustodyInvariant();

        vm.prank(alice);
        custody.withdraw(address(token0), depositAmount1);

        _verifyCustodyInvariant();
    }

    /// @notice Helper function to verify custody invariant
    function _verifyCustodyInvariant() internal view {
        UserBalance memory aliceBalance = custody.getBalance(alice);
        UserBalance memory bobBalance = custody.getBalance(bob);
        UserBalance memory charlieBalance = custody.getBalance(charlie);

        uint256 totalToken0User = aliceBalance.token0Available + aliceBalance.token0Locked
            + bobBalance.token0Available + bobBalance.token0Locked + charlieBalance.token0Available
            + charlieBalance.token0Locked;

        uint256 totalToken1User = aliceBalance.token1Available + aliceBalance.token1Locked
            + bobBalance.token1Available + bobBalance.token1Locked + charlieBalance.token1Available
            + charlieBalance.token1Locked;

        uint256 actualToken0 = token0.balanceOf(address(custody));
        uint256 actualToken1 = token1.balanceOf(address(custody));

        assertEq(totalToken0User, actualToken0, "Token0 custody invariant violated");
        assertEq(totalToken1User, actualToken1, "Token1 custody invariant violated");
    }

    /// @notice Property 15: No Double-Spending
    /// @dev For any user at any point in time, the sum of locked and available balances
    ///      SHALL equal the total deposited amount, and locked assets SHALL not be usable for new orders
    /// Feature: flowhook, Property 15: No Double-Spending
    /// Validates: Requirements 6.5
    function testProperty_NoDoubleSpending(
        uint256 depositAmount,
        uint256 lockAmount1,
        uint256 lockAmount2
    ) public {
        depositAmount = bound(depositAmount, 1e18, 100000e18);
        lockAmount1 = bound(lockAmount1, 1e16, depositAmount);
        lockAmount2 = bound(lockAmount2, 1e16, depositAmount);

        vm.prank(alice);
        custody.deposit(address(token0), depositAmount);

        UserBalance memory initialBalance = custody.getBalance(alice);
        uint256 initialTotal = initialBalance.token0Available + initialBalance.token0Locked;

        custody.lockForOrder(alice, address(token0), lockAmount1);

        UserBalance memory afterLock = custody.getBalance(alice);
        uint256 afterLockTotal = afterLock.token0Available + afterLock.token0Locked;
        assertEq(afterLockTotal, initialTotal, "Total balance changed after lock");

        assertEq(afterLock.token0Locked, lockAmount1, "Locked amount incorrect");
        assertEq(afterLock.token0Available, depositAmount - lockAmount1, "Available amount incorrect");

        if (lockAmount2 > afterLock.token0Available) {
            try custody.lockForOrder(alice, address(token0), lockAmount2) {
                fail("Should have reverted when locking more than available");
            } catch (bytes memory reason) {
                bytes4 errorSelector = bytes4(reason);
                assertEq(errorSelector, InsufficientBalance.selector, "Wrong error type");
            }
        } else {
            custody.lockForOrder(alice, address(token0), lockAmount2);

            UserBalance memory afterSecondLock = custody.getBalance(alice);
            uint256 afterSecondLockTotal = afterSecondLock.token0Available + afterSecondLock.token0Locked;
            assertEq(afterSecondLockTotal, initialTotal, "Total balance changed after second lock");

            if (afterSecondLock.token0Locked > afterSecondLock.token0Available) {
                vm.prank(alice);
                try custody.withdraw(address(token0), afterSecondLock.token0Locked) {
                    fail("Should have reverted when withdrawing more than available");
                } catch (bytes memory reason) {
                    bytes4 errorSelector = bytes4(reason);
                    assertEq(errorSelector, InsufficientBalance.selector, "Wrong error type");
                }
            }
        }
    }

    /// @notice Test zero amount deposit reverts
    /// Validates: Requirements 6.6
    function test_ZeroAmountDeposit_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(ZeroAmount.selector);
        custody.deposit(address(token0), 0);
    }

    /// @notice Test zero amount withdrawal reverts
    /// Validates: Requirements 6.6
    function test_ZeroAmountWithdrawal_Reverts() public {
        vm.prank(alice);
        vm.expectRevert(ZeroAmount.selector);
        custody.withdraw(address(token0), 0);
    }

    /// @notice Test insufficient balance withdrawal reverts
    /// Validates: Requirements 6.7
    function test_InsufficientBalanceWithdrawal_Reverts() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 200e18;

        vm.prank(alice);
        custody.deposit(address(token0), depositAmount);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(InsufficientBalance.selector, alice, withdrawAmount, depositAmount)
        );
        custody.withdraw(address(token0), withdrawAmount);
    }

    /// @notice Test locked balance withdrawal attempt reverts
    /// Validates: Requirements 6.7
    function test_LockedBalanceWithdrawal_Reverts() public {
        uint256 depositAmount = 100e18;
        uint256 lockAmount = 60e18;

        vm.prank(alice);
        custody.deposit(address(token0), depositAmount);

        custody.lockForOrder(alice, address(token0), lockAmount);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                InsufficientBalance.selector, alice, depositAmount, depositAmount - lockAmount
            )
        );
        custody.withdraw(address(token0), depositAmount);
    }

    /// @notice Test locking more than available reverts
    /// Validates: Requirements 6.7
    function test_LockMoreThanAvailable_Reverts() public {
        uint256 depositAmount = 100e18;
        uint256 lockAmount = 150e18;

        vm.prank(alice);
        custody.deposit(address(token0), depositAmount);

        vm.expectRevert(
            abi.encodeWithSelector(InsufficientBalance.selector, alice, lockAmount, depositAmount)
        );
        custody.lockForOrder(alice, address(token0), lockAmount);
    }

    /// @notice Test transfer between users works correctly
    /// Validates: Requirements 6.4
    function test_TransferBetweenUsers_Success() public {
        uint256 depositAmount = 100e18;
        uint256 lockAmount = 60e18;
        uint256 transferAmount = 40e18;

        vm.prank(alice);
        custody.deposit(address(token0), depositAmount);
        custody.lockForOrder(alice, address(token0), lockAmount);

        custody.transferBetweenUsers(alice, bob, address(token0), transferAmount);

        UserBalance memory aliceBalance = custody.getBalance(alice);
        assertEq(aliceBalance.token0Locked, lockAmount - transferAmount, "Alice locked incorrect");
        assertEq(aliceBalance.token0Available, depositAmount - lockAmount, "Alice available incorrect");

        UserBalance memory bobBalance = custody.getBalance(bob);
        assertEq(bobBalance.token0Available, transferAmount, "Bob available incorrect");
        assertEq(bobBalance.token0Locked, 0, "Bob locked should be zero");
    }

    /// @notice Test transfer more than locked reverts
    /// Validates: Requirements 6.7
    function test_TransferMoreThanLocked_Reverts() public {
        uint256 depositAmount = 100e18;
        uint256 lockAmount = 60e18;
        uint256 transferAmount = 80e18;

        vm.prank(alice);
        custody.deposit(address(token0), depositAmount);
        custody.lockForOrder(alice, address(token0), lockAmount);

        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector, alice, transferAmount, lockAmount));
        custody.transferBetweenUsers(alice, bob, address(token0), transferAmount);
    }

    /// @notice Test unlock and re-lock works correctly
    /// Validates: Requirements 6.3
    function test_UnlockAndRelock_Success() public {
        uint256 depositAmount = 100e18;
        uint256 lockAmount = 60e18;

        vm.prank(alice);
        custody.deposit(address(token0), depositAmount);
        custody.lockForOrder(alice, address(token0), lockAmount);

        custody.unlockFromOrder(alice, address(token0), lockAmount);

        UserBalance memory afterUnlock = custody.getBalance(alice);
        assertEq(afterUnlock.token0Available, depositAmount, "Available should be full deposit");
        assertEq(afterUnlock.token0Locked, 0, "Locked should be zero");

        custody.lockForOrder(alice, address(token0), lockAmount);

        UserBalance memory afterRelock = custody.getBalance(alice);
        assertEq(afterRelock.token0Available, depositAmount - lockAmount, "Available incorrect after relock");
        assertEq(afterRelock.token0Locked, lockAmount, "Locked incorrect after relock");
    }

    /// @notice Test deposit and immediate withdrawal
    /// Validates: Requirements 6.2, 6.6
    function test_DepositAndImmediateWithdrawal_Success() public {
        uint256 depositAmount = 100e18;

        uint256 initialBalance = token0.balanceOf(alice);

        vm.prank(alice);
        custody.deposit(address(token0), depositAmount);

        vm.prank(alice);
        custody.withdraw(address(token0), depositAmount);

        uint256 finalBalance = token0.balanceOf(alice);
        assertEq(finalBalance, initialBalance, "Balance should be restored");

        UserBalance memory balance = custody.getBalance(alice);
        assertEq(balance.token0Available, 0, "Available should be zero");
        assertEq(balance.token0Locked, 0, "Locked should be zero");
    }

    /// @notice Test invalid token address reverts
    /// Validates: Requirements 6.6
    function test_InvalidTokenAddress_Reverts() public {
        address invalidToken = address(0x999);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(InvalidInput.selector, "token"));
        custody.deposit(invalidToken, 100e18);
    }
}
