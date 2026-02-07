import { useState } from 'react';
import clsx from 'clsx';
import { PositionsDashboard } from './PositionsDashboard';
import { OrderHistory } from './OrderHistory';

type TabType = 'positions' | 'orders' | 'history';

export const PositionsTabs = () => {
    const [activeTab, setActiveTab] = useState<TabType>('positions');

    const tabs: { id: TabType; label: string }[] = [
        { id: 'positions', label: 'Positions' },
        { id: 'orders', label: 'Orders' },
        { id: 'history', label: 'History' },
    ];

    return (
        <div className="flex flex-col h-full bg-black">
            {/* Tab Headers */}
            <div className="flex-none px-2 py-2 border-b border-zinc-800 bg-zinc-900/30">
                <div className="flex gap-1">
                    {tabs.map((tab) => (
                        <button
                            key={tab.id}
                            onClick={() => setActiveTab(tab.id)}
                            className={clsx(
                                "px-3 py-1.5 text-xs font-bold uppercase tracking-wider rounded-md transition-all",
                                activeTab === tab.id
                                    ? "bg-emerald-500/10 text-emerald-500 border border-emerald-500/30"
                                    : "text-zinc-500 hover:text-zinc-300 hover:bg-zinc-800/50"
                            )}
                        >
                            {tab.label}
                        </button>
                    ))}
                </div>
            </div>

            {/* Tab Content */}
            <div className="flex-1 overflow-auto p-2">
                {activeTab === 'positions' && <PositionsDashboard />}
                {activeTab === 'orders' && <PositionsDashboard />}
                {activeTab === 'history' && <OrderHistory />}
            </div>
        </div>
    );
};
