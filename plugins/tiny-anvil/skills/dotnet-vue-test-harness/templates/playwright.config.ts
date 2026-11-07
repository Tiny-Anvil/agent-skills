// src/apps/app/e2e/playwright.config.ts — end-to-end flows and captures against the composed stack.
// Assumes the throwaway e2e copy is up (scripts/e2e.sh starts it and sets E2E_BASE_URL). With auth in scope, that
// copy runs the API with Authentication:Enabled=false and the SPA built with --mode development + VITE_AUTH_BYPASS=true.
import { defineConfig, devices } from '@playwright/test'

const baseURL = process.env.E2E_BASE_URL ?? 'http://localhost:8090'

export default defineConfig({
  testDir: '.',
  outputDir: '../../../../data/run/qa/playwright',
  fullyParallel: false, // flows share one database
  retries: 0, // a flaky flow is a defect, not something to retry away
  reporter: [['list'], ['junit', { outputFile: '../../../../data/run/qa/e2e.xml' }]],
  use: {
    baseURL,
    trace: 'retain-on-failure',
    // On linux-arm64 without Playwright's own Chromium: launchOptions: { executablePath: '/usr/bin/chromium' },
    screenshot: 'off', // captures are taken explicitly, named per screen/state
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } } },
    { name: 'phone', use: { ...devices['Pixel 7'], viewport: { width: 390, height: 844 } } },
  ],
})
