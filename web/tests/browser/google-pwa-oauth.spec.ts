import { readFileSync } from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";

test("installed iPhone invokes Google OAuth in an app-owned popup without redirecting Welcome to Safari", async ({ page }) => {
  await page.addInitScript(() => {
    Object.defineProperties(navigator, {
      standalone: { configurable: true, value: true },
      userAgent: { configurable: true, value: "Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X)" },
    });
    const events: Array<string> = [];
    const storage = new Map<string,string>();
    const fakePopup = {
      sessionStorage: {
        setItem(key:string,value:string){storage.set(key,value);},
        getItem(key:string){return storage.get(key)??null;},
        removeItem(key:string){storage.delete(key);},
      },
      document: { title:"", body:{textContent:""} },
      location: { replace(url:string) {events.push("popup navigated:"+url);} },
      close() {events.push("popup closed");},
    };
    Object.assign(window, {
      open: (url:string) => {events.push("opened:"+url);return fakePopup;},
      __wynosOauthEvents: events,
    });
  });
  await page.goto("/dev/google-pwa-oauth-fixture", {waitUntil:"networkidle"});
  await page.getByRole("button", {name:"Start mocked Google"}).click();
  await expect(page.getByLabel("OAuth result")).toHaveText("started");
  await expect(page.getByLabel("OAuth callback")).toHaveText(page.url().split("/dev/")[0]+"/auth/callback");
  await expect(page.getByLabel("Skip browser redirect")).toHaveText("true");
  const events = await page.evaluate(() =>
    (window as typeof window & {__wynosOauthEvents:string[]}).__wynosOauthEvents,
  );
  expect(events[0]).toBe("opened:about:blank");
  expect(events.some(s=>s.includes("popup navigated:")&&s.includes("/auth/v1/authorize"))).toBe(true);
  await expect(page).toHaveURL(/\/dev\/google-pwa-oauth-fixture/);
});

test("the shared callback announces Google completion only AFTER verifying the session", () => {
  const source=(name:string)=>readFileSync(path.join(process.cwd(),name),"utf8");
  const helper=source("lib/google-pwa-oauth.ts");
  const callback=source("app/auth/callback/page.tsx");
  const welcome=source("components/auth-flow/screens.tsx");
  expect(helper).toContain('window.open("about:blank", "_blank")');
  expect(helper).toContain("skipBrowserRedirect: true");
  expect(callback.indexOf("getUser()")).toBeLessThan(callback.indexOf("announceGooglePwaCompletion()"));
  expect(callback).toContain("consumeGooglePwaPopupMarker()");
  expect(welcome).toContain("GOOGLE_PWA_COMPLETED_CHANNEL");
  expect(welcome).toContain("googlePwaPending.current");
});


test("installed iPhone arms the parent pending flag before awaiting OAuth startup", () => {
  const source=(name:string)=>readFileSync(path.join(process.cwd(),name),"utf8");
  for (const name of ["components/food/food-auth.tsx", "components/auth-flow/screens.tsx"]) {
    const body=source(name);
    const oauthStart=body.indexOf("await startGoogleOAuth");
    const pendingArm=body.lastIndexOf("googlePwaPending.current = true", oauthStart);
    expect(oauthStart).toBeGreaterThan(-1);
    expect(pendingArm).toBeGreaterThan(-1);
    expect(pendingArm).toBeLessThan(oauthStart);
  }
});


test("installed iPhone securely hands popup session to the waiting PWA and does not fail on focus alone", () => {
  const source=(name:string)=>readFileSync(path.join(process.cwd(),name),"utf8");
  const helper=source("lib/google-pwa-oauth.ts");
  const foodCallback=source("app/food/auth/callback/page.tsx");
  const socialCallback=source("app/auth/callback/page.tsx");
  const foodLogin=source("components/food/food-auth.tsx");
  const welcome=source("components/auth-flow/screens.tsx");

  expect(helper).toContain("GOOGLE_PWA_SESSION_MESSAGE");
  expect(helper).toContain("opener.postMessage");
  expect(foodCallback.indexOf("announceGooglePwaSession(session)")).toBeLessThan(foodCallback.indexOf("announceGooglePwaCompletion()"));
  expect(socialCallback.indexOf("announceGooglePwaSession(session)")).toBeLessThan(socialCallback.indexOf("announceGooglePwaCompletion()"));
  for (const body of [foodLogin, welcome]) {
    expect(body).toContain("GOOGLE_PWA_SESSION_MESSAGE");
    expect(body).toContain("auth.setSession");
    expect(body).toContain("popupClosed()");
  }
  expect(foodLogin).toContain("resumeGoogle(undefined, popupClosed())");
  expect(welcome).toContain("resume(undefined, popupClosed())");
});
