"use client";

import {
  AlertTriangle,
  BellRing,
  CheckCircle2,
  Circle,
  LoaderCircle,
  Radio,
  Smartphone,
} from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useCallback, useEffect, useState } from "react";

import type { FoodStore } from "@/lib/food-merchant";
import {
  MERCHANT_NOTIFICATION_TEST_RESULT_KEY,
  countMerchantWebPushTokens,
  fetchMerchantNotificationById,
  fetchMerchantPushDeliveries,
  sendMerchantTestNotification,
} from "@/lib/merchant-core";
import {
  pushReasonDescription,
  subscribeToPushNotifications,
} from "@/lib/push-notifications";

type TestStatus = "idle" | "running" | "pass" | "warn" | "fail";
type TestKey = "permission" | "worker" | "in_app" | "realtime" | "web_push" | "deep_link";
type TestResult = { status: TestStatus; detail: string };
type TestResults = Record<TestKey, TestResult>;

const IDLE_RESULTS: TestResults = {
  permission: { status: "idle", detail: "ยังไม่ได้ทดสอบ" },
  worker: { status: "idle", detail: "ยังไม่ได้ทดสอบ" },
  in_app: { status: "idle", detail: "ยังไม่ได้ทดสอบ" },
  realtime: { status: "idle", detail: "ยังไม่ได้ทดสอบ" },
  web_push: { status: "idle", detail: "ยังไม่ได้ทดสอบ" },
  deep_link: { status: "idle", detail: "ยังไม่ได้ทดสอบ" },
};

const TEST_ROWS: Array<{ key: TestKey; label: string; icon: typeof BellRing }> = [
  { key: "permission", label: "สิทธิ์แจ้งเตือน", icon: BellRing },
  { key: "worker", label: "Service Worker", icon: Smartphone },
  { key: "in_app", label: "In-App", icon: CheckCircle2 },
  { key: "realtime", label: "Realtime", icon: Radio },
  { key: "web_push", label: "Web Push", icon: BellRing },
  { key: "deep_link", label: "Deep Link", icon: Smartphone },
];

function savedResults(): TestResults {
  if (typeof window === "undefined") return IDLE_RESULTS;
  try {
    const raw = JSON.parse(window.sessionStorage.getItem(MERCHANT_NOTIFICATION_TEST_RESULT_KEY) ?? "null") as Partial<TestResults> | null;
    if (!raw) return IDLE_RESULTS;
    return {
      permission: raw.permission ?? IDLE_RESULTS.permission,
      worker: raw.worker ?? IDLE_RESULTS.worker,
      in_app: raw.in_app ?? IDLE_RESULTS.in_app,
      realtime: raw.realtime ?? IDLE_RESULTS.realtime,
      web_push: raw.web_push ?? IDLE_RESULTS.web_push,
      deep_link: raw.deep_link ?? IDLE_RESULTS.deep_link,
    };
  } catch {
    return IDLE_RESULTS;
  }
}

function wait(ms: number) {
  return new Promise<void>((resolve) => window.setTimeout(resolve, ms));
}

function StatusIcon({ status }: { status: TestStatus }) {
  if (status === "running") return <LoaderCircle className="wm-test-spin" size={18} />;
  if (status === "pass") return <CheckCircle2 size={18} />;
  if (status === "warn" || status === "fail") return <AlertTriangle size={18} />;
  return <Circle size={18} />;
}

