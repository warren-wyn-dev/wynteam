"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";

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
import { adminAdError, reviewAdTopup, saveAdSettings, setAdAccountStatus } from "@/lib/admin-food-actions";
import type { AdminAdSettings } from "@/lib/admin-ads";

const fieldClass = "h-11 w-full rounded-md border bg-background px-3 text-sm";

/** WYN-207: price per click, minimum top-up, WYNOS PromptPay and the master switch. */
export function AdSettingsForm({ settings }: { settings: AdminAdSettings }) {
  const router = useRouter();
  const [form, setForm] = useState({
    costPerClick: String(settings.cost_per_click),
    minTopup: String(settings.min_topup),
    promptpayName: settings.wynos_promptpay_name ?? "",
    promptpayId: settings.wynos_promptpay_id ?? "",
    enabled: settings.ads_enabled,
  });
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [pending, startTransition] = useTransition();

  function submit() {
    setError(null);
    setSaved(false);
    startTransition(async () => {
      try {
        await saveAdSettings({
          costPerClick: Number(form.costPerClick),
          minTopup: Number(form.minTopup),
          promptpayName: form.promptpayName,
          promptpayId: form.promptpayId,
          enabled: form.enabled,
        });
        setSaved(true);
        router.refresh();
      } catch (err) {
        setError(adminAdError(err, "บันทึกไม่สำเร็จ"));
      }
    });
  }

  return (
    <div className="grid gap-3 rounded-xl border p-4 text-sm">
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="grid gap-1"><span>ราคาต่อคลิก (บาท)</span><input className={fieldClass} inputMode="decimal" value={form.costPerClick} onChange={(e) => setForm({ ...form, costPerClick: e.target.value })} /></label>
        <label className="grid gap-1"><span>เติมขั้นต่ำ (บาท)</span><input className={fieldClass} inputMode="decimal" value={form.minTopup} onChange={(e) => setForm({ ...form, minTopup: e.target.value })} /></label>
        <label className="grid gap-1"><span>ชื่อบัญชี PromptPay ของ WYNOS</span><input className={fieldClass} value={form.promptpayName} maxLength={120} onChange={(e) => setForm({ ...form, promptpayName: e.target.value })} /></label>
        <label className="grid gap-1"><span>เลข PromptPay ของ WYNOS</span><input className={fieldClass} inputMode="numeric" value={form.promptpayId} onChange={(e) => setForm({ ...form, promptpayId: e.target.value })} /></label>
      </div>
      <label className="flex min-h-11 items-center gap-2"><input type="checkbox" checked={form.enabled} onChange={(e) => setForm({ ...form, enabled: e.target.checked })} />เปิดระบบโฆษณา (ร้านเติมเครดิตได้ และโฆษณาแสดงใน WYNOS Food)</label>
      {error ? <p role="alert" className="text-destructive">{error}</p> : null}
      {saved ? <p className="text-muted-foreground">บันทึกแล้ว</p> : null}
      <div><Button onClick={submit} disabled={pending}>{pending ? "กำลังบันทึก…" : "บันทึกการตั้งค่า"}</Button></div>
    </div>
  );
}

/** WYN-207: approve (adds credit) or reject (needs a reason) a store's top-up. */
export function AdTopupReview({ topupId, storeName, amount }: { topupId: string; storeName: string; amount: string }) {
  const router = useRouter();
  const [rejecting, setRejecting] = useState(false);
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function act(approve: boolean) {
    if (approve && !window.confirm(`ยืนยันว่าได้รับเงิน ${amount} จากร้าน ${storeName} แล้ว?`)) return;
    setError(null);
    startTransition(async () => {
      try {
        await reviewAdTopup({ topupId, approve, note });
        setRejecting(false);
        router.refresh();
      } catch (err) {
        setError(adminAdError(err, "ทำรายการไม่สำเร็จ"));
      }
    });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <div className="flex gap-2">
        <Button variant="outline" size="sm" className="min-h-9" disabled={pending} onClick={() => setRejecting(true)}>ไม่อนุมัติ</Button>
        <Button size="sm" className="min-h-9" disabled={pending} onClick={() => act(true)}>อนุมัติ เติมเครดิต</Button>
      </div>
      {error ? <p role="alert" className="text-xs text-destructive">{error}</p> : null}
      <Dialog open={rejecting} onOpenChange={setRejecting}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{`ไม่อนุมัติการเติมของ ${storeName}`}</DialogTitle>
            <DialogDescription>ร้านจะเห็นเหตุผลนี้ในประวัติการเติม</DialogDescription>
          </DialogHeader>
          <Textarea value={note} maxLength={300} onChange={(e) => setNote(e.target.value)} placeholder="เช่น ยอดในสลิปไม่ตรงกับที่แจ้ง" />
          <DialogFooter>
            <Button variant="outline" onClick={() => setRejecting(false)} disabled={pending}>ยกเลิก</Button>
            <Button variant="destructive" onClick={() => act(false)} disabled={pending || !note.trim()}>ยืนยันไม่อนุมัติ</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

/** WYN-207: stop a store's ads (with a reason) or let it advertise again. */
export function AdAccountToggle({ storeId, storeName, stopped }: { storeId: string; storeName: string; stopped: boolean }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function act(stop: boolean) {
    setError(null);
    startTransition(async () => {
      try {
        await setAdAccountStatus({ storeId, stop, reason });
        setOpen(false);
        router.refresh();
      } catch (err) {
        setError(adminAdError(err, "ทำรายการไม่สำเร็จ"));
      }
    });
  }

  if (stopped) {
    return <Button variant="outline" size="sm" className="min-h-9" disabled={pending} onClick={() => act(false)}>ให้ลงโฆษณาได้อีกครั้ง</Button>;
  }
  return (
    <>
      <Button variant="destructive" size="sm" className="min-h-9" onClick={() => setOpen(true)}>หยุดโฆษณา</Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{`หยุดโฆษณาของ ${storeName}`}</DialogTitle>
            <DialogDescription>โฆษณาหยุดแสดงทันที ร้านเปิดเองไม่ได้จนกว่า Admin จะให้ลงอีกครั้ง เครดิตที่เหลือยังอยู่</DialogDescription>
          </DialogHeader>
          <Textarea value={reason} maxLength={300} onChange={(e) => setReason(e.target.value)} placeholder="เหตุผล (จำเป็น)" />
          {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)} disabled={pending}>ยกเลิก</Button>
            <Button variant="destructive" onClick={() => act(true)} disabled={pending || !reason.trim()}>ยืนยันหยุดโฆษณา</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
