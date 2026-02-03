// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CustodyManager} from "../src/CustodyManager.sol";
import {UserBalance} from "../src/DataStructures.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/// @title Non-Standard ERC20 Token Mock
/// @notice Mock token that doesn't return boolean values (like USDT)
/// @dev This simulates tokens that don't follow the ERC20 standard strictly
contract NonStandardERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name = "Non-Standard Token";
    string public symbol = "NST";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    /// @notice Transfer without returning boolean (non-standard)
    function transfer(address to, uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        // Note: No return value (non-standard behavior)
    }

    /// @notice TransferFrom without returning boolean (non-standard)
    function transferFrom(address from, address to, uint256 amount) external {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        // Note: No return value (non-standard behavior)
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}

/// @title Custody Manager Test Contract for SafeERC20 Testing
contract CustodyManagerTestContract is CustodyManager {
    constructor(address _token0, address _token1) CustodyManager(_token0, _token1) {}

    function getBalance(address user) external view returns (UserBalance memory) {
        return balances[user];
    }
}

/// @title SafeERC20 Integration Tests
/// @notice Tests to verify SafeERC20 is properly implemented for all token transfers
/// @dev Validates: Requirements 15.6
contract SafeERC20IntegrationTest is Test {
    CustodyManagerTestContract public custody;
    NonStandardERC20 public nonStandardToken0;
    NonStandardERC20 public nonStandardToken1;
    ERC20Mock public standardToken0;
    ERC20Mock public standardToken1;

    address public alice = address(0x1);
    address public bob = address(0x2);

    uint256 constant INITIAL_MINT = 1000000e18;

    function setUp() public {
        // Deploy non-standard tokens
        nonStandardToken0 = new NonStandardERC20();
        nonStandardToken1 = new NonStandardERC20();

        // Deploy standard tokens
        standardToken0 = new ERC20Mock();
        standardToken1 = new ERC20Mock();
    }

    /// @notice Test SafeERC20 with non-standard tokens (no return value)
    /// @dev SafeERC20 should handle tokens that don't return boolean values
    /// Validates: Requirements 15.6
    function test_SafeERC20_NonStandardTokens_Success() public {
        custody = new CustodyManagerTestContract(
            address(nonStandardToken0),
            address(nonStandardToken1)
        );

        // Mint tokens to alice
        nonStandardToken0.mint(alice, INITIAL_MINT);
        nonStandardToken1.mint(alice, INITIAL_MINT);

        // Approve custody contract
        vm.prank(alice);
        nonStandardToken0.approve(address(custody), type(uint256).max);
        vm.prank(alice);
        nonStandardToken1.approve(address(custody), type(uint256).max);

        uint256 depositAmount = 100e18;

        // Test deposit with non-standard token (uses safeTransferFrom)
        vm.prank(alice);
        custody.deposit(address(nonStandardToken0), depositAmount);

        UserBalance memory balance = custody.getBalance(alice);
        assertEq(balance.token0Available, depositAmount, "Deposit failed with non-standard token");

        // Test withdrawal with non-standard token (uses safeTransfer)
        vm.prank(alice);
        custody.withdraw(address(nonStandardToken0), depositAmount / 2);

        balance = custody.getBalance(alice);
        assertEq(balance.token0Available, depositAmount / 2, "Withdrawal failed with non-standard token");

        // Verify token balances
        assertEq(
            nonStandardToken0.balanceOf(alice),
            INITIAL_MINT - depositAmount / 2,
            "Alice's token balance incorrect"
        );
        assertEq(
            nonStandardToken0.balanceOf(address(custody)),
            depositAmount / 2,
            "Custody token balance incorrect"
        );
    }

    /// @notice Test SafeERC20 with standard ERC20 tokens
    /// @dev Verify SafeERC20 works correctly with standard tokens too
    /// Validates: Requirements 15.6
    function test_SafeERC20_StandardTokens_Success() public {
        custody = new CustodyManagerTestContract(
            address(standardToken0),
            address(standardToken1)
        );

        // Mint tokens to alice
        standardToken0.mint(alice, INITIAL_MINT);
        standardToken1.mint(alice, INITIAL_MINT);

        // Approve custody contract
        vm.prank(alice);
        standardToken0.approve(address(custody), type(uint256).max);
        vm.prank(alice);
        standardToken1.approve(address(custody), type(uint256).max);

        uint256 depositAmount = 100e18;

        // Test deposit with standard token
        vm.prank(alice);
        custody.deposit(address(standardToken0), depositAmount);

        UserBalance memory balance = custody.getBalance(alice);
        assertEq(balance.token0Available, depositAmount, "Deposit failed with standard token");

        // Test withdrawal with standard token
        vm.prank(alice);
        custody.withdraw(address(standardToken0), depositAmount / 2);

        balance = custody.getBalance(alice);
        assertEq(balance.token0Available, depositAmount / 2, "Withdrawal failed with standard token");
    }

    /// @notice Property test: SafeERC20 handles various token amounts correctly
    /// @dev Fuzz test to verify SafeERC20 works across different amounts
    /// Validates: Requirements 15.6
    function testProperty_SafeERC20_VariousAmounts(uint256 depositAmount, uint256 withdrawAmount) public {
        depositAmount = bound(depositAmount, 1e18, 100000e18);
        withdrawAmount = bound(withdrawAmount, 1e16, depositAmount);

        custody = new CustodyManagerTestContract(
            address(nonStandardToken0),
            address(nonStandardToken1)
        );

        nonStandardToken0.mint(alice, INITIAL_MINT);
        
        vm.prank(alice);
        nonStandardToken0.approve(address(custody), type(uint256).max);

        // Deposit
        vm.prank(alice);
        custody.deposit(address(nonStandardToken0), depositAmount);

        UserBalance memory balanceAfterDeposit = custody.getBalance(alice);
        assertEq(
            balanceAfterDeposit.token0Available,
            depositAmount,
            "SafeERC20 deposit amount mismatch"
        );

        // Withdraw
        vm.prank(alice);
        custody.withdraw(address(nonStandardToken0), withdrawAmount);

        UserBalance memory balanceAfterWithdraw = custody.getBalance(alice);
        assertEq(
            balanceAfterWithdraw.token0Available,
            depositAmount - withdrawAmount,
            "SafeERC20 withdrawal amount mismatch"
        );

        // Verify actual token balances match internal accounting
        assertEq(
            nonStandardToken0.balanceOf(address(custody)),
            depositAmount - withdrawAmount,
            "Custody contract token balance mismatch"
        );
    }

    /// @notice Test SafeERC20 protects against tokens that revert on failure
    /// @dev Verify that SafeERC20 properly handles transfer failures
    /// Validates: Requirements 15.6
    function test_SafeERC20_HandlesTransferFailure() public {
        custody = new CustodyManagerTestContract(
            address(nonStandardToken0),
            address(nonStandardToken1)
        );

        nonStandardToken0.mint(alice, 100e18);
        
        vm.prank(alice);
        nonStandardToken0.approve(address(custody), type(uint256).max);

        // Try to deposit more than alice has - should revert
        vm.prank(alice);
        vm.expectRevert();
        custody.deposit(address(nonStandardToken0), 200e18);

        // Try to withdraw without depositing - should revert
        vm.prank(bob);
        vm.expectRevert();
        custody.withdraw(address(nonStandardToken0), 10e18);
    }

    /// @notice Test that all token transfer operations use SafeERC20
    /// @dev Comprehensive test covering deposit, withdraw, and internal transfers
    /// Validates: Requirements 15.6
    function test_AllTransferOperations_UseSafeERC20() public {
        custody = new CustodyManagerTestContract(
            address(nonStandardToken0),
            address(nonStandardToken1)
        );

        // Setup: mint and approve for both users
        nonStandardToken0.mint(alice, INITIAL_MINT);
        nonStandardToken1.mint(bob, INITIAL_MINT);
        
        vm.prank(alice);
        nonStandardToken0.approve(address(custody), type(uint256).max);
        vm.prank(bob);
        nonStandardToken1.approve(address(custody), type(uint256).max);

        // Test 1: Deposit (uses safeTransferFrom)
        vm.prank(alice);
        custody.deposit(address(nonStandardToken0), 100e18);
        assertEq(
            nonStandardToken0.balanceOf(address(custody)),
            100e18,
            "SafeTransferFrom failed in deposit"
        );

        // Test 2: Withdraw (uses safeTransfer)
        vm.prank(alice);
        custody.withdraw(address(nonStandardToken0), 50e18);
        assertEq(
            nonStandardToken0.balanceOf(alice),
            INITIAL_MINT - 50e18,
            "SafeTransfer failed in withdraw"
        );

        // Test 3: Multiple deposits and withdrawals
        vm.prank(bob);
        custody.deposit(address(nonStandardToken1), 200e18);
        
        vm.prank(bob);
        custody.withdraw(address(nonStandardToken1), 100e18);
        
        assertEq(
            nonStandardToken1.balanceOf(address(custody)),
            100e18,
            "SafeERC20 failed in multiple operations"
        );
    }
}
