import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { AdminDashboard } from '../components/admin/AdminDashboard';
import '@testing-library/jest-dom';

// Simple Mocks
vi.mock('../hooks/useAdmin', () => ({
    useAdmin: () => ({ isAdmin: true, isLoading: false })
}));

vi.mock('wagmi', () => ({
    useAccount: () => ({ isConnected: true }),
    useChainId: () => 1,
    useReadContract: () => ({ data: null }),
    useWriteContract: () => ({ writeContract: vi.fn(), isPending: false }),
    useWaitForTransactionReceipt: () => ({ isLoading: false, isSuccess: false })
}));

// Mock child components to avoid complex sub-renders
vi.mock('../components/admin/SystemHealth', () => ({
    SystemHealth: () => <div data-testid="system-health">System Health</div>
}));
vi.mock('../components/admin/ParameterEditor', () => ({
    ParameterEditor: () => <div data-testid="parameter-editor">Parameter Editor</div>
}));
vi.mock('../components/admin/EmergencyControls', () => ({
    EmergencyControls: () => <div data-testid="emergency-controls">Emergency Controls</div>
}));

describe('AdminDashboard', () => {
    it('renders dashboard when user is admin', () => {
        render(<AdminDashboard />);
        expect(screen.getByText('Admin Dashboard')).toBeInTheDocument();
        expect(screen.getByTestId('system-health')).toBeInTheDocument();
    });
});
