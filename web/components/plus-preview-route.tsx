"use client";

import Link from "next/link";
import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome } from "@/components/phase3-ui";
import styles from "./plus-preview.module.css";

/** A design-only gate. Entitlements and payment are NOT configured. */
export function PlusPreviewRoute() {
  if (process.env.NEXT_PUBLIC_WYNOS_PLUS_PREVIEW !== "1") {
    return <main className={styles.unavailable}>
      <h1>WYNOS Plus</h1>
      <p>ระบบสมาชิกกำลังพัฒนา และยังไม่เปิดรับสมัคร</p>
      <Link href="/settings">กลับไปการตั้งค่า</Link>
    </main>;
  }
  return <DeveloperRouteGate>{({ userId }) =>
    <AppChrome title="WYNOS Plus" userId={userId} backHref="/settings" showBottomNav={false}>
      <section className={styles.page} aria-label="ตัวอย่าง WYNOS Plus">
        <div className={styles.hero}>
          <span className={styles.emblem} aria-hidden="true">✦</span>
          <p className={styles.eyebrow}>WYNOS PLUS · PREVIEW</p>
          <h1>พื้นที่สำหรับประสบการณ์ที่มากขึ้น</h1>
          <p>ตัวอย่างหน้าสมาชิกแบบชำระเงิน ฟีเจอร์ สิทธิประโยชน์และราคาจะประกาศเมื่อระบบพร้อม</p>
        </div>
        <div className={styles.notice}>
          <strong>ยังไม่เปิดรับสมัคร</strong>
          <p>หน้านี้ไม่สามารถชำระเงิน เปิดใช้สมาชิก หรือเปลี่ยนสถานะบัญชีได้</p>
        </div>
        <Link className={styles.return} href="/settings">กลับไปการตั้งค่า</Link>
      </section>
    </AppChrome>
  }</DeveloperRouteGate>;
}
