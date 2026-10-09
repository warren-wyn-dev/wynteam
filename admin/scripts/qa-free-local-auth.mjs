#!/usr/bin/env node
/**
 * No hosted Supabase, Vercel or Production requests are authorized here.
 * Only synthetic accounts on a loopback Supabase CLI stack.
 * Requires Playwright installed in the ephemeral, standard GitHub runner.
 */
import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";
import { createClient } from "@supabase/supabase-js";
import { chromium } from "playwright";

const stackDir = process.env.WYNOS_LOCAL_STACK_DIR;
if (!stackDir || !process.env.GITHUB_ACTIONS || !process.env.CI) {
  throw new Error("Local-only GitHub CI runner required");
}

const output = execFileSync("supabase", ["status", "-o", "env"], {
  cwd: stackDir,
  encoding: "utf8",
  maxBuffer: 1_000_000,
});
const values = Object.fromEntries(output.split(/\r?\n/).flatMap((line) => {
  const m = line.trim().match(/^(?:export )?([A-Z_]+)=(.*)$/);
  return m ? [[m[1], m[2].replace(/^["']|["']$/g, "")]] : [];
}));
const url = values.API_URL;
const publishable = values.ANON_KEY;
const service = values.SERVICE_ROLE_KEY;
assert.ok(publishable && service && publishable !== service, "Missing distinct synthetic local keys");
const local = new URL(url);
assert.ok(local.protocol === "http:" && ["localhost", "127.0.0.1", "::1"].includes(local.hostname),
  "Remote Supabase is forbidden");
assert.equal(local.port, "54321", "Only the expected isolated local Supabase port is allowed");

// No real user email, password or content. This account data lives only in
// ephemeral runner containers. Use a unique synthetic password per execution.
const password = "LocalOnly!" + "E2E29QA" + Date.now().toString(36);
const people = [
  { role: "admin", email: "qa-admin@example.test", username: "qa_admin_e2e" },
  { role: "moderator", email: "qa-moderator@example.test", username: "qa_mod_e2e" },
  { role: "user", email: "qa-user@example.test", username: "qa_user_e2e" },
];
const supabase = createClient(url, service, {
  auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
});
for (const person of people) {
  const { data, error } = await supabase.auth.admin.createUser({
    email: person.email,
    password,
    email_confirm: true,
  });
  assert.ifError(error);
  assert.ok(data.user?.id);
  const insert = await supabase.from("profiles").insert({
    id: data.user.id, username: person.username,
    display_name: "Synthetic " + person.role, platform_role: person.role,
  });
  assert.ifError(insert.error);
}
console.log("PASS: three synthetic local Auth users and role profiles prepared (no Production records)");

const adminDir = new URL("../", import.meta.url).pathname;
const baseEnv = {
  ...process.env,
  NEXT_PUBLIC_SUPABASE_URL: url,
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: publishable,
  NEXT_PUBLIC_ADMIN_SECURITY_CENTER_ENABLED: "true",
  NEXT_PUBLIC_ADMIN_NOTIFICATIONS_ENABLED: "true",
  NEXT_PUBLIC_ADMIN_ANALYTICS_ENABLED: "true",
  // These checks target local auth only. Never set VERCEL_ENV or use hosted backend.
  VERCEL_ENV: "",
  NEXT_TELEMETRY_DISABLED: "1",
  PORT: "3109",
};
function invoke(command, args) {
  execFileSync(command, args, { cwd: adminDir, env: baseEnv, stdio: "inherit", timeout: 300_000 });
}
invoke("npm", ["run", "build"]);

const server = spawn("npm", ["run", "start"], {
  cwd: adminDir,
  env: baseEnv,
  stdio: ["ignore", "pipe", "pipe"],
  // Isolate the whole Next.js process group, not just the npm wrapper.
  detached: true,
});
let serverOutput = "";
for (const output of [server.stdout, server.stderr]) {
  output.setEncoding("utf8");
  output.on("data", (part) => { serverOutput += part.toString().slice(0, 2000); });
}
const base = "http://127.0.0.1:3109";
const browser = await chromium.launch({ headless: true, args: ["--no-sandbox"] });
const errors = [];
try {
  let ready = false;
  for (let attempt = 0; attempt < 60; attempt++) {
    try {
      const res = await fetch(base + "/login", { redirect: "manual" });
      if (res.status === 200) { ready = true; break; }
    } catch { /* Await Next server startup. */ }
    await delay(1000);
  }
  assert.ok(ready, "Local Admin Next.js server failed to start");

  for (const person of people) {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    page.on("pageerror", (error) => errors.push(person.role + ": " + error.message));
    await page.goto(base + "/login");
    await page.getByLabel("อีเมล").fill(person.email);
    await page.getByLabel("รหัสผ่าน").fill(password);
    await page.getByRole("button", { name: "เข้าสู่ระบบ" }).click();

    if (person.role === "user") {
      await page.getByRole("alert").getByText("บัญชีนี้ไม่มีสิทธิ์").waitFor({ timeout: 25_000 });
      await page.goto(base + "/analytics");
      assert.ok(new URL(page.url()).pathname === "/login", "Ordinary user could reach protected Admin");
      console.log("PASS: ordinary user login denied and protected URL blocked");
    } else {
      await page.waitForURL((url) => url.pathname === "/", { timeout: 30_000 });
      const routes = ["/", "/action-center", "/audit-log", "/search",
        "/security-center", "/admin-notifications"];
      if (person.role === "admin") routes.push("/analytics");
      for (const route of routes) {
        const response = await page.goto(base + route, { waitUntil: "domcontentloaded" });
        assert.ok(response && response.status() < 400,
          person.role + " cannot access " + route + ": " + response?.status());
        assert.equal(new URL(page.url()).pathname, route,
          person.role + " unexpectedly redirected from " + route);
      }
      await page.goto(base + "/");
      const picker = page.locator("#admin-workspace");
      assert.equal(await picker.count(), 1, "Exactly one workspace selector is required");
      if (person.role === "moderator") {
        const res = await page.goto(base + "/analytics", { waitUntil: "networkidle" });
        const html = await page.content();
        // Next App Router can stream a 404 boundary with HTTP 200 after
        // response headers have already been sent. Check the rendered
        // denial AND absence of sensitive finance panels instead of
        // trusting the HTTP status alone.
        const notFound = res.status() === 404 ||
          /This page could not be found|<title>404|ไม่พบหน้า|NOT_FOUND/.test(html);
        assert.ok(notFound, "Moderator Analytics must render the Not Found boundary");
        assert.ok(!html.includes("ยอดขายวันนี้ (บาท)") &&
          !html.includes("WYNOS Social · ผู้ใช้งาน"),
          "Moderator must never receive financial Analytics panel content");
        console.log("PASS: Moderator login and scoped routes; Analytics denied");
      } else {
        console.log("PASS: Admin login and all enabled local non-network feature routes");
      }
      const width = await page.evaluate(() => ({ view: window.innerWidth, content: document.documentElement.scrollWidth }));
      assert.ok(width.content <= width.view + 3, "Page exceeds phone viewport");
    }
    await context.close();
  }
  assert.equal(errors.length, 0, "Browser runtime errors detected: " + errors.join(" | "));
  console.log("PASS: synthetic login, role gating, 390px navigation and browser runtime smoke");
  console.log("NOT TESTED: remote Staging, full RPC/schema fidelity, System Health public HEAD endpoints and payments");
} catch (error) {
  // Avoid dumping the server environment / private synthetic test key.
  console.error("LOCAL QA FAILED:", error instanceof Error ? error.message : "Unknown failure");
  throw error;
} finally {
  await browser.close();
  // Killing only npm leaves next-server and open log pipes alive on CI.
  // Stop the entire synthetic local web process group on success or failure.
  try { process.kill(-server.pid, "SIGTERM"); } catch { server.kill("SIGTERM"); }
  server.stdout.destroy();
  server.stderr.destroy();
}
