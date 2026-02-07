import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { PriceDisplay } from '../components/charts/PriceDisplay';
import { MarketOverview } from '../components/charts/MarketOverview';

describe('Price and Market Feeds', () => {
    it('renders PriceDisplay', () => {
        render(<PriceDisplay />);
        expect(screen.getByText('ETH / USDC')).toBeDefined();
    });

    it('renders MarketOverview stats', () => {
        render(<MarketOverview />);
        expect(screen.getByText('Dynamic Fee Rate')).toBeDefined();
        expect(screen.getByText('Effective Volatility')).toBeDefined();
        expect(screen.getByText('Open Interest Ratio')).toBeDefined();
    });
});
