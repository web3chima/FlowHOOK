// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/// @title Mock ERC20 Token for Testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        allowance[from][msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

/// @title Deploy Mock Tokens Script
/// @notice Deploys mock vBTC and USDC tokens for testing
contract DeployMockTokensScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("========================================");
        console.log("Deploying Mock Tokens on Sepolia");
        console.log("========================================");
        console.log("Deployer:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy vBTC (virtual BTC) - 8 decimals like real BTC
        MockERC20 vBTC = new MockERC20("Virtual Bitcoin", "vBTC", 8);
        console.log("vBTC deployed at:", address(vBTC));
        
        // Deploy USDC - 6 decimals like real USDC
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        console.log("USDC deployed at:", address(usdc));
        
        // Mint initial supply to deployer
        vBTC.mint(deployer, 1000 * 10**8);      // 1000 vBTC
        usdc.mint(deployer, 10000000 * 10**6);  // 10M USDC
        
        console.log("");
        console.log("Minted 1000 vBTC to deployer");
        console.log("Minted 10,000,000 USDC to deployer");
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("========================================");
        console.log("UPDATE YOUR .env FILE:");
        console.log("========================================");
        console.log("TOKEN0=", address(vBTC));
        console.log("TOKEN1=", address(usdc));
    }
}
