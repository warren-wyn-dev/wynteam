"use client";

// ZOKY-LINE-001: the /line LIFF endpoint.
//   /line?to=/food?order=WF0015      LINE message button -> open that page.
//   /line?mode=link&oa=food|merchant  manage "รับแจ้งเตือนทาง LINE".
// The ZOKY session comes from the existing shared browser client. The LINE
// userId is never sent: only LINE's ID token, which line-link verifies.
import { useCallback, useEffect, useRef, useState } from "react";
import type { Liff } from "@line/liff";

import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import {
  configuredLiffIds,
  lineAudienceFor,
  lineLinkPath,
  lineLinkStatusFrom,
  lineStatusText,
  liffIdFor,
  safeLineDestination,
  type LineAudience,
  type LineLinkStatus,
} from "@/lib/line-liff";
import { rememberReturnPath } from "@/lib/return-to";

type View =
  | { kind: "loading" }
  | { kind: "not_configured" }
  | { kind: "need_signin"; inLine: boolean }
  | { kind: "ready"; status: LineLinkStatus }
  | { kind: "error"; message: string };

const LINKING_FLAG = "zoky.line-linking.v1";

let liffPromise: Promise<Liff> | null = null;
function loadLiff(liffId: string): Promise<Liff> {
  liffPromise ??= import("@line/liff").then(async ({ default: liff }) => {
    await liff.init({ liffId });
    return liff;
  });
  return liffPromise;
}

function setFlag(on: boolean) {
  try {
    if (on) window.sessionStorage.setItem(LINKING_FLAG, String(Date.now()));
    else window.sessionStorage.removeItem(LINKING_FLAG);
  } catch { /* storage unavailable */ }
}
function hasFreshFlag(): boolean {
  try {
    const at = Number(window.sessionStorage.getItem(LINKING_FLAG));
    return Number.isFinite(at) && Date.now() - at < 10 * 60 * 1000;
  } catch {
    return false;
  }
}

const ERRORS: Record<string, string> = {
  invalid_line_token: "ยืนยันบัญชี LINE ไม่สำเร็จ กรุณาลองใหม่",
  line_disabled: "การแจ้งเตือนทาง LINE ยังไม่เปิดใช้งาน",
  line_not_configured: "การแจ้งเตือนทาง LINE ยังไม่เปิดใช้งาน",
  unauthorized: "กรุณาเข้าสู่ระบบ ZOKY ใหม่อีกครั้ง",
};

