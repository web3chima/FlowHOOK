import { ExternalLink, History } from 'lucide-react';
import { useAdminHistory } from '../../hooks/useAdminHistory';

export const AdminActionHistory = () => {
    const { events, isLoading } = useAdminHistory();

    const getExplorerLink = (hash: string) => `https://sepolia.etherscan.io/tx/${hash}`;

    if (isLoading) {
        return (
            <div className="p-6 bg-slate-900 rounded-xl border border-slate-800 flex justify-center py-8">
                <div className="animate-spin h-5 w-5 border-2 border-blue-500 rounded-full border-t-transparent"></div>
            </div>
        );
    }

    return (
        <div className="p-6 bg-slate-900 rounded-xl border border-slate-800">
            <h3 className="text-lg font-bold text-slate-200 mb-4 flex items-center gap-2">
                <History className="w-5 h-5 text-blue-400" />
                Admin Action History
            </h3>

            <div className="space-y-3">
                {events.length === 0 ? (
                    <div className="text-center py-4 text-slate-500 text-sm">
                        No admin actions recorded recently
                    </div>
                ) : (
                    events.map((event) => (
                        <div key={event.hash} className="flex items-center justify-between p-3 bg-slate-950 rounded border border-slate-800 hover:border-slate-700 transition-colors">
                            <div className="flex flex-col">
                                <span className="text-sm font-medium text-slate-200">{event.name}</span>
                                <span className="text-xs text-slate-400">{event.details}</span>
                            </div>
                            <a
                                href={getExplorerLink(event.hash)}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="flex items-center gap-1 text-xs text-blue-400 hover:text-blue-300 ml-4 shrink-0"
                            >
                                View <ExternalLink className="w-3 h-3" />
                            </a>
                        </div>
                    ))
                )}
            </div>
        </div>
    );
};
