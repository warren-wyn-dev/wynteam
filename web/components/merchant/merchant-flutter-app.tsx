"use client";

import dynamic from "next/dynamic";
import Link from "next/link";

import { DeveloperRouteGate, type DeveloperRouteContext } from "@/components/developer-route-gate";

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

// Avoid downloading merchant order/finance, push and Flutter bridge helpers
// for signed-out visitors. The authenticated chunk keeps its original
// service-worker invalidation and account cleanup.
const AuthenticatedMerchantFlutter = dynamic<DeveloperRouteContext>(
  () => import("@/components/merchant/merchant-flutter-authenticated")
    .then((module) => module.AuthenticatedMerchantFlutter)
    .catch(() => MerchantFlutterLoadError),
  {
    ssr: false,
    loading: () => (
      <main aria-label="Zoky Merchant" className="route-state" role="status" style={{ height: "100dvh", minHeight: 360, width: "100%", background: "#fff" }}>
        <div className="route-system-spinner" /><p>กำลังเปิด Zoky Merchant…</p>
      </main>
    ),
  },
);

export function MerchantFlutterApp() {
  return (
    <DeveloperRouteGate signedOutPath="/merchant/login">
      {(context) => <AuthenticatedMerchantFlutter key={context.userId} {...context} />}
    </DeveloperRouteGate>
  );
}
