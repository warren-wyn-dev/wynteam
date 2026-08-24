"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { sendAnnouncement } from "@/lib/admin-announcements-actions";
import type { AnnouncementAudience, AnnouncementCategory } from "@/lib/admin-announcements";

const CATEGORY_OPTIONS: { value: AnnouncementCategory; label: string }[] = [
  { value: "system_update", label: "อัปเดตระบบ" },
  { value: "policy_update", label: "อัปเดตนโยบาย" },
  { value: "maintenance", label: "แจ้งปิดปรับปรุงระบบ" },
  { value: "important", label: "ประกาศสำคัญ" },
];

const AUDIENCE_OPTIONS: { value: AnnouncementAudience; label: string; confirmLabel: string }[] = [
  { value: "all", label: "ทุกคน", confirmLabel: "ส่งถึงทุกคน" },
  { value: "users", label: "ผู้ใช้ทั่วไปเท่านั้น", confirmLabel: "ส่งถึงผู้ใช้ทั่วไปทุกคน" },
  { value: "staff", label: "ทีมงานเท่านั้น (Admin/Moderator)", confirmLabel: "ส่งถึงทีมงานทุกคน" },
];

export function ComposeForm() {
  const router = useRouter();
  const [category, setCategory] = useState<AnnouncementCategory | "">("");
  const [audience, setAudience] = useState<AnnouncementAudience | "">("");
  const [message, setMessage] = useState("");
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successCount, setSuccessCount] = useState<number | null>(null);
  const [isPending, startTransition] = useTransition();

  const canSubmit = category !== "" && audience !== "" && message.trim().length > 0 && !isPending;
  const selectedAudience = AUDIENCE_OPTIONS.find((opt) => opt.value === audience);

  function handleSend() {
    if (category === "" || audience === "") return;
    setError(null);
    startTransition(async () => {
      try {
        const count = await sendAnnouncement({
          category,
          audience,
          message: message.trim(),
        });
        setConfirmOpen(false);
        setSuccessCount(count);
        setCategory("");
        setAudience("");
        setMessage("");
        router.refresh();
      } catch {
        setError("ส่งประกาศไม่สำเร็จ ลองใหม่อีกครั้ง");
      }
    });
  }

  return (
    <div className="flex max-w-lg flex-col gap-3 rounded-lg border p-4">
      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium">ประเภท</label>
        <Select value={category} onValueChange={(v) => setCategory(v as AnnouncementCategory)}>
          <SelectTrigger aria-label="ประเภทประกาศ">
            <SelectValue placeholder="เลือกประเภท" />
          </SelectTrigger>
          <SelectContent>
            {CATEGORY_OPTIONS.map((opt) => (
              <SelectItem key={opt.value} value={opt.value}>
                {opt.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium">กลุ่มผู้รับ</label>
        <Select value={audience} onValueChange={(v) => setAudience(v as AnnouncementAudience)}>
          <SelectTrigger aria-label="กลุ่มผู้รับ">
            <SelectValue placeholder="เลือกกลุ่มผู้รับ" />
          </SelectTrigger>
          <SelectContent>
            {AUDIENCE_OPTIONS.map((opt) => (
              <SelectItem key={opt.value} value={opt.value}>
                {opt.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium">ข้อความ</label>
        <Textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="เนื้อหาประกาศ"
          aria-label="เนื้อหาประกาศ"
        />
      </div>

      {successCount !== null ? (
        <p className="text-sm font-medium">ส่งประกาศสำเร็จ ถึงผู้รับ {successCount} คน</p>
      ) : null}
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}

      <Button
        type="button"
        disabled={!canSubmit}
        onClick={() => {
          setSuccessCount(null);
          setConfirmOpen(true);
        }}
      >
        ส่งประกาศ
      </Button>

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>ยืนยันการส่งประกาศ</DialogTitle>
            <DialogDescription>
              {selectedAudience ? selectedAudience.confirmLabel : ""} — การส่งนี้ย้อนกลับไม่ได้
            </DialogDescription>
          </DialogHeader>
          <p className="whitespace-pre-wrap rounded-md border bg-muted/40 p-3 text-sm">
            {message}
          </p>
          <DialogFooter>
            <Button
              type="button"
              disabled={isPending}
              aria-busy={isPending}
              onClick={handleSend}
            >
              {isPending ? "กำลังส่ง..." : "ยืนยันส่ง"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
