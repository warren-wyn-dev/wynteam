import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const read = (path) => readFile(new URL("../" + path, import.meta.url), "utf8");

test("Food signed-out users stay in the Food auth flow", async () => {
  const source = await read("components/food/wynos-food-developer-app.tsx");
  assert.match(source, /DeveloperRouteGate signedOutPath="\/food\/login" afterSignOutPath="\/food\/login"/);
  assert.match(source, /onSignOut=\{\(\) => void signOut\(\)\}/);
  assert.match(source, /href="https:\/\/wynos\.online\/login"/);
  assert.match(source, /href="https:\/\/wynos\.online\/" aria-label="ออกจาก WYNOS Food"/);
});

test("Food signup creates only the central auth account", async () => {
  const source = await read("components/food/food-auth.tsx");
  assert.match(source, /signUpWithEmail\(client, normalized, password, "\/food"\)/);
  assert.doesNotMatch(source, /\bsetUsername\s*\(/);
  assert.doesNotMatch(source, /\bsetDisplayName\s*\(/);
  assert.doesNotMatch(source, /\bsetDateOfBirth\s*\(/);
  assert.doesNotMatch(source, /\bcompleteOnboarding\s*\(/);
  assert.doesNotMatch(source, /@wynos_s/);
});

test("email confirmation only honors a safe internal destination", async () => {
  const repository = await read("lib/auth-repository.ts");
  const callback = await read("app/auth/callback/page.tsx");
  assert.match(repository, /getEmailConfirmationRedirectUrl\(nextPath\?: string\)/);
  assert.match(repository, /url\.searchParams\.set\("next", nextPath\)/);
  assert.match(callback, /isSafeReturnPath\(requestedNext\)/);
  assert.match(callback, /: "\/signup\/step-1"/);
});

test("Food auth routes are separate from Social onboarding", async () => {
  const login = await read("app/food/login/page.tsx");
  const signup = await read("app/food/signup/page.tsx");
  assert.match(login, /FoodLoginScreen/);
  assert.match(signup, /FoodSignupScreen/);
  assert.doesNotMatch(login + signup, /signup\/step-1|onboarding\/profile/);
});

test("Food menu card photos stay square at every responsive width", async () => {
  const css = await read("app/food/food.css");
  assert.match(css, /\.wf-menu-image\s*\{[\s\S]*?width:\s*100%;[\s\S]*?height:\s*auto;[\s\S]*?aspect-ratio:\s*1\s*\/\s*1;/);
  assert.doesNotMatch(css, /\.wf-menu-image\s*\{\s*height:\s*(?:120|170)px;/);
});
