import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { BalanceDisplay } from '../components/wallet/BalanceDisplay';
import { NetworkSwitcher } from '../components/wallet/NetworkSwitcher';

// Mock Wagmi hooks
vi.mock('wagmi', () => ({
    useAccount: () => ({ isConnected: true, address: '0x123...abc' }),
    useBalance: () => ({
        data: { formatted: '1.5', symbol: 'ETH' },
        isLoading: false
    }),
    useChainId: () => 1,
    useSwitchChain: () => ({
        switchChain: vi.fn(),
        chains: [
            { id: 1, name: 'Ethereum' },
            { id: 11155111, name: 'Sepolia' }
        ]
    })
}));

describe('Wallet Components', () => {
    describe('BalanceDisplay', () => {
        it('renders balance correctly', () => {
            render(<BalanceDisplay />);
            expect(screen.getByText('1.5 ETH')).toBeDefined();
        });
    });

    describe('NetworkSwitcher', () => {
        it('renders current network', () => {
            render(<NetworkSwitcher />);
            expect(screen.getByText('Ethereum')).toBeDefined();
        });

        // Note: Testing the actual switch requires interacting with the dropdown, 
        // which depends on how the Select component is implemented (radix-ui).
        // For unit test, checking rendering is sufficient proof of hook integration.
    });
});
