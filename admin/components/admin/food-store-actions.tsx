"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Ban, RotateCcw } from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/textarea";
import { adminFoodError, setFoodStoreMemberActive, setFoodStoreSuspension } from "@/lib/admin-food-actions";

/** WYN-203: suspend / lift a store (admin only; the RPC re-checks). */
export function FoodStoreSuspensionActions({
  storeId,
  storeName,
  suspended,
}: {
  storeId: string;
  storeName: string;
  suspended: boolean;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function submit(suspend: boolean) {
    setError(null);
    startTransition(async () => {
      try {
        await setFoodStoreSuspension({ storeId, suspend, reason });
        setOpen(false);
        setReason("");
        router.refresh();
      } catch (err) {
        setError(adminFoodError(err, suspend ? "ระงับร้านไม่สำเร็จ" : "ยกเลิกการระงับไม่สำเร็จ"));
      }
    });
  }

  if (suspended) {
    return (
      <div className="flex flex-col gap-2">
        <Button variant="outline" disabled={pending} onClick={() => submit(false)} className="min-h-11 gap-2">
          <RotateCcw className="size-4" />
          {pending ? "กำลังบันทึก…" : "ยกเลิกการระงับ"}
        </Button>
        <p className="text-xs text-muted-foreground">ร้านยังปิดอยู่จนกว่าเจ้าของจะเปิดและเผยแพร่เองใน Wynos Merchant</p>
        {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
      </div>
    );
  }

  return (
    <>
      <Button variant="destructive" onClick={() => setOpen(true)} className="min-h-11 gap-2">
        <Ban className="size-4" />
        ระงับร้าน
      </Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>ระงับร้าน {storeName}</DialogTitle>
            <DialogDescription>
              ร้านจะถูกซ่อนจากลูกค้าและรับออเดอร์ใหม่ไม่ได้ทันที ออเดอร์ที่มีอยู่ร้านยังจัดการต่อได้ เจ้าของร้านจะได้รับแจ้งพร้อมเหตุผล
            </DialogDescription>
          </DialogHeader>
          <Textarea
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            maxLength={500}
            placeholder="เหตุผลการระงับ (จำเป็น) เช่น ได้รับร้องเรียนเรื่องไม่ส่งอาหารซ้ำหลายครั้ง"
            aria-label="เหตุผลการระงับ"
          />
          {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)} disabled={pending}>ยกเลิก</Button>
            <Button variant="destructive" onClick={() => submit(true)} disabled={pending || !reason.trim()}>
              {pending ? "กำลังระงับ…" : "ยืนยันระงับร้าน"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}

/** WYN-203: deactivate / reactivate one team member (admin only). */
export function FoodTeamMemberToggle({
  storeId,
  userId,
  active,
  label,
}: {
  storeId: string;
  userId: string;
  active: boolean;
  label: string;
}) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function toggle() {
    if (active && !window.confirm(`ปิดสิทธิ์ ${label} ในร้านนี้?`)) return;
    setError(null);
    startTransition(async () => {
      try {
        await setFoodStoreMemberActive({ storeId, userId, active: !active });
        router.refresh();
      } catch (err) {
        setError(adminFoodError(err, "เปลี่ยนสิทธิ์ไม่สำเร็จ"));
      }
    });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <Button size="sm" variant={active ? "outline" : "default"} disabled={pending} onClick={toggle} className="min-h-9">
        {pending ? "กำลังบันทึก…" : active ? "ปิดสิทธิ์" : "เปิดสิทธิ์อีกครั้ง"}
      </Button>
      {error ? <p role="alert" className="text-xs text-destructive">{error}</p> : null}
    </div>
  );
}
