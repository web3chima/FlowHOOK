import { useState } from 'react';
import { BookOpen, ArrowLeftRight, Wallet, Activity } from 'lucide-react';
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

// We will pass specific slots for each tab content
interface MobileTabsProps {
    marketSlot: React.ReactNode;
    bookSlot: React.ReactNode;
    tradeSlot: React.ReactNode;
    portfolioSlot: React.ReactNode;
}

export const MobileLayout = ({ marketSlot, bookSlot, tradeSlot, portfolioSlot }: MobileTabsProps) => {
    const [activeTab, setActiveTab] = useState<'market' | 'book' | 'trade' | 'portfolio'>('trade');

    return (
        <div className="flex flex-col h-[calc(100vh-64px)] bg-slate-950">
            {/* Content Area - Scrollable */}
            <div className="flex-1 overflow-y-auto overflow-x-hidden pb-24 px-2 pt-2">
                <div className={clsx("h-full", activeTab === 'market' ? 'block' : 'hidden')}>
                    {marketSlot}
                </div>
                <div className={clsx("h-full", activeTab === 'book' ? 'block' : 'hidden')}>
                    {bookSlot}
                </div>
                <div className={clsx("h-full", activeTab === 'trade' ? 'block' : 'hidden')}>
                    {tradeSlot}
                </div>
                <div className={clsx("h-full", activeTab === 'portfolio' ? 'block' : 'hidden')}>
                    {portfolioSlot}
                </div>
            </div>

            {/* Bottom Navigation */}
            <div className="fixed bottom-0 left-0 right-0 bg-slate-900 border-t border-slate-800 h-16 flex items-center justify-around z-50 px-2 safe-area-pb">
                <NavButton
                    active={activeTab === 'market'}
                    onClick={() => setActiveTab('market')}
                    icon={<Activity size={20} />}
                    label="Market"
                />
                <NavButton
                    active={activeTab === 'book'}
                    onClick={() => setActiveTab('book')}
                    icon={<BookOpen size={20} />}
                    label="Book"
                />
                <NavButton
                    active={activeTab === 'trade'}
                    onClick={() => setActiveTab('trade')}
                    icon={<ArrowLeftRight size={20} />}
                    label="Trade"
                />
                <NavButton
                    active={activeTab === 'portfolio'}
                    onClick={() => setActiveTab('portfolio')}
                    icon={<Wallet size={20} />}
                    label="Portfolio"
                />
            </div>
        </div>
    );
};

const NavButton = ({ active, onClick, icon, label }: { active: boolean, onClick: () => void, icon: React.ReactNode, label: string }) => (
    <button
        onClick={onClick}
        className={twMerge(
            "flex flex-col items-center justify-center w-full h-full gap-1 transition-colors duration-200",
            active ? "text-blue-500" : "text-slate-500 hover:text-slate-400"
        )}
    >
        {icon}
        <span className="text-[10px] font-medium tracking-wide uppercase">{label}</span>
    </button>
);
