import { useAccount, useReadContract, useChainId } from 'wagmi';
import { FLOW_HOOK_ROUTER_ABI, getContractAddress } from '../lib/contracts';

/**
 * Hook to check if the connected wallet is an admin
 * Uses the FlowHookRouter's admin() function
 */
export function useAdmin() {
    const { address } = useAccount();
    const chainId = useChainId();
    const contractAddress = getContractAddress(chainId);

    // FlowHookRouter has a simple admin() function that returns the admin address
    const { data: adminAddress, isLoading } = useReadContract({
        address: contractAddress as `0x${string}`,
        abi: FLOW_HOOK_ROUTER_ABI,
        functionName: 'admin',
        query: {
            enabled: !!contractAddress,
        }
    });

    // Check if connected address matches admin
    const isAdmin = address && adminAddress
        ? address.toLowerCase() === (adminAddress as string).toLowerCase()
        : false;

    return {
        isAdmin,
        isLoading,
        adminAddress: adminAddress as `0x${string}` | undefined,
    };
}
