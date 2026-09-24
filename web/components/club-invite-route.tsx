"use client";

import Image from "next/image";
import Link from "next/link";
import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { AppChrome, EmptyState, LoadingState } from "@/components/phase3-ui";

type InvitePreview = {
  status: string;
  club_id?: string | null;
  club_name?: string | null;
  club_privacy?: string | null;
  club_icon_url?: string | null;
};

function InviteInner({ client, userId, code }: { client: SupabaseClient; userId: string; code: string }) {
  const [preview, setPreview] = useState<InvitePreview | null | undefined>(undefined);
  const [iconUrl, setIconUrl] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [joinedId, setJoinedId] = useState<string | null>(null);

  useEffect(() => {
    let live = true;
    void client.rpc("preview_club_invite_link", { p_code: code }).then(async ({ data, error }) => {
      if (!live) return;
      if (error) { setPreview(null); return; }
      const raw = Array.isArray(data) ? data[0] : data;
      if (!raw || typeof raw !== "object") { setPreview({ status: "not_found" }); return; }
      const value = raw as InvitePreview;
      setPreview(value);
      if (value.status === "valid" && value.club_icon_url) {
        const signed = await client.storage.from("club-media").createSignedUrl(value.club_icon_url, 3600);
        if (live && !signed.error) setIconUrl(signed.data.signedUrl);
      }
    });
    return () => { live = false; };
  }, [client, code]);

  const redeem = async () => {
    if (busy) return;
    setBusy(true); setMessage("");
    try {
      const result = await client.rpc("redeem_club_invite_link", { p_code: code });
      if (result.error) throw result.error;
      const clubId = String(result.data ?? preview?.club_id ?? "");
      setJoinedId(clubId || null);
      setMessage("เข้าร่วม Club แล้ว");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "ใช้ลิงก์เชิญไม่สำเร็จ");
    } finally { setBusy(false); }
  };

  if (preview === undefined) return <AppChrome title="คำเชิญ Club" userId={userId} backHref="/"><LoadingState /></AppChrome>;
  if (!preview || preview.status === "not_found") return <AppChrome title="คำเชิญ Club" userId={userId} backHref="/"><EmptyState>ไม่พบลิงก์เชิญนี้</EmptyState></AppChrome>;
  const valid = preview.status === "valid";
  const statusLabel: Record<string, string> = { expired: "หมดอายุ", revoked: "ถูกยกเลิก", exhausted: "ถูกใช้ครบแล้ว" };
  if (!valid) {
    return <AppChrome title="คำเชิญ Club" userId={userId} backHref="/">
      <section className="invite-card"><p>ลิงก์เชิญนี้{statusLabel[preview.status] || "ไม่สามารถใช้งานได้"}</p></section>
    </AppChrome>;
  }
  const targetId = joinedId || preview.club_id || "";
  return (
    <AppChrome title="คำเชิญ Club" userId={userId} backHref="/">
      <section className="invite-card">
        {iconUrl ? <Image className="club-cover" src={iconUrl} alt="" width={76} height={76} sizes="76px" /> : null}
        <h2>{preview.club_name || "Club"}</h2>
        <small>{preview.club_privacy === "private" ? "Club ส่วนตัว" : "Club สาธารณะ"}</small>
        {valid && !joinedId ? <button className="route-primary" type="button" disabled={busy} onClick={() => void redeem()}>{busy ? "กำลังเข้าร่วม…" : "เข้าร่วม Club"}</button> : null}
        {message ? <p className="route-notice">{message}</p> : null}
        {targetId ? <Link className="route-secondary inline" href={`/club/${targetId}`}>เปิด Club</Link> : null}
      </section>
    </AppChrome>
  );
}

export function ClubInviteLinkRoute({ code }: { code: string }) {
  return <DeveloperRouteGate>{({ client, userId }) => <InviteInner client={client} userId={userId} code={code} />}</DeveloperRouteGate>;
}