export function MerchantNotificationTest({
  client,
  store,
  userId,
  onMessage,
  onReload,
}: {
  client: SupabaseClient;
  store: FoodStore;
  userId: string;
  onMessage: (message: string) => void;
  onReload: () => Promise<void> | void;
}) {
  const [results, setResults] = useState<TestResults>(savedResults);
  const [busy, setBusy] = useState(false);

  const commitResults = useCallback((next: TestResults) => {
    setResults(next);
    try {
      window.sessionStorage.setItem(MERCHANT_NOTIFICATION_TEST_RESULT_KEY, JSON.stringify(next));
    } catch {
      // Private browsing can disable storage; the current test still works.
    }
  }, []);

  useEffect(() => {
    const handler = () => commitResults(savedResults());
    window.addEventListener("wynos:merchant-notification-test-deep-link", handler);
    return () => window.removeEventListener("wynos:merchant-notification-test-deep-link", handler);
  }, [commitResults]);

  const runTest = async () => {
    if (busy) return;
    setBusy(true);

    let next: TestResults = {
      permission: { status: "running", detail: "กำลังทดสอบ…" },
      worker: { status: "running", detail: "กำลังทดสอบ…" },
      in_app: { status: "running", detail: "กำลังทดสอบ…" },
      realtime: { status: "running", detail: "กำลังทดสอบ…" },
      web_push: { status: "running", detail: "กำลังทดสอบ…" },
      deep_link: { status: "running", detail: "รอ Push ทดสอบ" },
    };
    commitResults(next);

    let channel: ReturnType<SupabaseClient["channel"]> | null = null;
    try {
      // This must stay the first awaited browser operation after the user's
      // click: installed iOS PWAs require a live gesture for permission.
      const pushSetup = await subscribeToPushNotifications(client, userId);

      const permission = typeof Notification === "undefined" ? "unsupported" : Notification.permission;
      next = {
        ...next,
        permission: permission === "granted"
          ? { status: "pass", detail: "อนุญาตแล้ว" }
          : permission === "unsupported"
            ? { status: "fail", detail: "ไม่รองรับ" }
            : { status: "warn", detail: pushSetup.ok ? "ยังไม่ได้อนุญาต" : pushReasonDescription(pushSetup.reason) },
      };
      commitResults(next);

      let registration: ServiceWorkerRegistration | null = null;
      if (typeof navigator !== "undefined" && "serviceWorker" in navigator) {
        registration = (await navigator.serviceWorker.getRegistration("/")) ?? null;
      }
      next = {
        ...next,
        worker: registration?.active
          ? { status: "pass", detail: "พร้อมทำงาน" }
          : { status: "warn", detail: "Service Worker ยังไม่พร้อม" },
      };
      commitResults(next);

      const observedIds = new Set<string>();
      let expectedId: string | null = null;
      let channelState: "connecting" | "subscribed" | "failed" = "connecting";

      channel = client
        .channel(`merchant-notification-test:${userId}:${new Date().getTime()}`)
        .on(
          "postgres_changes",
          {
            event: "INSERT",
            schema: "public",
            table: "merchant_notifications",
            filter: `recipient_user_id=eq.${userId}`,
          },
          (payload) => {
            const id = typeof payload.new?.id === "string" ? payload.new.id : null;
            if (id) observedIds.add(id);
          },
        )
        .subscribe((status) => {
          if (status === "SUBSCRIBED") channelState = "subscribed";
          if (status === "CHANNEL_ERROR" || status === "TIMED_OUT") channelState = "failed";
        });

      for (let attempt = 0; attempt < 8 && channelState === "connecting"; attempt += 1) {
        await wait(500);
      }
      const subscribed = channelState === "subscribed";

      const receipt = await sendMerchantTestNotification(client, store.id);
      expectedId = receipt.merchant_notification_id;

      const inApp = await fetchMerchantNotificationById(client, receipt.merchant_notification_id);
      next = {
        ...next,
        in_app: inApp
          ? { status: "pass", detail: "ได้รับรายการทดสอบแล้ว" }
          : { status: "fail", detail: "ไม่พบรายการทดสอบ" },
      };
      commitResults(next);

      if (subscribed) {
        for (let attempt = 0; attempt < 10 && expectedId && !observedIds.has(expectedId); attempt += 1) {
          await wait(500);
        }
      }
      const gotRealtime = subscribed && expectedId !== null && observedIds.has(expectedId);
      next = {
        ...next,
        realtime: gotRealtime
          ? { status: "pass", detail: "ได้รับแบบ Realtime แล้ว" }
          : { status: "warn", detail: subscribed ? "ไม่ได้รับ Realtime ภายในเวลาทดสอบ" : "เชื่อมต่อ Realtime ไม่สำเร็จ" },
      };
      commitResults(next);

      const webTokenCount = await countMerchantWebPushTokens(client, userId);
      if (!pushSetup.ok || webTokenCount === 0) {
        next = {
          ...next,
          web_push: {
            status: "warn",
            detail: pushSetup.ok ? "ไม่มีอุปกรณ์ Web Push ที่ลงทะเบียน" : pushReasonDescription(pushSetup.reason),
          },
          deep_link: {
            status: "warn",
            detail: "เปิด Web Push ก่อนเพื่อทดสอบ Deep Link",
          },
        };
      } else {
        let deliveries = await fetchMerchantPushDeliveries(client, receipt.push_notification_id);
        for (let attempt = 0; attempt < 8 && !deliveries.some((item) => ["sent", "failed", "skipped"].includes(item.status)); attempt += 1) {
          await wait(750);
          deliveries = await fetchMerchantPushDeliveries(client, receipt.push_notification_id);
        }

        const sent = deliveries.some((item) => item.status === "sent");
        const failed = deliveries.some((item) => item.status === "failed");
        const skipped = deliveries.some((item) => item.status === "skipped");
        next = {
          ...next,
          web_push: sent
            ? { status: "pass", detail: "ส่ง Push แล้ว" }
            : failed
              ? { status: "fail", detail: "ส่ง Push ไม่สำเร็จ" }
              : skipped
                ? { status: "warn", detail: "Push ถูกข้ามตามการตั้งค่า" }
                : { status: "warn", detail: "กำลังรอผล Push" },
          deep_link: sent
            ? { status: "running", detail: "แตะ Push ทดสอบที่ได้รับ เพื่อตรวจ Deep Link" }
            : { status: "warn", detail: "ต้องส่ง Push สำเร็จก่อนทดสอบ Deep Link" },
        };
      }
      commitResults(next);
      await onReload();
      onMessage("ส่งการแจ้งเตือนทดสอบแล้ว");
    } catch (error) {
      next = {
        ...next,
        in_app: next.in_app.status === "running"
          ? { status: "fail", detail: "ทดสอบการแจ้งเตือนไม่สำเร็จ" }
          : next.in_app,
        realtime: next.realtime.status === "running"
          ? { status: "warn", detail: "ยังตรวจสอบ Realtime ไม่ครบ" }
          : next.realtime,
        web_push: next.web_push.status === "running"
          ? { status: "warn", detail: "ยังตรวจสอบ Web Push ไม่ครบ" }
          : next.web_push,
        deep_link: next.deep_link.status === "running"
          ? { status: "warn", detail: "ยังตรวจสอบ Deep Link ไม่ครบ" }
          : next.deep_link,
      };
      commitResults(next);
      onMessage(error instanceof Error ? error.message : "ทดสอบการแจ้งเตือนไม่สำเร็จ");
    } finally {
      if (channel) await client.removeChannel(channel);
      setBusy(false);
    }
  };

  return (
    <section className="wm-core-section wm-notification-test">
      <div className="wm-core-section-head">
        <div>
          <BellRing size={20} />
          <span>
            <strong>ทดสอบการแจ้งเตือน</strong>
            <small>ตรวจสอบ In-App, Realtime, Web Push และ Deep Link ของอุปกรณ์นี้</small>
          </span>
        </div>
      </div>

      <p className="wm-notification-test-copy">ระบบทดสอบจะส่งเฉพาะบัญชีของคุณ และไม่สร้างออเดอร์จริง</p>

      <div className="wm-notification-test-grid">
        {TEST_ROWS.map(({ key, label, icon: Icon }) => (
          <div className={`wm-notification-test-row is-${results[key].status}`} key={key}>
            <span className="wm-notification-test-channel"><Icon size={17} /></span>
            <span>
              <strong>{label}</strong>
              <small>{results[key].detail}</small>
            </span>
            <span className="wm-test-status" aria-label={results[key].status}>
              <StatusIcon status={results[key].status} />
            </span>
          </div>
        ))}
      </div>

      <button className="wm-primary wm-full" type="button" disabled={busy} onClick={() => void runTest()}>
        {busy ? "กำลังทดสอบ…" : "ทดสอบทั้งหมด"}
      </button>
    </section>
  );
}
