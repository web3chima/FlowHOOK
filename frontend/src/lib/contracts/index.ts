import {
    FLOW_HOOK_ROUTER_ABI,
    VAMM_ENGINE_ABI,
    FEE_ENGINE_ABI,
    ORDERBOOK_ABI,
    ORACLE_ENGINE_ABI,
    CONTRACT_ADDRESSES as DEPLOYED_ADDRESSES,
    SEPOLIA_CONFIG
} from '../../abi/contracts';

// Re-export ABIs
export { FLOW_HOOK_ROUTER_ABI, VAMM_ENGINE_ABI, FEE_ENGINE_ABI, ORDERBOOK_ABI, ORACLE_ENGINE_ABI };

// Contract addresses by chain ID
export const CONTRACT_ADDRESSES: Record<number, {
    router: `0x${string}`;
    vammEngine: `0x${string}`;
    feeEngine: `0x${string}`;
    orderbookEngine: `0x${string}`;
    oracleEngine: `0x${string}`;
}> = {
    // Sepolia Testnet
    11155111: {
        router: DEPLOYED_ADDRESSES.FLOW_HOOK_ROUTER as `0x${string}`,
        vammEngine: DEPLOYED_ADDRESSES.VAMM_ENGINE as `0x${string}`,
        feeEngine: DEPLOYED_ADDRESSES.FEE_ENGINE as `0x${string}`,
        orderbookEngine: DEPLOYED_ADDRESSES.ORDERBOOK_ENGINE as `0x${string}`,
        oracleEngine: DEPLOYED_ADDRESSES.ORACLE_ENGINE as any as `0x${string}`, // To be updated
    },
    // Local development (placeholder)
    31337: {
        router: '0x0000000000000000000000000000000000000000' as `0x${string}`,
        vammEngine: '0x0000000000000000000000000000000000000000' as `0x${string}`,
        feeEngine: '0x0000000000000000000000000000000000000000' as `0x${string}`,
        orderbookEngine: '0x0000000000000000000000000000000000000000' as `0x${string}`,
        oracleEngine: '0x0000000000000000000000000000000000000000' as `0x${string}`,
    },
};

// Get FlowHookRouter address (main entry point)
export const getContractAddress = (chainId: number): `0x${string}` | undefined => {
    const addresses = CONTRACT_ADDRESSES[chainId];
    if (addresses) {
        return addresses.router;
    }
    // Fallback to env variable
    return import.meta.env.VITE_HOOK_ADDRESS as `0x${string}` | undefined;
};

// Get VAMM Engine address
export const getVAMMEngineAddress = (chainId: number): `0x${string}` | undefined => {
    const addresses = CONTRACT_ADDRESSES[chainId];
    if (addresses) {
        return addresses.vammEngine;
    }
    return import.meta.env.VITE_VAMM_ENGINE_ADDRESS as `0x${string}` | undefined;
};

// Get Fee Engine address
export const getFeeEngineAddress = (chainId: number): `0x${string}` | undefined => {
    const addresses = CONTRACT_ADDRESSES[chainId];
    if (addresses) {
        return addresses.feeEngine;
    }
    return import.meta.env.VITE_FEE_ENGINE_ADDRESS as `0x${string}` | undefined;
};

// Get Orderbook Engine address
export const getOrderbookEngineAddress = (chainId: number): `0x${string}` | undefined => {
    const addresses = CONTRACT_ADDRESSES[chainId];
    if (addresses) {
        return addresses.orderbookEngine;
    }
    return import.meta.env.VITE_ORDERBOOK_ENGINE_ADDRESS as `0x${string}` | undefined;
};

// Get Oracle Engine address
export const getOracleEngineAddress = (chainId: number): `0x${string}` | undefined => {
    const addresses = CONTRACT_ADDRESSES[chainId];
    if (addresses) {
        return addresses.oracleEngine;
    }
    return import.meta.env.VITE_ORACLE_ENGINE_ADDRESS as `0x${string}` | undefined;
};

// Network configuration
export const SUPPORTED_CHAINS = {
    sepolia: SEPOLIA_CONFIG,
};

// Helper to check if on supported network
export const isSupportedChain = (chainId: number): boolean => {
    return chainId in CONTRACT_ADDRESSES && CONTRACT_ADDRESSES[chainId].router !== '0x0000000000000000000000000000000000000000';
};
