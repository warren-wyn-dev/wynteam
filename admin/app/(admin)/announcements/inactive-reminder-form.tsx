"use client";

import { useRef, useState, useTransition } from "react";
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
import { countInactiveUsers, sendInactiveReminder } from "@/lib/admin-inactive-reminders-actions";
import {
  INACTIVE_DAY_OPTIONS,
  INACTIVE_REMINDER_MAX_LENGTH,
  type InactiveDays,
} from "@/lib/admin-inactive-reminder-options";

/**
 * Reminds people who signed up but have not used WYNOS for 24 hours,
 * 3 days or 7 days: an in-app notification plus Push. The server skips
 * staff, banned accounts, people who turned off system notifications and
 * anyone already reminded in the last 24 hours.
 */
export function InactiveReminderForm() {
  const router = useRouter();
  const [days, setDays] = useState<InactiveDays | null>(null);
  const [message, setMessage] = useState("");
  const [count, setCount] = useState<number | null>(null);
  const [countError, setCountError] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [successCount, setSuccessCount] = useState<number | null>(null);
  const [isPending, startTransition] = useTransition();

  // Only the latest choice's count is shown, even if answers arrive out of order.
  const countRequest = useRef(0);

  function choose(next: InactiveDays) {
    const request = ++countRequest.current;
    setSuccessCount(null);
    setDays(next);
    setCount(null);
    setCountError(false);
    countInactiveUsers(next)
      .then((value) => {
        if (countRequest.current === request) setCount(value);
      })
      .catch(() => {
        if (countRequest.current === request) setCountError(true);
      });
  }

  const trimmed = message.trim();
  const tooLong = trimmed.length > INACTIVE_REMINDER_MAX_LENGTH;
  const canSubmit = days !== null && trimmed.length > 0 && !tooLong && (count ?? 0) > 0 && !isPending;
  const selected = INACTIVE_DAY_OPTIONS.find((opt) => opt.value === days);

  function handleSend() {
    if (days === null) return;
    setError(null);
    startTransition(async () => {
      try {
        const sent = await sendInactiveReminder({ days, message: trimmed });
        setConfirmOpen(false);
        setSuccessCount(sent);
        countRequest.current += 1;
        setDays(null);
        setCount(null);
        setMessage("");
        router.refresh();
      } catch {
        setError("ส่งการเตือนไม่สำเร็จ ลองใหม่อีกครั้ง");
      }
    });
  }

  return (
    <div className="flex max-w-lg flex-col gap-3 rounded-lg border p-4">
      <div className="flex flex-col gap-1">
        <h3 className="text-sm font-medium">เตือนผู้ใช้ที่ไม่ได้เข้ามาใช้งาน</h3>
        <p className="text-xs text-muted-foreground">
          ส่งเป็นแจ้งเตือนในแอปและ Push ไม่ส่งถึงทีมงาน บัญชีที่ถูกระงับ คนที่ปิดแจ้งเตือนระบบ
          และคนที่เพิ่งได้รับการเตือนภายใน 24 ชั่วโมง
        </p>
      </div>

      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium">กลุ่มผู้รับ</label>
        <Select
          value={days === null ? "" : String(days)}
          onValueChange={(value) => choose(Number(value) as InactiveDays)}
        >
          <SelectTrigger aria-label="กลุ่มผู้ใช้ที่ไม่ได้ใช้งาน">
            <SelectValue placeholder="เลือกระยะเวลาที่ไม่ได้ใช้งาน" />
          </SelectTrigger>
          <SelectContent>
            {INACTIVE_DAY_OPTIONS.map((opt) => (
              <SelectItem key={opt.value} value={String(opt.value)}>
                {opt.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        {days !== null ? (
          <p className="text-sm text-muted-foreground" aria-live="polite">
            {countError
              ? "นับจำนวนผู้รับไม่สำเร็จ"
              : count === null
                ? "กำลังนับจำนวนผู้รับ..."
                : `จะส่งถึง ${count} คน`}
          </p>
        ) : null}
      </div>

      <div className="flex flex-col gap-1.5">
        <label className="text-sm font-medium">ข้อความ</label>
        <Textarea
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="เช่น มีโพสต์ใหม่จากเพื่อนรอคุณอยู่ กลับมาดูกันที่ WYNOS"
          aria-label="ข้อความเตือน"
          aria-invalid={tooLong}
        />
        <p className={`text-xs ${tooLong ? "text-destructive" : "text-muted-foreground"}`}>
          {trimmed.length}/{INACTIVE_REMINDER_MAX_LENGTH}
        </p>
      </div>

      {successCount !== null ? (
        <p className="text-sm font-medium">ส่งการเตือนสำเร็จ ถึงผู้รับ {successCount} คน</p>
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
        ส่งการเตือน
      </Button>

      <Dialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>ยืนยันการส่งการเตือน</DialogTitle>
            <DialogDescription>
              {selected ? `${selected.label} · ประมาณ ${count ?? 0} คน` : ""} — การส่งนี้ย้อนกลับไม่ได้
            </DialogDescription>
          </DialogHeader>
          <p className="whitespace-pre-wrap rounded-md border bg-muted/40 p-3 text-sm">{trimmed}</p>
          <DialogFooter>
            <Button type="button" disabled={isPending} aria-busy={isPending} onClick={handleSend}>
              {isPending ? "กำลังส่ง..." : "ยืนยันส่ง"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
