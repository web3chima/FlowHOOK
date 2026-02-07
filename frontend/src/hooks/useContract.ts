import { useMemo } from 'react';
import { useChainId, useWalletClient, usePublicClient } from 'wagmi';
import { getContract } from 'viem';
import { ORDERBOOK_ABI, getContractAddress } from '../lib/contracts';

export function useOrderbookContract() {
    const chainId = useChainId();
    const { data: walletClient } = useWalletClient();
    const publicClient = usePublicClient();

    const contractAddress = getContractAddress(chainId);

    const contract = useMemo(() => {
        if (!contractAddress || !publicClient) return null;
        return getContract({
            address: contractAddress,
            abi: ORDERBOOK_ABI,
            client: { public: publicClient, wallet: walletClient },
        });
    }, [contractAddress, publicClient, walletClient]);

    return contract;
}

export function useOrderbookRead() {
    const chainId = useChainId();
    const contractAddress = getContractAddress(chainId);
    return {
        address: contractAddress,
        abi: ORDERBOOK_ABI,
    };
}
