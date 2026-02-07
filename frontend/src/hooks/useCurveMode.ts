import { useReadContract, useChainId } from 'wagmi';
import { FLOW_HOOK_ROUTER_ABI, getContractAddress } from '../lib/contracts';

// CurveMode values matching the Solidity contract
export const CurveMode = {
    LOB: 0,      // Limit Order Book (Binance style)
    HYBRID: 1,   // Orderbook + AMM (dYdX style)
    VAMM: 2,     // Virtual AMM (Perpetual style)
    ORACLE: 3,   // Oracle-based (GMX/GNS style)
} as const;

export type CurveModeType = typeof CurveMode[keyof typeof CurveMode];

export interface CurveModeState {
    activeMode: CurveModeType;
    oracleFeed: `0x${string}`;
    useOrderbook: boolean;
    usePool: boolean;
    lastModeChange: bigint;
}

export function useCurveMode() {
    const chainId = useChainId();
    const contractAddress = getContractAddress(chainId);

    // Read current curve mode from FlowHookRouter
    const { data: modeData, isLoading, error, refetch } = useReadContract({
        address: contractAddress as `0x${string}`,
        abi: FLOW_HOOK_ROUTER_ABI,
        functionName: 'curveMode',
        query: {
            enabled: !!contractAddress,
            staleTime: 5000, // Faster updates for mode changes
        }
    });

    // Parse mode - contract returns uint8
    const mode: CurveModeType = typeof modeData === 'number'
        ? modeData as CurveModeType
        : CurveMode.VAMM; // Default to VAMM

    // Build curve mode state from available data
    const curveModeState: CurveModeState = {
        activeMode: mode,
        oracleFeed: '0x0000000000000000000000000000000000000000',
        useOrderbook: mode === CurveMode.LOB || mode === CurveMode.HYBRID,
        usePool: mode === CurveMode.HYBRID || mode === CurveMode.VAMM,
        lastModeChange: BigInt(0),
    };

    return {
        mode,
        curveModeState,
        isLoading,
        error,

        // Helper booleans for easy conditional rendering
        isLOB: mode === CurveMode.LOB,
        isHybrid: mode === CurveMode.HYBRID,
        isVAMM: mode === CurveMode.VAMM,
        isOracle: mode === CurveMode.ORACLE,

        // UI configuration based on mode
        showOrderbook: mode === CurveMode.LOB || mode === CurveMode.HYBRID,
        showPool: mode === CurveMode.HYBRID || mode === CurveMode.VAMM,
        showOraclePrice: mode === CurveMode.ORACLE,

        // Mode display names
        modeLabel: getCurveModeLabel(mode),
        modeDescription: getCurveModeDescription(mode),

        refetch,
    };
}

function getCurveModeLabel(mode: CurveModeType): string {
    switch (mode) {
        case CurveMode.LOB: return 'Limit Order Book';
        case CurveMode.HYBRID: return 'Hybrid';
        case CurveMode.VAMM: return 'Virtual AMM';
        case CurveMode.ORACLE: return 'Oracle';
        default: return 'Unknown';
    }
}

function getCurveModeDescription(mode: CurveModeType): string {
    switch (mode) {
        case CurveMode.LOB: return 'Binance-style orderbook with price-time priority';
        case CurveMode.HYBRID: return 'dYdX-style orderbook with AMM liquidity backup';
        case CurveMode.VAMM: return 'Perpetual-style virtual AMM with P = K × Q^(-2)';
        case CurveMode.ORACLE: return 'GMX/GNS-style oracle-based instant execution';
        default: return '';
    }
}
