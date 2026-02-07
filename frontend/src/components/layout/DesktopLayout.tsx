import type { ReactNode } from 'react';

interface DesktopLayoutProps {
    leftColumn: ReactNode;   // Orderbook
    centerTop: ReactNode;    // Charts
    centerBottom: ReactNode; // History/Tables
    rightColumn: ReactNode;  // OrderForm/Assets
}

export const DesktopLayout = ({ leftColumn, centerTop, centerBottom, rightColumn }: DesktopLayoutProps) => {
    return (
        <div className="hidden lg:grid grid-cols-12 gap-3 p-3 h-[calc(100vh-64px)] bg-slate-950 overflow-hidden">
            {/* Col 1: Orderbook (Fixed Width) */}
            <div className="col-span-3 flex flex-col gap-1 bg-slate-900/50 border border-slate-800/50 rounded-md overflow-hidden shadow-sm">
                <div className="flex-1 overflow-hidden flex flex-col">
                    {leftColumn}
                </div>
            </div>

            {/* Col 2: Visualization & Data */}
            <div className="col-span-6 flex flex-col gap-1">
                {/* Top: Charts (60% height) */}
                <div className="flex-[3] bg-slate-900/50 border border-slate-800/50 rounded-sm overflow-hidden relative">
                    {centerTop}
                </div>
                {/* Bottom: History (40% height) */}
                <div className="flex-[2] bg-slate-900/50 border border-slate-800/50 rounded-sm overflow-hidden flex flex-col">
                    {centerBottom}
                </div>
            </div>

            {/* Col 3: Action */}
            <div className="col-span-3 flex flex-col gap-1 bg-slate-900/50 border border-slate-800/50 rounded-sm overflow-hidden">
                <div className="h-full overflow-y-auto">
                    {rightColumn}
                </div>
            </div>
        </div>
    );
};
