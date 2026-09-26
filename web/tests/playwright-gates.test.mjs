import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { test } from "node:test";
import ts from "typescript";

const CONFIG = new URL("../playwright.config.ts", import.meta.url);
const fixtureOnly = [
  "content-reference-flow",
  "composer-caption-spacing",
  "wynos-food-customer-demo",
  "composer-handle-drag",
  "composer-middle-swipe",
  "composer-popup-height",
  "composer-slide-dismiss",
];

function evaluateConfig(baseUrl) {
  const { outputText } = ts.transpileModule(readFileSync(CONFIG, "utf8"), {
    fileName: "playwright.config.ts",
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
  });
  const exports = {};
  runInNewContext(outputText, {
    exports,
    require: (id) => {
      if (id === "@playwright/test") {
        return {
          defineConfig: (value) => value,
          devices: {
            "iPhone 13": {},
            "Pixel 5": {},
            "Desktop Chrome": {},
          },
        };
      }
      throw new Error("Unexpected dependency: " + id);
    },
    process: { env: baseUrl ? { PLAYWRIGHT_BASE_URL: baseUrl } : {} },
  });
  return exports.default;
}

test("fixture-only composer suites remain mandatory in local CI", () => {
  const config = evaluateConfig(null);
  assert.deepEqual(Array.from(config.testIgnore), []);
  assert.ok(config.webServer, "local CI must launch its local Next.js test server");
});

test("hosted QA excludes only fake-client fixture suites, not real route tests", () => {
  const config = evaluateConfig("https://preview.example.test");
  assert.equal(config.webServer, undefined);
  const actual = Array.from(config.testIgnore, (entry) => String(entry).replace(/^.*\//, "").replace(/\.spec\.ts$/, "")).sort();
  assert.deepEqual(actual, fixtureOnly.slice().sort());
  assert.ok(!config.testIgnore.some((entry) => /native-push|native-navigation|pwa-install|viewport-accessibility|phase4/.test(entry)));
});
