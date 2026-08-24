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

const DURATION_OPTIONS = [
  { value: "1", label: "1 วัน" },
  { value: "3", label: "3 วัน" },
  { value: "7", label: "7 วัน" },
];

/**
 * Shared dialog shape for Warn/Restrict/Suspend/Unban -- Design spec's
 * Screen 2 "โครงเดียวกัน ต่างแค่ title/wording" (Ban is deliberately its
 * own component, ban-dialog.tsx, for the typed-confirmation flow).
 */
export function ActionDialog({
  triggerLabel,
  triggerVariant = "outline",
  triggerDisabled,
  title,
  description,
  requireDuration = false,
  confirmLabel,
  onConfirm,
}: {
  triggerLabel: string;
  triggerVariant?: "outline" | "default" | "destructive";
  triggerDisabled?: boolean;
  title: string;
  description?: string;
  requireDuration?: boolean;
  confirmLabel: string;
  onConfirm: (reason: string, durationDays?: 1 | 3 | 7) => Promise<void>;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [duration, setDuration] = useState<string>("");
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const canConfirm =
    reason.trim().length > 0 && (!requireDuration || duration !== "") && !isPending;

  function reset() {
    setReason("");
    setDuration("");
    setError(null);
  }

  function handleConfirm() {
    setError(null);
    startTransition(async () => {
      try {
        await onConfirm(
          reason.trim(),
          requireDuration ? (Number(duration) as 1 | 3 | 7) : undefined,
        );
        setOpen(false);
        reset();
        router.refresh();
      } catch {
        setError("ดำเนินการไม่สำเร็จ ลองใหม่อีกครั้ง");
      }
    });
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(next) => {
        setOpen(next);
        if (!next) reset();
      }}
    >
      <Button
        type="button"
        variant={triggerVariant}
        disabled={triggerDisabled}
        onClick={() => setOpen(true)}
      >
        {triggerLabel}
      </Button>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          {description ? <DialogDescription>{description}</DialogDescription> : null}
        </DialogHeader>
        <div className="flex flex-col gap-3">
          <Textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="เหตุผล"
            disabled={isPending}
            aria-label="เหตุผล"
          />
          {requireDuration ? (
            <Select value={duration} onValueChange={setDuration} disabled={isPending}>
              <SelectTrigger aria-label="ระยะเวลา">
                <SelectValue placeholder="เลือกระยะเวลา" />
              </SelectTrigger>
              <SelectContent>
                {DURATION_OPTIONS.map((opt) => (
                  <SelectItem key={opt.value} value={opt.value}>
                    {opt.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          ) : null}
          {error ? (
            <p role="alert" className="text-sm text-destructive">
              {error}
            </p>
          ) : null}
        </div>
        <DialogFooter>
          <Button
            type="button"
            variant={triggerVariant === "outline" ? "default" : triggerVariant}
            disabled={!canConfirm}
            aria-busy={isPending}
            onClick={handleConfirm}
          >
            {isPending ? "กำลังดำเนินการ..." : confirmLabel}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
