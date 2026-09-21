/* eslint-disable @next/next/no-img-element */
"use client";

import {
  BarChart3,
  Camera,
  Check,
  Globe2,
  ImagePlus,
  LockKeyhole,
  Plus,
  Save,
  Users,
  X,
  type LucideIcon,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { Avatar } from "@/components/phase3-ui";
import { deleteDraft, fetchDraft, saveDraft } from "@/lib/drafts";
import { publishDropSafely } from "@/lib/drop-publication";
import { fetchHomeIdentity, type HomeIdentity } from "@/lib/home-parity-data";
import styles from "./beta4-composer-refresh.module.css";

type ComposeMode = "image" | "poll";
type AspectRatioChoice = "original" | "1:1" | "4:5" | "16:9";
type AudienceChoice = "everyone" | "friends" | "only_me";

type AudienceOption = {
  value: AudienceChoice;
  label: string;
  description: string;
  icon: LucideIcon;
};

const AUDIENCE_OPTIONS: AudienceOption[] = [
  {
    value: "everyone",
    label: "สาธารณะ",
    description: "ทุกคนเห็นโพสต์นี้ได้",
    icon: Globe2,
  },
  {
    value: "friends",
    label: "เพื่อน",
    description: "เฉพาะเพื่อนของคุณเท่านั้นที่เห็นโพสต์นี้ได้",
    icon: Users,
  },
  {
    value: "only_me",
    label: "เฉพาะฉัน",
    description: "มีเพียงคุณที่เห็นโพสต์นี้",
    icon: LockKeyhole,
  },
];

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
  const [audience, setAudience] = useState<AudienceChoice>("everyone");
  const [audienceOpen, setAudienceOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [closePrompt, setClosePrompt] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<{ uploaded: number; total: number } | null>(null);
  const [draftRecordId, setDraftRecordId] = useState<string | null>(null);
  const [existingImageUrl, setExistingImageUrl] = useState<string | null>(null);
  const [savingDraft, setSavingDraft] = useState(false);
  const [draftError, setDraftError] = useState("");
  const [autosaveStatus, setAutosaveStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const draftRecordIdRef = useRef<string | null>(null);
  const autosaveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const skipNextAutosaveRef = useRef(true); // true until the user actually edits something post-mount/post-draft-load
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
      draftRecordIdRef.current = row.id;
      setCaption(row.caption ?? "");
      setExistingImageUrl(row.image_url ?? null);
      if (row.poll_options && row.poll_options.length) { setMode("poll"); setPollOptions(row.poll_options); }
      skipNextAutosaveRef.current = true; // loading a saved draft into the form isn't itself an edit
    }).catch(() => undefined);
    return () => { live = false; };
  }, [client, draftId]);

  const previews = useMemo(() => files.map((file) => URL.createObjectURL(file)), [files]);
  useEffect(() => () => previews.forEach((url) => URL.revokeObjectURL(url)), [previews]);

  const selectedAudience = AUDIENCE_OPTIONS.find((option) => option.value === audience) ?? AUDIENCE_OPTIONS[0];
  const SelectedAudienceIcon = selectedAudience.icon;
  const pollValid = caption.trim().length > 0 && pollOptions.length >= 2 && pollOptions.every((value) => value.trim().length > 0 && value.trim().length <= 80) && new Set(pollOptions.map((value) => value.trim().toLowerCase())).size === pollOptions.length;
  const canPublish = !busy && (mode === "poll" ? pollValid : caption.trim().length > 0 || files.length > 0 || Boolean(existingImageUrl));
  const hasContent = caption.trim().length > 0 || files.length > 0 || Boolean(existingImageUrl) || pollOptions.some((value) => value.trim().length > 0);

  const requestClose = () => {
    if (busy) return;
    if (!hasContent) { onClose(); return; }
    setDraftError("");
    setClosePrompt(true);
  };

  // Shared by the close-prompt's "บันทึกร่าง", the always-visible quick-action
  // button, and autosave below — insert when no draft row exists yet, update
  // in place otherwise (mirrors lib/drafts.ts saveDraft's own upsert doc).
  const persistDraft = useCallback(async (): Promise<string> => {
    const id = await saveDraft(client, userId, {
      draftId: draftRecordIdRef.current,
      file: files[0] ?? null,
      existingImageUrl,
      caption,
      pollOptions: mode === "poll" ? pollOptions : null,
      pollDurationDays: mode === "poll" ? POLL_DURATION_DAYS : null,
    });
    draftRecordIdRef.current = id;
    setDraftRecordId(id);
    return id;
  }, [client, userId, files, existingImageUrl, caption, mode, pollOptions]);

  const saveDraftNow = async () => {
    setSavingDraft(true); setDraftError("");
    try { await persistDraft(); onClose(); }
    catch (reason) { setDraftError(reason instanceof Error ? reason.message : "บันทึกร่างไม่สำเร็จ ลองใหม่อีกครั้ง"); }
    finally { setSavingDraft(false); }
  };

  // Always-visible "บันทึกร่าง" quick action — WYN-185 item 4: the old flow
  // only offered saving a draft as a side effect of trying to close, which
  // the Founder flagged as not a clear/discoverable way to save one.
  const saveDraftExplicit = async () => {
    if (!hasContent || savingDraft) return;
    setSavingDraft(true); setAutosaveStatus("saving"); setDraftError("");
    try { await persistDraft(); setAutosaveStatus("saved"); }
    catch { setAutosaveStatus("error"); }
    finally { setSavingDraft(false); }
  };

  // Autosave every ~800ms of no further edits (WYN-185 item 4). Skips the
  // very first run after mount/after a draft finishes loading into the form,
  // so opening an existing draft doesn't immediately re-save it unchanged.
  useEffect(() => {
    if (skipNextAutosaveRef.current) { skipNextAutosaveRef.current = false; return; }
    if (!hasContent || busy) return;
    if (autosaveTimerRef.current) clearTimeout(autosaveTimerRef.current);
    autosaveTimerRef.current = setTimeout(() => {
      setAutosaveStatus("saving");
      void persistDraft().then(() => setAutosaveStatus("saved")).catch(() => setAutosaveStatus("error"));
    }, 800);
    return () => { if (autosaveTimerRef.current) clearTimeout(autosaveTimerRef.current); };
    // caption/pollOptions/mode/files/existingImageUrl are the editable draft
    // fields; persistDraft/hasContent/busy are intentionally excluded so a
    // re-render alone (e.g. busy flipping during publish) doesn't reset the
    // debounce timer.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [caption, pollOptions, mode, files, existingImageUrl]);

  useEffect(() => () => { if (autosaveTimerRef.current) clearTimeout(autosaveTimerRef.current); }, []);

  const publishPoll = async () => {
    const result = await client.rpc("create_poll_drop", {
      p_caption: caption.trim(),
      p_options: pollOptions.map((value) => value.trim()),
      p_duration_days: POLL_DURATION_DAYS,
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
    // A pending autosave debounce firing after publish deletes the draft
    // row would silently re-create it with now-stale content.
    if (autosaveTimerRef.current) { clearTimeout(autosaveTimerRef.current); autosaveTimerRef.current = null; }
    setBusy(true); setError(""); setUploadProgress(null);
    try {
      if (mode === "poll") await publishPoll();
      else await publishDropSafely(client, userId, {
        caption,
        files,
        audience,
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
        <header className={`beta4-composer-header ${styles.header}`}>
          <button className="beta4-cancel" type="button" onClick={requestClose}>ยกเลิก</button>
          <strong className={styles.draftTitle}>ฉบับร่าง</strong>
          <button className={`beta4-post ${styles.headerPost}`} type="button" disabled={!canPublish} onClick={() => void submit()}>{busy ? <span className="route-system-spinner tiny" /> : "โพสต์"}</button>
        </header>

        <div className={`beta4-composer-scroll ${styles.scroll}`}>
          <div className={styles.composerRow}>
            <div className={styles.avatarSlot}>
              <Avatar src={identity?.avatar_url} label={identity?.username || "WYNOS"} size={44} />
            </div>
            <div className={styles.composerBody}>
              <strong className={styles.authorName}>{identity?.display_name?.trim() || identity?.username || "WYNOS"}</strong>
              <textarea ref={captionRef} autoFocus className={`beta4-compose-text ${styles.composeText}`} maxLength={500} value={caption} disabled={busy} onChange={(event) => setCaption(event.target.value)} placeholder={mode === "poll" ? "ตั้งคำถามโพล..." : "มีอะไรเกิดขึ้นบ้าง"} />

              {uploadProgress && uploadProgress.total > 0 ? <div className="beta4-upload-progress"><span>กำลังอัปโหลด {uploadProgress.uploaded}/{uploadProgress.total} รูป... {Math.round((uploadProgress.uploaded / uploadProgress.total) * 100)}%</span><progress max={uploadProgress.total} value={uploadProgress.uploaded} /></div> : null}

              {mode === "image" ? (
                previews.length || existingImageUrl ? <><div className={`beta4-image-strip ${styles.mediaStrip}`}>
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
              {autosaveStatus === "saving" ? <p className="beta4-draft-status" role="status">กำลังบันทึกร่าง…</p>
                : autosaveStatus === "saved" ? <p className="beta4-draft-status" role="status">บันทึกร่างแล้ว</p>
                : autosaveStatus === "error" ? <p className="beta4-draft-status error" role="alert">บันทึกร่างไม่สำเร็จ ลองใหม่อีกครั้ง</p>
                : null}
            </div>
          </div>
        </div>

        <div className={`beta4-bottom-bar ${styles.bottomBar}`}>
          <div className={styles.quickActions}>
            <button className={`${styles.quickAction} ${styles.audienceAction}`} type="button" aria-label={`เลือกผู้ชมโพสต์ ตอนนี้เลือก ${selectedAudience.label}`} aria-haspopup="dialog" disabled={busy} onClick={() => setAudienceOpen(true)}>
              <SelectedAudienceIcon aria-hidden="true" />
              <span>{selectedAudience.label}</span>
            </button>
            <button className={styles.quickAction} type="button" aria-label="เพิ่มรูปภาพ" disabled={busy || mode === "poll" || files.length >= 9} onClick={() => galleryRef.current?.click()}>
              <ImagePlus aria-hidden="true" />
              <span>เพิ่มรูปภาพ</span>
            </button>
            <button className={styles.quickAction} type="button" aria-label="ถ่ายภาพ" disabled={busy || mode === "poll" || files.length >= 9} onClick={() => cameraRef.current?.click()}>
              <Camera aria-hidden="true" />
              <span>ถ่ายภาพ</span>
            </button>
            <button className={`${styles.quickAction} ${mode === "poll" ? styles.active : ""}`} type="button" aria-label="เพิ่มโพล" aria-pressed={mode === "poll"} disabled={busy} onClick={() => setMode((current) => current === "poll" ? "image" : "poll")}>
              <BarChart3 aria-hidden="true" />
              <span>เพิ่มโพล</span>
            </button>
            <button className={styles.quickAction} type="button" aria-label="บันทึกร่าง" disabled={busy || savingDraft || !hasContent} onClick={() => void saveDraftExplicit()}>
              {savingDraft ? <span className="route-system-spinner tiny" /> : <Save aria-hidden="true" />}
              <span>บันทึกร่าง</span>
            </button>
          </div>
          <input ref={galleryRef} hidden type="file" accept="image/*" multiple onChange={(event) => { setFiles((current) => [...current, ...Array.from(event.target.files ?? [])].slice(0, 9)); event.currentTarget.value = ""; }} />
          <input ref={cameraRef} hidden type="file" accept="image/*" capture="environment" onChange={(event) => { const picked = event.target.files?.[0]; if (picked) setFiles((current) => [...current, picked].slice(0, 9)); event.currentTarget.value = ""; }} />
        </div>

        {audienceOpen ? (
          <div className={styles.audienceOverlay} role="presentation" onClick={() => setAudienceOpen(false)}>
            <section className={styles.audienceSheet} role="dialog" aria-modal="true" aria-label="เลือกผู้ชมโพสต์" onClick={(event) => event.stopPropagation()}>
              <div className={styles.sheetHandle} aria-hidden="true" />
              <div className={styles.sheetHeader}>
                <strong>ใครเห็นโพสต์นี้ได้บ้าง</strong>
                <button type="button" aria-label="ปิด" onClick={() => setAudienceOpen(false)}><X size={20} /></button>
              </div>
              <div className={styles.audienceList}>
                {AUDIENCE_OPTIONS.map((option) => {
                  const OptionIcon = option.icon;
                  const selected = option.value === audience;
                  return (
                    <button
                      className={`${styles.audienceOption} ${selected ? styles.audienceSelected : ""}`}
                      type="button"
                      aria-pressed={selected}
                      onClick={() => { setAudience(option.value); setAudienceOpen(false); }}
                      key={option.value}
                    >
                      <span className={styles.audienceOptionIcon}><OptionIcon aria-hidden="true" /></span>
                      <span className={styles.audienceOptionCopy}>
                        <strong>{option.label}</strong>
                        <small>{option.description}</small>
                      </span>
                      <span className={`${styles.audienceCheck} ${selected ? styles.audienceCheckSelected : ""}`} aria-hidden="true">
                        {selected ? <Check size={14} /> : null}
                      </span>
                    </button>
                  );
                })}
              </div>
            </section>
          </div>
        ) : null}

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
