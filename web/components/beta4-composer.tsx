/* eslint-disable @next/next/no-img-element */
"use client";

import { BarChart3, Camera, ImagePlus, Plus, X } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { Avatar } from "@/components/phase3-ui";
import { deleteDraft, fetchDraft, saveDraft } from "@/lib/drafts";
import { publishDropSafely } from "@/lib/drop-publication";
import { fetchHomeIdentity, type HomeIdentity } from "@/lib/home-parity-data";

type ComposeMode = "image" | "poll";
type AspectRatioChoice = "original" | "1:1" | "4:5" | "16:9";

/** Poll duration is fixed at Flutter's own default (create_drop_screen.dart's
 * `_pollDurationDays = 1`) — the reference design has no duration picker. */
const POLL_DURATION_DAYS = 1;

export function Beta4Composer({
  client,
  userId,
  draftId,
  onClose,
  onPublished,
}: {
  client: SupabaseClient;
  userId: string;
  draftId?: string | null;
  onClose: () => void;
  onPublished: () => void;
}) {
  const [identity, setIdentity] = useState<HomeIdentity | null>(null);
  const [caption, setCaption] = useState("");
  const [files, setFiles] = useState<File[]>([]);
  const [mode, setMode] = useState<ComposeMode>("image");
  const [aspectRatio, setAspectRatio] = useState<AspectRatioChoice>("4:5");
  const [pollOptions, setPollOptions] = useState(["", ""]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [closePrompt, setClosePrompt] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<{ uploaded: number; total: number } | null>(null);
  const [draftRecordId, setDraftRecordId] = useState<string | null>(null);
  const [existingImageUrl, setExistingImageUrl] = useState<string | null>(null);
  const [savingDraft, setSavingDraft] = useState(false);
  const [draftError, setDraftError] = useState("");
  const galleryRef = useRef<HTMLInputElement | null>(null);
  const cameraRef = useRef<HTMLInputElement | null>(null);
  const captionRef = useRef<HTMLTextAreaElement | null>(null);

  useEffect(() => {
    let live = true;
    void fetchHomeIdentity(client, userId).then((value) => { if (live) setIdentity(value); }).catch(() => undefined);
    return () => { live = false; };
  }, [client, userId]);

  useEffect(() => {
    if (!draftId) return;
    let live = true;
    void fetchDraft(client, draftId).then((row) => {
      if (!live || !row) return;
      setDraftRecordId(row.id);
      setCaption(row.caption ?? "");
      setExistingImageUrl(row.image_url ?? null);
      if (row.poll_options && row.poll_options.length) { setMode("poll"); setPollOptions(row.poll_options); }
    }).catch(() => undefined);
    return () => { live = false; };
  }, [client, draftId]);

  const previews = useMemo(() => files.map((file) => URL.createObjectURL(file)), [files]);
  useEffect(() => () => previews.forEach((url) => URL.revokeObjectURL(url)), [previews]);

  const pollValid = caption.trim().length > 0 && pollOptions.length >= 2 && pollOptions.every((value) => value.trim().length > 0 && value.trim().length <= 80) && new Set(pollOptions.map((value) => value.trim().toLowerCase())).size === pollOptions.length;
  const canPublish = !busy && (mode === "poll" ? pollValid : caption.trim().length > 0 || files.length > 0 || Boolean(existingImageUrl));
  const hasContent = caption.trim().length > 0 || files.length > 0 || Boolean(existingImageUrl) || pollOptions.some((value) => value.trim().length > 0);

  const requestClose = () => {
    if (busy) return;
    if (!hasContent) { onClose(); return; }
    setDraftError("");
    setClosePrompt(true);
  };

  const saveDraftNow = async () => {
    setSavingDraft(true); setDraftError("");
    try {
      const id = await saveDraft(client, userId, {
        draftId: draftRecordId,
        file: files[0] ?? null,
        existingImageUrl,
        caption,
        pollOptions: mode === "poll" ? pollOptions : null,
        pollDurationDays: mode === "poll" ? POLL_DURATION_DAYS : null,
      });
      setDraftRecordId(id);
      onClose();
    } catch (reason) { setDraftError(reason instanceof Error ? reason.message : "บันทึกร่างไม่สำเร็จ ลองใหม่อีกครั้ง"); }
    finally { setSavingDraft(false); }
  };

  const publishPoll = async () => {
    const result = await client.rpc("create_poll_drop", {
      p_caption: caption.trim(),
      p_options: pollOptions.map((value) => value.trim()),
      p_duration_days: POLL_DURATION_DAYS,
      p_mentioned_user_ids: [],
      p_audience: "everyone",
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
    setBusy(true); setError(""); setUploadProgress(null);
    try {
      if (mode === "poll") await publishPoll();
      else await publishDropSafely(client, userId, {
        caption,
        files,
        audience: "everyone",
        excludedFriendIds: [],
        mentionedUserIds: [],
        imageAspectRatio: aspectRatio,
        onImageUploaded: (uploaded, total) => setUploadProgress(total > 0 ? { uploaded, total } : null),
      });
      if (draftRecordId) void deleteDraft(client, draftRecordId).catch(() => undefined);
      onPublished();
      onClose();
    } catch (reason) { setError(reason instanceof Error ? reason.message : "แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง"); }
    finally { setBusy(false); setUploadProgress(null); }
  };

  const addPollOption = () => setPollOptions((current) => current.length >= 4 ? current : [...current, ""]);
  const updatePollOption = (index: number, value: string) => setPollOptions((current) => current.map((item, itemIndex) => itemIndex === index ? value : item));
  const removePollOption = (index: number) => setPollOptions((current) => current.length <= 2 ? current : current.filter((_, itemIndex) => itemIndex !== index));

  return (
    <div className="route-modal-backdrop beta4-composer-backdrop" role="presentation" onClick={requestClose}>
      <section className="beta4-composer" role="dialog" aria-modal="true" aria-label="สร้างโพสต์" onClick={(event) => event.stopPropagation()}>
        <header className="beta4-composer-header">
          <button className="beta4-cancel" type="button" onClick={requestClose}>ยกเลิก</button>
          <span className="beta4-composer-header-title">ฉบับร่าง</span>
          <button className="beta4-post" type="button" disabled={!canPublish} onClick={() => void submit()}>{busy ? <span className="route-system-spinner tiny" /> : "โพสต์"}</button>
        </header>

        <div className="beta4-composer-scroll">
          <div className="beta4-composer-identity">
            <Avatar src={identity?.avatar_url} label={identity?.username || "WYNOS"} size={44} />
            <strong>{identity?.display_name?.trim() || identity?.username || "WYNOS"}</strong>
          </div>

          <textarea ref={captionRef} autoFocus className="beta4-compose-text" maxLength={500} value={caption} disabled={busy} onChange={(event) => setCaption(event.target.value)} placeholder={mode === "poll" ? "ตั้งคำถามโพล..." : "มีอะไรเกิดขึ้นบ้าง"} />
          {uploadProgress && uploadProgress.total > 0 ? <div className="beta4-upload-progress"><span>กำลังอัปโหลด {uploadProgress.uploaded}/{uploadProgress.total} รูป... {Math.round((uploadProgress.uploaded / uploadProgress.total) * 100)}%</span><progress max={uploadProgress.total} value={uploadProgress.uploaded} /></div> : null}

          {mode === "image" ? (
            previews.length || existingImageUrl ? <><div className="beta4-image-strip">
              {!files.length && existingImageUrl ? <div className={`beta4-image-preview ratio-${aspectRatio.replace(":", "-")}`} key="existing-draft-image"><img src={existingImageUrl} alt="" /><button type="button" aria-label="ลบรูปที่บันทึกไว้ในร่าง" onClick={() => setExistingImageUrl(null)}><X size={13} /></button></div> : null}
              {previews.map((url, index) => <div className={`beta4-image-preview ratio-${aspectRatio.replace(":", "-")}`} key={url}><img src={url} alt="" /><button type="button" aria-label={`ลบรูปที่ ${index + 1}`} onClick={() => setFiles((current) => current.filter((_, itemIndex) => itemIndex !== index))}><X size={13} /></button></div>)}
            </div><div className="beta4-ratio-chips" role="group" aria-label="อัตราส่วนรูป">{(["original", "1:1", "4:5", "16:9"] as AspectRatioChoice[]).map((ratio) => <button className={`ratio-chip ratio-${ratio.replace(":", "-")} ${aspectRatio === ratio ? "active" : ""}`} aria-pressed={aspectRatio === ratio} type="button" onClick={() => setAspectRatio(ratio)} key={ratio}>{ratio === "original" ? "ต้นฉบับ" : ratio}</button>)}</div><div className="beta4-image-count">{files.length}/9</div></> : null
          ) : (
            <div className="beta4-poll-composer">
              <div className="beta4-poll-options">{pollOptions.map((value, index) => <label key={index}><input maxLength={80} value={value} disabled={busy} onChange={(event) => updatePollOption(index, event.target.value)} placeholder={`ตัวเลือกที่ ${index + 1}`} />{index >= 2 ? <button type="button" aria-label={`ลบตัวเลือก ${index + 1}`} onClick={() => removePollOption(index)}><X size={18} /></button> : null}</label>)}</div>
              {pollOptions.length < 4 ? <button className="beta4-add-option" type="button" disabled={busy} onClick={addPollOption}><Plus size={18} />เพิ่มตัวเลือก</button> : null}
            </div>
          )}

          {error ? <p className="route-error beta4-composer-error">{error}</p> : null}

          <div className="beta4-toolbar">
            <div className="beta4-toolbar-actions">
              <button type="button" aria-label="แนบรูปภาพ" disabled={busy || mode === "poll" || files.length >= 9} onClick={() => galleryRef.current?.click()}><ImagePlus size={22} /></button>
              <button type="button" aria-label="เปิดกล้อง" disabled={busy || mode === "poll" || files.length >= 9} onClick={() => cameraRef.current?.click()}><Camera size={22} /></button>
              <button className={mode === "poll" ? "active" : ""} type="button" aria-label="สร้างโพล" aria-pressed={mode === "poll"} disabled={busy} onClick={() => setMode((current) => current === "poll" ? "image" : "poll")}><BarChart3 size={22} /></button>
            </div>
            <input ref={galleryRef} hidden type="file" accept="image/*" multiple onChange={(event) => { setFiles((current) => [...current, ...Array.from(event.target.files ?? [])].slice(0, 9)); event.currentTarget.value = ""; }} />
            <input ref={cameraRef} hidden type="file" accept="image/*" capture="environment" onChange={(event) => { const picked = event.target.files?.[0]; if (picked) setFiles((current) => [...current, picked].slice(0, 9)); event.currentTarget.value = ""; }} />
          </div>

          {mode === "poll" ? <div className="beta4-character-count">โพลจะปิดใน 1 วัน</div> : caption.length > 400 ? <div className="beta4-character-count">{500 - caption.length}</div> : null}
        </div>

        {closePrompt ? (
          <div className="route-modal-backdrop detail-dialog-backdrop" role="presentation" onClick={() => !savingDraft && setClosePrompt(false)}>
            <section className="route-modal detail-confirm-dialog" role="alertdialog" aria-modal="true" aria-label="บันทึกเป็นร่างก่อนออกไหม?" onClick={(event) => event.stopPropagation()}>
              <strong>บันทึกเป็นร่างก่อนออกไหม?</strong>
              {draftError ? <p className="route-error">{draftError}</p> : null}
              <footer>
                <button type="button" disabled={savingDraft} onClick={onClose}>ทิ้ง</button>
                <button type="button" disabled={savingDraft} onClick={() => setClosePrompt(false)}>ยกเลิก</button>
                <button className="primary" type="button" disabled={savingDraft} onClick={() => void saveDraftNow()}>{savingDraft ? <span className="route-system-spinner tiny" /> : "บันทึกร่าง"}</button>
              </footer>
            </section>
          </div>
        ) : null}
      </section>
    </div>
  );
}
