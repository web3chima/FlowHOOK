import { useQuery } from '@tanstack/react-query';
import { usePublicClient, useChainId } from 'wagmi';
import {
    getContractAddress,
    getVAMMEngineAddress,
    getOrderbookEngineAddress,
    getOracleEngineAddress,
    ORDERBOOK_ABI,
    VAMM_ENGINE_ABI,
    FLOW_HOOK_ROUTER_ABI,
    ORACLE_ENGINE_ABI
} from '../lib/contracts';
import { useOrderbookStore } from '../stores/orderbookStore';
import { useEffect } from 'react';
import type { Order } from '../types/orderbook';

// Curve modes matching the contract
export const CurveMode = {
    LOB: 0,      // Limit Order Book only
    HYBRID: 1,   // Orderbook + AMM
    VAMM: 2,     // Virtual AMM (P = K × Q^(-2))
    ORACLE: 3    // Oracle-based pricing
} as const;

export type CurveModeType = typeof CurveMode[keyof typeof CurveMode];

export interface VAMMPoolState {
    poolConstant: bigint;      // K
    vBTCQuantity: bigint;      // Q
    currentPrice: bigint;      // P = K / Q²
    priceSensitivity: bigint;  // |dP/dQ|
    longOI: bigint;
    shortOI: bigint;
    netOI: bigint;
}

export interface OrderbookData {
    mode: CurveModeType;
    buyOrders: Order[];
    sellOrders: Order[];
    vammState: VAMMPoolState | null;
}

/**
 * Hook to fetch orderbook or VAMM state based on current curve mode
 * Supports multiple modes: LOB, HYBRID, VAMM, ORACLE
 */
export function useOrderbook() {
    const chainId = useChainId();
    const publicClient = usePublicClient();
    const contractAddress = getContractAddress(chainId);
    const vammEngineAddress = getVAMMEngineAddress(chainId);
    const orderbookEngineAddress = getOrderbookEngineAddress(chainId);
    const oracleEngineAddress = getOracleEngineAddress(chainId);
    const { setOrders, setLoading, setError } = useOrderbookStore();

    const queryKey = ['orderbook', chainId, contractAddress];

    const { data, isLoading, error, refetch } = useQuery({
        queryKey,
        queryFn: async (): Promise<OrderbookData> => {
            if (!publicClient || !contractAddress) {
                throw new Error('Client or address not ready');
            }

            // First, get the current curve mode from the router
            let mode: CurveModeType = CurveMode.VAMM; // Default
            try {
                const modeResult = await publicClient.readContract({
                    address: contractAddress,
                    abi: FLOW_HOOK_ROUTER_ABI,
                    functionName: 'curveMode',
                });
                mode = Number(modeResult) as CurveModeType;
            } catch {
                // If curveMode call fails, default to VAMM
                console.warn('Could not fetch curve mode, defaulting to VAMM');
            }

            // For VAMM and HYBRID modes, fetch virtual pool state
            if ((mode === CurveMode.VAMM || mode === CurveMode.HYBRID) && vammEngineAddress) {
                try {
                    const [curveState, oiState] = await Promise.all([
                        publicClient.readContract({
                            address: vammEngineAddress,
                            abi: VAMM_ENGINE_ABI,
                            functionName: 'getCurveState',
                        }),
                        publicClient.readContract({
                            address: vammEngineAddress,
                            abi: VAMM_ENGINE_ABI,
                            functionName: 'getOpenInterest',
                        }),
                    ]);

                    const curveData = curveState as readonly [bigint, bigint, bigint, bigint];
                    const oiData = oiState as readonly [bigint, bigint, bigint];

                    const vammState: VAMMPoolState = {
                        poolConstant: curveData[0],
                        vBTCQuantity: curveData[1],
                        currentPrice: curveData[2],
                        priceSensitivity: curveData[3],
                        longOI: oiData[0],
                        shortOI: oiData[1],
                        netOI: oiData[2],
                    };

                    // In VAMM mode, we generate synthetic orderbook from virtual liquidity
                    const syntheticOrders = generateVAMMOrderbook(vammState);

                    return {
                        mode,
                        buyOrders: syntheticOrders.bids,
                        sellOrders: syntheticOrders.asks,
                        vammState,
                    };
                } catch (err) {
                    console.error('Error fetching VAMM state:', err);
                    return {
                        mode,
                        buyOrders: [],
                        sellOrders: [],
                        vammState: null,
                    };
                }
            }

            // For LOB and HYBRID modes, fetch real orderbook data
            if ((mode === CurveMode.LOB || mode === CurveMode.HYBRID) && orderbookEngineAddress) {
                try {
                    const ordersResult = await publicClient.readContract({
                        address: orderbookEngineAddress,
                        abi: ORDERBOOK_ABI,
                        functionName: 'getOrders',
                    });

                    const orders = ordersResult as any[];
                    const mappedOrders: Order[] = orders.map(o => ({
                        orderId: BigInt(o.id),
                        price: BigInt(o.price),
                        quantity: BigInt(o.quantity),
                        isBuy: o.isBuy,
                        trader: o.trader,
                        timestamp: BigInt(Date.now() / 1000), // Default
                        lockedAmount: BigInt(0)
                    })).filter(o => o.quantity > 0n);

                    const buyOrders = mappedOrders.filter(o => o.isBuy).sort((a, b) => Number(b.price - a.price));
                    const sellOrders = mappedOrders.filter(o => !o.isBuy).sort((a, b) => Number(a.price - b.price));

                    return {
                        mode,
                        buyOrders,
                        sellOrders,
                        vammState: null,
                    };
                } catch (err) {
                    console.error('Error fetching LOB data:', err);
                }
            }

            // For ORACLE mode, fetch oracle price
            if (mode === CurveMode.ORACLE && oracleEngineAddress) {
                try {
                    const [price, timestamp] = await publicClient.readContract({
                        address: oracleEngineAddress,
                        abi: ORACLE_ENGINE_ABI,
                        functionName: 'getOraclePrice',
                    }) as [bigint, bigint];

                    // Generate a narrow spread around oracle price
                    const spread = price / 1000n; // 0.1%
                    return {
                        mode,
                        buyOrders: [{
                            orderId: 1n, price: price - spread, quantity: 100n * 10n ** 18n, isBuy: true,
                            trader: '0x0' as `0x${string}`, timestamp, lockedAmount: 0n
                        }],
                        sellOrders: [{
                            orderId: 2n, price: price + spread, quantity: 100n * 10n ** 18n, isBuy: false,
                            trader: '0x0' as `0x${string}`, timestamp, lockedAmount: 0n
                        }],
                        vammState: null,
                    };
                } catch (err) {
                    console.error('Error fetching Oracle data:', err);
                }
            }

            return {
                mode,
                buyOrders: [],
                sellOrders: [],
                vammState: null,
            };
        },
        enabled: !!publicClient && !!contractAddress,
        refetchInterval: 5000, // Poll every 5 seconds
    });

    // Sync with Store
    useEffect(() => {
        setLoading(isLoading);
        if (error) {
            setError(error.message);
        }
        if (data) {
            setOrders(data.buyOrders, data.sellOrders);
        }
    }, [data, isLoading, error, setOrders, setLoading, setError]);

    return {
        refetch,
        isLoading,
        error,
        mode: data?.mode ?? CurveMode.VAMM,
        vammState: data?.vammState ?? null,
        buyOrders: data?.buyOrders ?? [],
        sellOrders: data?.sellOrders ?? [],
    };
}

