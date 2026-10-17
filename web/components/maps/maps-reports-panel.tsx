"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState, useTransition, type CSSProperties } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { WynosMapsAddressPicker } from "@/app/maps/wynos-maps-address-picker";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import {
  loadMyMapReports, mapReportErrorCopy, mapReportKinds, mapReportStatuses,
  searchReportableMapPlaces, submitMapReport, type MapReportKind, type MyMapReport, type ReportableMapPlace,
} from "@/lib/maps-reports";

function useReportAccount() {
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [account, setAccount] = useState<{ userId?: string; ready: boolean; allowed: boolean }>({ ready: false, allowed: false });
  useEffect(() => {
    if (!client) return;
    const connectedClient = client;
    let live = true;
    let request = 0;
    let authEvent = false;
    let timer: number | undefined;
    function check(userId?: string) {
      const current = ++request;
      setAccount(previous => previous.userId === userId && previous.ready ? previous : { userId, ready: !userId, allowed: false });
      if (!userId) return;
      void connectedClient.rpc("is_developer_account").abortSignal(AbortSignal.timeout(10_000)).then(({ data, error }) => {
        if (live && current === request) setAccount({ userId, ready: true, allowed: !error && data === true });
      }, () => { if (live && current === request) setAccount({ userId, ready: true, allowed: false }); });
    }
    const { data: listener } = client.auth.onAuthStateChange((_event, session) => {
      authEvent = true;
      // Preserve an existing account's draft through routine token refreshes.
      // Clear immediately on identity changes; run SDK work outside its auth lock.
      const userId = session?.user.id;
      setAccount(previous => previous.userId === userId && previous.ready ? previous : { userId, ready: !userId, allowed: false });
      ++request;
      window.clearTimeout(timer);
      timer = window.setTimeout(() => { if (live) check(session?.user.id); }, 0);
    });
    void client.auth.getSession().then(({ data }) => { if (live && !authEvent) check(data.session?.user.id); }, () => {
      if (live && !authEvent) setAccount({ ready: true, allowed: false });
    });
    return () => { live = false; ++request; window.clearTimeout(timer); listener.subscription.unsubscribe(); };
  }, [client]);
  return { client, ...account, ready: !client || account.ready };
}

export function MapsReportsLink() {
  const { allowed } = useReportAccount();
  if (!allowed) return null;
  return <Link href="/maps/reports" style={{ position: "fixed", zIndex: 34, top: "calc(env(safe-area-inset-top) + 70px)", left: 16,
    minHeight: 44, display: "flex", alignItems: "center", padding: "8px 12px", borderRadius: 18, background: "#fff", color: "#222", boxShadow: "0 3px 16px #0002", fontSize: 12 }}>
    แจ้งปัญหาสถานที่
  </Link>;
}

export function MapsReportsPage() {
  const { client, userId, ready, allowed } = useReportAccount();
  if (!ready) return <main style={{ padding: 24 }}><p role="status">กำลังตรวจสอบบัญชี…</p></main>;
  // Preserve the Maps experience for accounts outside the existing staged rollout.
  if (!allowed || !client || !userId) return <WynosMapsAddressPicker />;
  return <MapsReportsPanel key={userId} client={client} />;
}

