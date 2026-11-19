import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [react()],

  // In development the page is served by Vite on port 5173 and the Ruby API
  // runs on port 9292. Passing /api through to the API lets the page call
  // `/api/accounts` the same way it does once both are deployed together.
  server: {
    proxy: { '/api': 'http://localhost:9292' },
  },

  // The tests need a browser-like `document`, which jsdom provides.
  test: {
    environment: 'jsdom',
    setupFiles: './src/test-setup.ts',
  },
})
