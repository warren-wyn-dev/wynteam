import { defineConfig, devices } from "@playwright/test";

const remoteBaseURL = process.env.PLAYWRIGHT_BASE_URL?.trim();
const vercelBypassSecret = process.env.VERCEL_AUTOMATION_BYPASS_SECRET?.trim();

export default defineConfig({
  testDir: "./tests/browser",
  // Hosted Preview is wired to production Supabase, not local reference
  // fixtures. These two suites require the local fixture routes/seeded
  // reference accounts and remain mandatory in the Phase 4 local CI job.
  // All other Browser QA still runs against the real deployed preview.
  testIgnore: remoteBaseURL
    ? ["**/content-reference-flow.spec.ts", "**/composer-caption-spacing.spec.ts"]
    : [],
  timeout: 45_000,
  expect: { timeout: 8_000 },
  fullyParallel: false,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? "line" : "list",
  use: {
    baseURL: remoteBaseURL || "http://127.0.0.1:3000",
    trace: "retain-on-failure",
    extraHTTPHeaders: vercelBypassSecret
      ? {
          "x-vercel-protection-bypass": vercelBypassSecret,
          "x-vercel-set-bypass-cookie": "true",
        }
      : undefined,
  },
  webServer: remoteBaseURL
    ? undefined
    : {
        command: "npm run dev -- --hostname 127.0.0.1",
        url: "http://127.0.0.1:3000",
        reuseExistingServer: !process.env.CI,
        timeout: 120_000,
      },
  projects: [
    {
      name: "webkit-iphone",
      use: { ...devices["iPhone 13"], browserName: "webkit" },
    },
    {
      name: "chromium-android",
      use: { ...devices["Pixel 5"], browserName: "chromium" },
    },
    {
      name: "chromium-desktop",
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1440, height: 900 },
      },
    },
  ],
});
