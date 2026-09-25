"use client";

import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome } from "@/components/phase3-ui";
import { fetchPlusMembership, hasCurrentPlusMembership, type PlusLookup } from "@/lib/plus-membership";
import styles from "./plus-route.module.css";

function PlusContent({ client, userId }: { client: SupabaseClient; userId: string }) {
  const [lookup, setLookup] = useState<PlusLookup | null>(null);
  const [error, setError] = useState("");
  useEffect(() => {
    let live = true;
    void fetchPlusMembership(client, userId)
      .then((value) => { if (live) setLookup(value); })
      .catch(() => { if (live) setError("ตรวจสอบสถานะสมาชิกไม่สำเร็จ กรุณาลองอีกครั้ง"); });
    return () => { live = false; };
  }, [client, userId]);

  const isMember = hasCurrentPlusMembership(lookup?.membership ?? null);
  const expiry = lookup?.membership?.current_period_end;
  const expiresOn = expiry && !Number.isNaN(Date.parse(expiry))
    ? new Intl.DateTimeFormat("th-TH", { dateStyle: "medium" }).format(new Date(expiry))
    : null;
  return (
    <AppChrome title="WYNOS Plus" userId={userId} backHref={"/profile/" + userId} showBottomNav={false}>
      <div className={styles.page}>
        <section className={styles.hero} aria-labelledby="plus-title">
          <span className={styles.eyebrow}>WYNOS</span>
          <h1 id="plus-title">Plus<span className={styles.spark} aria-hidden="true">✦</span></h1>
          <p>พื้นที่สำหรับสมาชิก WYNOS Plus — เตรียมพร้อมสำหรับประสบการณ์ใหม่ โดยยังคงความเรียบง่ายแบบ WYNOS</p>
          <span className={styles.status} role="status">
            {lookup === null && !error ? "กำลังตรวจสอบสถานะ…" :
              isMember ? "สมาชิก Plus" : "กำลังเตรียมเปิดให้บริการ"}
          </span>
        </section>
        <section className={styles.details} aria-label="สถานะการสมัครสมาชิก">
          <h2>สถานะสมาชิก</h2>
          {error ? <p role="alert" className={styles.error}>{error}</p>
            : isMember ? <>
                <p>บัญชีนี้มีสถานะ WYNOS Plus</p>
                {expiresOn ? <p className={styles.muted}>สิ้นสุดรอบปัจจุบัน {expiresOn}</p> : null}
                {lookup?.membership?.cancel_at_period_end
                  ? <p className={styles.muted}>ตั้งค่าให้สิ้นสุดการต่ออายุเมื่อครบกำหนด</p> : null}
              </> : <p>{lookup?.available === false
                ? "ระบบสมาชิกยังไม่เปิดใช้งานในเวอร์ชันนี้"
                : "ยังไม่ได้สมัคร WYNOS Plus"}</p>}
          <button className={styles.cta} type="button" disabled aria-disabled="true">
            การสมัครสมาชิกยังไม่เปิดให้บริการ
          </button>
          <p className={styles.notice}>
            ยังไม่มีการเรียกเก็บเงิน สิทธิประโยชน์ ราคา และเงื่อนไขจะแสดงหลังผ่านการอนุมัติก่อนเปิดบริการจริง
          </p>
        </section>
      </div>
    </AppChrome>
  );
}
export function PlusRoute() {
  return <DeveloperRouteGate>{({ client, userId }) =>
    <PlusContent key={userId} client={client} userId={userId} />
  }</DeveloperRouteGate>;
}