export function LineEntry() {
  const [view, setView] = useState<View>({ kind: "loading" });
  const [busy, setBusy] = useState(false);
  const [audience, setAudience] = useState<LineAudience>("food");
  const context = useRef<{ audience: LineAudience; liffId: string } | null>(null);

  const callLineLink = useCallback(async (body: Record<string, unknown>): Promise<LineLinkStatus> => {
    const client = getSupabaseBrowserClient();
    if (!client) throw new Error("line_not_configured");
    const { data, error } = await client.functions.invoke("line-link", { body });
    if (error) {
      const code = await (error as { context?: Response }).context?.json?.().then((value: { error?: string }) => value.error).catch(() => null);
      throw new Error(code ?? "request_failed");
    }
    const status = lineLinkStatusFrom(data);
    if (!status) throw new Error("request_failed");
    return status;
  }, []);

  const link = useCallback(async () => {
    const current = context.current;
    if (!current) return;
    setBusy(true);
    try {
      const liff = await loadLiff(current.liffId);
      if (!liff.isLoggedIn()) {
        setFlag(true);
        liff.login({ redirectUri: `${window.location.origin}${lineLinkPath(current.audience)}` });
        return;
      }
      setFlag(false);
      const idToken = liff.getIDToken();
      if (!idToken) throw new Error("invalid_line_token");
      const status = await callLineLink({ action: "link", audience: current.audience, idToken });
      setView({ kind: "ready", status });
    } catch (error) {
      setFlag(false);
      const code = error instanceof Error ? error.message : "";
      setView({ kind: "error", message: ERRORS[code] ?? "เชื่อม LINE ไม่สำเร็จ กรุณาลองใหม่" });
    } finally {
      setBusy(false);
    }
  }, [callLineLink]);

  const unlink = useCallback(async () => {
    const current = context.current;
    if (!current) return;
    setBusy(true);
    try {
      setView({ kind: "ready", status: await callLineLink({ action: "unlink", audience: current.audience }) });
    } catch {
      setView({ kind: "error", message: "ยกเลิกการเชื่อม LINE ไม่สำเร็จ กรุณาลองใหม่" });
    } finally {
      setBusy(false);
    }
  }, [callLineLink]);

  useEffect(() => {
    let live = true;
    (async () => {
      const params = new URLSearchParams(window.location.search);
      const audience = lineAudienceFor(window.location.hostname, params.get("oa"));
      const liffId = liffIdFor(audience, configuredLiffIds());
      if (!liffId) {
        if (params.get("mode") !== "link") window.location.replace(safeLineDestination(audience, params.get("to")));
        else if (live) setView({ kind: "not_configured" });
        return;
      }
      context.current = { audience, liffId };
      if (live) setAudience(audience);

      if (params.get("mode") !== "link") {
        // LINE message button. liff.init finishes LIFF's own liff.state
        // redirect; afterwards only an allowlisted in-app path is opened.
        try { await loadLiff(liffId); } catch { /* still open the page */ }
        if (params.has("liff.state")) return;
        window.location.replace(safeLineDestination(audience, params.get("to")));
        return;
      }

      const client = getSupabaseBrowserClient();
      const { data } = client ? await client.auth.getSession() : { data: { session: null } };
      if (!data.session) {
        let inLine = false;
        try { inLine = (await loadLiff(liffId)).isInClient(); } catch { /* not in LINE */ }
        if (audience === "merchant") rememberReturnPath(lineLinkPath(audience));
        if (live) setView({ kind: "need_signin", inLine });
        return;
      }

      // Back from LINE Login: finish the link the user started.
      if (hasFreshFlag()) {
        await link();
        return;
      }
      try {
        const status = await callLineLink({ action: "status", audience });
        if (live) setView({ kind: "ready", status });
      } catch (error) {
        const code = error instanceof Error ? error.message : "";
        if (!live) return;
        if (code === "line_disabled" || code === "line_not_configured") setView({ kind: "not_configured" });
        else setView({ kind: "error", message: ERRORS[code] ?? "โหลดสถานะ LINE ไม่สำเร็จ" });
      }
    })();
    return () => { live = false; };
  }, [callLineLink, link]);

  const appName = audience === "merchant" ? "ZOKY Merchant" : "ZOKY";
  const backHref = `/${audience}`;

  return (
    <main className="zl-page">
      <section className="zl-card" aria-live="polite">
        <span className="zl-badge" aria-hidden="true">LINE</span>
        <h1>รับแจ้งเตือนทาง LINE</h1>
        <p className="zl-sub">
          {audience === "merchant"
            ? "ร้านได้รับแจ้งออเดอร์ใหม่ ลูกค้ายกเลิก และเงินเข้า ผ่าน LINE OA ของ ZOKY Merchant"
            : "รับแจ้งสถานะออเดอร์ การชำระเงิน และการคืนเงิน ผ่าน LINE OA ของ ZOKY"}
        </p>

        {view.kind === "loading" ? <p className="zl-status">กำลังโหลด…</p> : null}

        {view.kind === "not_configured" ? <p className="zl-status">การแจ้งเตือนทาง LINE ยังไม่เปิดใช้งาน</p> : null}

        {view.kind === "need_signin" ? (
          <>
            <p className="zl-status">เข้าสู่ระบบ {appName} ในเบราว์เซอร์นี้ก่อน แล้วกลับมาเชื่อม LINE</p>
            {view.inLine ? (
              <p className="zl-note">ในแอป LINE เข้าสู่ระบบด้วย Google ไม่ได้ ใช้อีเมลและรหัสผ่าน หรือเปิดในเบราว์เซอร์ของเครื่อง</p>
            ) : null}
            <a className="zl-primary" href={`/${audience}/login`}>เข้าสู่ระบบ</a>
            {view.inLine ? (
              <button
                className="zl-secondary"
                type="button"
                onClick={() => {
                  const liffId = context.current?.liffId;
                  if (liffId) void loadLiff(liffId).then((liff) => liff.openWindow({ url: window.location.href, external: true }));
                }}
              >เปิดในเบราว์เซอร์</button>
            ) : null}
          </>
        ) : null}

        {view.kind === "ready" ? (
          <>
            <p className={`zl-status ${view.status.linked ? "is-on" : ""}`}>{lineStatusText(view.status)}</p>
            {view.status.linked && view.status.friendStatus === "not_friend" && view.status.addFriendUrl ? (
              <a className="zl-primary" href={view.status.addFriendUrl} target="_blank" rel="noreferrer">เพิ่มเพื่อน LINE OA</a>
            ) : null}
            {view.status.linked ? (
              <button className="zl-secondary" type="button" disabled={busy} onClick={() => void unlink()}>ยกเลิกการเชื่อม LINE</button>
            ) : (
              <>
                <button className="zl-primary" type="button" disabled={busy} onClick={() => void link()}>
                  {busy ? "กำลังเชื่อม…" : "เชื่อม LINE"}
                </button>
                {view.status.addFriendUrl ? (
                  <a className="zl-secondary" href={view.status.addFriendUrl} target="_blank" rel="noreferrer">เพิ่มเพื่อน LINE OA</a>
                ) : null}
              </>
            )}
            <p className="zl-note">เชื่อมแล้วยังได้รับ Web Push ตามเดิม · ZOKY เก็บเฉพาะรหัสผู้ใช้ LINE เพื่อส่งข้อความ และลบทันทีเมื่อยกเลิก</p>
          </>
        ) : null}

        {view.kind === "error" ? (
          <>
            <p className="zl-status is-error" role="alert">{view.message}</p>
            <button className="zl-secondary" type="button" onClick={() => window.location.reload()}>ลองใหม่</button>
          </>
        ) : null}

        <a className="zl-back" href={backHref}>กลับไป {appName}</a>
      </section>
    </main>
  );
}
