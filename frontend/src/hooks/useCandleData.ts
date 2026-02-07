import { useState, useEffect } from 'react';
import { usePublicClient, useChainId } from 'wagmi';
import { getContractAddress } from '../lib/contracts';
import { parseAbiItem } from 'viem';

export interface Candle {
    time: number;
    open: number;
    high: number;
    low: number;
    close: number;
    volume: number;
}

// Helper to get time bucket (e.g., 1 minute)
const getCandleTime = (timestamp: number) => {
    return Math.floor(timestamp / 60) * 60;
};

export function useCandleData() {
    const chainId = useChainId();
    const publicClient = usePublicClient();
    const contractAddress = getContractAddress(chainId);
    const [candles, setCandles] = useState<Candle[]>([]);

    useEffect(() => {
        if (!publicClient || !contractAddress) return;

        // Load cached candles from local storage
        const cached = localStorage.getItem(`candles_${chainId}_${contractAddress}`);
        if (cached) {
            try {
                setCandles(JSON.parse(cached));
            } catch (e) {
                console.error("Failed to parse cached candles", e);
            }
        }

        // Listen for OrderMatched events
        // event OrderMatched(uint256 indexed orderId, address indexed trader, bool isBuy, uint256 price, uint256 quantity);
        const unwatch = publicClient.watchEvent({
            address: contractAddress,
            event: parseAbiItem('event OrderMatched(uint256 indexed orderId, address indexed trader, bool isBuy, uint256 price, uint256 quantity, uint256 timestamp)'),
            // Note: Check if timestamp is in ABI. If not, use block timestamp. 
            // Assuming standard OrderMatched might not have timestamp, we'll fetch block.
            onLogs: async (logs) => {
                for (const log of logs) {
                    // @ts-ignore - Viem typing for dynamic logs
                    const { price: priceBig, quantity: qtyBig } = log.args;
                    const price = Number(priceBig);
                    const quantity = Number(qtyBig);

                    // Get block timestamp
                    const block = await publicClient.getBlock({ blockHash: log.blockHash });
                    const timestamp = Number(block.timestamp);
                    const time = getCandleTime(timestamp);

                    setCandles(prev => {
                        const newCandles = [...prev];
                        const lastCandle = newCandles[newCandles.length - 1];

                        if (lastCandle && lastCandle.time === time) {
                            // Update existing candle
                            lastCandle.high = Math.max(lastCandle.high, price);
                            lastCandle.low = Math.min(lastCandle.low, price);
                            lastCandle.close = price;
                            lastCandle.volume += quantity;
                        } else {
                            // Create new candle
                            newCandles.push({
                                time,
                                open: price,
                                high: price,
                                low: price,
                                close: price,
                                volume: quantity
                            });
                        }

                        // Sort and limit
                        const sorted = newCandles.sort((a, b) => a.time - b.time).slice(-100);
                        localStorage.setItem(`candles_${chainId}_${contractAddress}`, JSON.stringify(sorted));
                        return sorted;
                    });
                }
            }
        });

        return () => unwatch();
    }, [publicClient, contractAddress, chainId]);

    return { candles };
}
