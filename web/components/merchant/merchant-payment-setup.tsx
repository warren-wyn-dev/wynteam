"use client";

import { Check, ChevronRight, CircleDollarSign, X } from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useEffect, useRef, useState } from "react";

import {
  createMerchantStripeSession,
  refreshMerchantStripeStatus,
  startMerchantStripeOnboarding,
  type MerchantStripeStatus,
} from "@/lib/merchant-core";

type ConnectElement = HTMLElement & {
  setOnLoaderStart?: (handler: () => void) => void;
};
type ConnectInstance = {
  create: (name: "account-onboarding" | "account-management") => ConnectElement;
};
type StripeConnectGlobal = {
  init: (options: {
    publishableKey: string;
    fetchClientSecret: () => Promise<string>;
    locale?: string;
    appearance?: Record<string, unknown>;
  }) => ConnectInstance;
};
declare global {
  interface Window {
    StripeConnect?: StripeConnectGlobal;
  }
}

const CONNECT_JS = "https://connect-js.stripe.com/v1.0/connect.js";
let connectLoader: Promise<StripeConnectGlobal> | null = null;

function loadConnectJs() {
  if (typeof window === "undefined") return Promise.reject(new Error("browser_required"));
  if (window.StripeConnect?.init) return Promise.resolve(window.StripeConnect);
  if (connectLoader) return connectLoader;
  connectLoader = new Promise<StripeConnectGlobal>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(`script[src="${CONNECT_JS}"]`);
    const script = existing ?? document.createElement("script");
    const ready = () => window.StripeConnect?.init ? resolve(window.StripeConnect) : reject(new Error("connect_js_unavailable"));
    script.addEventListener("load", ready, { once: true });
    script.addEventListener("error", () => reject(new Error("connect_js_load_failed")), { once: true });
    if (!existing) {
      script.src = CONNECT_JS;
      script.async = true;
      document.head.appendChild(script);
    } else if (window.StripeConnect?.init) {
      ready();
    }
  });
  return connectLoader;
}

function statusText(status: MerchantStripeStatus | null) {
  if (!status?.connected) return null;
  if (status.status === "ready") return "พร้อมรับเงิน";
  if (status.status === "restricted") return "มีปัญหา กรุณาดำเนินการต่อ";
  if (status.requirements_due || status.status === "onboarding") return "ต้องยืนยันข้อมูล";
  return "กำลังตั้งค่า";
}
function payoutText(status: MerchantStripeStatus | null) {
  if (!status?.payout_interval) return "อัตโนมัติ";
  if (status.payout_interval === "daily") return "อัตโนมัติ";
  if (status.payout_interval === "weekly") return "อัตโนมัติ · ตามรอบรายสัปดาห์";
  if (status.payout_interval === "monthly") return "อัตโนมัติ · ตามรอบรายเดือน";
  if (status.payout_interval === "manual") return "ตามรอบที่บัญชีนี้รองรับ";
  return "อัตโนมัติ";
}
function bankText(status: MerchantStripeStatus | null) {
  if (!status?.bank_ready) return "กำลังรอยืนยันบัญชีรับเงิน";
  return `${status.bank_name || "บัญชีธนาคาร"} ${status.bank_last4 ? `•••• ${status.bank_last4}` : ""}`.trim();
}

