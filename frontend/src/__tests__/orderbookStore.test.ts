import { describe, it, expect, beforeEach } from 'vitest';
import { useOrderbookStore } from '../stores/orderbookStore';

describe('useOrderbookStore', () => {
    beforeEach(() => {
        useOrderbookStore.getState().setOrders([], []);
    });

    it('should initialize with empty orderbook', () => {
        const { bids, asks, spread, midPrice } = useOrderbookStore.getState();
        expect(bids).toEqual([]);
        expect(asks).toEqual([]);
        expect(spread).toBe(0n);
        expect(midPrice).toBe(0n);
    });

    it('should set orders correctly', () => {
        const { setOrders } = useOrderbookStore.getState();
        const bids = [{ id: '1', price: 100n, quantity: 10n, total: 10n }];
        const asks = [{ id: '2', price: 200n, quantity: 10n, total: 10n }];

        setOrders(bids as any[], asks as any[]);

        const state = useOrderbookStore.getState();
        expect(state.bids).toHaveLength(1);
        expect(state.asks).toHaveLength(1);
        expect(state.bids[0].price).toBe(100n);
        expect(state.asks[0].price).toBe(200n);
    });
});
