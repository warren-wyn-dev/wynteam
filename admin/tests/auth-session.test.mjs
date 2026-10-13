import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const require = createRequire(import.meta.url);
const { NextRequest, NextResponse } = require("next/server");

function loadModule(path, dependencies) {
  const source = readFileSync(new URL(path, import.meta.url), "utf8");
  const { outputText } = ts.transpileModule(source, {
    fileName: path,
    compilerOptions: {
      module: ts.ModuleKind.CommonJS,
      target: ts.ScriptTarget.ES2022,
      jsx: ts.JsxEmit.ReactJSX,
    },
  });
  const exports = {};
  runInNewContext(outputText, {
    exports,
    require: (name) => dependencies[name] ?? require(name),
    process: { env: {
      NEXT_PUBLIC_SUPABASE_URL: "https://supabase.test",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "synthetic-publishable-key",
    } },
  }, { filename: `${path}.compiled.js` });
  return exports;
}

function logoutWith(createClient, redirect) {
  return loadModule("../app/(admin)/actions.ts", {
    "@/lib/supabase/server": { createClient },
    "next/navigation": { redirect },
  }).signOutAction;
}

test("logout waits for successful global sign-out before redirecting", async () => {
  let finish;
  let redirects = 0;
  const signedOut = new Promise((resolve) => { finish = resolve; });
  const redirected = new Error("NEXT_REDIRECT");
  const logout = logoutWith(async () => ({ auth: { signOut: (...args) => {
    assert.equal(args.length, 0, "the existing global sign-out scope must be preserved");
    return signedOut;
  } } }), (path) => {
    assert.equal(path, "/login");
    redirects++;
    throw redirected;
  });
  const pending = logout();
  await Promise.resolve();
  assert.equal(redirects, 0);
  finish({ error: null });
  await assert.rejects(pending, (error) => error === redirected);
  assert.equal(redirects, 1);
});

test("a rejected Supabase sign-out stays on Admin and returns a safe retry message", async () => {
  const logout = logoutWith(async () => ({ auth: {
    signOut: async () => ({ error: { message: "synthetic private details", status: 503 } }),
    getSession: async () => ({ data: { session: { user: { id: "synthetic-user" } } }, error: null }),
  } }), () => assert.fail("failed sign-out with an existing session must not redirect"));
  const result = await logout();
  assert.equal(result.error, "ออกจากระบบไม่สำเร็จ กรุณาลองอีกครั้ง");
  assert.doesNotMatch(JSON.stringify(result), /private details|503/);
});

test("a failed global revoke with a cleared local session redirects to a qualified notice", async () => {
  const redirected = new Error("NEXT_REDIRECT");
  const logout = logoutWith(async () => ({ auth: {
    signOut: async (...args) => {
      assert.equal(args.length, 0);
      return { error: { message: "synthetic private details", status: 503 } };
    },
    getSession: async () => ({ data: { session: null }, error: null }),
  } }), (path) => {
    assert.equal(path, "/login?logout=local");
    throw redirected;
  });
  await assert.rejects(logout(), (error) => error === redirected);
});

test("failed local session inspection never claims a completed sign-out", async () => {
  for (const getSession of [
    async () => ({ data: { session: null }, error: new Error("synthetic inspection failed") }),
    async () => { throw new Error("synthetic inspection unavailable"); },
  ]) {
    const logout = logoutWith(async () => ({ auth: {
      signOut: async () => ({ error: { status: 503 } }),
      getSession,
    } }), () => assert.fail("unconfirmed local cleanup must not redirect"));
    assert.equal((await logout()).error, "ออกจากระบบไม่สำเร็จ กรุณาลองอีกครั้ง");
  }
});

test("client creation and thrown network errors return retry state without redirect", async () => {
  for (const createClient of [
    async () => { throw new Error("synthetic unavailable client"); },
    async () => ({ auth: { signOut: async () => { throw new Error("synthetic offline"); } } }),
  ]) {
    const logout = logoutWith(createClient, () => assert.fail("failed sign-out must not redirect"));
    assert.equal((await logout()).error, "ออกจากระบบไม่สำเร็จ กรุณาลองอีกครั้ง");
  }
});

const authHeaders = {
  "Cache-Control": "private, no-cache, no-store, must-revalidate, max-age=0",
  Expires: "0",
  Pragma: "no-cache",
};

function sessionWith(user, cookies = []) {
  return loadModule("../lib/supabase/middleware.ts", {
    "next/server": { NextResponse },
    "@supabase/ssr": { createServerClient: (_url, _key, options) => ({ auth: {
      getUser: async () => {
        if (cookies.length) options.cookies.setAll(cookies, authHeaders);
        return { data: { user } };
      },
    } }) },
  }).updateSession;
}

