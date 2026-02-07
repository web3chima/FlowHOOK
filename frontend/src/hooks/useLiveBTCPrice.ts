import { useQuery } from '@tanstack/react-query';

export interface OHLCCandle {
    time: number;    // Unix timestamp in seconds
    open: number;
    high: number;
    low: number;
    close: number;
}

/**
 * Fetch live BTC OHLC data from CoinGecko API
 * Returns 24 hours of 1-hour candles
 */
export function useLiveBTCPrice() {
    const { data, isLoading, error, refetch } = useQuery({
        queryKey: ['liveBTCPrice'],
        queryFn: async (): Promise<OHLCCandle[]> => {
            // CoinGecko free API - BTC OHLC data
            // Days = 1 gives hourly candles
            const response = await fetch(
                'https://api.coingecko.com/api/v3/coins/bitcoin/ohlc?vs_currency=usd&days=1'
            );

            if (!response.ok) {
                throw new Error('Failed to fetch price data');
            }

            const data = await response.json();

            // CoinGecko returns: [[timestamp, open, high, low, close], ...]
            // Timestamp is in milliseconds
            return data.map((candle: number[]) => ({
                time: Math.floor(candle[0] / 1000), // Convert to seconds
                open: candle[1],
                high: candle[2],
                low: candle[3],
                close: candle[4]
            }));
        },
        refetchInterval: 60000, // Refetch every minute
        staleTime: 30000, // Consider data stale after 30 seconds
    });

    // Get current price (latest close)
    const currentPrice = data && data.length > 0 ? data[data.length - 1].close : null;

    // Calculate 24h change
    const priceChange = data && data.length > 1
        ? ((data[data.length - 1].close - data[0].open) / data[0].open) * 100
        : 0;

    return {
        candles: data || [],
        currentPrice,
        priceChange,
        isLoading,
        error,
        refetch
    };
}
