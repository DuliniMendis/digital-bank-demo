import { defineConfig } from '@playwright/test'

// The end-to-end tests run the real page against the real API and a real
// Postgres database. Playwright starts both servers before the first test
// and stops them after the last.
//
// The servers get ports of their own, so they never clash with, or talk to,
// servers that are already running for development.
const API_URL = 'http://localhost:9494'
const PAGE_URL = 'http://localhost:5174'

// A database kept for these tests alone. Every test resets it, so it must
// never be one that holds anything worth keeping.
const DATABASE_URL = process.env.E2E_DATABASE_URL ?? 'postgres://localhost/bank_e2e'

export default defineConfig({
  testDir: './e2e',

  // The tests share one database, so they run one at a time.
  workers: 1,

  use: { baseURL: PAGE_URL },

  webServer: [
    {
      command: 'bundle exec rackup --port 9494',
      cwd: '../backend',
      env: { DATABASE_URL },
      url: `${API_URL}/api/accounts`,
      reuseExistingServer: false,
    },
    {
      // API_URL tells the development server where to pass /api requests.
      command: 'npm run dev -- --port 5174 --strictPort',
      env: { API_URL },
      url: PAGE_URL,
      reuseExistingServer: false,
    },
  ],
})
