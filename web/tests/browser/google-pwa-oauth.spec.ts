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
