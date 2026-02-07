import { useReadContract, useChainId } from 'wagmi';
import { formatEther, formatUnits } from 'viem';
import { FLOW_HOOK_ROUTER_ABI, VAMM_ENGINE_ABI, getContractAddress, getVAMMEngineAddress } from '../lib/contracts';

// Curve precision constant (matches Solidity)
const CURVE_PRECISION = BigInt(1e18);

export interface VAMMCurveState {
    poolConstant: bigint;        // K - the curve invariant
    vBTCQuantity: bigint;        // Q - vBTC in pool
    currentPrice: bigint;        // P = K / Q²
    priceSensitivity: bigint;    // |dP/dQ| = 2K / Q³
}

export interface OpenInterestState {
    longOI: bigint;
    shortOI: bigint;
    netOI: bigint;
}

export interface VAMMTradeSimulation {
    expectedPrice: bigint;
    expectedImpact: bigint;
}

/**
 * Hook to read VAMM custom curve state (P = K × Q^(-2))
 * 
 * The custom curve implements:
 * - Price formula: P = K / Q²
 * - Long trades: Q decreases → Price sensitivity increases → Volatility ↑
 * - Short trades: Q increases → Price sensitivity decreases → Volatility ↓
 */
export function useVAMMCurve() {
    const chainId = useChainId();
    const contractAddress = getContractAddress(chainId);

    // Read curve state (k, q, price, sensitivity) from FlowHookRouter
    const { data: curveState, isLoading: curveLoading, error: curveError, refetch: refetchCurve } = useReadContract({
        address: contractAddress as `0x${string}`,
        abi: FLOW_HOOK_ROUTER_ABI,
        functionName: 'getVAMMState',
        query: {
            enabled: !!contractAddress,
        }
    });

    // Parse curve state
    const parsedCurveState: VAMMCurveState | null = curveState ? {
        poolConstant: (curveState as readonly [bigint, bigint, bigint, bigint])[0],
        vBTCQuantity: (curveState as readonly [bigint, bigint, bigint, bigint])[1],
        currentPrice: (curveState as readonly [bigint, bigint, bigint, bigint])[2],
        priceSensitivity: (curveState as readonly [bigint, bigint, bigint, bigint])[3],
    } : null;

    // Read open interest
    const { data: oiData, isLoading: oiLoading, refetch: refetchOI } = useReadContract({
        address: contractAddress as `0x${string}`,
        abi: FLOW_HOOK_ROUTER_ABI,
        functionName: 'getOpenInterest',
        query: {
            enabled: !!contractAddress,
        }
    });

    const openInterest: OpenInterestState | null = oiData ? {
        longOI: (oiData as readonly [bigint, bigint, bigint])[0],
        shortOI: (oiData as readonly [bigint, bigint, bigint])[1],
        netOI: (oiData as readonly [bigint, bigint, bigint])[2],
    } : null;

    // Helper: Format price for display (convert from 1e18 to human readable)
    const formatPrice = (price: bigint): string => {
        const val = Number(formatEther(price));
        // If huge, just return string directly so UI component can use compact formatter
        if (val > 1000000) return val.toString();
        return val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    };

    // Helper: Format quantity for display
    const formatQuantity = (quantity: bigint): string => {
        const val = Number(formatEther(quantity));
        if (val > 1000000) return val.toExponential(2);
        return val.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 4 });
    };

    // Helper: Calculate price impact percentage
    const formatImpact = (impact: bigint): string => {
        // Impact is usually 1e16 scale (bps -> percent)
        return (Number(impact) / 1e16).toFixed(2) + '%';
    };

    // Helper: Get price level description
    // Helper: Get price level description
    const getPriceSensitivityLevel = (): 'low' | 'medium' | 'high' | 'extreme' => {
        if (!parsedCurveState) return 'medium';

        // Sensitivity = |dP/dQ| = 2K/Q^3
        // If K and Q are 1e18 scaled, sensitivity can be very small or very large depending on units
        // Based on VAMM math, usually sensitivity is around 1e-18 to 1e-10 if normalized
        // dP approx = sensitivity * dQ
        // If dQ = 1 ETH (1e18), dP = sensitivity * 1e18
        // If Price = 2500, and dP = 25, that's 1% impact.
        // So we want sensitivity * 1e18 / Price < 0.01 for low impact.

        if (Number(parsedCurveState.vBTCQuantity) === 0) return 'extreme';

        // STRICT_MODE: Use on-chain Sensitivity and Price directly
        // Impact % = (Sensitivity / Price)
        // Sensitivity = dP/dQ
        // Relative Impact = (dP/dQ) / P

        const sensitivity = Number(formatUnits(parsedCurveState.priceSensitivity, 36));
        const price = Number(formatEther(parsedCurveState.currentPrice));

        if (price === 0) return 'extreme';

        const percentImpact = sensitivity / price;

        if (percentImpact < 0.01) return 'low';     // < 1%
        if (percentImpact < 0.05) return 'medium';  // < 5%
        if (percentImpact < 0.20) return 'high';    // < 20%
        return 'extreme';
    };

    // Helper: Estimate volatility direction based on OI
    const getVolatilityTrend = (): 'increasing' | 'decreasing' | 'neutral' => {
        if (!openInterest) return 'neutral';

        const netOI = Number(openInterest.netOI);
        if (netOI > 0) return 'increasing';  // More longs = higher volatility
        if (netOI < 0) return 'decreasing';  // More shorts = lower volatility
        return 'neutral';
    };

    const refetch = () => {
        refetchCurve();
        refetchOI();
    };

    return {
        // Raw state
        curveState: parsedCurveState,
        openInterest,

        // Loading/error states
        isLoading: curveLoading || oiLoading,
        error: curveError,

        // Formatted values for display
        formattedPrice: parsedCurveState ? formatPrice(parsedCurveState.currentPrice) : '—',
        formattedQuantity: parsedCurveState ? formatQuantity(parsedCurveState.vBTCQuantity) : '—',

        // Indicators
        priceSensitivityLevel: getPriceSensitivityLevel(),
        volatilityTrend: getVolatilityTrend(),

        // Utilities
        formatPrice,
        formatQuantity,
        formatImpact,
        refetch,

        // Curve precision for calculations
        CURVE_PRECISION,
    };
}

/**
 * Hook to simulate a VAMM trade before execution
 * Uses the VAMM Engine contract directly for simulation
 */
export function useVAMMTradeSimulation(size: bigint, isLong: boolean) {
    const chainId = useChainId();
    const vammEngineAddress = getVAMMEngineAddress(chainId);

    const { data: simulation, isLoading, error } = useReadContract({
        address: vammEngineAddress as `0x${string}`,
        abi: VAMM_ENGINE_ABI,
        functionName: 'simulateTrade',
        args: [size, isLong],
        query: {
            enabled: !!vammEngineAddress && size > 0n,
        }
    });

    const parsedSimulation: VAMMTradeSimulation | null = simulation ? {
        expectedPrice: (simulation as readonly [bigint, bigint])[0],
        expectedImpact: (simulation as readonly [bigint, bigint])[1],
    } : null;

    return {
        simulation: parsedSimulation,
        isLoading,
        error,
    };
}

