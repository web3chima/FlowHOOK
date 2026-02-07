import { Activity, Database, Clock, Server } from 'lucide-react';

export const SystemHealth = () => {

    const utilization = "45.2%";
    const oracleStatus = "Optimistic";
    const totalVolume = "$1.2M";

    return (
        <div className="p-6 bg-slate-900 rounded-xl border border-slate-700">
            <h3 className="text-lg font-bold text-slate-200 mb-6 flex items-center gap-2">
                <Activity className="w-5 h-5 text-blue-400" /> System Health
            </h3>

            <div className="grid grid-cols-2 gap-4">
                <div className="p-3 bg-slate-950 rounded border border-slate-800">
                    <span className="text-xs text-slate-500 mb-1 block flex items-center gap-1">
                        <Database className="w-3 h-3" /> Utilization
                    </span>
                    <span className="text-xl font-mono text-emerald-400">{utilization}</span>
                </div>

                <div className="p-3 bg-slate-950 rounded border border-slate-800">
                    <span className="text-xs text-slate-500 mb-1 block flex items-center gap-1">
                        <Server className="w-3 h-3" /> Oracle
                    </span>
                    <span className="text-xl font-mono text-blue-400">{oracleStatus}</span>
                </div>

                <div className="p-3 bg-slate-950 rounded border border-slate-800">
                    <span className="text-xs text-slate-500 mb-1 block flex items-center gap-1">
                        <Clock className="w-3 h-3" /> Latency
                    </span>
                    <span className="text-xl font-mono text-slate-200">140ms</span>
                </div>

                <div className="p-3 bg-slate-950 rounded border border-slate-800">
                    <span className="text-xs text-slate-500 mb-1 block flex items-center gap-1">
                        <Activity className="w-3 h-3" /> Volume (24h)
                    </span>
                    <span className="text-xl font-mono text-purple-400">{totalVolume}</span>
                </div>
            </div>

            <div className="mt-4 p-3 bg-blue-500/10 border border-blue-500/20 rounded text-xs text-blue-300">
                System operating normally. All circuits functional.
            </div>
        </div>
    );
};
