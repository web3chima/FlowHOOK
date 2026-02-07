import { describe, it, expect } from 'vitest';

describe('Frontend Setup', () => {
    it('should have correct environment variables', () => {
        expect(import.meta.env.VITE_WALLET_CONNECT_PROJECT_ID).toBeDefined();
    });
});
