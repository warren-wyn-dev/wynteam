// ZOKY install card rules: never when installed, "open in browser" inside a
// frame (WynChat mini app), iOS gets instructions, Android needs the install
// event, and a dismissal waits a week. Storage failures must never throw.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const compiled = ts.transpileModule(readFileSync(new URL("../lib/zoky-pwa.ts", import.meta.url), "utf8"), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const exports = {};
runInNewContext(compiled, { exports, Number, Date });
const { zokyInstallMode, isEmbeddedFrame, isIosDevice, readZokyDismissedAt, writeZokyDismissedAt, ZOKY_INSTALL_COOLDOWN_MS, ZOKY_INSTALL_DISMISS_KEY } = exports;

const now = 1_800_000_000_000;
const base = { standalone: false, embedded: false, ios: false, hasInstallEvent: true, dismissedAt: null, now };

test("installed app never shows the card", () => {
  assert.equal(zokyInstallMode({ ...base, standalone: true }), null);
  assert.equal(zokyInstallMode({ ...base, standalone: true, embedded: true }), null);
});

test("inside a frame it offers the browser, not install", () => {
  assert.equal(zokyInstallMode({ ...base, embedded: true }), "open-browser");
  assert.equal(zokyInstallMode({ ...base, embedded: true, ios: true, hasInstallEvent: false }), "open-browser");
});

test("iOS shows instructions; Android needs the install event", () => {
  assert.equal(zokyInstallMode({ ...base, ios: true, hasInstallEvent: false }), "ios");
  assert.equal(zokyInstallMode(base), "android-prompt");
  assert.equal(zokyInstallMode({ ...base, hasInstallEvent: false }), null);
});

test("dismissal waits seven days, including in a frame", () => {
  const recent = now - ZOKY_INSTALL_COOLDOWN_MS + 1000;
  const old = now - ZOKY_INSTALL_COOLDOWN_MS - 1000;
  assert.equal(zokyInstallMode({ ...base, dismissedAt: recent }), null);
  assert.equal(zokyInstallMode({ ...base, embedded: true, dismissedAt: recent }), null);
  assert.equal(zokyInstallMode({ ...base, dismissedAt: old }), "android-prompt");
});

test("frame detection", () => {
  const self = {};
  assert.equal(isEmbeddedFrame({ top: self, self }), false);
  assert.equal(isEmbeddedFrame({ top: {}, self }), true);
  const blocked = { self: {} };
  Object.defineProperty(blocked, "top", { get() { throw new Error("cross-origin"); } });
  assert.equal(isEmbeddedFrame(blocked), true);
  assert.equal(isEmbeddedFrame(null), false);
});

test("iOS detection includes iPadOS desktop UA", () => {
  assert.equal(isIosDevice("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)", "iPhone", 5), true);
  assert.equal(isIosDevice("Mozilla/5.0 (Macintosh)", "MacIntel", 5), true);
  assert.equal(isIosDevice("Mozilla/5.0 (Macintosh)", "MacIntel", 0), false);
  assert.equal(isIosDevice("Mozilla/5.0 (Linux; Android 14)", "Linux armv8l", 5), false);
});

test("storage helpers survive blocked storage and bad values", () => {
  const boom = { getItem() { throw new Error("blocked"); }, setItem() { throw new Error("blocked"); } };
  assert.equal(readZokyDismissedAt(boom), null);
  assert.doesNotThrow(() => writeZokyDismissedAt(boom, now));
  assert.equal(readZokyDismissedAt({ getItem: () => "abc" }), null);
  assert.equal(readZokyDismissedAt(null), null);
  const map = new Map();
  const storage = { getItem: (k) => map.get(k) ?? null, setItem: (k, v) => map.set(k, v) };
  writeZokyDismissedAt(storage, now);
  assert.equal(map.get(ZOKY_INSTALL_DISMISS_KEY), String(now));
  assert.equal(readZokyDismissedAt(storage), now);
});
