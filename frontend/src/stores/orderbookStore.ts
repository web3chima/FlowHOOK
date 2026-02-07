import { create } from 'zustand';
import type { Order, OrderbookState, OrderbookLevel } from '../types/orderbook';

interface OrderbookStore extends OrderbookState {
    setOrders: (buyOrders: Order[], sellOrders: Order[]) => void;
    setLoading: (isLoading: boolean) => void;
    setError: (error: string | null) => void;
    setLastTxHash: (hash: string | null) => void;
}

export const useOrderbookStore = create<OrderbookStore>((set) => ({
    bids: [],
    asks: [],
    spread: 0n,
    midPrice: 0n,
    lastUpdated: 0,
    isLoading: false,
    error: null,
    lastTxHash: null,

    setLoading: (isLoading) => set({ isLoading }),
    setError: (error) => set({ error }),
    setLastTxHash: (hash) => set({ lastTxHash: hash }),

    setOrders: (buyOrders, sellOrders) => {
        // Process Bids (Buy Orders) - Sort by Price Descending
        const bidsMap = new Map<string, OrderbookLevel>();
        buyOrders.forEach(order => {
            const priceKey = order.price.toString();
            if (!bidsMap.has(priceKey)) {
                bidsMap.set(priceKey, {
                    price: order.price,
                    quantity: 0n,
                    orderCount: 0,
                    total: 0n, // Calculated needed? or just cumulative depth
                    orders: []
                });
            }
            const level = bidsMap.get(priceKey)!;
            level.quantity += order.quantity;
            level.orderCount += 1;
            level.orders.push(order);
        });

        const sortedBids = Array.from(bidsMap.values()).sort((a, b) => {
            // Descending for bids: Higher price is better
            return Number(b.price - a.price); // Beware of bigint overflow on primitive Number cast if diff is huge, but for sorting -1/0/1 it's "okay" via subtraction if range is safe. Better:
            // if (a.price > b.price) return -1;
            // if (a.price < b.price) return 1;
            // return 0;
        }).sort((a, b) => (a.price > b.price ? -1 : 1));


        // Process Asks (Sell Orders) - Sort by Price Ascending
        const asksMap = new Map<string, OrderbookLevel>();
        sellOrders.forEach(order => {
            const priceKey = order.price.toString();
            if (!asksMap.has(priceKey)) {
                asksMap.set(priceKey, {
                    price: order.price,
                    quantity: 0n,
                    orderCount: 0,
                    total: 0n,
                    orders: []
                });
            }
            const level = asksMap.get(priceKey)!;
            level.quantity += order.quantity;
            level.orderCount += 1;
            level.orders.push(order);
        });

        const sortedAsks = Array.from(asksMap.values()).sort((a, b) => (a.price < b.price ? -1 : 1));

        // Calculate simple stats
        let spread = 0n;
        let midPrice = 0n;

        if (sortedBids.length > 0 && sortedAsks.length > 0) {
            const bestBid = sortedBids[0].price;
            const bestAsk = sortedAsks[0].price;
            spread = bestAsk - bestBid;
            midPrice = (bestAsk + bestBid) / 2n;
        }

        set({
            bids: sortedBids,
            asks: sortedAsks,
            spread,
            midPrice,
            lastUpdated: Date.now(),
            isLoading: false,
            error: null
        });
    },
}));
