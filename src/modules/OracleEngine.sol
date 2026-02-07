// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IOracleEngine} from "./Interfaces.sol";

/// @title Oracle Engine
/// @notice Simple Oracle implementation for FlowHook demo

// Chainlink Interface
interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract OracleEngine is IOracleEngine {
    
    address public priceFeed;
    uint256 public mockPrice = 69420e18; // Default $69,420 for BTC/ETH (Updated)
    uint256 public lastUpdate;
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Unauthorized");
        _;
    }

    constructor() {
        admin = msg.sender;
        lastUpdate = block.timestamp;
    }

    /// @notice Get latest oracle price
    function getOraclePrice() external view override returns (uint256 price, uint256 timestamp) {
        if (priceFeed != address(0)) {
            // Live Mode: Strict Revert if Oracle Fails (No Mocks)
            (
                uint80 roundId,
                int256 answer,
                uint256 startedAt,
                uint256 updatedAt,
                uint80 answeredInRound
            ) = AggregatorV3Interface(priceFeed).latestRoundData();
            
            require(answer > 0, "Oracle: Invalid price");
            require(updatedAt > 0, "Oracle: Incomplete round");
            
            // Chainlink returns 8 decimals for USD pairs usually, we want 18
            return (uint256(answer) * 1e10, updatedAt);
        }
        
        // Demo Mode (Only if no feed set)
        return (mockPrice, lastUpdate);
    }
    
    /// @notice Set price feed address (Chainlink)
    function setPriceFeed(address feed) external override onlyAdmin {
        priceFeed = feed;
    }
    
    /// @notice Update mock price for demo
    function setMockPrice(uint256 price) external onlyAdmin {
        mockPrice = price;
        lastUpdate = block.timestamp;
    }

    /// @notice Check if oracle is healthy
    function isOracleHealthy() external view override returns (bool) {
        return (block.timestamp - lastUpdate) < 3600; // 1 hour threshold
    }
}
