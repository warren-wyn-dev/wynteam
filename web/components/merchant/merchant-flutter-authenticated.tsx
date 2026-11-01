"use client";

import { useEffect, useRef, useState } from "react";
import dynamic from "next/dynamic";
import Link from "next/link";

import { type DeveloperRouteContext } from "@/components/developer-route-gate";
import { createMerchantFlutterBridge, type MerchantMapRequest, type MerchantMapResult } from "@/lib/merchant-flutter-bridge";

// Loaded only when a merchant opens the map (Founder 2026-11-01: drag the store pin).
const FoodDeliveryMapPicker = dynamic(
  () => import("@/components/food/food-delivery-map-picker").then((m) => m.FoodDeliveryMapPicker),
  { ssr: false },
);
type MapOverlay = MerchantMapRequest & { resolve: (value: MerchantMapResult) => void };
import { loadMerchantFlutterApp, type MerchantFlutterApp } from "@/lib/merchant-flutter-loader";
import { markMerchantFlutterStartup, observeMerchantFlutterStartup } from "@/lib/merchant-flutter-startup";

type BridgeBrowser = Window & {
  zokyMerchant?: ReturnType<typeof createMerchantFlutterBridge>;
};

export function AuthenticatedMerchantFlutter({ client, userId, signOut }: DeveloperRouteContext) {
  const host = useRef<HTMLDivElement>(null);
  const latestSignOut = useRef(signOut);
  const [mapOverlay, setMapOverlay] = useState<MapOverlay | null>(null);
  useEffect(() => { latestSignOut.current = signOut; }, [signOut]);
  const [result, setResult] = useState<{
    client: DeveloperRouteContext["client"];
    userId: string;
    phase: "ready" | "slow" | "error";
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
    const setState = (phase: "ready" | "slow" | "error") => setResult({ client, userId, phase });
    markMerchantFlutterStartup("start");
    const startup = observeMerchantFlutterStartup({
      onReady: (detail) => {
        if (!active || browser.zokyMerchant !== bridge) return;
        markMerchantFlutterStartup("content", detail);
        setState("ready");
      },
      onTimeout: () => { if (active) setState("error"); },
      onSlow: () => { if (active) setState("slow"); },
    });
    const bridge = createMerchantFlutterBridge({
      client,
      userId,
      signOut: () => {
        try { window.localStorage.removeItem("zoky-merchant-flutter-seen"); } catch { /* optional speed hint */ }
        return latestSignOut.current();
      },
      onOrderChange: () => window.dispatchEvent(new Event("zoky-merchant-order-change")),
      pickLocation: (request) => new Promise<MerchantMapResult>((resolve) => {
        if (!active) { resolve(null); return; }
        setMapOverlay((current) => {
          current?.resolve(null);
          return { ...request, resolve };
        });
      }),
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
    try { window.localStorage.setItem("zoky-merchant-flutter-seen", "1"); } catch { /* optional speed hint */ }
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
      setMapOverlay((current) => { current?.resolve(null); return null; });
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
      <div ref={host} data-merchant-flutter-host="" aria-hidden={state !== "ready" || mapOverlay !== null} inert={state !== "ready" || mapOverlay !== null} style={{ height: "100%", width: "100%" }} />
      {mapOverlay ? (
        <FoodDeliveryMapPicker
          client={client}
          storeId={null}
          initialLocation={mapOverlay.initial}
          title={mapOverlay.kind === "store" ? "ตำแหน่งร้าน" : "จุดรับอาหาร / ทางเข้าร้าน"}
          subtitle={mapOverlay.kind === "store" ? "ค้นหาแล้วเลื่อนหมุดให้ตรงหน้าร้านจริง" : "กำหนดจุดที่ไรเดอร์ควรมารับอาหาร"}
          confirmLabel={mapOverlay.kind === "store" ? "ใช้เป็นตำแหน่งร้าน" : "ใช้เป็นจุดรับอาหาร"}
          onClose={() => { mapOverlay.resolve(null); setMapOverlay(null); }}
          onConfirm={(location, place) => {
            mapOverlay.resolve({ latitude: location.latitude, longitude: location.longitude, address: place?.address ?? null });
            setMapOverlay(null);
          }}
        />
      ) : null}
      {state !== "ready" && (
        <div className="route-state" role={state === "error" ? "alert" : "status"} style={{ position: "absolute", inset: 0, background: "#fff" }}>
          {state === "loading" ? <><div className="route-system-spinner" /><p>กำลังเปิด Zoky Merchant…</p></> : state === "slow" ? <>
            <div className="route-system-spinner" />
            <p>ยังกำลังเปิด Zoky Merchant… อินเทอร์เน็ตอาจช้ากว่าปกติ</p>
            <button className="route-primary" type="button" onClick={() => window.location.reload()}>ลองโหลดใหม่</button>
            <Link href="/merchant?legacy=1">เปิดหน้าร้านเดิม</Link>
          </> : <>
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
