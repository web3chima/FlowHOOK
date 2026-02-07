import type { ReactNode } from 'react';

interface DesktopPerpLayoutProps {
    header: ReactNode;
    leftPanel: ReactNode;   // Chart + Positions
    middlePanel: ReactNode; // Orderbook
    rightPanel: ReactNode;  // Trade Form
}

import { ResizableLayout } from './ResizableLayout';

interface DesktopPerpLayoutProps {
    header: ReactNode;
    leftPanel: ReactNode;   // Chart + Positions
    middlePanel: ReactNode; // Orderbook
    rightPanel: ReactNode;  // Trade Form
}

export const DesktopPerpLayout = ({ header, leftPanel, middlePanel, rightPanel }: DesktopPerpLayoutProps) => {
    return (
        <div className="w-screen h-screen flex flex-col bg-black text-zinc-200 overflow-hidden">
            {/* Header - Fixed Height */}
            <header className="h-14 w-full shrink-0 border-b border-zinc-800 bg-black">
                {header}
            </header>

            {/* Main Content - Resizable */}
            <main className="flex-1 w-full min-h-0 relative">
                <ResizableLayout
                    leftPanel={
                        <section className="h-full flex flex-col overflow-hidden border-r border-zinc-800">
                            {leftPanel}
                        </section>
                    }
                    middlePanel={
                        <section className="h-full flex flex-col overflow-hidden border-r border-zinc-800 bg-black">
                            {middlePanel}
                        </section>
                    }
                    rightPanel={
                        <section className="h-full flex flex-col overflow-hidden bg-black">
                            {rightPanel}
                        </section>
                    }
                    initialLeftWidth={55} // Chart gets most space
                    initialRightWidth={20} // Trade form gets standardized width
                />
            </main>
        </div>
    );
};
