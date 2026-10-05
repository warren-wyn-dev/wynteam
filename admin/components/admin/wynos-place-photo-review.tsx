"use client";

import { ImageIcon, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";

import { reviewWynosPlacePhoto } from "@/lib/admin-food-actions";
import type { AdminWynosPlacePhoto } from "@/lib/admin-food";

export function WynosPlacePhotoReview({ photos }: { photos: AdminWynosPlacePhoto[] }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [message, setMessage] = useState("");

  const review = (photo: AdminWynosPlacePhoto, approve: boolean) => startTransition(async () => {
    try {
      await reviewWynosPlacePhoto(photo.id, photo.storage_path, approve);
      setMessage(approve ? "อนุมัติรูปแล้ว รูปจะขึ้นบน WYNOS Maps" : "ปฏิเสธและลบรูปแล้ว");
      router.refresh();
    } catch (error) {
      const text = error instanceof Error ? error.message : "";
      setMessage(text.includes("Only admins") ? "เฉพาะ Admin ที่ตรวจรูปได้" : "ตรวจรูปไม่สำเร็จ ลองใหม่อีกครั้ง");
    }
  });

  return (
    <section className="flex flex-col gap-3 rounded-xl border p-4">
      <div className="flex items-center gap-2">
        <ImageIcon className="size-4" />
        <div>
          <h3 className="font-semibold">รูปสถานที่รอตรวจ</h3>
          <p className="text-xs text-muted-foreground">รูปจากผู้ใช้ WYNOS Maps จะไม่ขึ้นให้คนอื่นเห็นจนกว่า Admin อนุมัติ · ปฏิเสธแล้วไฟล์จะถูกลบ</p>
        </div>
      </div>
      {message ? (
        <div className="flex items-center justify-between rounded-lg border bg-muted/40 px-3 py-2 text-sm" role="status">
          <span>{message}</span>
          <button type="button" aria-label="ปิดข้อความ" onClick={() => setMessage("")}><X className="size-4" /></button>
        </div>
      ) : null}
      {photos.length === 0 ? (
        <div className="rounded-lg border border-dashed p-5 text-center text-sm text-muted-foreground">ไม่มีรูปที่รอตรวจ</div>
      ) : (
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          {photos.map((photo) => (
            <article key={photo.id} className="flex flex-col gap-2 rounded-lg border p-2">
              {photo.url ? (
                // Signed Storage URL for a private bucket; next/image would proxy and cache it.
                // eslint-disable-next-line @next/next/no-img-element
                <img src={photo.url} alt={`รูปที่ส่งมาสำหรับ ${photo.place_name}`} className="aspect-square w-full rounded-md object-cover" />
              ) : (
                <div className="grid aspect-square w-full place-items-center rounded-md bg-muted text-xs text-muted-foreground">โหลดรูปไม่ได้</div>
              )}
              <div className="min-w-0">
                <div className="truncate text-sm font-medium">{photo.place_name}</div>
                <div className="text-xs text-muted-foreground">{new Date(photo.created_at).toLocaleString("th-TH")}</div>
              </div>
              <div className="flex gap-2">
                <button type="button" disabled={pending} className="h-9 flex-1 rounded-md border px-3 text-xs" onClick={() => review(photo, false)}>ปฏิเสธ</button>
                <button type="button" disabled={pending} className="h-9 flex-1 rounded-md bg-primary px-3 text-xs font-medium text-primary-foreground" onClick={() => review(photo, true)}>อนุมัติ</button>
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
