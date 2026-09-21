"use client";

import { Heart, MoreHorizontal, Sparkles, UserRound, X } from "lucide-react";
import Link from "next/link";
import { Fragment, useCallback, useEffect, useMemo, useState } from "react";
import type { RealtimeChannel, SupabaseClient } from "@supabase/supabase-js";

import { Avatar } from "@/components/phase3-ui";
import type { ProfileRow } from "@/lib/phase3-data";
import {
  fetchWynii,
  startWynii,
  subscribeWyniiMessages,
  wyniiNextMilestone,
  wyniiStage,
  wyniiStageLabel,
  type WyniiRow,
  type WyniiStage,
} from "@/lib/wynii";

import styles from "./wynii-chat.module.css";

type Props = {
  client: SupabaseClient;
  userId: string;
  conversationId: string;
  other: ProfileRow;
  displayName: string;
  canStart: boolean;
  online: boolean;
  onOpenProfile: () => void;
};

type Status = {
  short: string;
  detail: string;
  mineDone: boolean;
  otherDone: boolean;
};

function WyniiGlyph({ stage, className }: { stage: WyniiStage; className?: string }) {
  if (stage === "egg" || stage === "hatching") {
    return (
      <svg className={className} viewBox="0 0 64 64" aria-hidden="true">
        <defs>
          <linearGradient id={`wynii-egg-${stage}`} x1="8" y1="6" x2="56" y2="58" gradientUnits="userSpaceOnUse">
            <stop stopColor="#fff" />
            <stop offset=".48" stopColor="#ece9ff" />
            <stop offset="1" stopColor="#b9d7ff" />
          </linearGradient>
          <linearGradient id={`wynii-core-${stage}`} x1="22" y1="22" x2="43" y2="43" gradientUnits="userSpaceOnUse">
            <stop stopColor="#cab9ff" />
            <stop offset="1" stopColor="#83c8ff" />
          </linearGradient>
        </defs>
        <path d="M32 5C19 5 10 24 10 39c0 12 9 20 22 20s22-8 22-20C54 24 45 5 32 5Z" fill={`url(#wynii-egg-${stage})`} stroke="#d8d5e7" strokeWidth="2" />
        {stage === "hatching" ? <path d="m15 32 8-5 6 6 7-9 6 8 8-4" fill="none" stroke="#a89bd0" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" /> : null}
        <path d="M32 24c-4-6-13-2-11 5 1 5 7 9 11 12 4-3 10-7 11-12 2-7-7-11-11-5Z" fill={`url(#wynii-core-${stage})`} opacity=".96" />
        <circle cx="32" cy="31" r="3" fill="#fff" opacity=".85" />
      </svg>
    );
  }

  const grown = stage === "growing" || stage === "mature" || stage === "max";
  const mature = stage === "mature" || stage === "max";
  const max = stage === "max";
  return (
    <svg className={className} viewBox="0 0 180 180" aria-hidden="true">
      <defs>
        <radialGradient id={`wynii-body-${stage}`} cx="50%" cy="38%" r="68%">
          <stop stopColor="#fff" />
          <stop offset=".65" stopColor="#fbfbff" />
          <stop offset="1" stopColor="#e9ecff" />
        </radialGradient>
        <linearGradient id={`wynii-glow-${stage}`} x1="52" y1="52" x2="132" y2="142" gradientUnits="userSpaceOnUse">
          <stop stopColor="#c5aef9" />
          <stop offset=".5" stopColor="#91c9ff" />
          <stop offset="1" stopColor="#c4a9ef" />
        </linearGradient>
        <radialGradient id={`wynii-eye-${stage}`} cx="50%" cy="35%" r="70%">
          <stop stopColor="#d6c8ff" />
          <stop offset=".42" stopColor="#6e78d8" />
          <stop offset="1" stopColor="#25244a" />
        </radialGradient>
      </defs>
      {grown ? <path d={mature ? "M139 111c23 1 31 21 18 34-10 10-25 1-29-8 6 3 16 2 18-5 2-7-5-13-14-13Z" : "M138 116c17 3 23 17 13 27-8 8-19 1-22-6 5 2 11 1 13-4 2-5-3-9-10-10Z"} fill={`url(#wynii-glow-${stage})`} opacity={max ? 1 : .78} /> : null}
      <path d="M55 55 30 33c-4-4-10 0-8 6l11 34Z" fill={`url(#wynii-body-${stage})`} stroke="#dddff0" strokeWidth="2" />
      <path d="m125 55 25-22c4-4 10 0 8 6l-11 34Z" fill={`url(#wynii-body-${stage})`} stroke="#dddff0" strokeWidth="2" />
      {mature ? <path d="M48 56 31 43l7 25Z" fill={`url(#wynii-glow-${stage})`} opacity=".72" /> : null}
      {mature ? <path d="m132 56 17-13-7 25Z" fill={`url(#wynii-glow-${stage})`} opacity=".72" /> : null}
      <ellipse cx="90" cy="96" rx={grown ? 58 : 53} ry={grown ? 61 : 56} fill={`url(#wynii-body-${stage})`} stroke="#e0e1ef" strokeWidth="2" />
      {max ? <path d="M75 42c6-12 24-12 30 0-7-3-10 1-15 7-5-6-8-10-15-7Z" fill={`url(#wynii-glow-${stage})`} opacity=".9" /> : null}
      <ellipse cx="68" cy="88" rx="12" ry="15" fill={`url(#wynii-eye-${stage})`} />
      <ellipse cx="112" cy="88" rx="12" ry="15" fill={`url(#wynii-eye-${stage})`} />
      <circle cx="64" cy="82" r="4" fill="#fff" />
      <circle cx="108" cy="82" r="4" fill="#fff" />
      <path d="M86 103c2 2 6 2 8 0" fill="none" stroke="#77718b" strokeWidth="2.4" strokeLinecap="round" />
      <path d="M90 105c0 6-5 9-10 8m10-8c0 6 5 9 10 8" fill="none" stroke="#77718b" strokeWidth="2" strokeLinecap="round" />
      <path d="M90 119c-7-10-21-5-18 6 2 8 11 14 18 19 7-5 16-11 18-19 3-11-11-16-18-6Z" fill={`url(#wynii-glow-${stage})`} />
      <path d="M90 124c-3-4-9-2-8 3 1 4 5 7 8 9 3-2 7-5 8-9 1-5-5-7-8-3Z" fill="#fff" opacity=".78" />
      {max ? <g fill={`url(#wynii-glow-${stage})`}><circle cx="30" cy="92" r="3" /><circle cx="151" cy="82" r="2.5" /><circle cx="138" cy="38" r="2" /></g> : null}
    </svg>
  );
}

function statusFor(pet: WyniiRow, userId: string, now: number): Status {
  const mineIsA = userId === pet.user_a_id;
  const mineDone = mineIsA ? pet.user_a_done : pet.user_b_done;
  const otherDone = mineIsA ? pet.user_b_done : pet.user_a_done;
  const cycleStarted = pet.cycle_started_at ? new Date(pet.cycle_started_at).getTime() : null;
  const cycleExpired = cycleStarted != null && now > cycleStarted + 24 * 60 * 60 * 1000;
  const nextCycle = new Date(pet.next_cycle_at).getTime();

  if (cycleExpired) return { short: "พักอยู่", detail: "รอบก่อนหน้าไม่ครบภายใน 24 ชั่วโมง เริ่มรอบใหม่ได้เมื่อมีข้อความใหม่", mineDone: false, otherDone: false };
  if (cycleStarted != null) {
    if (mineDone && !otherDone) return { short: "รออีกฝ่าย", detail: "คุณส่งแล้ว รออีกฝ่ายส่งภายใน 24 ชั่วโมง", mineDone, otherDone };
    if (!mineDone && otherDone) return { short: "ถึงตาคุณ", detail: "อีกฝ่ายส่งแล้ว ส่งอะไรก็ได้ในแชทเพื่อดูแล Wynii", mineDone, otherDone };
    return { short: `${pet.age_days} วัน`, detail: "กำลังดูแล Wynii ในรอบนี้", mineDone, otherDone };
  }
  if (pet.last_completed_at && now < nextCycle) return { short: "วันนี้ครบแล้ว ✓", detail: "ทั้งสองฝ่ายส่งครบแล้ว รอบถัดไปจะเปิดอีกครั้งหลังครบ 24 ชั่วโมง", mineDone: true, otherDone: true };
  return { short: `${pet.age_days} วัน`, detail: "ส่งอะไรก็ได้ในแชทคนละ 1 ครั้งภายใน 24 ชั่วโมง", mineDone: false, otherDone: false };
}

function progressFor(ageDays: number, next: number | null): number {
  if (next == null) return 100;
  const previous = next === 1 ? 0 : next === 7 ? 1 : next === 30 ? 7 : next === 100 ? 30 : 100;
  const span = Math.max(1, next - previous);
  return Math.max(0, Math.min(100, ((ageDays - previous) / span) * 100));
}

export function WyniiConversationHeader({ client, userId, conversationId, other, displayName, canStart, online, onOpenProfile }: Props) {
  const [pet, setPet] = useState<WyniiRow | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [starting, setStarting] = useState(false);
  const [error, setError] = useState("");
  const [now, setNow] = useState(() => Date.now());

  const load = useCallback(async () => {
    try {
      setPet(await fetchWynii(client, conversationId));
      setError("");
    } catch (e) {
      setError(e instanceof Error ? e.message : "โหลด Wynii ไม่สำเร็จ");
    } finally {
      setLoaded(true);
    }
  }, [client, conversationId]);

  useEffect(() => {
    const timer = window.setTimeout(() => { void load(); }, 0);
    return () => window.clearTimeout(timer);
  }, [load]);
  useEffect(() => {
    let channel: RealtimeChannel | null = subscribeWyniiMessages(client, conversationId, () => { void load(); });
    return () => { if (channel) void client.removeChannel(channel); channel = null; };
  }, [client, conversationId, load]);
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 60_000);
    return () => window.clearInterval(timer);
  }, []);

  const stage = wyniiStage(pet?.age_days ?? 0);
  const status = useMemo(() => pet ? statusFor(pet, userId, now) : null, [pet, userId, now]);
  const nextMilestone = pet ? wyniiNextMilestone(pet.age_days) : null;
  const progress = pet ? progressFor(pet.age_days, nextMilestone) : 0;

  const begin = async () => {
    if (!canStart || starting) return;
    setStarting(true); setError("");
    try {
      const created = await startWynii(client, conversationId);
      setPet(created);
      setMenuOpen(false);
      setSheetOpen(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : "เริ่มเลี้ยง Wynii ไม่สำเร็จ");
    } finally {
      setStarting(false);
    }
  };

  return (
    <Fragment>
      <div className={`conversation-modern-header-person ${styles.person}`}>
        <Link className={styles.personLink} href={`/profile/${other.id}`} aria-label={`ดูโปรไฟล์ ${displayName}`}>
          <span className={styles.avatarWrap}>
            <Avatar src={other.avatar_url} label={other.username} size={44} />
            {online ? <span className={styles.statusDot} aria-hidden="true" /> : null}
          </span>
        </Link>
        <span className={styles.copy}>
          <Link className={styles.personLink} href={`/profile/${other.id}`}><strong>{displayName}</strong></Link>
          <span className={styles.subline}>
            {online ? (
              <small className={styles.status}>ออนไลน์</small>
            ) : (
              <Link className={styles.personLink} href={`/profile/${other.id}`}><small className={styles.handle}>@{other.username}</small></Link>
            )}
            {pet && status ? <><span className={styles.dot}>·</span><button className={styles.pill} type="button" onClick={() => setSheetOpen(true)} aria-label={`Wynii ${status.short}`}><WyniiGlyph stage={stage} className={styles.glyph} /><span className={styles.pillText}>Wynii {status.short}</span></button></> : null}
          </span>
        </span>
      </div>

      <div className={styles.moreWrap}>
        <button className="conversation-modern-more" type="button" aria-label="เพิ่มเติม" aria-expanded={menuOpen} onClick={() => setMenuOpen((value) => !value)}><MoreHorizontal size={26} strokeWidth={1.8} /></button>
        {menuOpen ? <>
          <button className={styles.menuBackdrop} type="button" aria-label="ปิดเมนู" onClick={() => setMenuOpen(false)} />
          <div className={styles.menu} role="menu">
            <button type="button" role="menuitem" onClick={() => { setMenuOpen(false); onOpenProfile(); }}><UserRound size={18} /><span>ดูโปรไฟล์</span></button>
            {pet ? <button type="button" role="menuitem" onClick={() => { setMenuOpen(false); setSheetOpen(true); }}><Heart size={18} /><span>ดู Wynii</span></button> : <button type="button" role="menuitem" disabled={!canStart || starting || !loaded} onClick={() => void begin()}><Sparkles size={18} /><span>{starting ? "กำลังเริ่ม…" : "เลี้ยง Wynii ด้วยกัน"}</span></button>}
          </div>
        </> : null}
      </div>

      {sheetOpen ? <div className={styles.sheetBackdrop} role="presentation" onClick={() => setSheetOpen(false)}>
        <section className={styles.sheet} role="dialog" aria-modal="true" aria-label="Wynii ของเรา" onClick={(event) => event.stopPropagation()}>
          <div className={styles.sheetHeader}><strong>Wynii ของเรา</strong><button className={styles.close} type="button" aria-label="ปิด" onClick={() => setSheetOpen(false)}><X size={19} /></button></div>
          {pet && status ? <>
            <div className={styles.hero}>
              <WyniiGlyph stage={stage} className={styles.visual} />
              <h2>{pet.age_days} วัน</h2>
              <p>{wyniiStageLabel(stage)}{stage === "max" ? " · เติบโตต่อได้เรื่อย ๆ" : ""}</p>
            </div>
            <div className={styles.statusCard}>
              <div className={styles.statusTop}><strong>{status.short}</strong><span>{status.detail}</span></div>
              <div className={styles.members}>
                <div className={styles.member}><span>คุณ</span><span className={status.mineDone ? styles.done : styles.waiting}>{status.mineDone ? "✓ ส่งแล้ว" : "รอ"}</span></div>
                <div className={styles.member}><span>{displayName}</span><span className={status.otherDone ? styles.done : styles.waiting}>{status.otherDone ? "✓ ส่งแล้ว" : "รอ"}</span></div>
              </div>
              <div className={styles.progressBlock}>
                <div className={styles.progressCopy}><span>{wyniiStageLabel(stage)}</span><span>{nextMilestone == null ? "MAX" : `อีก ${Math.max(0, nextMilestone - pet.age_days)} วัน`}</span></div>
                <div className={styles.progressTrack}><div className={styles.progressFill} style={{ width: `${progress}%` }} /></div>
              </div>
            </div>
            <p className={styles.rule}>ทั้งสองฝ่ายส่งอะไรก็ได้ในแชทคนละ 1 ครั้งภายใน 24 ชั่วโมง = Wynii อายุ +1 วัน · อายุไม่ลดและไม่รีเซ็ตเมื่อพัก</p>
          </> : <>
            <div className={styles.hero}><WyniiGlyph stage="egg" className={styles.visual} /><h2>เริ่มจากไข่</h2><p>Wynii จะเติบโตไปกับการคุยของคุณสองคน</p></div>
            {error ? <p className={styles.rule}>{error}</p> : null}
            <button className={styles.startButton} type="button" disabled={!canStart || starting} onClick={() => void begin()}>{starting ? "กำลังเริ่ม…" : "เริ่มเลี้ยง Wynii ด้วยกัน"}</button>
          </>}
          {error && pet ? <p className={styles.rule}>{error}</p> : null}
        </section>
      </div> : null}
    </Fragment>
  );
}
