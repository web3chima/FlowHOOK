import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { OrderForm } from '../components/trading/OrderForm';

// Mock dependencies
vi.mock('wagmi', () => ({
    useAccount: () => ({ isConnected: true }),
    useBalance: () => ({ data: { value: 1000000000000000000n } }), // 1 ETH
    useChainId: () => 1
}));

vi.mock('../../hooks/useOrders', () => ({
    useOrders: () => ({
        placeOrder: vi.fn(),
        isPending: false,
        isConfirmed: false,
        error: null
    })
}));

vi.mock('../../stores/orderbookStore', () => ({
    useOrderbookStore: {
        getState: () => ({ midPrice: 2000000000000000000000n }) // 2000
    }
}));

describe('OrderForm', () => {
    it('renders buy/sell toggle', () => {
        render(<OrderForm />);
        expect(screen.getByText('Buy')).toBeDefined();
        expect(screen.getByText('Sell')).toBeDefined();
    });

    it('requires wallet connection', () => {
        vi.mocked(require('wagmi').useAccount).mockReturnValue({ isConnected: false });
        render(<OrderForm />);
        expect(screen.getByText('Connect Wallet to Trade')).toBeDefined();
    });
});
