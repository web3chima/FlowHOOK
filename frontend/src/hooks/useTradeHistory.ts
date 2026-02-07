import { usePublicClient, useChainId } from 'wagmi';
import { useQuery } from '@tanstack/react-query';
import { getContractAddress, getVAMMEngineAddress } from '../lib/contracts';
import { parseAbiItem } from 'viem';

export interface Trade {
    hash: string;
    isLong: boolean;
    size: bigint;
    price: bigint;
    impact: bigint;
    timestamp: bigint;
    trader: `0x${string}`;
}

export function useTradeHistory() {
    const chainId = useChainId();
    const publicClient = usePublicClient();
    const contractAddress = getContractAddress(chainId);
    const vammEngineAddress = getVAMMEngineAddress(chainId);

    const { data: trades, isLoading, error, refetch } = useQuery({
        queryKey: ['tradeHistory', chainId],
        queryFn: async () => {
            if (!publicClient || !contractAddress) return [];

            // Use a specific block number to avoid RPC limits
            // Deployment was around block 7000000 on Sepolia
            const fromBlock = 7000000n;

            console.log('[TradeHistory] Fetching logs from block', fromBlock.toString(), 'for contracts:', {
                router: contractAddress,
                vammEngine: vammEngineAddress
            });

            // 1. Fetch SwapExecuted from Router
            let routerLogs: any[] = [];
            try {
                routerLogs = await publicClient.getLogs({
                    address: contractAddress as `0x${string}`,
                    event: parseAbiItem('event SwapExecuted(address indexed trader, bool isLong, uint256 size, uint256 executionPrice, uint256 priceImpact, uint256 timestamp)'),
                    fromBlock,
                    toBlock: 'latest'
                });
                console.log('[TradeHistory] Router logs:', routerLogs.length);
            } catch (e) {
                console.error('[TradeHistory] Error fetching router logs:', e);
            }

            // 2. Fetch CurveTradeExecuted from VAMMEngine (enhanced with Kyle model data)
            let vammLogs: any[] = [];
            if (vammEngineAddress) {
                try {
                    vammLogs = await publicClient.getLogs({
                        address: vammEngineAddress as `0x${string}`,
                        // Enhanced event with Kyle model + volatility params
                        event: parseAbiItem('event CurveTradeExecuted(bool isLong, uint256 size, uint256 executionPrice, uint256 priceImpact, uint256 kyleLambda, uint256 effectiveVolatility)'),
                        fromBlock,
                        toBlock: 'latest'
                    });
                    console.log('[TradeHistory] VAMM logs:', vammLogs.length);
                } catch (e) {
                    console.error('[TradeHistory] Error fetching VAMM logs:', e);
                }
            }

            // Normalization
            const normalizedRouterTrades = routerLogs.map(log => ({
                hash: log.transactionHash,
                isLong: log.args.isLong!,
                size: log.args.size!,
                price: log.args.executionPrice!,
                impact: log.args.priceImpact!,
                timestamp: log.args.timestamp!,
                trader: log.args.trader!
            }));

            // Fetch missing trader/timestamp for VAMM logs (limit to recent)
            const recentVammLogs = vammLogs.slice(-20); // Only process last 20 for perf
            const normalizedVammTrades = await Promise.all(recentVammLogs.map(async (log) => {
                try {
                    // Fetch tx and block for trader/timestamp
                    const [tx, block] = await Promise.all([
                        publicClient.getTransaction({ hash: log.transactionHash }),
                        publicClient.getBlock({ blockNumber: log.blockNumber! })
                    ]);

                    return {
                        hash: log.transactionHash,
                        isLong: log.args.isLong!,
                        size: log.args.size!,
                        price: log.args.executionPrice!,
                        impact: log.args.priceImpact!,
                        timestamp: block.timestamp,
                        trader: tx.from
                    };
                } catch (e) {
                    return {
                        hash: log.transactionHash,
                        isLong: log.args.isLong!,
                        size: log.args.size!,
                        price: log.args.executionPrice!,
                        impact: log.args.priceImpact!,
                        timestamp: BigInt(Math.floor(Date.now() / 1000)),
                        trader: '0x0000000000000000000000000000000000000000' as `0x${string}`
                    };
                }
            }));

            // Combine and Sort
            const combined = [...normalizedRouterTrades, ...normalizedVammTrades]
                .sort((a, b) => Number(b.timestamp - a.timestamp)); // Newest first

            console.log('Trade History Fetched:', {
                router: normalizedRouterTrades.length,
                vamm: normalizedVammTrades.length,
                total: combined.length
            });

            return combined;
        },
        enabled: !!publicClient && !!contractAddress,
        refetchInterval: 15000 // Slow down refetch to avoid RPC spam
    });

    return {
        trades: trades || [],
        isLoading,
        error,
        refetch
    };
}
