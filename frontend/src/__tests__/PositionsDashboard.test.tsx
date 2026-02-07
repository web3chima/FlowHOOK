import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { PositionsDashboard } from '../components/positions/PositionsDashboard';

vi.mock('../../hooks/usePositions', () => ({
    usePositions: () => ({
        positions: [
            { id: '1', side: 'buy', originalAmount: 1000000000000000000n, remainingAmount: 500000000000000000n, price: 2000000000000000000000n, orderId: 1n }
        ],
        cancelOrder: vi.fn(),
        isPending: false
    })
}));

describe('PositionsDashboard', () => {
    it('renders active orders', () => {
        render(<PositionsDashboard />);
        expect(screen.getByText('Active Orders')).toBeDefined();
        // Since formatting might vary, we check for presence of list items
        expect(screen.getAllByRole('listitem')).toHaveLength(1);
    });
});