export function MerchantPaymentSetup({
  client,
  storeId,
  status,
  onStatus,
  onMessage,
  onReady,
}: {
  client: SupabaseClient;
  storeId: string;
  status: MerchantStripeStatus | null;
  onStatus: (status: MerchantStripeStatus) => void;
  onMessage: (message: string) => void;
  onReady: () => Promise<void> | void;
}) {
  const [busy, setBusy] = useState(false);
  const [panel, setPanel] = useState<"account_onboarding" | "account_management" | null>(null);
  const [componentLoading, setComponentLoading] = useState(false);
  const mountRef = useRef<HTMLDivElement>(null);

  const sync = async () => {
    const next = await refreshMerchantStripeStatus(client, storeId);
    onStatus(next);
    if (next.status === "ready") await onReady();
    return next;
  };

  const openEmbedded = async (component: "account_onboarding" | "account_management") => {
    setPanel(component);
    setComponentLoading(true);
    const first = await createMerchantStripeSession(client, storeId, component);
    const StripeConnect = await loadConnectJs();
    let initialSecret: string | null = first.clientSecret;
    const instance = StripeConnect.init({
      publishableKey: first.publishableKey,
      locale: "th-TH",
      appearance: {
        overlays: "dialog",
        variables: {
          colorPrimary: "#111111",
          borderRadius: "14px",
          fontFamily: "inherit",
        },
      },
      fetchClientSecret: async () => {
        if (initialSecret) {
          const value = initialSecret;
          initialSecret = null;
          return value;
        }
        return (await createMerchantStripeSession(client, storeId, component)).clientSecret;
      },
    });
    const element = instance.create(component === "account_management" ? "account-management" : "account-onboarding");
    element.setOnLoaderStart?.(() => setComponentLoading(false));
    if (!mountRef.current) return;
    mountRef.current.replaceChildren(element);
    setComponentLoading(false);
  };

  const start = async (manage = false) => {
    if (busy) return;
    setBusy(true);
    try {
      if (manage && status?.connected) {
        await openEmbedded("account_management");
        return;
      }
      const result = await startMerchantStripeOnboarding(client, storeId);
      onStatus(result.status);
      if (result.url) {
        window.location.assign(result.url);
        return;
      }
      if (result.flow === "embedded") {
        await openEmbedded(result.status.status === "ready" ? "account_management" : "account_onboarding");
        return;
      }
      if (result.status.status === "ready") {
        onMessage("พร้อมรับเงินแล้ว");
        await onReady();
      }
    } catch (error) {
      onMessage(error instanceof Error ? error.message : "เปิดรับชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
      setPanel(null);
    } finally {
      setBusy(false);
    }
  };

  useEffect(() => {
    if (!panel) return;
    let active = true;
    const timer = window.setInterval(() => {
      void sync().then((next) => {
        if (!active) return;
        if (next.status === "ready" && panel === "account_onboarding") {
          onMessage("พร้อมรับเงินแล้ว");
          setPanel(null);
        }
      }).catch(() => {});
    }, 4000);
    return () => { active = false; window.clearInterval(timer); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [panel, storeId]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const current = new URL(window.location.href);
    const stripeReturn = current.searchParams.get("stripe");
    const returnedStore = current.searchParams.get("store");
    if (!["return","refresh"].includes(stripeReturn ?? "") || (returnedStore && returnedStore !== storeId)) return;

    current.searchParams.delete("stripe");
    current.searchParams.delete("store");
    window.history.replaceState(window.history.state, "", `${current.pathname}${current.search}${current.hash}`);

    if (stripeReturn === "refresh") {
      void start(false);
      return;
    }
    setBusy(true);
    void sync()
      .then((next) => {
        onMessage(next.status === "ready" ? "พร้อมรับเงินแล้ว" : "บันทึกข้อมูลแล้ว หากยังมีข้อมูลที่ต้องยืนยันสามารถดำเนินการต่อได้");
      })
      .catch(() => onMessage("อัปเดตสถานะการรับเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง"))
      .finally(() => setBusy(false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [storeId]);

  const label = statusText(status);
  const ready = status?.status === "ready";

  return (
    <div className="wm-payment-setup">
      {label ? <div className={ready ? "wm-payment-state is-ready" : status?.status === "restricted" ? "wm-payment-state is-error" : "wm-payment-state"}>
        {ready ? <Check size={16} /> : <CircleDollarSign size={16} />}
        <strong>{label}</strong>
      </div> : null}

      <div className="wm-payment-copy">
        <strong>{ready ? "รับบัตรและ PromptPay" : "รับเงินจากลูกค้าได้สะดวกผ่านบัตรและ PromptPay"}</strong>
        <small>{ready ? "เงินจะโอนเข้าบัญชีธนาคารของร้านอัตโนมัติ" : "เมื่อเปิดใช้งานแล้ว เงินจะถูกโอนเข้าบัญชีของร้านอัตโนมัติ"}</small>
      </div>

      {ready ? (
        <div className="wm-payment-summary">
          <div><span>บัญชีรับเงิน</span><strong>{bankText(status)}</strong>{status.bank_ready ? <small>พร้อมรับเงิน</small> : null}</div>
          <div><span>รอบโอนเงิน</span><strong>{payoutText(status)}</strong><small>Stripe จะใช้รอบที่เร็วที่สุดที่บัญชีนี้รองรับ</small></div>
        </div>
      ) : null}

      {!status?.connected ? (
        <button className="wm-primary wm-full wm-payment-main" type="button" disabled={busy} onClick={() => void start(false)}>
          {busy ? "กำลังตั้งค่า…" : "เปิดรับชำระเงิน"}
        </button>
      ) : ready ? (
        <button className="wm-secondary wm-full wm-payment-manage" type="button" disabled={busy} onClick={() => void start(true)}>
          จัดการข้อมูลรับเงิน <ChevronRight size={16} />
        </button>
      ) : (
        <button className="wm-primary wm-full wm-payment-main" type="button" disabled={busy} onClick={() => void start(false)}>
          {busy ? "กำลังเปิด…" : "ดำเนินการต่อ"}
        </button>
      )}

      {panel ? (
        <div className="wm-connect-panel" role="dialog" aria-modal="true" aria-label={panel === "account_management" ? "จัดการข้อมูลรับเงิน" : "ยืนยันข้อมูลรับเงิน"}>
          <div className="wm-connect-panel-head">
            <span><strong>{panel === "account_management" ? "จัดการข้อมูลรับเงิน" : "ยืนยันข้อมูลเพื่อรับเงิน"}</strong><small>ข้อมูลสำคัญจะถูกส่งให้ผู้ให้บริการชำระเงินโดยตรง</small></span>
            <button type="button" aria-label="ปิด" onClick={() => { setPanel(null); void sync().catch(() => {}); }}><X size={20} /></button>
          </div>
          {componentLoading ? <div className="wm-connect-loading"><span className="wm-mini-loader" /><small>กำลังเปิดแบบฟอร์มที่ปลอดภัย…</small></div> : null}
          <div ref={mountRef} className="wm-connect-mount" />
        </div>
      ) : null}
    </div>
  );
}
