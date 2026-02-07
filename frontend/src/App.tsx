import { WalletConnect } from './components/wallet/WalletConnect';
import { NetworkSwitcher } from './components/wallet/NetworkSwitcher';
import { BalanceDisplay } from './components/wallet/BalanceDisplay';
import { OrderbookView } from './components/orderbook/OrderbookView';
import { OrderForm } from './components/trading/OrderForm';
import { MarketOverview } from './components/charts/MarketOverview';
import { PositionsDashboard } from './components/positions/PositionsDashboard';
import { PriceDisplay } from './components/charts/PriceDisplay';
import { TransactionStatus } from './components/transactions/TransactionStatus';
import { ErrorBoundary } from './components/common/ErrorBoundary';
import { BalanceBreakdown } from './components/positions/BalanceBreakdown';
import { OrderHistory } from './components/positions/OrderHistory';
import { PositionsTabs } from './components/positions/PositionsTabs';
import { AdminDashboard } from './components/admin/AdminDashboard';
import { VAMMDashboard } from './components/vamm/VAMMDashboard';
import { OraclePriceView } from './components/oracle/OraclePriceView';
import { OraclePriceTicker } from './components/oracle/OraclePriceTicker';
import { useCurveMode, CurveMode } from './hooks/useCurveMode';
import { Suspense, lazy, useState } from 'react';
import { Loader2, LayoutDashboard, LineChart } from 'lucide-react';
import { MobileTradeLayout } from './components/layout/MobileTradeLayout';
import { DesktopPerpLayout } from './components/layout/DesktopPerpLayout';
const DepthChart = lazy(() => import('./components/orderbook/DepthChart').then(module => ({ default: module.DepthChart })));
const PriceChart = lazy(() => import('./components/charts/PriceChart').then(module => ({ default: module.PriceChart })));

