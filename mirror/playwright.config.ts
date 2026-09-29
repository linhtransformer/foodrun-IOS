import { defineConfig, devices } from '@playwright/test';

// Foodrun iOS mirror — Playwright config.
// The mirror renders inside a 402x874pt iPhone frame (per bundle README);
// we run against iPhone 15 Pro viewport to match.

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: true,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
  use: {
    baseURL: 'http://127.0.0.1:4321',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  webServer: {
    command: 'npx http-server . -p 4321 -c-1 -s',
    url: 'http://127.0.0.1:4321/index.html',
    reuseExistingServer: !process.env.CI,
    timeout: 20_000,
  },
  projects: [
    {
      name: 'iphone-15-pro',
      use: { ...devices['iPhone 15 Pro'] },
    },
  ],
});