/**
 * Generate synthetic orderbook from VAMM state
 * Creates bid/ask levels based on the P = K × Q^(-2) curve
 */
function generateVAMMOrderbook(state: VAMMPoolState): { bids: Order[]; asks: Order[] } {
    const PRECISION = BigInt(1e18);
    const q = state.vBTCQuantity;
    const k = state.poolConstant;

    const bids: Order[] = [];
    const asks: Order[] = [];

    // Generate 10 levels each side
    const levels = 10;
    const stepSize = q / BigInt(100); // 1% of Q per level

    for (let i = 1; i <= levels; i++) {
        const step = stepSize * BigInt(i);

        // Ask prices (buying vBTC = Q decreases = price increases)
        if (q > step) {
            const newQ = q - step;
            const askPrice = (k * PRECISION) / (newQ * newQ / PRECISION);
            asks.push({
                orderId: BigInt(i),
                trader: '0x0000000000000000000000000000000000000000' as `0x${string}`,
                isBuy: false,
                price: askPrice,
                quantity: step,
                timestamp: BigInt(Date.now() / 1000),
                lockedAmount: BigInt(0),
            });
        }

        // Bid prices (selling vBTC = Q increases = price decreases)
        const newQ = q + step;
        const bidPrice = (k * PRECISION) / (newQ * newQ / PRECISION);
        bids.push({
            orderId: BigInt(i + levels),
            trader: '0x0000000000000000000000000000000000000000' as `0x${string}`,
            isBuy: true,
            price: bidPrice,
            quantity: step,
            timestamp: BigInt(Date.now() / 1000),
            lockedAmount: BigInt(0),
        });
    }

    return { bids, asks };
}
