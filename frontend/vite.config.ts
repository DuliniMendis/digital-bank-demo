import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [react()],

  // In development the page and the Ruby API run as two separate servers.
  // Passing /api through to the API lets the page call `/api/accounts` the
  // same way it does once both are deployed together.
  server: {
    proxy: { '/api': 'http://localhost:9292' },
  },

  // The tests need a browser-like `document`, which jsdom provides.
  test: {
    environment: 'jsdom',
    setupFiles: './src/test-setup.ts',
  },
})
