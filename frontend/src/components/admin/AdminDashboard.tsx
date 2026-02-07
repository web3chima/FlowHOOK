import { useAdmin } from '../../hooks/useAdmin';
import { useAccount } from 'wagmi';
import { Loader2, ShieldAlert } from 'lucide-react';

import { SystemHealth } from './SystemHealth';
import { AdminActionHistory } from './AdminActionHistory';
import { ParameterEditor } from './ParameterEditor';
import { EmergencyControls } from './EmergencyControls';
import { ModelSelector } from './ModelSelector';

export const AdminDashboard = () => {
    const { isAdmin, isLoading } = useAdmin();
    const { isConnected } = useAccount();

    if (!isConnected) {
        return (
            <div className="flex flex-col items-center justify-center min-h-[50vh] text-slate-500">
                <ShieldAlert className="w-16 h-16 mb-4 text-slate-700" />
                <p>Connect wallet to access Admin Dashboard</p>
            </div>
        );
    }

    if (isLoading) {
        return (
            <div className="flex items-center justify-center min-h-[50vh]">
                <Loader2 className="w-8 h-8 text-blue-500 animate-spin" />
            </div>
        );
    }

    if (!isAdmin) {
        return (
            <div className="flex flex-col items-center justify-center min-h-[50vh] text-red-400">
                <ShieldAlert className="w-16 h-16 mb-4" />
                <h2 className="text-2xl font-bold mb-2">Access Denied</h2>
                <p className="text-slate-500">Your address does not have admin privileges.</p>
            </div>
        );
    }

    return (
        <div className="container mx-auto p-6">
            <header className="mb-8">
                <h1 className="text-3xl font-bold text-white mb-2">Admin Dashboard</h1>
                <p className="text-slate-400">System management and monitoring</p>
            </header>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Model Selector - Full Width */}
                <ModelSelector />

                {/* Left Column */}
                <div className="col-span-1 lg:col-span-1 space-y-6">
                    <SystemHealth />
                    <AdminActionHistory />
                </div>

                {/* Middle Column */}
                <ParameterEditor />

                {/* Right Column */}
                <EmergencyControls />
            </div>
        </div>
    );
};
