// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {PriceFeed} from "./DataStructures.sol";
import {StaleOracle, PriceOutOfBounds} from "./Errors.sol";
import {PriceDeviationAlert} from "./Events.sol";

/// @title OracleManager
/// @notice Manages Chainlink price feeds for external price validation
/// @dev Implements staleness checking and price deviation alerts
contract OracleManager {
    /// @notice Maximum age for oracle data (5 minutes)
    uint256 public constant ORACLE_HEARTBEAT = 5 minutes;
    
    /// @notice Price deviation threshold for alerts (2%)
    uint256 public constant DEVIATION_THRESHOLD = 200; // 2% in basis points (200/10000)
    
    /// @notice Maximum price deviation for de-leveraging (5%)
    uint256 public constant MAX_DELEVERAGING_DEVIATION = 500; // 5% in basis points
    
    /// @notice Mapping of token addresses to their price feeds
    mapping(address => PriceFeed) public priceFeeds;
    
    /// @notice Mapping to track last query block per feed
    mapping(address => uint256) private lastQueryBlock;
    
    /// @notice Whether the system is paused due to oracle failure
    bool public oraclePaused;
    
    /// @notice Event emitted when a price feed is configured
    event PriceFeedConfigured(address indexed token, address indexed feedAddress, uint256 heartbeat);
    
    /// @notice Event emitted when oracle pause state changes
    event OraclePauseStateChanged(bool paused, string reason);
    
    /// @notice Configure a price feed for a token
    /// @param token The token address
    /// @param feedAddress The Chainlink aggregator address
    /// @param heartbeat The maximum staleness threshold (0 = use default)
    function _configurePriceFeed(
        address token,
        address feedAddress,
        uint256 heartbeat
    ) internal {
        require(token != address(0), "Invalid token address");
        require(feedAddress != address(0), "Invalid feed address");
        
        // Validate heartbeat range if provided (min: 1 minute, max: 1 hour)
        if (heartbeat != 0) {
            require(heartbeat >= 1 minutes && heartbeat <= 1 hours, "Invalid heartbeat");
        }
        
        uint256 effectiveHeartbeat = heartbeat == 0 ? ORACLE_HEARTBEAT : heartbeat;
        
        priceFeeds[token] = PriceFeed({
            feedAddress: feedAddress,
            heartbeat: effectiveHeartbeat,
            lastUpdate: 0,
            lastPrice: 0
        });
        
        emit PriceFeedConfigured(token, feedAddress, effectiveHeartbeat);
    }
    
    /// @notice Update oracle price from Chainlink
    /// @param token The token to update price for
    /// @return price The latest price from oracle
    /// @return updatedAt The timestamp of the price update
    function updateOraclePrice(address token) public returns (int256 price, uint256 updatedAt) {
        // Validate token address
        require(token != address(0), "Invalid token address");
        
        PriceFeed storage feed = priceFeeds[token];
        require(feed.feedAddress != address(0), "Price feed not configured");
        
        // Enforce once-per-block query limit (Requirement 10.2)
        require(
            lastQueryBlock[token] < block.number,
            "Oracle already queried this block"
        );
        lastQueryBlock[token] = block.number;
        
        // Fetch latest price from Chainlink
        AggregatorV3Interface aggregator = AggregatorV3Interface(feed.feedAddress);
        
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAtTimestamp,
            uint80 answeredInRound
        ) = aggregator.latestRoundData();
        
        // Validate the data
        require(answer > 0, "Invalid price from oracle");
        require(answeredInRound >= roundId, "Stale round data");
        
        // Check staleness (Requirement 10.4)
        if (block.timestamp - updatedAtTimestamp > feed.heartbeat) {
            revert StaleOracle(feed.feedAddress, updatedAtTimestamp);
        }
        
        // Update stored values
        feed.lastUpdate = updatedAtTimestamp;
        feed.lastPrice = answer;
        
        return (answer, updatedAtTimestamp);
    }
    
    /// @notice Validate internal price against oracle price
    /// @param token The token to validate
    /// @param internalPrice The internal price to validate (18 decimals)
    /// @return isValid Whether the price is within acceptable deviation
    /// @return deviation The deviation in basis points
    function validatePrice(
        address token,
        uint256 internalPrice
    ) public returns (bool isValid, uint256 deviation) {
        // Validate inputs
        require(token != address(0), "Invalid token address");
        require(internalPrice > 0, "Invalid internal price");
        
        // Update oracle price first
        (int256 oraclePrice, ) = updateOraclePrice(token);
        
        // Convert oracle price to 18 decimals if needed
        AggregatorV3Interface aggregator = AggregatorV3Interface(priceFeeds[token].feedAddress);
        uint8 decimals = aggregator.decimals();
        uint256 normalizedOraclePrice = _normalizePrice(uint256(oraclePrice), decimals);
        
        // Calculate deviation in basis points
        uint256 diff = internalPrice > normalizedOraclePrice
            ? internalPrice - normalizedOraclePrice
            : normalizedOraclePrice - internalPrice;
        
        deviation = (diff * 10000) / normalizedOraclePrice;
        
        // Check if deviation exceeds threshold (Requirement 10.3)
        if (deviation > DEVIATION_THRESHOLD) {
            emit PriceDeviationAlert(
                token,
                internalPrice,
                normalizedOraclePrice,
                deviation,
                block.timestamp
            );
            isValid = false;
        } else {
            isValid = true;
        }
        
        return (isValid, deviation);
    }
    
    /// @notice Check if oracle price is stale
    /// @param token The token to check
    /// @return isStale Whether the price is stale
    function isPriceStale(address token) public view returns (bool isStale) {
        PriceFeed storage feed = priceFeeds[token];
        require(feed.feedAddress != address(0), "Price feed not configured");
        
        if (feed.lastUpdate == 0) {
            return true; // Never updated
        }
        
        return block.timestamp - feed.lastUpdate > feed.heartbeat;
    }
    
    /// @notice Get the latest oracle price without updating
    /// @param token The token to get price for
    /// @return price The last stored price
    /// @return updatedAt The timestamp of last update
    function getLatestPrice(address token) public view returns (int256 price, uint256 updatedAt) {
        PriceFeed storage feed = priceFeeds[token];
        require(feed.feedAddress != address(0), "Price feed not configured");
        
        return (feed.lastPrice, feed.lastUpdate);
    }
    
    /// @notice Pause system if oracle fails (Requirement 10.7)
    /// @param reason The reason for pausing
    function _pauseIfOracleFails(string memory reason) internal {
        if (!oraclePaused) {
            oraclePaused = true;
            emit OraclePauseStateChanged(true, reason);
        }
    }
    
    /// @notice Unpause system after oracle recovery
    function _unpauseOracle() internal {
        if (oraclePaused) {
            oraclePaused = false;
            emit OraclePauseStateChanged(false, "Oracle recovered");
        }
    }
    
    /// @notice Validate price for de-leveraging operations
    /// @param token The token to validate
    /// @param deleveragePrice The proposed de-leveraging price
    /// @return isValid Whether the price is within 5% of oracle
    function validateDeleveragingPrice(
        address token,
        uint256 deleveragePrice
    ) public returns (bool isValid) {
        // Validate inputs
        require(token != address(0), "Invalid token address");
        require(deleveragePrice > 0, "Invalid deleverage price");
        
        // Get oracle price
        (int256 oraclePrice, ) = updateOraclePrice(token);
        
        // Convert oracle price to 18 decimals
        AggregatorV3Interface aggregator = AggregatorV3Interface(priceFeeds[token].feedAddress);
        uint8 decimals = aggregator.decimals();
        uint256 normalizedOraclePrice = _normalizePrice(uint256(oraclePrice), decimals);
        
        // Calculate deviation
        uint256 diff = deleveragePrice > normalizedOraclePrice
            ? deleveragePrice - normalizedOraclePrice
            : normalizedOraclePrice - deleveragePrice;
        
        uint256 deviation = (diff * 10000) / normalizedOraclePrice;
        
        // Check if within 5% bounds (Requirement 9.5)
        if (deviation > MAX_DELEVERAGING_DEVIATION) {
            revert PriceOutOfBounds(
                deleveragePrice,
                (normalizedOraclePrice * (10000 - MAX_DELEVERAGING_DEVIATION)) / 10000,
                (normalizedOraclePrice * (10000 + MAX_DELEVERAGING_DEVIATION)) / 10000
            );
        }
        
        return true;
    }
    
    /// @notice Normalize price to 18 decimals
    /// @param price The price to normalize
    /// @param decimals The current decimals
    /// @return normalizedPrice The price in 18 decimals
    function _normalizePrice(uint256 price, uint8 decimals) internal pure returns (uint256 normalizedPrice) {
        if (decimals < 18) {
            return price * (10 ** (18 - decimals));
        } else if (decimals > 18) {
            return price / (10 ** (decimals - 18));
        }
        return price;
    }
    
    /// @notice Check if multiple price feeds are available (Requirement 10.6)
    /// @param tokens Array of token addresses to check
    /// @return allConfigured Whether all tokens have configured feeds
    function checkMultipleFeedsConfigured(address[] memory tokens) public view returns (bool allConfigured) {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (priceFeeds[tokens[i]].feedAddress == address(0)) {
                return false;
            }
        }
        return true;
    }
}
