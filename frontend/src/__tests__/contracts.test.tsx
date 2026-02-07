import { describe, it, expect, vi } from 'vitest';
import { renderHook } from '@testing-library/react';
import { useOrderbookContract } from '../hooks/useContract';
import { useTransactionStatus } from '../hooks/useTransactions';

// Mock wagmi
vi.mock('wagmi', () => ({
    useAccount: () => ({ isConnected: true }),
    useChainId: () => 1,
    useWriteContract: () => ({ writeContractAsync: vi.fn(), isPending: false }),
    useReadContract: () => ({ data: null }),
    useWaitForTransactionReceipt: () => ({ isSuccess: true })
}));

describe('Contract Hooks', () => {
    describe('useOrderbookContract', () => {
        it('returns contract instance helpers', () => {
            const { result } = renderHook(() => useOrderbookContract());
            expect(result.current).toBeDefined();
        });
    });

    describe('useTransactionStatus', () => {
        it('initializes with no pending transactions', () => {
            const { result } = renderHook(() => useTransactionStatus(undefined));
            expect(result.current.isLoading).toBe(false);
            expect(result.current.isError).toBe(false);
        });
    });
});
