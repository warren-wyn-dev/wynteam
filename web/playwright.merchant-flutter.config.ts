import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/merchant-browser",
  testMatch: ["merchant-flutter-embedded.spec.ts", "merchant-flutter-render.spec.ts", "food-fulfillment.spec.ts"],
  timeout: 45_000,
  fullyParallel: false,
  workers: 1,
  reporter: "list",
  use: {
    baseURL: "http://127.0.0.1:3011",
    locale: "th-TH",
    trace: "retain-on-failure",
    launchOptions: {
      ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE } : {}),
      ...(process.env.HTTPS_PROXY ? { proxy: { server: process.env.HTTPS_PROXY, bypass: "127.0.0.1,localhost" } } : {}),
    },
  },
  projects: [
    { name: "merchant-chromium-mobile", use: { ...devices["Pixel 5"], browserName: "chromium" } },
    { name: "merchant-chromium-desktop", use: { ...devices["Desktop Chrome"], browserName: "chromium" } },
  ],
  webServer: {
    command: "npm run dev -- --hostname 127.0.0.1 --port 3011",
    url: "http://127.0.0.1:3011",
    reuseExistingServer: process.env.ZOKY_FIXTURE_REUSE_SERVER === '1',
    timeout: 120_000,
    env: {
      NEXT_PUBLIC_SUPABASE_URL: "https://merchant-fixture.example.test",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_browser_fixture_only",
    },
  },
});
