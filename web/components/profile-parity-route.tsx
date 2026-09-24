"use client";

import { useRouter } from "next/navigation";
import { useMemo, useState, type MouseEvent } from "react";

import { ProfileRoute } from "@/components/profile-route";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

type ReportCategory = "spam" | "scam" | "harassment" | "hate" | "sexual_content" | "violence" | "privacy" | "illegal_content" | "copyright" | "other";

const categories: { value: ReportCategory; label: string }[] = [
  { value: "spam", label: "สแปม (Spam)" }, { value: "scam", label: "หลอกลวง (Scam)" },
  { value: "harassment", label: "คุกคาม/กลั่นแกล้ง (Harassment)" }, { value: "hate", label: "ความเกลียดชัง (Hate)" },
  { value: "sexual_content", label: "เนื้อหาทางเพศ (Sexual Content)" }, { value: "violence", label: "ความรุนแรง (Violence)" },
  { value: "privacy", label: "ละเมิดความเป็นส่วนตัว (Privacy)" }, { value: "illegal_content", label: "ผิดกฎหมาย (Illegal Content)" },
  { value: "copyright", label: "ละเมิดลิขสิทธิ์ (Copyright)" }, { value: "other", label: "อื่น ๆ (Other)" },
];

export function ProfileParityRoute({ profileId, fromTab = false }: { profileId: string; fromTab?: boolean }) {
  const router = useRouter();
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [menu, setMenu] = useState(false);
  const [reporting, setReporting] = useState(false);
  const [muted, setMuted] = useState(false);
  const [blocked, setBlocked] = useState(false);
  const [viewerId, setViewerId] = useState("");
  const [category, setCategory] = useState<ReportCategory>("spam");
  const [detail, setDetail] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [version, setVersion] = useState(0);

  const openMenu = async () => {
    if (!client) return;
    setError("");
    const auth = await client.auth.getUser();
    const me = auth.data.user?.id ?? "";
    setViewerId(me);
    if (!me || me === profileId) return;
    const [muteRow, blockRow] = await Promise.all([
      client.from("mutes").select("muted_id").eq("muter_id", me).eq("muted_id", profileId).maybeSingle(),
      client.from("blocks").select("blocked_id").eq("blocker_id", me).eq("blocked_id", profileId).maybeSingle(),
    ]);
    setMuted(Boolean(muteRow.data));
    setBlocked(Boolean(blockRow.data));
    setMenu(true);
  };

  const capture = (event: MouseEvent<HTMLDivElement>) => {
    const target = event.target;
    if (!(target instanceof Element)) return;
    const stat = target.closest<HTMLButtonElement>(".wyn-profile-stats button");
    if (stat) {
      event.preventDefault();
      event.stopPropagation();
      const text = stat.textContent ?? "";
      router.push(text.includes("ผู้ติดตาม") ? `/profile/${profileId}/followers` : `/profile/${profileId}/following`);
      return;
    }
    const more = target.closest<HTMLButtonElement>('button[aria-label="เพิ่มเติม"]');
    if (more) {
      event.preventDefault();
      event.stopPropagation();
      void openMenu();
    }
  };

  const toggleMute = async () => {
    if (!client || !viewerId || busy) return;
    setBusy(true); setError("");
    const result = muted
      ? await client.from("mutes").delete().eq("muter_id", viewerId).eq("muted_id", profileId)
      : await client.from("mutes").insert({ muter_id: viewerId, muted_id: profileId });
    if (result.error) setError("อัปเดตการปิดเสียงไม่สำเร็จ");
    else { setMuted(!muted); setMenu(false); setVersion((value) => value + 1); }
    setBusy(false);
  };

  const toggleBlock = async () => {
    if (!client || busy) return;
    if (!blocked && !window.confirm("บล็อกผู้ใช้นี้?")) return;
    setBusy(true); setError("");
    const result = await client.rpc(blocked ? "unblock_user" : "block_user", { p_target_user_id: profileId });
    if (result.error) setError(blocked ? "ปลดบล็อกไม่สำเร็จ" : "บล็อกไม่สำเร็จ");
    else { setBlocked(!blocked); setMenu(false); setVersion((value) => value + 1); }
    setBusy(false);
  };

  const submitReport = async () => {
    if (!client || busy) return;
    if (category === "other" && !detail.trim()) { setError("กรุณาระบุรายละเอียด"); return; }
    setBusy(true); setError("");
    const result = await client.rpc("submit_report", { p_target_type: "user", p_target_id: profileId, p_category: category, p_detail: category === "other" ? detail.trim() : null });
    if (result.error) setError(result.error.message || "ส่งรายงานไม่สำเร็จ");
    else { setReporting(false); setMenu(false); setDetail(""); }
    setBusy(false);
  };

  return <div className="profile-parity-boundary" onClickCapture={capture}>
    <ProfileRoute key={`${profileId}:${version}`} profileId={profileId} fromTab={fromTab} />
    {menu ? <div className="route-modal-backdrop audit-sheet-backdrop" role="presentation" onClick={() => setMenu(false)}><section className="audit-action-sheet profile-audit-sheet" role="dialog" aria-modal="true" aria-label="ตัวเลือกโปรไฟล์" onClick={(event) => event.stopPropagation()}><div className="audit-sheet-grip" /><header className="profile-audit-sheet-header"><strong>ตัวเลือกโปรไฟล์</strong><button type="button" aria-label="ปิด" onClick={() => setMenu(false)}><WynosIcon name="close" size={20} strokeWidth={2} /></button></header><button className="audit-sheet-row" type="button" onClick={() => setReporting(true)}><WynosIcon name="flag" size={20} strokeWidth={2} />รายงาน</button><button className="audit-sheet-row" type="button" disabled={busy} onClick={() => void toggleMute()}>{muted ? <WynosIcon name="voice" size={20} strokeWidth={2} /> : <WynosIcon name="voiceOff" size={20} strokeWidth={2} />}{muted ? "เปิดเสียง" : "ปิดเสียง"}</button><button className="audit-sheet-row danger" type="button" disabled={busy} onClick={() => void toggleBlock()}><WynosIcon name="userRoundX" size={20} strokeWidth={2} />{blocked ? "ปลดบล็อก" : "บล็อก"}</button>{error ? <p className="route-error audit-inline-error">{error}</p> : null}</section></div> : null}
    {reporting ? <div className="route-modal-backdrop audit-sheet-backdrop audit-report-layer" role="presentation" onClick={() => setReporting(false)}><section className="audit-action-sheet" role="dialog" aria-modal="true" aria-label="รายงานผู้ใช้นี้" onClick={(event) => event.stopPropagation()}><div className="audit-sheet-grip" /><div className="audit-sheet-form"><strong>รายงานผู้ใช้นี้</strong><div className="audit-report-list">{categories.map((item) => <label key={item.value}><input type="radio" name="profile-report-category" checked={category === item.value} onChange={() => setCategory(item.value)} />{item.label}</label>)}</div>{category === "other" ? <textarea maxLength={1000} value={detail} onChange={(event) => setDetail(event.target.value)} placeholder="รายละเอียดเพิ่มเติม" /> : null}{error ? <p className="route-error">{error}</p> : null}<button className="route-primary" type="button" disabled={busy} onClick={() => void submitReport()}>ส่งรายงาน</button></div></section></div> : null}
  </div>;
}
