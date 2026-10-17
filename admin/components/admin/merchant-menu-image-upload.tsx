"use client";

import { useEffect, useId, useRef, useState } from "react";
import Image from "next/image";
import { createClient } from "@/lib/supabase/client";
import {
  MENU_IMAGE_TIMEOUT_MS, MenuImageUploadError, menuImageUploadErrorMessage,
  prepareMerchantMenuImage, uploadMerchantMenuImage, waitForMenuImageTask,
} from "@/lib/admin-merchant-menu-image-upload";

type UploadState = {
  storeId: string; stage: "idle" | "preparing" | "uploading" | "processing" | "success" | "error";
  progress: number; message: string; preview: string;
};
const emptyState = (storeId: string): UploadState => ({ storeId, stage: "idle", progress: 0, message: "", preview: "" });
const buttonClass = "min-h-11 rounded-lg border px-4 text-sm font-medium disabled:opacity-40";

export function MerchantMenuImageUpload({ storeId, disabled, onUploaded, onBusyChange }: {
  storeId: string; disabled: boolean; onUploaded: (path: string) => void; onBusyChange: (busy: boolean) => void;
}) {
  const inputId = useId();
  const helpId = useId();
  const [state, setState] = useState<UploadState>(() => emptyState(storeId));
  const active = useRef<AbortController | null>(null);
  const candidate = useRef<File | null>(null);
  const preview = useRef("");
  const busyCallback = useRef(onBusyChange);
  useEffect(() => { busyCallback.current = onBusyChange; }, [onBusyChange]);
  useEffect(() => () => {
    const job = active.current;
    active.current = null;
    job?.abort();
    if (job) busyCallback.current(false);
    candidate.current = null;
    if (preview.current) URL.revokeObjectURL(preview.current);
    preview.current = "";
  }, [storeId]);

  const current = state.storeId === storeId ? state : emptyState(storeId);
  const busy = ["preparing", "uploading", "processing"].includes(current.stage);

  async function upload(file: File | null) {
    if (!file || disabled || active.current) return;
    const controller = new AbortController();
    active.current = controller;
    candidate.current = file;
    busyCallback.current(true);
    if (preview.current) URL.revokeObjectURL(preview.current);
    preview.current = "";
    setState({ ...emptyState(storeId), stage: "preparing" });
    let timedOut = false;
    // This deadline also covers decoding and session retrieval, beyond XHR's own request timeout.
    const timeout = window.setTimeout(() => { timedOut = true; controller.abort(); }, MENU_IMAGE_TIMEOUT_MS);
    const isCurrent = () => active.current === controller && !controller.signal.aborted;
    try {
      const image = await prepareMerchantMenuImage(file, controller.signal);
      if (!isCurrent()) return;
      const preparedPreview = URL.createObjectURL(image);
      preview.current = preparedPreview;
      setState(value => ({ ...value, preview: preparedPreview }));
      // The token is forwarded only. The Edge Function independently authenticates and authorizes it.
      const { data, error } = await waitForMenuImageTask(createClient().auth.getSession(), controller.signal);
      if (error || !data.session?.access_token) throw new MenuImageUploadError("401");
      if (!isCurrent()) return;
      setState(value => ({ ...value, stage: "uploading" }));
      const path = await uploadMerchantMenuImage({
        supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL ?? "",
        publishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "",
        accessToken: data.session.access_token, storeId, image, signal: controller.signal,
        onProgress: progress => { if (isCurrent()) setState(value => ({ ...value, progress })); },
        onProcessing: () => { if (isCurrent()) setState(value => ({ ...value, stage: "processing" })); },
      });
      if (!isCurrent()) return;
      onUploaded(path);
      candidate.current = null;
      setState(value => ({ ...value, stage: "success", progress: 100, message: "อัปโหลดแล้ว กดยืนยันบันทึกเมนูเพื่อใช้รูปใหม่นี้" }));
    } catch (error) {
      if (active.current !== controller) return;
      setState(value => ({ ...value, stage: "error", message: menuImageUploadErrorMessage(timedOut ? new MenuImageUploadError("timeout") : error) }));
    } finally {
      window.clearTimeout(timeout);
      if (active.current === controller) {
        active.current = null;
        busyCallback.current(false);
      }
    }
  }

  function cancel() {
    const job = active.current;
    if (!job) return;
    active.current = null;
    job.abort();
    busyCallback.current(false);
    setState(value => ({ ...value, stage: "error", message: menuImageUploadErrorMessage(new MenuImageUploadError("aborted")) }));
  }

  const status = current.stage === "preparing" ? "กำลังปรับขนาดและเตรียมรูป…"
    : current.stage === "uploading" ? `กำลังอัปโหลดรูป ${current.progress}%`
      : current.stage === "processing" ? "ส่งรูปครบแล้ว กำลังตรวจสอบรูปในระบบ…" : current.message;

  return <div className="space-y-3 rounded-xl border bg-muted/20 p-3" aria-busy={busy}>
    <label htmlFor={inputId} className="block text-sm font-medium">อัปโหลดรูปเมนูใหม่</label>
    <p id={helpId} className="text-xs leading-relaxed text-muted-foreground">
      JPEG, PNG หรือ WebP ไม่เกิน 8 MB และ 32 ล้านพิกเซล ระบบจะปรับขนาดรูปก่อนอัปโหลด รูปใหม่จะอยู่ในแบบร่างจนกว่าจะกดยืนยันบันทึกเมนู
    </p>
    <input id={inputId} type="file" accept="image/jpeg,image/png,image/webp" disabled={disabled || busy || !storeId}
      aria-describedby={helpId} className="min-h-11 w-full max-w-full rounded-lg border bg-background p-2 text-sm file:mr-3 file:min-h-11 file:rounded-md file:border file:bg-background file:px-3 file:text-sm disabled:opacity-40"
      onChange={event => { const file = event.target.files?.[0] ?? null; event.target.value = ""; void upload(file); }} />
    {current.preview ? <div className="space-y-1">
      <Image unoptimized src={current.preview} width={240} height={180} className="aspect-[4/3] max-w-full rounded-lg border object-cover" alt="ตัวอย่างรูปใหม่ที่เลือกอัปโหลด ยังต้องยืนยันบันทึกเมนู" />
      <p className="text-xs text-muted-foreground">ตัวอย่างรูปใหม่ — ยังไม่เผยแพร่จนกว่าจะยืนยันบันทึกเมนู</p>
    </div> : null}
    {current.stage === "uploading" || current.stage === "processing" ? <progress className="h-3 w-full" max={100} value={current.progress} aria-label="ความคืบหน้าการอัปโหลดรูปเมนู" /> : null}
    {status ? <p role={current.stage === "error" ? "alert" : "status"} className={`text-sm ${current.stage === "error" ? "text-red-600" : "text-muted-foreground"}`}>{status}</p> : null}
    <div className="flex flex-wrap gap-2">
      {busy ? <button type="button" className={buttonClass} onClick={cancel}>ยกเลิกอัปโหลด</button> : null}
      {current.stage === "error" ? <button type="button" className={buttonClass} disabled={disabled} onClick={() => { void upload(candidate.current); }}>ลองอัปโหลดอีกครั้ง</button> : null}
    </div>
  </div>;
}