function App() {
  const [currentView, setCurrentView] = useState<'trade' | 'admin'>('trade');
  const { mode } = useCurveMode();

  // Shared Header Content
  const HeaderContent = (
    <div className="flex items-center justify-between px-4 h-full bg-black relative z-50">
      <div className="flex items-center gap-6">
        {/* Text Logo */}
        <h1 className="text-xl font-bold text-white tracking-widest uppercase font-mono italic cursor-pointer" onClick={() => setCurrentView('trade')}>
          FLOWHOOK
        </h1>

        {/* Navigation */}
        <nav className="flex items-center gap-1 bg-zinc-900/50 p-1 rounded-lg border border-zinc-800">
          <button
            onClick={() => setCurrentView('trade')}
            className={`flex items-center gap-2 px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${currentView === 'trade' ? 'bg-zinc-800 text-white' : 'text-zinc-500 hover:text-zinc-300'}`}
          >
            <LineChart className="w-3 h-3" />
            Trade
          </button>
          <button
            onClick={() => setCurrentView('admin')}
            className={`flex items-center gap-2 px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${currentView === 'admin' ? 'bg-zinc-800 text-white' : 'text-zinc-500 hover:text-zinc-300'}`}
          >
            <LayoutDashboard className="w-3 h-3" />
            Admin
          </button>
        </nav>
      </div>
      <div className="flex items-center gap-2 lg:gap-4 shrink-0">
        <div className="hidden md:block">
          <OraclePriceTicker />
        </div>
        <div className="hidden lg:block">
          <BalanceDisplay />
        </div>
        <NetworkSwitcher />
        <WalletConnect />
      </div>
    </div>
  );

  // Admin View
  if (currentView === 'admin') {
    return (
      <div className="bg-black min-h-screen w-screen text-zinc-200 font-sans selection:bg-zinc-800 selection:text-white overflow-x-hidden flex flex-col">
        <div className="h-16 shrink-0 border-b border-zinc-800">
          {HeaderContent}
        </div>
        <div className="flex-1 overflow-auto">
          <AdminDashboard />
        </div>
      </div>
    );
  }

  // Trade View Components
  const MainContent = () => {
    // Dynamic Middle Panel Content

    let centerView = <OrderbookView />;
    let centerTitle = "Orderbook";

    if (mode === CurveMode.VAMM) {
      centerView = <VAMMDashboard />;
      centerTitle = "Liquidity Pool (VAMM)";
    } else if (mode === CurveMode.HYBRID) {
      centerView = (
        <div className="h-full flex flex-col">
          <div className="flex-1 overflow-hidden">
            <OrderbookView />
          </div>
          {/* In Hybrid, we might show a small pool indicator or just orderbook with depth from both */}
          <div className="p-2 bg-zinc-900 border-t border-zinc-800 text-xs text-center text-emerald-500">
            Hybrid Mode Active: AMM Liquidity Backstop Enabled
          </div>
        </div>
      );
      centerTitle = "Hybrid (Orderbook + AMM)";
    } else if (mode === CurveMode.ORACLE) {
      centerView = <OraclePriceView />;
      centerTitle = "Oracle Feed";
    }

    return (
      <>
        {/* Mobile Layout (Visible up to XL - 1280px) */}
        <div className="xl:hidden">
          <MobileTradeLayout
            header={HeaderContent}
            chart={
              <div className="h-full w-full bg-black relative">
                <Suspense fallback={<div className="absolute inset-0 flex items-center justify-center"><Loader2 className="animate-spin text-zinc-600" /></div>}>
                  <PriceChart />
                </Suspense>
                <div className="absolute top-4 left-4">
                  <PriceDisplay />
                </div>
              </div>
            }
            orderbook={
              <div className="min-h-[300px]">
                {centerView}
              </div>
            }
            history={
              <div className="space-y-4">
                <PositionsDashboard />
                <OrderHistory />
              </div>
            }
            orderForm={
              <div className="space-y-4">
                <BalanceBreakdown />
                <OrderForm />
              </div>
            }
          />
        </div>

        {/* Desktop Layout (Visible 1280px+) */}
        <div className="hidden xl:block w-full h-screen">
          <DesktopPerpLayout
            header={HeaderContent}
            leftPanel={
              <div className="flex flex-col h-full">
                {/* Top: Chart */}
                <div className="flex-[3] border-b border-zinc-800 relative bg-black overflow-hidden">
                  <div className="absolute top-0 left-0 right-0 p-2 z-10 flex gap-4 bg-black/80 backdrop-blur-sm border-b border-zinc-800/50 pointer-events-none">
                    <div className="pointer-events-auto flex items-center gap-4">
                      <PriceDisplay />
                      <MarketOverview />
                    </div>
                  </div>
                  <Suspense fallback={<div className="h-full flex items-center justify-center"><Loader2 className="animate-spin text-zinc-600" /></div>}>
                    <PriceChart />
                  </Suspense>
                </div>
                {/* Bottom: Positions/Orders/History Tabs */}
                <div className="flex-[2] bg-black overflow-hidden">
                  <PositionsTabs />
                </div>
              </div>
            }
            middlePanel={
              <div className="h-full flex flex-col">
                <div className="flex-none p-2 border-b border-zinc-800">
                  <h3 className="text-xs font-mono text-zinc-500 uppercase">{centerTitle}</h3>
                </div>
                <div className="flex-1 overflow-y-auto relative min-h-0"> {/* Changed overflow-hidden to overflow-y-auto */}
                  {centerView}
                </div>
                <div className="h-[200px] shrink-0 border-t border-zinc-800">
                  <DepthChart />
                </div>
              </div>
            }
            rightPanel={
              <div className="h-full overflow-y-auto p-3 flex flex-col gap-4">
                <div className="p-3 bg-zinc-900/30 rounded border border-zinc-800 shrink-0">
                  <BalanceBreakdown />
                </div>
                <div className="flex-1 min-h-0">
                  <OrderForm />
                </div>
                <div className="pt-4 border-t border-zinc-800 shrink-0">
                  <TransactionStatus />
                </div>
              </div>
            }
          />
        </div>
      </>
    );
  };

  return (
    <div className="bg-black min-h-screen w-screen text-zinc-200 font-sans selection:bg-zinc-800 selection:text-white overflow-x-hidden">
      <ErrorBoundary>
        <MainContent />
      </ErrorBoundary>
    </div>
  );
}

export default App;
