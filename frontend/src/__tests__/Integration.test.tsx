import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { OrderForm } from '../components/trading/OrderForm';
import { PositionsDashboard } from '../components/positions/PositionsDashboard';

// Mock all necessary hooks
vi.mock('wagmi', () => ({
    useAccount: () => ({ isConnected: true, address: '0x123' }),
    useBalance: () => ({ data: { value: 1000000000000000000n, formatted: '1.0' } }),
    useChainId: () => 1
}));

vi.mock('../hooks/useOrders', () => ({
    useOrders: () => ({
        placeOrder: vi.fn(),
        isPending: false,
        error: null,
        hash: '0xabc'
    })
}));

vi.mock('../hooks/usePositions', () => ({
    usePositions: () => ({
        positions: [
            { id: '1', side: 'buy', originalAmount: 1000000000000000000n, remainingAmount: 1000000000000000000n, price: 2000000000000000000000n, orderId: 1n }
        ],
        cancelOrder: vi.fn()
    })
}));

vi.mock('../stores/orderbookStore', () => ({
    useOrderbookStore: {
        getState: () => ({ midPrice: 2000000000000000000000n })
    }
}));

describe('Trading Flow Integration', () => {
    it('allows user to see form and active positions', () => {
        // Render OrderForm
        const { unmount: unmountForm } = render(<OrderForm />);
        expect(screen.getByText('Limit Order')).toBeDefined();
        expect(screen.getByPlaceholderText('0.00')).toBeDefined();
        unmountForm();

        // Render Positions
        render(<PositionsDashboard />);
        expect(screen.getByText('Active Orders')).toBeDefined();
        // Check if the mocked position is rendered (Amount: 1.0 ETH)
        // Note: The exact text depends on formatting components, checking for side/amount roughly
        expect(screen.getByText(/buy/i)).toBeDefined();
    });
});
