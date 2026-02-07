import { usePublicClient, useChainId } from 'wagmi';
import { useQuery } from '@tanstack/react-query';
import { getContractAddress } from '../lib/contracts';
import { parseAbiItem } from 'viem';

export interface AdminEvent {
    hash: string;
    name: string;
    details: string;
    timestamp: bigint; // Approximate from block? fetching block timestamp is expensive for each log
}

export function useAdminHistory() {
    const chainId = useChainId();
    const publicClient = usePublicClient();
    const contractAddress = getContractAddress(chainId);

    const { data: events, isLoading, refetch } = useQuery({
        queryKey: ['adminHistory', chainId],
        queryFn: async () => {
            if (!publicClient || !contractAddress) return [];

            // Fetch ModeChanged and EngineUpdated events
            const modeLogs = await publicClient.getLogs({
                address: contractAddress as `0x${string}`,
                event: parseAbiItem('event ModeChanged(uint8 oldMode, uint8 newMode)'),
                fromBlock: 'earliest',
                toBlock: 'latest'
            });

            const parsedModeLogs = modeLogs.map(log => ({
                hash: log.transactionHash,
                name: 'Mode Changed',
                details: `Switched from ${getModeName(log.args.oldMode)} to ${getModeName(log.args.newMode)}`,
                timestamp: 0n // Placeholder
            }));

            // In real app, we'd fetch block timestamps or just list them by block number
            // For MVP, just return logs reversed
            return [...parsedModeLogs].reverse();
        },
        enabled: !!publicClient && !!contractAddress,
    });

    return {
        events: events || [],
        isLoading,
        refetch
    };
}

function getModeName(mode: number | undefined): string {
    if (mode === undefined) return 'Unknown';
    const modes = ['LOB', 'HYBRID', 'VAMM', 'ORACLE'];
    return modes[mode] || 'Unknown';
}
