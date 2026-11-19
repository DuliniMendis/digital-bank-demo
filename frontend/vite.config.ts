import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [react()],

  // In development the page and the Ruby API run as two separate servers.
  // Passing /api through to the API lets the page call `/api/accounts` the
  // same way it does once both are deployed together. The API is expected on
  // port 9292 unless API_URL says otherwise, which the end-to-end tests use.
  server: {
    proxy: { '/api': process.env.API_URL ?? 'http://localhost:9292' },
  },

  // The tests need a browser-like `document`, which jsdom provides.
  test: {
    // Only the tests in src/. The ones in e2e/ belong to Playwright.
    include: ['src/**/*.test.tsx'],
    environment: 'jsdom',
    setupFiles: './src/test-setup.ts',
  },
})
