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
  Users,
  X,
  type LucideIcon,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState, type CSSProperties } from "react";
import { useRouter } from "next/navigation";
import type { SupabaseClient } from "@supabase/supabase-js";

import { Avatar } from "@/components/phase3-ui";
import { deleteDraft, fetchDraft, loadDraftImageFile, saveDraft } from "@/lib/drafts";
import { publishDropSafely } from "@/lib/drop-publication";
import { MAX_POST_IMAGES } from "@/lib/post-limits";
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
  const [exiting, setExiting] = useState(false);
  const [dragTouched, setDragTouched] = useState(false);
  const [dragging, setDragging] = useState(false);
  const [dragDistance, setDragDistance] = useState(0);
  const [uploadProgress, setUploadProgress] = useState<{ uploaded: number; total: number } | null>(null);
  const [draftRecordId, setDraftRecordId] = useState<string | null>(null);
  const [existingImageUrl, setExistingImageUrl] = useState<string | null>(null);
  const [savingDraft, setSavingDraft] = useState(false);
  const [draftError, setDraftError] = useState("");
  const [autosaveStatus, setAutosaveStatus] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const router = useRouter();
  const draftRecordIdRef = useRef<string | null>(null);
  const persistDraftQueueRef = useRef<Promise<string> | null>(null);
  const pendingNavRef = useRef<string | null>(null); // set when the close-prompt was opened via "ฉบับร่าง" (go to /drafts after resolving) instead of Cancel
  const autosaveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const exitTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pointerIdRef = useRef<number | null>(null);
  const pointerStartYRef = useRef(0);
  const pointerStartTimeRef = useRef(0);
  const dragDistanceRef = useRef(0);
  const suppressHandleClickRef = useRef(false);
  const middleSwipeSurfaceRef = useRef<HTMLDivElement | null>(null);
  const middleSwipeRef = useRef<{ identifier: number; startX: number; startY: number; active: boolean } | null>(null);
  const middleSwipeHandlersRef = useRef<{
    canStart: () => boolean;
    start: (pointerId: number, clientY: number) => void;
    move: (pointerId: number, clientY: number) => void;
    finish: (pointerId: number, cancelled?: boolean) => void;
  } | null>(null);
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

  // Recalculate after both typing and restoring a saved draft. onInput alone
  // misses the latter and would leave a multi-line saved caption one line tall.
  useEffect(() => {
    const field = captionRef.current;
    if (!field) return;
    field.style.height = "28px";
    field.style.height = `${Math.min(field.scrollHeight, 168)}px`;
  }, [caption]);

  const previews = useMemo(() => files.map((file) => URL.createObjectURL(file)), [files]);
  useEffect(() => () => previews.forEach((url) => URL.revokeObjectURL(url)), [previews]);

  const selectedAudience = AUDIENCE_OPTIONS.find((option) => option.value === audience) ?? AUDIENCE_OPTIONS[0];
  const SelectedAudienceIcon = selectedAudience.icon;
  const pollValid = caption.trim().length > 0 && pollOptions.length >= 2 && pollOptions.every((value) => value.trim().length > 0 && value.trim().length <= 80) && new Set(pollOptions.map((value) => value.trim().toLowerCase())).size === pollOptions.length;
  const canPublish = !busy && (mode === "poll" ? pollValid : caption.trim().length > 0 || files.length > 0 || Boolean(existingImageUrl));
  const hasContent = caption.trim().length > 0 || (mode === "poll" ? pollOptions.some((value) => value.trim().length > 0) : files.length > 0 || Boolean(existingImageUrl));

  // Leave the mounted sheet on screen long enough for its exit animation.
  // This is shared by Cancel, backdrop tap and the existing draft choices;
  // no content is discarded before the original confirmation has resolved.
  const closeWithSlide = () => {
    if (exiting || exitTimerRef.current !== null) return;
    const destination = pendingNavRef.current;
    setClosePrompt(false);
    // Collapse the software keyboard before the sheet exits on mobile.
    captionRef.current?.blur();
    setExiting(true);
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    exitTimerRef.current = setTimeout(() => {
      exitTimerRef.current = null;
      onClose();
      if (destination) router.push(destination);
    }, reduceMotion ? 0 : 260);
  };

  useEffect(() => () => {
    if (exitTimerRef.current !== null) clearTimeout(exitTimerRef.current);
  }, []);

  const requestClose = () => {
    if (busy || exiting) return;
    pendingNavRef.current = null;
    if (!hasContent) { closeWithSlide(); return; }
    setDraftError("");
    setClosePrompt(true);
  };

  // The grab handle is an actual gesture surface, not just a decoration.
  // Scope pointer capture to this strip so scrolling the composer stays native.
  const startHandleDrag = (pointerId: number, clientY: number) => {
    if (busy || exiting || closePrompt || audienceOpen) return;
    pointerIdRef.current = pointerId;
    pointerStartYRef.current = clientY;
    pointerStartTimeRef.current = performance.now();
    dragDistanceRef.current = 0;
    suppressHandleClickRef.current = false;
    setDragDistance(0);
    setDragTouched(true);
    setDragging(true);
  };

  const moveHandleDrag = (pointerId: number, clientY: number) => {
    if (pointerIdRef.current !== pointerId) return;
    const next = Math.max(0, clientY - pointerStartYRef.current);
    dragDistanceRef.current = next;
    setDragDistance(next);
  };

  const finishHandleDrag = (pointerId: number, cancelled = false) => {
    if (pointerIdRef.current !== pointerId) return;
    pointerIdRef.current = null;
    setDragging(false);
    const distance = dragDistanceRef.current;
    const elapsed = Math.max(1, performance.now() - pointerStartTimeRef.current);
    suppressHandleClickRef.current = distance > 8;
    if (!cancelled && (distance >= 105 || (distance >= 48 && distance / elapsed > 0.55))) {
      if (hasContent) {
        // Restore the normal 92% sheet behind the existing draft prompt.
        dragDistanceRef.current = 0;
        setDragDistance(0);
      }
      requestClose();
    } else {
      dragDistanceRef.current = 0;
      setDragDistance(0);
    }
  };

  // A downward swipe from the empty middle of the composer should dismiss
  // just like swiping the grab handle. Keep native scrolling for long drafts:
  // only take over a downward gesture when the central scroll area is already
  // at its top. Native non-passive touch listeners let iOS Safari cancel its
  // overscroll before WebKit takes ownership of the gesture; React's delegated
  // touch handlers may be passive and cannot reliably do that.
  useEffect(() => {
    middleSwipeHandlersRef.current = {
      canStart: () => !busy && !exiting && !closePrompt && !audienceOpen,
      start: startHandleDrag,
      move: moveHandleDrag,
      finish: finishHandleDrag,
    };
  });

  useEffect(() => {
    const surface = middleSwipeSurfaceRef.current;
    if (!surface) return;
    const gesturePointerId = (identifier: number) => -identifier - 1000;

    const onTouchStart = (event: TouchEvent) => {
      if (event.touches.length !== 1 || surface.scrollTop > 1 || !middleSwipeHandlersRef.current?.canStart()) return;
      const target = event.target;
      // Editing, image gestures, polls and interactive controls always win.
      if (!(target instanceof Element) || target.closest(
        "textarea, input, select, button, a, [role='button'], [contenteditable='true'], .beta4-image-strip, .beta4-ratio-chips, .beta4-poll-composer",
      )) return;
      const touch = event.changedTouches[0];
      if (!touch) return;
      middleSwipeRef.current = {
        identifier: touch.identifier,
        startX: touch.clientX,
        startY: touch.clientY,
        active: false,
      };
    };

    const onTouchMove = (event: TouchEvent) => {
      const swipe = middleSwipeRef.current;
      if (!swipe) return;
      if (event.touches.length !== 1 || !middleSwipeHandlersRef.current?.canStart()) {
        if (swipe.active) middleSwipeHandlersRef.current?.finish(gesturePointerId(swipe.identifier), true);
        middleSwipeRef.current = null;
        return;
      }
      const touch = Array.from(event.changedTouches).find((item) => item.identifier === swipe.identifier);
      if (!touch) return;
      const dy = touch.clientY - swipe.startY;
      const dx = Math.abs(touch.clientX - swipe.startX);
      if (!swipe.active) {
        // Upward or horizontal gestures belong to native scrolling/carousels.
        if (dy < -8 || (dx > 12 && dx > Math.abs(dy)) || surface.scrollTop > 1) {
          middleSwipeRef.current = null;
          return;
        }
        if (dy < 4 || dy <= dx * 1.2) return;
        middleSwipeHandlersRef.current?.start(gesturePointerId(swipe.identifier), swipe.startY);
        swipe.active = true;
      }
      if (event.cancelable) event.preventDefault();
      middleSwipeHandlersRef.current?.move(gesturePointerId(swipe.identifier), touch.clientY);
    };

    const finishTouch = (event: TouchEvent, cancelled: boolean) => {
      const swipe = middleSwipeRef.current;
      if (!swipe || !Array.from(event.changedTouches).some((item) => item.identifier === swipe.identifier)) return;
      middleSwipeRef.current = null;
      if (swipe.active) middleSwipeHandlersRef.current?.finish(gesturePointerId(swipe.identifier), cancelled);
    };
    const onTouchEnd = (event: TouchEvent) => finishTouch(event, false);
    const onTouchCancel = (event: TouchEvent) => finishTouch(event, true);

    surface.addEventListener("touchstart", onTouchStart, { passive: true });
    surface.addEventListener("touchmove", onTouchMove, { passive: false });
    surface.addEventListener("touchend", onTouchEnd, { passive: true });
    surface.addEventListener("touchcancel", onTouchCancel, { passive: true });
    return () => {
      surface.removeEventListener("touchstart", onTouchStart);
      surface.removeEventListener("touchmove", onTouchMove);
      surface.removeEventListener("touchend", onTouchEnd);
      surface.removeEventListener("touchcancel", onTouchCancel);
      middleSwipeRef.current = null;
    };
  }, []);

  // "ฉบับร่าง" header title -- tapping it goes to the saved-drafts list. With
  // nothing worth keeping, just navigate; with in-progress content, reuse
  // the same close-prompt as Cancel so it's never silently discarded, then
  // continue to /drafts once that resolves (see pendingNavRef below).
  const goToDrafts = () => {
    if (busy || exiting) return;
    pendingNavRef.current = "/drafts";
    if (!hasContent) { closeWithSlide(); return; }
    setDraftError("");
    setClosePrompt(true);
  };

  const closeAndNavigate = () => closeWithSlide();

  // Shared by the close-prompt's "บันทึกร่าง" and autosave below -- insert
  // when no draft row exists yet, update in place otherwise (mirrors
  // lib/drafts.ts saveDraft's own upsert doc).
  const persistDraft = useCallback(async (): Promise<string> => {
    // Serialize autosaves/explicit saves: no duplicate first drafts or stale write races.
    const run = async (): Promise<string> => {
      const id = await saveDraft(client, userId, {
        draftId: draftRecordIdRef.current,
        file: mode === "image" ? (files[0] ?? null) : null,
        existingImageUrl: mode === "image" ? existingImageUrl : null,
        caption,
        pollOptions: mode === "poll" ? pollOptions : null,
        pollDurationDays: mode === "poll" ? POLL_DURATION_DAYS : null,
      });
      draftRecordIdRef.current = id;
      setDraftRecordId(id);
      return id;
    };
    const previous = persistDraftQueueRef.current;
    const next: Promise<string> = previous
      ? previous.catch(() => undefined).then(run)
      : run();
    persistDraftQueueRef.current = next;
    try { return await next; }
    finally {
      if (persistDraftQueueRef.current === next) persistDraftQueueRef.current = null;
    }
  }, [client, userId, files, existingImageUrl, caption, mode, pollOptions]);

  const saveDraftNow = async () => {
    setSavingDraft(true); setDraftError("");
    try { await persistDraft(); closeAndNavigate(); }
    catch (reason) { setDraftError(reason instanceof Error ? reason.message : "บันทึกร่างไม่สำเร็จ ลองใหม่อีกครั้ง"); }
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
    if (autosaveTimerRef.current) { clearTimeout(autosaveTimerRef.current); autosaveTimerRef.current = null; }
    setBusy(true); setError(""); setUploadProgress(null);
    try {
      // Wait for pending autosave before publication and draft deletion.
      if (persistDraftQueueRef.current) await persistDraftQueueRef.current.catch(() => undefined);
      if (mode === "poll") await publishPoll();
      else {
        // A reopened image draft may have no newly selected File.
        const publishFiles = files.length ? files
          : existingImageUrl ? [await loadDraftImageFile(client, userId, existingImageUrl)] : [];
        await publishDropSafely(client, userId, {
          caption,
          files: publishFiles,
          audience,
          excludedFriendIds: [],
          mentionedUserIds: [],
          imageAspectRatio: aspectRatio,
          onImageUploaded: (uploaded, total) => setUploadProgress(total > 0 ? { uploaded, total } : null),
        });
      }
      const savedDraftId = draftRecordIdRef.current;
      if (savedDraftId) void deleteDraft(client, savedDraftId).catch(() => undefined);
      onPublished();
      onClose();
    } catch (reason) { setError(reason instanceof Error ? reason.message : "แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง"); }
    finally { setBusy(false); setUploadProgress(null); }
  };

  const addPollOption = () => setPollOptions((current) => current.length >= 4 ? current : [...current, ""]);
  const updatePollOption = (index: number, value: string) => setPollOptions((current) => current.map((item, itemIndex) => itemIndex === index ? value : item));
  const removePollOption = (index: number) => setPollOptions((current) => current.length <= 2 ? current : current.filter((_, itemIndex) => itemIndex !== index));

  return (
    <div
      className={`route-modal-backdrop beta4-composer-backdrop ${exiting ? "is-closing" : ""} ${dragTouched ? "has-dragged" : ""} ${dragging ? "is-dragging" : ""}`}
      role="presentation"
      style={{ "--wyn-composer-drag": `${dragDistance}px` } as CSSProperties}
      onClick={requestClose}
    >
      <section className="beta4-composer" role="dialog" aria-modal="true" aria-label="สร้างโพสต์" onClick={(event) => event.stopPropagation()}>
        <button
          className="beta4-composer-drag-region"
          type="button"
          aria-label="ดึงลงหรือแตะเพื่อปิดหน้าสร้างโพสต์"
          onPointerDown={(event) => {
            if (event.pointerType === "mouse" && event.button !== 0) return;
            if (busy || exiting || closePrompt || audienceOpen) return;
            startHandleDrag(event.pointerId, event.clientY);
            event.currentTarget.setPointerCapture(event.pointerId);
          }}
          onPointerMove={(event) => moveHandleDrag(event.pointerId, event.clientY)}
          onPointerUp={(event) => {
            if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId);
            finishHandleDrag(event.pointerId);
          }}
          onPointerCancel={(event) => finishHandleDrag(event.pointerId, true)}
          onClick={() => {
            if (suppressHandleClickRef.current) { suppressHandleClickRef.current = false; return; }
            requestClose();
          }}
        >
          <span className="beta4-composer-sheet-handle" aria-hidden="true" />
        </button>
        <header className={`beta4-composer-header ${styles.header}`}>
          <button className="beta4-cancel" type="button" onClick={requestClose}>ยกเลิก</button>
          <button className={styles.draftTitle} type="button" onClick={goToDrafts}>ฉบับร่าง</button>
          <button className={`beta4-post ${styles.headerPost}`} type="button" disabled={!canPublish} onClick={() => void submit()}>{busy ? <span className="route-system-spinner tiny" /> : "โพสต์"}</button>
        </header>

        <div ref={middleSwipeSurfaceRef} className={`beta4-composer-scroll ${styles.scroll}`}>
          <div className={styles.composerRow}>
            <div className={styles.avatarSlot}>
              <Avatar src={identity?.avatar_url} label={identity?.username || "WYNOS"} size={44} />
            </div>
            <div className={styles.composerBody}>
              <strong className={styles.authorName}>{identity?.display_name?.trim() || identity?.username || "WYNOS"}</strong>
              <textarea
                ref={captionRef}
                autoFocus
                className={`beta4-compose-text ${styles.composeText}`}
                maxLength={500}
                rows={1}
                value={caption}
                disabled={busy}
                onInput={(event) => {
                  const field = event.currentTarget;
                  field.style.height = "28px";
                  field.style.height = `${Math.min(field.scrollHeight, 168)}px`;
                }}
                onChange={(event) => setCaption(event.target.value)}
                placeholder={mode === "poll" ? "ตั้งคำถามโพล..." : "มีอะไรเกิดขึ้นบ้าง"}
              />

              {uploadProgress && uploadProgress.total > 0 ? <div className="beta4-upload-progress"><span>กำลังอัปโหลด {uploadProgress.uploaded}/{uploadProgress.total} รูป... {Math.round((uploadProgress.uploaded / uploadProgress.total) * 100)}%</span><progress max={uploadProgress.total} value={uploadProgress.uploaded} /></div> : null}

              {mode === "image" ? (
                previews.length || existingImageUrl ? <><div className={`beta4-image-strip ${styles.mediaStrip}`}>
                  {!files.length && existingImageUrl ? <div className={`beta4-image-preview ratio-${aspectRatio.replace(":", "-")}`} key="existing-draft-image"><img src={existingImageUrl} alt="" /><button type="button" aria-label="ลบรูปที่บันทึกไว้ในร่าง" onClick={() => setExistingImageUrl(null)}><X size={13} /></button></div> : null}
                  {previews.map((url, index) => <div className={`beta4-image-preview ratio-${aspectRatio.replace(":", "-")}`} key={url}><img src={url} alt="" /><button type="button" aria-label={`ลบรูปที่ ${index + 1}`} onClick={() => setFiles((current) => current.filter((_, itemIndex) => itemIndex !== index))}><X size={13} /></button></div>)}
                </div><div className="beta4-ratio-chips" role="group" aria-label="อัตราส่วนรูป">{(["original", "1:1", "4:5", "16:9"] as AspectRatioChoice[]).map((ratio) => <button className={`ratio-chip ratio-${ratio.replace(":", "-")} ${aspectRatio === ratio ? "active" : ""}`} aria-pressed={aspectRatio === ratio} type="button" onClick={() => setAspectRatio(ratio)} key={ratio}>{ratio === "original" ? "ต้นฉบับ" : ratio}</button>)}</div><div className="beta4-image-count">{files.length}/{MAX_POST_IMAGES}</div></> : null
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
            <button className={styles.quickAction} type="button" aria-label="เพิ่มรูปภาพ" disabled={busy || mode === "poll" || files.length >= MAX_POST_IMAGES} onClick={() => galleryRef.current?.click()}>
              <ImagePlus aria-hidden="true" />
              <span>เพิ่มรูปภาพ</span>
            </button>
            <button className={styles.quickAction} type="button" aria-label="ถ่ายภาพ" disabled={busy || mode === "poll" || files.length >= MAX_POST_IMAGES} onClick={() => cameraRef.current?.click()}>
              <Camera aria-hidden="true" />
              <span>ถ่ายภาพ</span>
            </button>
            <button className={`${styles.quickAction} ${mode === "poll" ? styles.active : ""}`} type="button" aria-label="เพิ่มโพล" aria-pressed={mode === "poll"} disabled={busy} onClick={() => setMode((current) => current === "poll" ? "image" : "poll")}>
              <BarChart3 aria-hidden="true" />
              <span>เพิ่มโพล</span>
            </button>
          </div>
          <input ref={galleryRef} hidden type="file" accept="image/*" multiple onChange={(event) => {
            const picked = Array.from(event.target.files ?? []);
            setFiles((current) => {
              const combined = [...current, ...picked];
              if (combined.length > MAX_POST_IMAGES) setError(`เลือกรูปได้สูงสุด ${MAX_POST_IMAGES} รูปต่อโพสต์`);
              return combined.slice(0, MAX_POST_IMAGES);
            });
            event.currentTarget.value = "";
          }} />
          <input ref={cameraRef} hidden type="file" accept="image/*" capture="environment" onChange={(event) => {
            const picked = event.target.files?.[0];
            if (!picked) return;
            setFiles((current) => {
              if (current.length >= MAX_POST_IMAGES) { setError(`เลือกรูปได้สูงสุด ${MAX_POST_IMAGES} รูปต่อโพสต์`); return current; }
              return [...current, picked].slice(0, MAX_POST_IMAGES);
            });
            event.currentTarget.value = "";
          }} />
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
                <button type="button" disabled={savingDraft} onClick={closeAndNavigate}>ทิ้ง</button>
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
