import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { TransactionStatus } from '../components/transactions/TransactionStatus';

// Mock hook
vi.mock('../hooks/useTransactions', () => ({
    useTransactionStatus: (hash: string) => {
        if (hash === 'pending') return { isLoading: true, isSuccess: false, isError: false };
        if (hash === 'success') return { isLoading: false, isSuccess: true, isError: false };
        if (hash === 'error') return { isLoading: false, isSuccess: false, isError: true };
        return { isLoading: false, isSuccess: false, isError: false };
    }
}));

// We need to mock useOrders to provide the current hash
vi.mock('../hooks/useOrders', () => ({
    useOrders: () => ({ hash: 'success' }) // Default to success for test
}));

describe('TransactionStatus', () => {
    it('renders success state correctly', () => {
        render(<TransactionStatus />);
        // Based on our mock returning 'success', it should show confirmed
        expect(screen.getByText('Transaction Confirmed')).toBeDefined();
        expect(screen.getByText('Download Receipt')).toBeDefined();
    });
});
