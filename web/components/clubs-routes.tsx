"use client";

import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { useRouteRefreshListener } from "@/components/route-refresh-runtime";
import { AppChrome, EmptyState, LoadingState } from "@/components/phase3-ui";
import { PullToRefreshIndicator } from "@/components/ui/pull-to-refresh-indicator";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import { fetchClubsByIds, searchClubs, type ClubRow } from "@/lib/phase3-data";
import { usePullToRefresh } from "@/lib/use-pull-to-refresh";

type Sections = { popular: ClubRow[]; newest: ClubRow[]; pending: Set<string> };

function ClubAvatar({ club, size = 44 }: { club: ClubRow; size?: number }) {
  return <span className="audit-club-avatar" style={{ width: size, height: size }}>{club.icon_url ? <Image src={club.icon_url} alt="" width={size} height={size} sizes={`${size}px`} /> : <b>{club.name.trim().slice(0, 1).toUpperCase() || "C"}</b>}</span>;
}

async function fetchExplore(client: SupabaseClient, userId: string): Promise<Sections> {
  const pages = await Promise.all([0, 1, 2].map((page) => searchClubs(client, "", page)));
  const all = pages.flat();
  const membership = await client.from("club_members").select("club_id,status").eq("user_id", userId);
  if (membership.error) throw membership.error;
  const approved = new Set((membership.data ?? []).filter((row) => row.status === "approved").map((row) => String(row.club_id)));
  const pending = new Set((membership.data ?? []).filter((row) => row.status === "pending").map((row) => String(row.club_id)));
  const discoverable = all.filter((club) => !approved.has(club.id));
  const popular = [...discoverable].sort((a, b) => b.member_count - a.member_count || b.created_at.localeCompare(a.created_at)).slice(0, 10);
  // WYN-185 item 13: both sections used to slice the same `discoverable`
  // pool independently, so with a small club count "ใหม่ล่าสุด" ended up
  // showing the exact same clubs as "ยอดนิยม" in a different order.
  // Excluding clubs already promoted into popular keeps the two sections
  // distinct.
  const popularIds = new Set(popular.map((club) => club.id));
  const newest = [...discoverable]
    .filter((club) => !popularIds.has(club.id))
    .sort((a, b) => b.created_at.localeCompare(a.created_at))
    .slice(0, 10);
  return { popular, newest, pending };
}

function ExploreClubRow({ club, pending, joining, onJoin }: { club: ClubRow; pending: boolean; joining: boolean; onJoin: () => void }) {
  return <div className="audit-club-row"><Link className="audit-club-main" href={`/club/${club.id}`}><ClubAvatar club={club} /><span><strong>{club.name}</strong><small>{club.member_count.toLocaleString("th-TH")} สมาชิก</small></span></Link>{pending ? <span className="audit-club-pending">รออนุมัติ</span> : <button className="audit-club-join" type="button" disabled={joining} onClick={onJoin}>{joining ? <span className="route-system-spinner tiny" /> : "เข้าร่วม"}</button>}</div>;
}

