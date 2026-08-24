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
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { applyUserAction } from "@/lib/admin-user-actions";

/**
 * Ban's own dialog (not ActionDialog) -- Design spec: typed-confirmation
 * flow mirroring the Flutter app's delete_account_screen.dart exactly
 * (WYN-047), since Ban is the single most severe action here.
 */
export function BanDialog({ userId, username }: { userId: string; username: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [confirmText, setConfirmText] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  const canConfirm = reason.trim().length > 0 && confirmText === username && !isPending;

  function reset() {
    setReason("");
    setConfirmText("");
    setError(null);
  }

  function handleConfirm() {
    setError(null);
    startTransition(async () => {
      try {
        await applyUserAction({
          targetUserId: userId,
          actionType: "ban",
          reason: reason.trim(),
        });
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
      <Button type="button" variant="destructive" onClick={() => setOpen(true)}>
        Ban
      </Button>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Ban ผู้ใช้</DialogTitle>
          <DialogDescription>
            การ Ban เป็นการบล็อกถาวร ผู้ใช้จะโพสต์/ทำกิจกรรมใดๆ ไม่ได้อีก จนกว่าจะมีคน Unban
          </DialogDescription>
        </DialogHeader>
        <div className="flex flex-col gap-3">
          <Textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="เหตุผล"
            disabled={isPending}
            aria-label="เหตุผล"
          />
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="ban-confirm">
              พิมพ์ <span className="font-mono font-semibold">{username}</span> เพื่อยืนยัน
            </Label>
            <Input
              id="ban-confirm"
              value={confirmText}
              onChange={(e) => setConfirmText(e.target.value)}
              disabled={isPending}
              aria-describedby="ban-confirm-help"
            />
            <p id="ban-confirm-help" className="text-xs text-muted-foreground">
              ต้องพิมพ์ username ให้ตรงเป๊ะ
            </p>
          </div>
          {error ? (
            <p role="alert" className="text-sm text-destructive">
              {error}
            </p>
          ) : null}
        </div>
        <DialogFooter>
          <Button
            type="button"
            variant="destructive"
            disabled={!canConfirm}
            aria-busy={isPending}
            onClick={handleConfirm}
          >
            {isPending ? "กำลังดำเนินการ..." : "ยืนยัน Ban"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