export function MapsReportsPanel({ client }: { client: SupabaseClient }) {
  const [query, setQuery] = useState("");
  const [places, setPlaces] = useState<ReportableMapPlace[]>([]);
  const [selected, setSelected] = useState<ReportableMapPlace | null>(null);
  const [searched, setSearched] = useState(false);
  const [kind, setKind] = useState<MapReportKind>("wrong_info");
  const [note, setNote] = useState("");
  const [reports, setReports] = useState<MyMapReport[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [busy, startTransition] = useTransition();
  const loadRequest = useRef(0);
  useEffect(() => {
    let live = true;
    const request = ++loadRequest.current;
    void loadMyMapReports(client).then(items => { if (live && request === loadRequest.current) { setReports(items); setLoaded(true); } })
      .catch(failure => { if (live && request === loadRequest.current) setError(mapReportErrorCopy(failure)); });
    return () => { live = false; };
  }, [client]);
  function search() {
    if (busy || query.trim().length < 2) return;
    setError(""); setSuccess(""); setSelected(null); setPlaces([]); setSearched(false);
    startTransition(async () => {
      try { setPlaces(await searchReportableMapPlaces(client, query)); setSearched(true); }
      catch (failure) { setError(mapReportErrorCopy(failure)); }
    });
  }
  function refresh() {
    ++loadRequest.current;
    setError("");
    startTransition(async () => {
      try { setReports(await loadMyMapReports(client)); setLoaded(true); }
      catch (failure) { setLoaded(false); setError(mapReportErrorCopy(failure)); }
    });
  }
  function submit() {
    if (!selected || busy || note.trim().length < 10) return;
    const place = selected;
    ++loadRequest.current;
    setError(""); setSuccess("");
    startTransition(async () => {
      try {
        const id = await submitMapReport(client, place.id, kind, note);
        const now = new Date().toISOString();
        const report: MyMapReport = { id, place_id: place.id, place_name: place.name_th, kind, status: "open", created_at: now, updated_at: now };
        setReports(previous => [report, ...previous].slice(0, 50));
        setLoaded(true); setNote(""); setSuccess("ส่งรายงานแล้ว เจ้าหน้าที่จะตรวจสอบและอัปเดตสถานะให้คุณ");
      } catch (failure) { setError(mapReportErrorCopy(failure)); }
    });
  }
  return <main className="maps-reports-page" style={{ maxWidth: 720, margin: "0 auto", padding: "max(24px, env(safe-area-inset-top)) 20px 40px", color: "#222", background: "#fff", minHeight: "100dvh", display: "grid", alignContent: "start", gap: 24 }}>
    <header style={{ display: "grid", gap: 10 }}><Link href="/maps" style={{ minHeight: 44, display: "flex", alignItems: "center" }}>← กลับ WYNOS Maps</Link>
      <h1 style={{ fontSize: 24, fontWeight: 750 }}>แจ้งปัญหาสถานที่</h1>
      <p>เลือกสถานที่สาธารณะบน WYNOS แล้วส่งข้อมูลให้เจ้าหน้าที่ตรวจสอบ</p>
      <p style={{ fontSize: 13, color: "#555" }}>ไม่ต้องแนบรูป ตำแหน่งส่วนตัว ประวัติการเดินทาง เบอร์โทร อีเมล หรือข้อมูลติดต่อ กรณีเร่งด่วนให้ติดต่อหน่วยงานฉุกเฉินโดยตรง</p>
    </header>
    <section style={sectionStyle} aria-label="เลือกสถานที่สาธารณะ">
      <form onSubmit={event => { event.preventDefault(); search(); }} style={{ display: "grid", gap: 12 }}>
        <label>ชื่อสถานที่ (อย่างน้อย 2 ตัวอักษร)<input style={inputStyle} value={query} minLength={2} maxLength={100} required disabled={busy} onChange={event => setQuery(event.target.value)} /></label>
        <button type="submit" disabled={busy || query.trim().length < 2} style={buttonStyle}>{busy ? "กำลังดำเนินการ…" : "ค้นหาสถานที่"}</button>
      </form>
      {searched && !places.length && <p role="status">ไม่พบสถานที่สาธารณะในชื่อนี้ ลองใช้ชื่ออื่น</p>}
      {places.length > 0 && <fieldset style={{ display: "grid", gap: 8, border: 0, padding: 0 }}><legend>เลือกสถานที่ที่ต้องการแจ้ง (สูงสุด 10 แห่ง)</legend>
        {places.map(place => <label key={place.id} style={{ padding: 12, border: "1px solid #ddd", borderRadius: 12, display: "flex", gap: 10, minHeight: 44 }}>
          <input type="radio" name="report-place" checked={selected?.id === place.id} disabled={busy} onChange={() => { setSelected(place); setSuccess(""); }} />
          <span><strong data-i18n-skip>{place.name_th}</strong>{place.address && <span data-i18n-skip style={{ display: "block", fontSize: 12, color: "#555" }}>{place.address}</span>}</span>
        </label>)}
      </fieldset>}
    </section>
    {selected && <form style={sectionStyle} onSubmit={event => { event.preventDefault(); submit(); }}>
      <h2 style={{ fontWeight: 700 }}>แจ้งปัญหา: <span data-i18n-skip>{selected.name_th}</span></h2>
      <label>ประเภทปัญหา<select value={kind} disabled={busy} onChange={event => setKind(event.target.value as MapReportKind)} style={inputStyle}>
        {Object.entries(mapReportKinds).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
      </select></label>
      <label>รายละเอียด (10–500 ตัวอักษร)<textarea required rows={4} minLength={10} maxLength={500} value={note} disabled={busy} onChange={event => setNote(event.target.value)} style={inputStyle} /></label>
      <p style={{ fontSize: 12 }}>รายงานนี้รอการตรวจสอบโดยเจ้าหน้าที่ การส่งรายงานไม่เปลี่ยนข้อมูลหรือซ่อนสถานที่อัตโนมัติ · สูงสุด 5 เรื่องใน 24 ชั่วโมง</p>
      <button type="submit" disabled={busy || note.trim().length < 10} style={buttonStyle}>{busy ? "กำลังส่ง…" : "ส่งรายงาน"}</button>
    </form>}
    {error && <p role="alert" style={{ color: "#b42318" }}>{error}</p>}{success && <p role="status">{success}</p>}
    <section style={sectionStyle} aria-label="รายงานของฉัน"><h2 style={{ fontWeight: 700 }}>รายงานของฉัน (ล่าสุด 50 เรื่อง)</h2>
      <button disabled={busy} type="button" onClick={refresh} style={buttonStyle}>โหลดสถานะล่าสุด</button>
      {!reports.length && <p>{loaded ? "ยังไม่มีรายงาน" : "กำลังโหลดรายงาน หรือกดโหลดสถานะล่าสุดเพื่อลองอีกครั้ง"}</p>}
      <ol style={{ display: "grid", gap: 12, listStyle: "none", padding: 0 }}>{reports.map(report => <li key={report.id} style={{ borderTop: "1px solid #eee", paddingTop: 12 }}>
        <strong data-i18n-skip>{report.place_name}</strong><p>{mapReportKinds[report.kind]} · {mapReportStatuses[report.status]}</p>
        <p style={{ fontSize: 12, color: "#555" }}>อัปเดต {new Date(report.updated_at).toLocaleString("th-TH", { timeZone: "Asia/Bangkok" })}</p>
      </li>)}</ol>
    </section>
  </main>;
}
const sectionStyle: CSSProperties = { display: "grid", gap: 14, border: "1px solid #ddd", borderRadius: 18, padding: 18 };
const inputStyle: CSSProperties = { display: "block", width: "100%", minHeight: 44, border: "1px solid #ccc", borderRadius: 10, padding: 10, marginTop: 6, background: "#fff", color: "#222", font: "inherit" };
const buttonStyle: CSSProperties = { minHeight: 44, border: "1px solid #ccc", borderRadius: 12, padding: "10px 14px", background: "#fff", color: "#222", fontWeight: 600 };