function ExploreClubs({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const cacheKey = `clubs-explore:${userId}`;
  const cached = getMountCache<Sections>(cacheKey);
  const hadCache = useRef(cached !== undefined);
  const [sections, setSections] = useState<Sections>(cached ?? { popular: [], newest: [], pending: new Set() });
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(!cached);
  const [joining, setJoining] = useState<string | null>(null);
  const [error, setError] = useState("");
  const load = useCallback(async (showLoading = true) => {
    if (showLoading) setLoading(true);
    setError("");
    try {
      const next = await fetchExplore(client, userId);
      setSections(next);
      setMountCache(cacheKey, next);
    } catch { setError("โหลด Club ไม่สำเร็จ"); } finally { setLoading(false); }
  }, [client, userId, cacheKey]);
  useEffect(() => { void load(!hadCache.current); }, [load]);
  const pull = usePullToRefresh({ enabled: true, onRefresh: () => load() });
  useRouteRefreshListener(pull.refresh);
  const join = async (club: ClubRow) => {
    if (joining) return;
    setJoining(club.id); setError("");
    const result = await client.from("club_members").insert({ club_id: club.id, user_id: userId, role: "member", status: club.privacy === "private" ? "pending" : "approved" });
    if (result.error) setError("เข้าร่วม Club ไม่สำเร็จ ลองใหม่อีกครั้ง"); else await load();
    setJoining(null);
  };
  const match = (club: ClubRow) => !query.trim() || club.name.toLocaleLowerCase("th").includes(query.trim().toLocaleLowerCase("th"));
  const popular = sections.popular.filter(match);
  const newest = sections.newest.filter(match);
  return <AppChrome title="สำรวจ Club" userId={userId} backHref="/" showBottomNav={false}>
    <PullToRefreshIndicator pull={pull} topOffset="60px" refreshingLabel="กำลังรีเฟรช Club" />
    <div onTouchStart={pull.onTouchStart} onTouchMove={pull.onTouchMove} onTouchEnd={pull.onTouchEnd} onTouchCancel={pull.onTouchCancel}>
    {loading ? <LoadingState /> : <div className="audit-club-explore">
      <section className="audit-club-hero"><h2>เจอคอมมูนิตี้ที่ใช่<span>สำหรับคุณ</span></h2><p>ร่วมคอมมูนิตี้ที่คุณสนใจ เชื่อมต่อกับคนที่คิดเหมือนกัน</p><button type="button" onClick={() => router.push("/clubs/new")}><WynosIcon name="post" size={17} strokeWidth={2} />สร้าง Club</button></section>
      <label className="audit-club-search"><WynosIcon name="search" size={16} strokeWidth={2} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="ค้นหา Club" /></label>
      {error ? <p className="route-error audit-club-error">{error}</p> : null}
      <section className="audit-club-section"><h3>กำลังนิยม</h3>{popular.length ? popular.map((club) => <ExploreClubRow club={club} pending={sections.pending.has(club.id)} joining={joining === club.id} onJoin={() => void join(club)} key={`popular:${club.id}`} />) : <p className="audit-club-empty">{query ? `ไม่พบ Club ที่ตรงกับ “${query}”` : "ยังไม่มี Club กำลังนิยมตอนนี้"}</p>}</section>
      <section className="audit-club-section"><h3>ใหม่ล่าสุด</h3>{newest.length ? newest.map((club) => <ExploreClubRow club={club} pending={sections.pending.has(club.id)} joining={joining === club.id} onJoin={() => void join(club)} key={`new:${club.id}`} />) : <p className="audit-club-empty">{query ? `ไม่พบ Club ที่ตรงกับ “${query}”` : "ยังไม่มี Club ใหม่ตอนนี้"}</p>}</section>
    </div>}
    </div>
  </AppChrome>;
}

function MyClubs({ client, userId }: { client: SupabaseClient; userId: string }) {
  const cacheKey = `clubs-mine:${userId}`;
  const cached = getMountCache<ClubRow[]>(cacheKey);
  const hadCache = useRef(cached !== undefined);
  const [rows, setRows] = useState<ClubRow[]>(cached ?? []);
  const [loading, setLoading] = useState(!cached);
  const [error, setError] = useState("");
  const load = useCallback(async (showLoading = true) => {
    if (showLoading) setLoading(true);
    setError("");
    try {
      const membership = await client.from("club_members").select("club_id").eq("user_id", userId).eq("status", "approved");
      if (membership.error) throw membership.error;
      const ids = (membership.data ?? []).map((row) => String(row.club_id));
      const next = await fetchClubsByIds(client, ids);
      setRows(next);
      setMountCache(cacheKey, next);
    } catch { setError("โหลดรายชื่อ Club ไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client, userId, cacheKey]);
  useEffect(() => { void load(!hadCache.current); }, [load]);
  const pull = usePullToRefresh({ enabled: true, onRefresh: () => load() });
  return <AppChrome title="Club ของฉัน" userId={userId} backHref="/" showBottomNav={false}>
    <PullToRefreshIndicator pull={pull} topOffset="60px" refreshingLabel="กำลังรีเฟรช Club ของฉัน" />
    <div onTouchStart={pull.onTouchStart} onTouchMove={pull.onTouchMove} onTouchEnd={pull.onTouchEnd} onTouchCancel={pull.onTouchCancel}>
      {loading ? <LoadingState /> : error ? <div className="route-empty"><p>{error}</p><button className="route-secondary" type="button" onClick={() => void load()}>ลองใหม่</button></div> : rows.length ? <div className="audit-my-clubs">{rows.map((club) => <Link className="audit-my-club-row" href={`/club/${club.id}`} key={club.id}><ClubAvatar club={club} /><span><strong>{club.name}</strong><small>{club.member_count.toLocaleString("th-TH")} สมาชิก</small></span><WynosIcon name="chevronRight" size={18} strokeWidth={2} /></Link>)}</div> : <EmptyState>ยังไม่ได้เข้าร่วม Club ไหนเลย ลองสร้างหรือค้นหาดูสิ</EmptyState>}
    </div>
  </AppChrome>;
}

export function ClubsRoute({ mine = false }: { mine?: boolean }) {
  return <DeveloperRouteGate>{({ client, userId }) => mine ? <MyClubs client={client} userId={userId} /> : <ExploreClubs client={client} userId={userId} />}</DeveloperRouteGate>;
}

function CreateClubInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("");
  const [privacy, setPrivacy] = useState<"public" | "private">("public");
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => { if (!file) { setPreview(null); return; } const url = URL.createObjectURL(file); setPreview(url); return () => URL.revokeObjectURL(url); }, [file]);
  const submit = async () => {
    if (!name.trim() || saving) return;
    setSaving(true); setError("");
    try {
      const result = await client.from("clubs").insert({ name: name.trim(), description: description.trim() || null, category: category.trim() || null, privacy, owner_id: userId }).select("id").single();
      if (result.error) throw result.error;
      const clubId = String(result.data.id);
      if (file) {
        const extension = file.name.split(".").pop()?.toLowerCase() || "jpg";
        const path = `${clubId}/icon.${extension}`;
        const upload = await client.storage.from("club-media").upload(path, file, { upsert: true });
        if (upload.error) throw upload.error;
        const update = await client.from("clubs").update({ icon_url: path }).eq("id", clubId);
        if (update.error) throw update.error;
      }
      router.replace(`/club/${clubId}`);
    } catch (e) { setError(e instanceof Error ? e.message : "สร้าง Club ไม่สำเร็จ"); setSaving(false); }
  };
  const count = name.trim().length;
  return <AppChrome title="สร้าง Club" userId={userId} backHref="/clubs" showBottomNav={false}><div className="audit-create-club"><section className="audit-create-club-intro"><h2>สร้างพื้นที่ของคุณ</h2><p>ตั้งชื่อ เล่าให้คนอื่นรู้ว่า Club นี้เกี่ยวกับอะไร แล้วเลือกว่าจะเปิดสาธารณะหรือส่วนตัว</p></section><label className="audit-club-image-picker">{preview ? (
        // Local blob preview of an unsaved file — not eligible for the remote image optimizer.
        <img src={preview} alt="" />
      ) : <WynosIcon name="camera" size={26} strokeWidth={2} />}<span>{file ? "เปลี่ยนรูป Club" : "เลือกรูป Club"}</span><input type="file" accept="image/*" hidden disabled={saving} onChange={(event) => setFile(event.target.files?.[0] ?? null)} /></label><label className="route-field"><span>ชื่อ Club <small>{count}/50</small></span><input value={name} maxLength={50} onChange={(event) => setName(event.target.value)} placeholder="ชื่อ Club" /></label><label className="route-field"><span>คำอธิบาย</span><textarea value={description} maxLength={500} onChange={(event) => setDescription(event.target.value)} placeholder="Club นี้เกี่ยวกับอะไร?" /></label><label className="route-field"><span>หมวดหมู่</span><input value={category} maxLength={50} onChange={(event) => setCategory(event.target.value)} placeholder="เช่น เทคโนโลยี, กีฬา" /></label><div className="audit-club-privacy"><button className={privacy === "public" ? "active" : ""} type="button" onClick={() => setPrivacy("public")}><WynosIcon name="club" size={19} strokeWidth={2} /><span><strong>สาธารณะ</strong><small>ทุกคนค้นหาและเข้าร่วมได้</small></span></button><button className={privacy === "private" ? "active" : ""} type="button" onClick={() => setPrivacy("private")}><WynosIcon name="lock" size={19} strokeWidth={2} /><span><strong>ส่วนตัว</strong><small>ต้องได้รับอนุมัติก่อนเข้าร่วม</small></span></button></div>{error ? <p className="route-error">{error}</p> : null}<button className="route-primary audit-create-club-submit" type="button" disabled={saving || !name.trim()} onClick={() => void submit()}>{saving ? "กำลังสร้าง…" : "สร้าง Club"}</button></div></AppChrome>;
}

export function CreateClubRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <CreateClubInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
