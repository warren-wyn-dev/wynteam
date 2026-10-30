"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";

import { type DeveloperRouteContext } from "@/components/developer-route-gate";
import { createMerchantFlutterBridge } from "@/lib/merchant-flutter-bridge";
import { loadMerchantFlutterApp, type MerchantFlutterApp } from "@/lib/merchant-flutter-loader";
import { markMerchantFlutterStartup, observeMerchantFlutterStartup } from "@/lib/merchant-flutter-startup";

type BridgeBrowser = Window & {
  zokyMerchant?: ReturnType<typeof createMerchantFlutterBridge>;
};

export function AuthenticatedMerchantFlutter({ client, userId, signOut }: DeveloperRouteContext) {
  const host = useRef<HTMLDivElement>(null);
  const latestSignOut = useRef(signOut);
  useEffect(() => { latestSignOut.current = signOut; }, [signOut]);
  const [result, setResult] = useState<{
    client: DeveloperRouteContext["client"];
    userId: string;
    phase: "ready" | "error";
  }>();
  // A replacement client/account must wait for its own view, even before the
  // previous effect's cleanup runs. Do not carry a ready state across scopes.
  const state = result?.client === client && result.userId === userId ? result.phase : "loading";

  useEffect(() => {
    const element = host.current;
    if (!element) return;
    let active = true;
    let viewId: number | undefined;
    let flutterApp: MerchantFlutterApp | undefined;
    const browser = window as BridgeBrowser;
    const setState = (phase: "ready" | "error") => setResult({ client, userId, phase });
    markMerchantFlutterStartup("start");
    const startup = observeMerchantFlutterStartup({
      onReady: (detail) => {
        if (!active || browser.zokyMerchant !== bridge) return;
        markMerchantFlutterStartup("content", detail);
        setState("ready");
      },
      onTimeout: () => { if (active) setState("error"); },
    });
    const bridge = createMerchantFlutterBridge({
      client,
      userId,
      signOut: () => latestSignOut.current(),
      onOrderChange: () => window.dispatchEvent(new Event("zoky-merchant-order-change")),
    });
    const wake = (event: MessageEvent) => {
      if (event.data?.kind !== "wynos:notification-push" || (event.data.recipientId && event.data.recipientId !== userId)) return;
      // Content-free invalidation only. The bridge rechecks the current session.
      window.dispatchEvent(new Event("zoky-merchant-order-change"));
    };
    navigator.serviceWorker?.addEventListener("message", wake);
    // Only the existing JS client owns the session. No token, password or
    // Supabase client reference is transferred into the Dart runtime.
    browser.zokyMerchant = bridge;
    void loadMerchantFlutterApp().then((app) => {
      if (!active || browser.zokyMerchant !== bridge) return;
      flutterApp = app;
      viewId = app.addView({ hostElement: element });
      markMerchantFlutterStartup("view");
      startup.watch(viewId);
    }).catch(() => {
      startup.dispose();
      if (active) setState("error");
    });

    return () => {
      active = false;
      startup.dispose();
      navigator.serviceWorker?.removeEventListener("message", wake);
      bridge.dispose();
      if (browser.zokyMerchant === bridge) delete browser.zokyMerchant;
      if (flutterApp && viewId !== undefined) flutterApp.removeView(viewId);
      element.replaceChildren();
    };
  }, [client, userId]);

  return (
    <main aria-label="Zoky Merchant" data-wyn-swipe-back="ignore" style={{ position: "relative", height: "100dvh", minHeight: 360, width: "100%", overflow: "hidden" }}>
      <div ref={host} data-merchant-flutter-host="" aria-hidden={state !== "ready"} inert={state !== "ready"} style={{ height: "100%", width: "100%" }} />
      {state !== "ready" && (
        <div className="route-state" role={state === "error" ? "alert" : "status"} style={{ position: "absolute", inset: 0, background: "#fff" }}>
          {state === "loading" ? <><div className="route-system-spinner" /><p>กำลังเปิด Zoky Merchant…</p></> : <>
            <h1>เปิด Zoky Merchant ไม่สำเร็จ</h1>
            <p>กรุณาตรวจอินเทอร์เน็ตแล้วลองใหม่ หรือใช้หน้าร้านเดิมได้ทันที</p>
            <button className="route-primary" type="button" onClick={() => window.location.reload()}>ลองโหลดใหม่</button>
            <Link href="/merchant?legacy=1">เปิดหน้าร้านเดิม</Link>
          </>}
        </div>
      )}
    </main>
  );
}