test("expired-session redirects keep cookie removals and Supabase cache protection", async () => {
  const updateSession = sessionWith(null, [{
    name: "sb-synthetic-auth-token", value: "",
    options: { path: "/", maxAge: 0, httpOnly: true, sameSite: "lax" },
  }]);
  const response = await updateSession(new NextRequest("https://admin.test/food/orders?q=synthetic"));
  assert.equal(response.status, 307);
  assert.equal(response.headers.get("location"), "https://admin.test/login");
  const removed = response.cookies.get("sb-synthetic-auth-token");
  assert.equal(removed.value, "");
  assert.equal(removed.maxAge, 0);
  assert.equal(removed.httpOnly, true);
  assert.equal(removed.sameSite, "lax");
  for (const [name, value] of Object.entries(authHeaders)) {
    assert.equal(response.headers.get(name), value);
  }
});

test("authenticated refresh updates downstream request and browser response cookies", async () => {
  const updateSession = sessionWith({ id: "synthetic-user" }, [{
    name: "sb-synthetic-auth-token", value: "synthetic-refreshed-session", options: { path: "/", sameSite: "lax" },
  }]);
  const request = new NextRequest("https://admin.test/");
  const response = await updateSession(request);
  assert.equal(response.headers.get("location"), null);
  assert.equal(request.cookies.get("sb-synthetic-auth-token").value, "synthetic-refreshed-session");
  assert.equal(response.cookies.get("sb-synthetic-auth-token").value, "synthetic-refreshed-session");
  assert.equal(response.headers.get("cache-control"), authHeaders["Cache-Control"]);
});

test("login remains public while protected routes reject a guest", async () => {
  const updateSession = sessionWith(null);
  const publicResponse = await updateSession(new NextRequest("https://admin.test/login"));
  assert.equal(publicResponse.headers.get("location"), null);
  const protectedResponse = await updateSession(new NextRequest("https://admin.test/team"));
  assert.equal(protectedResponse.headers.get("location"), "https://admin.test/login");
});

function logoutView(state, pending) {
  const { LogoutButton } = loadModule("../components/admin/logout-button.tsx", {
    react: { useActionState: () => [state, () => {}, pending], useId: () => "synthetic-logout-error" },
    "@/components/ui/button": { Button: "button" },
    "lucide-react": { LogOut: "svg", LoaderCircle: "svg" },
  });
  return LogoutButton({ signOutAction: async () => ({ error: null }) });
}

function findElement(element, predicate) {
  if (!element || typeof element !== "object") return null;
  if (predicate(element)) return element;
  for (const child of [element.props?.children].flat(Infinity)) {
    const match = findElement(child, predicate);
    if (match) return match;
  }
  return null;
}

test("logout pending state blocks repeat clicks and hides the old retry error", () => {
  const view = logoutView({ error: "synthetic previous error" }, true);
  const button = findElement(view, (element) => element.type === "button");
  assert.equal(button.props.disabled, true);
  assert.equal(button.props["aria-busy"], true);
  assert.ok(button.props.children.includes("กำลังออก..."));
  assert.equal(findElement(view, (element) => element.props?.role === "alert"), null);
});

test("logout failure exposes an accessible alert and enables retry", () => {
  const view = logoutView({ error: "synthetic retry message" }, false);
  const button = findElement(view, (element) => element.type === "button");
  const alert = findElement(view, (element) => element.props?.role === "alert");
  assert.equal(button.props.disabled, false);
  assert.equal(button.props["aria-busy"], false);
  assert.equal(button.props["aria-describedby"], alert.props.id);
  assert.equal(alert.props.children, "synthetic retry message");
});

test("login shows a fixed local-cleanup notice only for the exact logout marker", async () => {
  const { default: LoginPage } = loadModule("../app/login/page.tsx", {
    "@/components/ui/card": { Card: "div", CardContent: "div", CardDescription: "p", CardHeader: "div", CardTitle: "h1" },
    "./login-form": { LoginForm: "form" },
  });
  for (const logout of [undefined, "local", "synthetic untrusted message", ["local", "local"]]) {
    const view = await LoginPage({ searchParams: Promise.resolve({ logout }) });
    const notice = findElement(view, (element) => element.props?.role === "status");
    if (logout === "local") {
      assert.equal(notice.props.children,
        "ออกจาก WYNOS Admin ในเบราว์เซอร์นี้แล้ว แต่ยังยืนยันการออกจากระบบในอุปกรณ์อื่นไม่ได้");
    } else {
      assert.equal(notice, null);
    }
  }
});
