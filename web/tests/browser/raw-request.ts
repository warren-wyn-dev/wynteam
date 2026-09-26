import { test as base, type APIRequestContext } from "@playwright/test";

// Hosted staging QA sends `x-vercel-set-bypass-cookie`, which makes Vercel
// answer the first request with its own cookie-setting 307. Specs that assert
// the app's raw status codes and headers (maxRedirects: 0) use this context,
// which sends only the per-request protection bypass.
export const test = base.extend<{ rawRequest: APIRequestContext }>({
  rawRequest: async ({ playwright, baseURL }, provide) => {
    const secret = process.env.VERCEL_AUTOMATION_BYPASS_SECRET?.trim();
    const context = await playwright.request.newContext({
      baseURL,
      extraHTTPHeaders: secret ? { "x-vercel-protection-bypass": secret } : undefined,
    });
    await provide(context);
    await context.dispose();
  },
});
export { expect } from "@playwright/test";
