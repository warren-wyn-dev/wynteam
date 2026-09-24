"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { ArrowLeft, ChefHat, Store, UtensilsCrossed } from "lucide-react";
import Link from "next/link";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome } from "@/components/phase3-ui";

type Access = "checking" | "allowed" | "denied";

function FoodDeveloperPreview({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const [access, setAccess] = useState<Access>("checking");

  useEffect(() => {
    let live = true;
    // Check again on this route; hiding the Home shortcut alone is not access control.
    void (async () => {
      try {
        const { data, error } = await client.rpc("is_developer_account");
        if (live) setAccess(!error && data === true ? "allowed" : "denied");
      } catch {
        if (live) setAccess("denied");
      }
    })();
    return () => { live = false; };
  }, [client, userId]);

  useEffect(() => {
    if (access === "denied") router.replace("/");
  }, [access, router]);

  if (access !== "allowed") {
    return <main className="route-state" aria-label="กำลังตรวจสอบสิทธิ์"><div className="route-system-spinner" /></main>;
  }

  return (
    <AppChrome title="WYNOS Food" userId={userId} backHref="/" showBottomNav={false}>
      <section style={{ maxWidth: 680, margin: "0 auto", padding: "24px 18px 60px", color: "var(--wyn-text)" }}>
        <div style={{ width: 64, height: 64, borderRadius: 19, background: "#E8293D", display: "grid", placeItems: "center", color: "white" }}>
          <UtensilsCrossed size={30} strokeWidth={1.9} aria-hidden="true" />
        </div>
        <p style={{ display: "inline-flex", borderRadius: 999, padding: "6px 11px", margin: "20px 0 8px", background: "#FCE8EC", color: "#AE2031", fontWeight: 700, fontSize: 12 }}>
          เฉพาะบัญชีนักพัฒนา
        </p>
        <h1 style={{ fontSize: 29, lineHeight: 1.2, fontWeight: 800, margin: "2px 0 8px" }}>WYNOS Food</h1>
        <p style={{ color: "var(--wyn-text-secondary)", fontSize: 15, lineHeight: 1.7, margin: "0 0 24px" }}>
          บริการสั่งอาหารภายใน WYNOS กำลังอยู่ระหว่างพัฒนา ยังไม่เปิดให้สั่งอาหารหรือชำระเงินจริง
        </p>

        <div style={{ border: "1px solid var(--wyn-border)", borderRadius: 18, padding: 18, display: "grid", gap: 16 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <span style={{ width: 46, height: 46, display: "grid", placeItems: "center", borderRadius: 14, background: "#FCE8EC", color: "#E8293D" }}>
              <ChefHat size={25} aria-hidden="true" />
            </span>
            <div>
              <strong style={{ fontSize: 16 }}>WYNOS Food</strong>
              <p style={{ margin: "4px 0 0", color: "var(--wyn-text-secondary)", fontSize: 13 }}>ฝั่งลูกค้า · เมนูและคำสั่งซื้อ (อยู่ระหว่างพัฒนา)</p>
            </div>
          </div>
          <div style={{ borderTop: "1px solid var(--wyn-border)", paddingTop: 16, display: "flex", alignItems: "center", gap: 12 }}>
            <span style={{ width: 46, height: 46, display: "grid", placeItems: "center", borderRadius: 14, background: "var(--wyn-bg)", border: "1px solid var(--wyn-border)", color: "var(--wyn-text)" }}>
              <Store size={25} aria-hidden="true" />
            </span>
            <div>
              <strong style={{ fontSize: 16 }}>WYNOS Food Merchant</strong>
              <p style={{ margin: "4px 0 0", color: "var(--wyn-text-secondary)", fontSize: 13 }}>ฝั่งร้านค้า · รับออเดอร์และจัดการร้าน (อยู่ระหว่างพัฒนา)</p>
            </div>
          </div>
        </div>

        <p style={{ color: "var(--wyn-text-secondary)", fontSize: 13, lineHeight: 1.7, margin: "20px 0" }}>
          เริ่มต้นด้วยร้านอาหารเพียงร้านเดียว จ้างไรเดอร์ภายนอก ไม่มีระบบไรเดอร์ในแอป
        </p>
        <Link href="/" style={{ display: "inline-flex", alignItems: "center", gap: 7, color: "#E8293D", fontSize: 14, fontWeight: 700, textDecoration: "none" }}>
          <ArrowLeft size={18} aria-hidden="true" /> กลับไปยัง WYNOS
        </Link>
      </section>
    </AppChrome>
  );
}

export function WynosFoodPreviewRoute() {
  return (
    <DeveloperRouteGate>
      {({ client, userId }) => <FoodDeveloperPreview key={userId} client={client} userId={userId} />}
    </DeveloperRouteGate>
  );
}
