"use client";

import { Camera, Lock, Plus, UsersRound } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, EmptyState, LoadingState } from "@/components/phase3-ui";
import { fetchClub, searchClubs, type ClubRow } from "@/lib/phase3-data";

function ClubList({ rows }: { rows: ClubRow[] }) {
  return <div className="clubs-list">{rows.map((club) => <Link className="club-list-row" href={`/club/${club.id}`} key={club.id}><span className="club-list-avatar">{club.icon_url ? <img src={club.icon_url} alt="" /> : club.name.slice(0, 1)}</span><span className="club-list-copy"><strong>{club.name}</strong><small>{club.member_count.toLocaleString("th-TH")} สมาชิก{club.category ? ` · ${club.category}` : ""}</small>{club.description ? <p>{club.description}</p> : null}</span>{club.privacy === "private" ? <Lock size={16} /> : <UsersRound size={16} />}</Link>)}</div>;
}

function ClubsInner({ client, userId, mine }: { client: SupabaseClient; userId: string; mine: boolean }) {
  const router = useRouter();
  const [rows, setRows] = useState<ClubRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      if (!mine) {
        setRows(await searchClubs(client, "", 0));
      } else {
        const membership = await client.from("club_members").select("club_id").eq("user_id", userId).eq("status", "approved");
        if (membership.error) throw membership.error;
        const ids = (membership.data ?? []).map((row) => String(row.club_id));
        const clubs = await Promise.all(ids.map((id) => fetchClub(client, id)));
        setRows(clubs.filter((club): club is ClubRow => Boolean(club)));
      }
    } catch (e) { setError(e instanceof Error ? e.message : "โหลด Club ไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client, mine, userId]);
  useEffect(() => { void load(); }, [load]);

  return <AppChrome title={mine ? "Club ของฉัน" : "สำรวจ Club"} userId={userId} backHref="/" showBottomNav={false} actions={<button className="route-icon-button" type="button" aria-label="สร้าง Club" onClick={() => router.push("/clubs/new")}><Plus size={22} /></button>}>{loading ? <LoadingState /> : error ? <div className="route-empty"><p>{error}</p><button className="route-secondary" type="button" onClick={() => void load()}>ลองใหม่</button></div> : rows.length ? <ClubList rows={rows} /> : <EmptyState>{mine ? "คุณยังไม่ได้เข้าร่วม Club" : "ยังไม่มี Club ให้สำรวจ"}</EmptyState>}</AppChrome>;
}

export function ClubsRoute({ mine = false }: { mine?: boolean }) {
  return <DeveloperRouteGate>{({ client, userId }) => <ClubsInner client={client} userId={userId} mine={mine} />}</DeveloperRouteGate>;
}

function CreateClubInner({ client, userId }: { client: SupabaseClient; userId: string }) {
  const router = useRouter();
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("");
  const [privacy, setPrivacy] = useState<"public" | "private">("public");
  const [file, setFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

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
        const update = await client.from("clubs").update({ icon_url: path, cover_url: null }).eq("id", clubId);
        if (update.error) throw update.error;
      }
      router.replace(`/club/${clubId}`);
    } catch (e) { setError(e instanceof Error ? e.message : "สร้าง Club ไม่สำเร็จ"); setSaving(false); }
  };

  return <AppChrome title="สร้าง Club" userId={userId} backHref="/" showBottomNav={false}><div className="create-club-page"><label className="club-image-picker"><Camera size={22} /><span>{file ? file.name : "เลือกรูป Club"}</span><input type="file" accept="image/*" hidden disabled={saving} onChange={(e) => setFile(e.target.files?.[0] ?? null)} /></label><label className="route-field"><span>ชื่อ Club</span><input value={name} maxLength={60} onChange={(e) => setName(e.target.value)} /></label><label className="route-field"><span>คำอธิบาย</span><textarea value={description} maxLength={500} onChange={(e) => setDescription(e.target.value)} /></label><label className="route-field"><span>หมวดหมู่</span><input value={category} maxLength={50} onChange={(e) => setCategory(e.target.value)} /></label><div className="club-privacy-choice"><button className={privacy === "public" ? "active" : ""} type="button" onClick={() => setPrivacy("public")}>สาธารณะ</button><button className={privacy === "private" ? "active" : ""} type="button" onClick={() => setPrivacy("private")}>ส่วนตัว</button></div>{error ? <p className="route-error">{error}</p> : null}<button className="route-primary create-club-submit" type="button" disabled={saving || !name.trim()} onClick={() => void submit()}>{saving ? "กำลังสร้าง…" : "สร้าง Club"}</button></div></AppChrome>;
}

export function CreateClubRoute() {
  return <DeveloperRouteGate>{({ client, userId }) => <CreateClubInner client={client} userId={userId} />}</DeveloperRouteGate>;
}
