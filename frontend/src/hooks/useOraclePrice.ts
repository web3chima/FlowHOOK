import { useReadContract } from 'wagmi';
import { parseAbi } from 'viem';

// Chainlink Aggregator V3 Interface
const AGGREGATOR_V3_ABI = parseAbi([
    'function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)',
    'function decimals() external view returns (uint8)',
    'function description() external view returns (string memory)'
]);

// Sepolia Feed Addresses
const FEEDS = {
    BTC: '0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43',
    ETH: '0x694AA1769357215DE4FAC081bf1f309aDC325306' // ETH/USD Sepolia
};

export interface OraclePriceData {
    price: string;
    rawPrice: bigint;
    decimals: number;
    lastUpdated: Date;
    description: string;
    confidence: 'high' | 'medium' | 'low';
}

export function useOraclePrice(symbol: 'BTC' | 'ETH' = 'BTC') {
    const feedAddress = FEEDS[symbol];

    // Read Price Data
    const { data: roundData, isLoading: isLoadingPrice, refetch: refetchPrice } = useReadContract({
        address: feedAddress as `0x${string}`,
        abi: AGGREGATOR_V3_ABI,
        functionName: 'latestRoundData',
        query: {
            refetchInterval: 10000, // Update every 10s
        }
    });

    // Read Decimals
    const { data: decimals } = useReadContract({
        address: feedAddress as `0x${string}`,
        abi: AGGREGATOR_V3_ABI,
        functionName: 'decimals',
    });

    // Read Description
    const { data: description } = useReadContract({
        address: feedAddress as `0x${string}`,
        abi: AGGREGATOR_V3_ABI,
        functionName: 'description',
    });

    // Parse Data
    let parsedData: OraclePriceData | null = null;

    if (roundData && decimals) {
        const [, , , updatedAt] = roundData;
        const answer = roundData[1];

        // Convert to string with proper decimals
        const priceNum = Number(answer) / Math.pow(10, Number(decimals));

        // Basic staleness check (if > 1 hour old, low confidence)
        const lastUpdatedDate = new Date(Number(updatedAt) * 1000);
        const now = new Date();
        const diffMinutes = (now.getTime() - lastUpdatedDate.getTime()) / 1000 / 60;

        let confidence: 'high' | 'medium' | 'low' = 'high';
        if (diffMinutes > 60) confidence = 'low';
        else if (diffMinutes > 10) confidence = 'medium';

        parsedData = {
            price: priceNum.toLocaleString('en-US', { style: 'currency', currency: 'USD' }),
            rawPrice: BigInt(answer),
            decimals: Number(decimals),
            lastUpdated: lastUpdatedDate,
            description: description || `${symbol}/USD`,
            confidence
        };
    }

    return {
        data: parsedData,
        isLoading: isLoadingPrice,
        refetch: refetchPrice
    };
}
