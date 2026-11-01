"use client";

import dynamic from "next/dynamic";
import Link from "next/link";

import { DeveloperRouteGate, type DeveloperRouteContext } from "@/components/developer-route-gate";
import { loadMerchantFlutterApp } from "@/lib/merchant-flutter-loader";

/** Set after a merchant view opened on this device; cleared on sign-out. */
export const MERCHANT_FLUTTER_SEEN_KEY = "zoky-merchant-flutter-seen";

// Founder 2026-11-01 ("ให้มันเร็วๆมากๆ"): a returning merchant's engine
// download and start overlap the session check instead of waiting for it.
// It only fetches the reviewed same-origin build; no store view or bridge
// exists until the gate authorizes this account.
if (typeof window !== "undefined") {
  try {
    if (window.localStorage.getItem(MERCHANT_FLUTTER_SEEN_KEY) === "1") void loadMerchantFlutterApp().catch(() => {});
  } catch {
    // Storage may be unavailable (private mode); the gate path still loads it.
  }
}

function MerchantFlutterLoadError() {
  return (
    <main aria-label="Zoky Merchant" className="route-state" role="alert" style={{ height: "100dvh", minHeight: 360, width: "100%", background: "#fff" }}>
      <h1>เปิด Zoky Merchant ไม่สำเร็จ</h1>
      <p>กรุณาตรวจอินเทอร์เน็ตแล้วลองใหม่ หรือใช้หน้าร้านเดิมได้ทันที</p>
      <button className="route-primary" type="button" onClick={() => window.location.reload()}>ลองโหลดใหม่</button>
      <Link href="/merchant?legacy=1">เปิดหน้าร้านเดิม</Link>
    </main>
  );
}

function MerchantFlutterLoading() {
  return (
    <main aria-label="Zoky Merchant" className="route-state" role="status" style={{ height: "100dvh", minHeight: 360, width: "100%", background: "#fff" }}>
      <div className="route-system-spinner" /><p>กำลังเปิด Zoky Merchant…</p>
    </main>
  );
}

// The bridge includes order, finance and push helpers. Guests only need the
// shared session gate, so fetch this code after it authorizes a Merchant view.
const AuthenticatedMerchantFlutter = dynamic<DeveloperRouteContext>(
  () => {
    // This lazy loader only runs when the session gate renders its authorized
    // child. Start the engine and bridge downloads together when requested.
    // No store bridge/view exists until the authenticated host mounts, and that
    // host handles the same singleton engine promise's error and recovery.
    if (typeof window !== "undefined") void loadMerchantFlutterApp().catch(() => {});
    return import("@/components/merchant/merchant-flutter-authenticated")
      .then((module) => module.AuthenticatedMerchantFlutter)
      .catch(() => MerchantFlutterLoadError);
  },
  {
    ssr: false,
    loading: MerchantFlutterLoading,
  },
);

export function MerchantFlutterApp() {
  return (
    <DeveloperRouteGate signedOutPath="/merchant/login">
      {(context) => <AuthenticatedMerchantFlutter key={context.userId} {...context} />}
    </DeveloperRouteGate>
  );
}
