"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";

import { DeveloperRouteGate, type DeveloperRouteContext } from "@/components/developer-route-gate";
import { createMerchantFlutterBridge } from "@/lib/merchant-flutter-bridge";
import { loadMerchantFlutterApp, type MerchantFlutterApp } from "@/lib/merchant-flutter-loader";

type BridgeBrowser = Window & {
  zokyMerchant?: ReturnType<typeof createMerchantFlutterBridge>;
};

function AuthenticatedMerchantFlutter({ client, userId, signOut }: DeveloperRouteContext) {
  const host = useRef<HTMLDivElement>(null);
  const latestSignOut = useRef(signOut);
  useEffect(() => { latestSignOut.current = signOut; }, [signOut]);
  const [state, setState] = useState<"loading" | "ready" | "error">("loading");

  useEffect(() => {
    const element = host.current;
    if (!element) return;
    let active = true;
    let viewId: number | undefined;
    let flutterApp: MerchantFlutterApp | undefined;
    const browser = window as BridgeBrowser;
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
      setState("ready");
    }).catch(() => {
      if (active) setState("error");
    });

    return () => {
      active = false;
      navigator.serviceWorker?.removeEventListener("message", wake);
      bridge.dispose();
      if (browser.zokyMerchant === bridge) delete browser.zokyMerchant;
      if (flutterApp && viewId !== undefined) flutterApp.removeView(viewId);
      element.replaceChildren();
    };
  }, [client, userId]);

  return (
    <main aria-label="Zoky Merchant" style={{ position: "relative", height: "100dvh", minHeight: 360, width: "100%", overflow: "hidden" }}>
      <div ref={host} data-merchant-flutter-host="" style={{ height: "100%", width: "100%" }} />
      {state !== "ready" && (
        <div className="route-state" role={state === "error" ? "alert" : "status"} style={{ position: "absolute", inset: 0, background: "#fff" }}>
          {state === "loading" ? <><div className="route-system-spinner" /><p>กำลังเปิด Zoky Merchant…</p></> : <>
            <h1>เปิด Zoky Merchant ไม่สำเร็จ</h1>
            <p>กรุณาตรวจอินเทอร์เน็ตแล้วลองใหม่ หรือใช้หน้าร้านเดิมได้ทันที</p>
            <button className="route-primary" type="button" onClick={() => window.location.reload()}>ลองโหลดใหม่</button>
            <Link href="/merchant">เปิดหน้าร้านเดิม</Link>
          </>}
        </div>
      )}
    </main>
  );
}

export function MerchantFlutterApp() {
  return (
    <DeveloperRouteGate signedOutPath="/merchant/login">
      {(context) => <AuthenticatedMerchantFlutter key={context.userId} {...context} />}
    </DeveloperRouteGate>
  );
}
