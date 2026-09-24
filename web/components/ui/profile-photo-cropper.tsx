"use client";

import { useEffect, useRef, useState, type PointerEvent as ReactPointerEvent, type WheelEvent as ReactWheelEvent } from "react";

type Vec = { x: number; y: number };
type Source = { url: string; width: number; height: number };
type Gesture = { kind: "drag" | "pinch"; x: number; y: number; distance: number; zoom: number; offset: Vec };

export type ProfilePhotoCropperProps = {
  file: File;
  onCancel: () => void;
  onConfirm: (cropped: File) => void | Promise<void>;
};

const OUTPUT_SIZE = 512;
const MAX_ZOOM = 4;
const MIN_ZOOM = 1;

/** Local-only crop: do not upload the original image or retain a full-resolution data URL. */
export function ProfilePhotoCropper({ file, onCancel, onConfirm }: ProfilePhotoCropperProps) {
  const [source, setSource] = useState<Source | null>(null);
  const [loadError, setLoadError] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [zoom, setZoom] = useState(1);
  const [offset, setOffset] = useState<Vec>({ x: 0, y: 0 });
  const viewportRef = useRef<HTMLDivElement>(null);
  const imageRef = useRef<HTMLImageElement>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);
  const pointers = useRef(new Map<number, Vec>());
  const gesture = useRef<Gesture | null>(null);

  useEffect(() => {
    let active = true;
    const url = URL.createObjectURL(file);
    const image = new window.Image();
    image.onload = () => {
      if (!active) return;
      if (!image.naturalWidth || !image.naturalHeight || image.naturalWidth * image.naturalHeight > 50_000_000) {
        setLoadError("รูปภาพนี้มีขนาดใหญ่เกินไปหรือไม่รองรับ กรุณาเลือกรูปอื่น");
        return;
      }
      setSource({ url, width: image.naturalWidth, height: image.naturalHeight });
    };
    image.onerror = () => {
      if (active) setLoadError("เปิดรูปภาพไม่ได้ กรุณาเลือกรูป JPG หรือ PNG");
    };
    image.src = url;
    cancelRef.current?.focus();
    const originalOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      active = false;
      image.onload = null;
      image.onerror = null;
      URL.revokeObjectURL(url);
      document.body.style.overflow = originalOverflow;
    };
  }, [file]);

  const baseWidth = source ? Math.max(1, source.width / source.height) : 1;
  const baseHeight = source ? Math.max(1, source.height / source.width) : 1;

  const clampOffset = (next: Vec, nextZoom: number): Vec => ({
    x: Math.max(-(baseWidth * nextZoom - 1) / 2, Math.min((baseWidth * nextZoom - 1) / 2, next.x)),
    y: Math.max(-(baseHeight * nextZoom - 1) / 2, Math.min((baseHeight * nextZoom - 1) / 2, next.y)),
  });

  const setScale = (next: number) => {
    const value = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, next));
    setZoom(value);
    setOffset((current) => clampOffset(current, value));
  };

  const startGesture = (points: Vec[]) => {
    if (points.length === 1) {
      gesture.current = { kind: "drag", x: points[0].x, y: points[0].y, distance: 0, zoom, offset };
    } else if (points.length >= 2) {
      const x = (points[0].x + points[1].x) / 2;
      const y = (points[0].y + points[1].y) / 2;
      gesture.current = { kind: "pinch", x, y, distance: Math.hypot(points[0].x - points[1].x, points[0].y - points[1].y) || 1, zoom, offset };
    } else gesture.current = null;
  };

  const onPointerDown = (event: ReactPointerEvent<HTMLDivElement>) => {
    if (!source || busy) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    startGesture([...pointers.current.values()]);
  };

  const onPointerMove = (event: ReactPointerEvent<HTMLDivElement>) => {
    if (!pointers.current.has(event.pointerId) || !gesture.current || !source || busy) return;
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    const points = [...pointers.current.values()];
    const gestureStart = gesture.current;
    const side = viewportRef.current?.getBoundingClientRect().width || 1;
    if (points.length === 1 && gestureStart.kind === "drag") {
      setOffset(clampOffset({ x: gestureStart.offset.x + (points[0].x - gestureStart.x) / side, y: gestureStart.offset.y + (points[0].y - gestureStart.y) / side }, zoom));
    } else if (points.length >= 2 && gestureStart.kind === "pinch") {
      const distance = Math.hypot(points[0].x - points[1].x, points[0].y - points[1].y);
      const nextZoom = Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, gestureStart.zoom * distance / gestureStart.distance));
      const midpoint = { x: (points[0].x + points[1].x) / 2, y: (points[0].y + points[1].y) / 2 };
      setZoom(nextZoom);
      setOffset(clampOffset({
        x: gestureStart.offset.x + (midpoint.x - gestureStart.x) / side,
        y: gestureStart.offset.y + (midpoint.y - gestureStart.y) / side,
      }, nextZoom));
    }
  };

  const onPointerUp = (event: ReactPointerEvent<HTMLDivElement>) => {
    pointers.current.delete(event.pointerId);
    startGesture([...pointers.current.values()]);
  };

  const onWheel = (event: ReactWheelEvent<HTMLDivElement>) => {
    if (!source || busy) return;
    event.preventDefault();
    setScale(zoom + (event.deltaY < 0 ? 0.12 : -0.12));
  };

  const confirm = async () => {
    if (!source || !imageRef.current || busy) return;
    setBusy(true);
    setError("");
    try {
      const canvas = document.createElement("canvas");
      canvas.width = OUTPUT_SIZE;
      canvas.height = OUTPUT_SIZE;
      const context = canvas.getContext("2d");
      if (!context) throw new Error("ไม่สามารถตัดรูปภาพบนอุปกรณ์นี้ได้");
      context.imageSmoothingEnabled = true;
      context.imageSmoothingQuality = "high";
      context.fillStyle = "#fff";
      context.fillRect(0, 0, OUTPUT_SIZE, OUTPUT_SIZE);
      const drawWidth = baseWidth * zoom * OUTPUT_SIZE;
      const drawHeight = baseHeight * zoom * OUTPUT_SIZE;
      context.drawImage(
        imageRef.current,
        (OUTPUT_SIZE - drawWidth) / 2 + offset.x * OUTPUT_SIZE,
        (OUTPUT_SIZE - drawHeight) / 2 + offset.y * OUTPUT_SIZE,
        drawWidth,
        drawHeight,
      );
      const blob = await new Promise<Blob>((resolve, reject) => {
        canvas.toBlob((result) => result ? resolve(result) : reject(new Error("ไม่สามารถบันทึกรูปที่ปรับแล้วได้")), "image/jpeg", 0.9);
      });
      await onConfirm(new File([blob], "profile-avatar.jpg", { type: "image/jpeg" }));
    } catch (cause) {
      setError(cause instanceof Error && /ไม่สามารถ/.test(cause.message) ? cause.message : "บันทึกรูปไม่สำเร็จ กรุณาลองอีกครั้ง");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="wyn-photo-crop-backdrop" role="presentation" onPointerDown={(event) => { if (event.target === event.currentTarget && !busy) onCancel(); }}>
      <section className="wyn-photo-crop-dialog" role="dialog" aria-modal="true" aria-labelledby="wyn-photo-crop-heading" onKeyDown={(event) => { if (event.key === "Escape" && !busy) onCancel(); }}>
        <h2 id="wyn-photo-crop-heading">ปรับรูปโปรไฟล์</h2>
        <p className="wyn-photo-crop-hint">ใช้สองนิ้วซูม หรือเลื่อนรูปให้พอดีกับวงกลม</p>
        <div
          ref={viewportRef}
          className="wyn-photo-crop-viewport"
          role="img"
          aria-label="ลากรูปเพื่อจัดตำแหน่ง และใช้สองนิ้วซูม"
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
          onWheel={onWheel}
          onDoubleClick={() => setScale(zoom > 1 ? 1 : 2)}
        >
          {source ? <img ref={imageRef} src={source.url} alt="" draggable={false} className="wyn-photo-crop-image" style={{
            width: String(baseWidth * zoom * 100) + "%",
            height: String(baseHeight * zoom * 100) + "%",
            left: String(50 + offset.x * 100) + "%",
            top: String(50 + offset.y * 100) + "%",
          }} /> : <span className="wyn-photo-crop-loading">{loadError || "กำลังเปิดรูปภาพ…"}</span>}
        </div>
        <div className="wyn-photo-crop-zoom">
          <label htmlFor="wyn-photo-crop-slider">ซูมรูปโปรไฟล์</label>
          <div className="wyn-photo-crop-slider-row">
            <span aria-hidden="true">−</span>
            <input id="wyn-photo-crop-slider" type="range" min="1" max="4" step="0.05" value={zoom} disabled={!source || busy} onChange={(event) => setScale(Number(event.target.value))} />
            <span aria-hidden="true">+</span>
            <button type="button" className="wyn-photo-crop-reset" disabled={!source || busy} onClick={() => { setZoom(1); setOffset({ x: 0, y: 0 }); }}>รีเซ็ต</button>
          </div>
        </div>
        {error || loadError ? <p className="wyn-photo-crop-error" role="alert">{error || loadError}</p> : null}
        <div className="wyn-photo-crop-actions">
          <button ref={cancelRef} className="wyn-photo-crop-cancel" type="button" onClick={onCancel} disabled={busy}>ยกเลิก</button>
          <button className="wyn-photo-crop-confirm" type="button" onClick={() => void confirm()} disabled={!source || busy}>{busy ? "กำลังบันทึก…" : "ใช้รูปนี้"}</button>
        </div>
      </section>
    </div>
  );
}
