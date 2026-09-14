/* eslint-disable @next/next/no-img-element */
"use client";

import {
  BarChart3,
  Camera,
  ChevronDown,
  ChevronRight,
  FilePenLine,
  Globe2,
  ImagePlus,
  Lock,
  Star,
  UserRoundX,
  UsersRound,
  X,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { Avatar } from "@/components/phase3-ui";
import { publishDropSafely } from "@/lib/drop-publication";
import { fetchHomeIdentity, type HomeIdentity } from "@/lib/home-parity-data";

type ComposeMode = "image" | "poll";
type AspectRatioChoice = "original" | "1:1" | "4:5" | "16:9";
type Audience = "everyone" | "friends" | "friends_except" | "close_friends" | "only_me";

type DraftRow = {
  id: string;
  caption?: string | null;
  image_url?: string | null;
  poll_options?: string[] | null;
  poll_duration_days?: number | null;
  updated_at: string;
};

const audienceOptions: Array<{
  value: Audience;
  label: string;
  description: string;
  icon: typeof Globe2;
  nested?: boolean;
}> = [
  { value: "everyone", label: "ทุกคน", description: "ทุกคนเห็นโพสต์นี้ได้", icon: Globe2 },
  { value: "friends", label: "เพื่อน", description: "เฉพาะเพื่อนของคุณเท่านั้นที่เห็นได้", icon: UsersRound },
  { value: "friends_except", label: "ซ่อนเพื่อนบางคน", description: "เพื่อนทุกคนเห็นได้ ยกเว้นคนที่คุณเลือกซ่อน", icon: UserRoundX, nested: true },
  { value: "close_friends", label: "เพื่อนที่สนิท", description: "เฉพาะเพื่อนที่สนิทที่คุณเลือกไว้เท่านั้น", icon: Star, nested: true },
  { value: "only_me", label: "เฉพาะฉัน", description: "เห็นเฉพาะคุณคนเดียว", icon: Lock },
];

function audienceLabel(value: Audience) {
  return audienceOptions.find((item) => item.value === value)?.label ?? "ทุกคน";
}

function extensionFor(file: File): string {
  return file.name.split(".").pop()?.toLowerCase().replace(/[^a-z0-9]/g, "") || "jpg";
}

export function Beta4Composer({
  client,
  userId,
  onClose,
  onPublished,
}: {
  client: SupabaseClient;
  userId: string;
  onClose: () => void;
  onPublished: () => void;
}) {
  const [identity, setIdentity] = useState<HomeIdentity | null>(null);
  const [caption, setCaption] = useState("");
  const [files, setFiles] = useState<File[]>([]);
  const [mode, setMode] = useState<ComposeMode>("image");
  const [aspectRatio, setAspectRatio] = useState<AspectRatioChoice>("4:5");
  const [audience, setAudience] = useState<Audience>("everyone");
  const [audienceOpen, setAudienceOpen] = useState(false);
  const [pollOptions, setPollOptions] = useState(["", ""]);
  const [pollDuration, setPollDuration] = useState(1);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [closePrompt, setClosePrompt] = useState(false);
  const [draftsOpen, setDraftsOpen] = useState(false);
  const [drafts, setDrafts] = useState<DraftRow[]>([]);
  const [draftsLoading, setDraftsLoading] = useState(false);
  const [draftId, setDraftId] = useState<string | null>(null);
  const galleryRef = useRef<HTMLInputElement | null>(null);
  const cameraRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    let live = true;
    void fetchHomeIdentity(client, userId).then((value) => { if (live) setIdentity(value); }).catch(() => undefined);
    return () => { live = false; };
  }, [client, userId]);

  const previews = useMemo(() => files.map((file) => URL.createObjectURL(file)), [files]);
  useEffect(() => () => previews.forEach((url) => URL.revokeObjectURL(url)), [previews]);

  const pollValid = caption.trim().length > 0 && pollOptions.length >= 2 && pollOptions.every((value) => value.trim().length > 0 && value.trim().length <= 80) && new Set(pollOptions.map((value) => value.trim().toLowerCase())).size === pollOptions.length;
  const canPublish = !busy && (mode === "poll" ? pollValid : caption.trim().length > 0 || files.length > 0);
  const hasContent = caption.trim().length > 0 || files.length > 0 || pollOptions.some((value) => value.trim().length > 0);

  const requestClose = () => {
    if (busy) return;
    if (!hasContent) { onClose(); return; }
    setClosePrompt(true);
  };

  const loadDrafts = async () => {
    setDraftsOpen(true);
    setDraftsLoading(true);
    setError("");
    try {
      const result = await client
        .from("drop_drafts")
        .select("id,caption,image_url,poll_options,poll_duration_days,updated_at")
        .eq("author_id", userId)
        .order("updated_at", { ascending: false });
      if (result.error) throw result.error;
      setDrafts((result.data ?? []) as DraftRow[]);
    } catch {
      setError("โหลดร่างไม่สำเร็จ");
    } finally {
      setDraftsLoading(false);
    }
  };

  const openDraft = (draft: DraftRow) => {
    setDraftId(draft.id);
    setCaption(draft.caption ?? "");
    if (Array.isArray(draft.poll_options) && draft.poll_options.length >= 2) {
      setMode("poll");
      setPollOptions(draft.poll_options.slice(0, 4));
      setPollDuration(draft.poll_duration_days === 3 || draft.poll_duration_days === 7 ? draft.poll_duration_days : 1);
    } else {
      setMode("image");
      setPollOptions(["", ""]);
    }
    setDraftsOpen(false);
  };

  const saveDraft = async () => {
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      let imageUrl: string | null = null;
      if (mode === "image" && files[0]) {
        const file = files[0];
        const path = `${userId}/drafts/${draftId ?? crypto.randomUUID()}.${extensionFor(file)}`;
        const uploaded = await client.storage.from("drop-images").upload(path, file, { upsert: true });
        if (uploaded.error) throw uploaded.error;
        imageUrl = client.storage.from("drop-images").getPublicUrl(path).data.publicUrl;
      }
      const payload = {
        author_id: userId,
        image_url: mode === "image" ? imageUrl : null,
        caption: caption.trim() || null,
        poll_options: mode === "poll" ? pollOptions.map((value) => value.trim()) : null,
        poll_duration_days: mode === "poll" ? pollDuration : null,
        updated_at: new Date().toISOString(),
      };
      if (draftId) {
        const result = await client.from("drop_drafts").update(payload).eq("id", draftId).eq("author_id", userId);
        if (result.error) throw result.error;
      } else {
        const result = await client.from("drop_drafts").insert(payload).select("id").single();
        if (result.error) throw result.error;
        setDraftId(String(result.data.id));
      }
      setClosePrompt(false);
      onClose();
    } catch {
      setError("บันทึกร่างไม่สำเร็จ ลองใหม่อีกครั้ง");
      setClosePrompt(false);
    } finally {
      setBusy(false);
    }
  };

  const publishPoll = async () => {
    const result = await client.rpc("create_poll_drop", {
      p_caption: caption.trim(),
      p_options: pollOptions.map((value) => value.trim()),
      p_duration_days: pollDuration,
      p_mentioned_user_ids: [],
      p_audience: audience,
      p_excluded_friend_ids: [],
      p_location: null,
      p_location_lat: null,
      p_location_lon: null,
      p_location_place_id: null,
    });
    if (result.error) throw result.error;
  };

  const submit = async () => {
    if (!canPublish) return;
    setBusy(true);
    setError("");
    try {
      if (mode === "poll") await publishPoll();
      else await publishDropSafely(client, userId, { caption, files, audience, imageAspectRatio: aspectRatio });
      if (draftId) void client.from("drop_drafts").delete().eq("id", draftId).eq("author_id", userId);
      onPublished();
      onClose();
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง");
    } finally {
      setBusy(false);
    }
  };

  const addPollOption = () => setPollOptions((current) => current.length >= 4 ? current : [...current, ""]);
  const updatePollOption = (index: number, value: string) => setPollOptions((current) => current.map((item, itemIndex) => itemIndex === index ? value : item));
  const removePollOption = (index: number) => setPollOptions((current) => current.length <= 2 ? current : current.filter((_, itemIndex) => itemIndex !== index));

  return (
    <div className="route-modal-backdrop beta4-composer-backdrop" role="presentation" onClick={requestClose}>
      <section className="beta4-composer" role="dialog" aria-modal="true" aria-label="สร้างโพสต์" onClick={(event) => event.stopPropagation()}>
        <header className="beta4-composer-header">
          <button className="beta4-cancel" type="button" onClick={requestClose}>ยกเลิก</button>
          <button className="beta4-drafts" type="button" disabled={busy} onClick={() => void loadDrafts()}><FilePenLine size={19} />ร่าง</button>
          <button className="beta4-post" type="button" disabled={!canPublish} onClick={() => void submit()}>{busy ? <span className="route-system-spinner tiny" /> : "โพสต์"}</button>
        </header>

        <div className="beta4-composer-scroll">
          <div className="beta4-composer-identity">
            <Avatar src={identity?.avatar_url} label={identity?.username || "WYNOS"} size={44} />
            <button className="beta4-audience-chip" type="button" disabled={busy} onClick={() => setAudienceOpen(true)}><Globe2 size={14} /><span>{audienceLabel(audience)}</span><ChevronDown size={13} /></button>
          </div>

          <textarea
            autoFocus
            className="beta4-compose-text"
            maxLength={500}
            value={caption}
            disabled={busy}
            onChange={(event) => setCaption(event.target.value)}
            placeholder={mode === "poll" ? "ตั้งคำถามโพล..." : "มีอะไรเกิดขึ้นบ้าง"}
          />

          {mode === "image" ? (
            previews.length ? <><div className="beta4-image-strip">{previews.map((url, index) => <div className={`beta4-image-preview ratio-${aspectRatio.replace(":", "-")}`} key={url}><img src={url} alt="" /><button type="button" aria-label={`ลบรูปที่ ${index + 1}`} onClick={() => setFiles((current) => current.filter((_, itemIndex) => itemIndex !== index))}><X size={16} /></button></div>)}</div><div className="beta4-ratio-chips" role="group" aria-label="อัตราส่วนรูป">{(["original", "1:1", "4:5", "16:9"] as AspectRatioChoice[]).map((ratio) => <button className={aspectRatio === ratio ? "active" : ""} type="button" onClick={() => setAspectRatio(ratio)} key={ratio}>{ratio === "original" ? "ต้นฉบับ" : ratio}</button>)}</div></> : null
          ) : (
            <div className="beta4-poll-composer">
              <div className="beta4-poll-options">
                {pollOptions.map((value, index) => <label key={index}><span>{index + 1}</span><input maxLength={80} value={value} disabled={busy} onChange={(event) => updatePollOption(index, event.target.value)} placeholder={`ตัวเลือก ${index + 1}`} />{pollOptions.length > 2 ? <button type="button" aria-label={`ลบตัวเลือก ${index + 1}`} onClick={() => removePollOption(index)}><X size={15} /></button> : null}</label>)}
              </div>
              {pollOptions.length < 4 ? <button className="beta4-add-option" type="button" disabled={busy} onClick={addPollOption}>+ เพิ่มตัวเลือก</button> : null}
              <strong className="beta4-duration-title">ระยะเวลาโหวต</strong>
              <div className="beta4-duration" role="group" aria-label="ระยะเวลาโหวต">{[1, 3, 7].map((days) => <button className={pollDuration === days ? "active" : ""} type="button" onClick={() => setPollDuration(days)} key={days}>{days} วัน</button>)}</div>
            </div>
          )}

          {caption.length > 400 ? <div className="beta4-character-count">{500 - caption.length}</div> : null}
          {error ? <p className="route-error beta4-composer-error">{error}</p> : null}
        </div>

        <div className="beta4-toolbar">
          <strong>เพิ่มไปยังโพสต์ของคุณ</strong>
          <div className="beta4-toolbar-actions">
            <button type="button" disabled={busy || mode === "poll" || files.length >= 9} onClick={() => galleryRef.current?.click()}><ImagePlus size={22} /><span>รูปภาพ</span></button>
            <button type="button" disabled={busy || mode === "poll" || files.length >= 9} onClick={() => cameraRef.current?.click()}><Camera size={22} /><span>กล้อง</span></button>
            <button className={mode === "poll" ? "active" : ""} type="button" disabled={busy} onClick={() => setMode((current) => current === "poll" ? "image" : "poll")}><BarChart3 size={22} /><span>โพล</span></button>
          </div>
          <input ref={galleryRef} hidden type="file" accept="image/*" multiple onChange={(event) => { setFiles((current) => [...current, ...Array.from(event.target.files ?? [])].slice(0, 9)); event.currentTarget.value = ""; }} />
          <input ref={cameraRef} hidden type="file" accept="image/*" capture="environment" onChange={(event) => { const picked = event.target.files?.[0]; if (picked) setFiles((current) => [...current, picked].slice(0, 9)); event.currentTarget.value = ""; }} />
        </div>

        {audienceOpen ? <div className="beta4-sheet-backdrop" role="presentation" onClick={() => setAudienceOpen(false)}><section className="beta4-sheet" role="dialog" aria-modal="true" aria-label="เลือกกลุ่มผู้ชม" onClick={(event) => event.stopPropagation()}><div className="beta4-sheet-grip" /><header><strong>ใครเห็นโพสต์นี้ได้</strong><button type="button" aria-label="ปิด" onClick={() => setAudienceOpen(false)}><X size={20} /></button></header>{audienceOptions.map((item) => { const Icon = item.icon; return <button className="beta4-audience-row" type="button" onClick={() => { setAudience(item.value); setAudienceOpen(false); }} key={item.value}><span className="beta4-audience-icon"><Icon size={18} /></span><span><strong>{item.label}</strong><small>{item.description}</small></span>{item.nested ? <ChevronRight size={18} /> : <i className={audience === item.value ? "selected" : ""} />}</button>; })}</section></div> : null}

        {draftsOpen ? <div className="beta4-sheet-backdrop" role="presentation" onClick={() => setDraftsOpen(false)}><section className="beta4-sheet beta4-drafts-sheet" role="dialog" aria-modal="true" aria-label="ร่าง" onClick={(event) => event.stopPropagation()}><div className="beta4-sheet-grip" /><header><strong>ร่าง</strong><button type="button" aria-label="ปิด" onClick={() => setDraftsOpen(false)}><X size={20} /></button></header>{draftsLoading ? <div className="route-empty"><span className="route-system-spinner" /></div> : drafts.length ? drafts.map((draft) => <button className="beta4-draft-row" type="button" onClick={() => openDraft(draft)} key={draft.id}><span><strong>{draft.caption?.trim() || (draft.poll_options?.length ? "โพลที่ยังไม่ได้เผยแพร่" : "ร่างที่ยังไม่ได้เผยแพร่")}</strong><small>{new Intl.DateTimeFormat("th-TH", { dateStyle: "medium", timeStyle: "short" }).format(new Date(draft.updated_at))}</small></span><ChevronRight size={18} /></button>) : <div className="route-empty">ยังไม่มีร่าง</div>}</section></div> : null}

        {closePrompt ? <div className="beta4-close-dialog-backdrop" role="presentation" onClick={() => setClosePrompt(false)}><section className="beta4-close-dialog" role="alertdialog" aria-modal="true" aria-label="บันทึกเป็นร่างก่อนออกไหม" onClick={(event) => event.stopPropagation()}><strong>บันทึกเป็นร่างก่อนออกไหม?</strong><div><button type="button" onClick={onClose}>ทิ้ง</button><button type="button" onClick={() => setClosePrompt(false)}>ยกเลิก</button><button className="primary" type="button" onClick={() => void saveDraft()}>บันทึกร่าง</button></div></section></div> : null}
      </section>
    </div>
  );
}
