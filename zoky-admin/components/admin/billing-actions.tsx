"use client";

import { useState, useTransition, type ChangeEvent } from "react";
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
import { adminBillingError, reviewBillingInvoice, saveBillingSettings, waiveBillingInvoice } from "@/lib/admin-billing-actions";
import type { AdminBillingSettings } from "@/lib/admin-billing";

const fieldClass = "h-11 w-full rounded-md border bg-background px-3 text-sm disabled:opacity-60";

/** Blank is "not set"; anything else must be a number. */
function optionalNumber(value: string): number | null | undefined {
  const trimmed = value.trim();
  if (!trimmed) return null;
  const n = Number(trimmed);
  return Number.isFinite(n) ? n : undefined;
}

/** ZOKY-BILLING-001: fee, trial, ZOKY's payment account, receipt issuer and the master switch. */
export function BillingSettingsForm({ settings, canEdit }: { settings: AdminBillingSettings; canEdit: boolean }) {
  const router = useRouter();
  const [form, setForm] = useState({
    monthlyFee: settings.monthly_fee == null ? "" : String(settings.monthly_fee),
    trialDays: settings.trial_days == null ? "" : String(settings.trial_days),
    promptpayName: settings.zoky_promptpay_name ?? "",
    promptpayId: settings.zoky_promptpay_id ?? "",
    bankName: settings.zoky_bank_name ?? "",
    bankAccountName: settings.zoky_bank_account_name ?? "",
    bankAccountNumber: settings.zoky_bank_account_number ?? "",
    issuerName: settings.receipt_issuer_name ?? "",
    issuerAddress: settings.receipt_issuer_address ?? "",
    issuerTaxId: settings.receipt_issuer_tax_id ?? "",
    enabled: settings.billing_enabled,
  });
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [pending, startTransition] = useTransition();
  const set = (key: keyof typeof form) => (e: ChangeEvent<HTMLInputElement>) =>
    setForm({ ...form, [key]: key === "enabled" ? e.target.checked : e.target.value });

  function submit() {
    setError(null);
    setSaved(false);
    const monthlyFee = optionalNumber(form.monthlyFee);
    const trialDays = optionalNumber(form.trialDays);
    if (monthlyFee === undefined || trialDays === undefined || (trialDays !== null && !Number.isInteger(trialDays))) {
      setError("ค่าบริการและวันทดลองใช้ต้องเป็นตัวเลข");
      return;
    }
    const turningOn = form.enabled && !settings.billing_enabled;
    if (turningOn && !window.confirm(
      settings.launched_on
        ? "เปิดระบบค่าบริการอีกครั้ง? ร้านที่ยังไม่มีรอบบิลจะเริ่มนับวันทดลองใช้ตั้งแต่วันนี้"
        : "เปิดระบบค่าบริการ? ร้านที่เปิดขายอยู่ทุกร้านจะเริ่มนับวันทดลองใช้ตั้งแต่วันนี้ และวันเปิดระบบจะเปลี่ยนไม่ได้",
    )) return;
    startTransition(async () => {
      try {
        await saveBillingSettings({ ...form, monthlyFee, trialDays });
        setSaved(true);
        router.refresh();
      } catch (err) {
        setError(adminBillingError(err, "บันทึกไม่สำเร็จ"));
      }
    });
  }

  const disabled = !canEdit || pending;
  return (
    <div className="grid gap-4 rounded-xl border p-4 text-sm">
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="grid gap-1"><span>ค่าบริการรายเดือน (บาท)</span><input className={fieldClass} inputMode="decimal" disabled={disabled} value={form.monthlyFee} onChange={set("monthlyFee")} /></label>
        <label className="grid gap-1"><span>ทดลองใช้ฟรี (วัน)</span><input className={fieldClass} inputMode="numeric" disabled={disabled} value={form.trialDays} onChange={set("trialDays")} /></label>
      </div>
      <p className="text-xs text-muted-foreground">ราคาใหม่ใช้กับใบแจ้งหนี้ที่ออกหลังบันทึก ใบที่ออกไปแล้วไม่เปลี่ยน · วันทดลองใช้ใหม่ใช้กับร้านที่เริ่มขายหลังบันทึก</p>
      <fieldset className="grid gap-3 sm:grid-cols-2">
        <legend className="mb-1 font-medium">บัญชีรับเงินของ ZOKY (ร้านเห็นในใบแจ้งหนี้)</legend>
        <label className="grid gap-1"><span>ชื่อบัญชี PromptPay</span><input className={fieldClass} maxLength={160} disabled={disabled} value={form.promptpayName} onChange={set("promptpayName")} /></label>
        <label className="grid gap-1"><span>เลข PromptPay</span><input className={fieldClass} inputMode="numeric" disabled={disabled} value={form.promptpayId} onChange={set("promptpayId")} /></label>
        <label className="grid gap-1"><span>ธนาคาร</span><input className={fieldClass} maxLength={120} disabled={disabled} value={form.bankName} onChange={set("bankName")} /></label>
        <label className="grid gap-1"><span>ชื่อบัญชีธนาคาร</span><input className={fieldClass} maxLength={160} disabled={disabled} value={form.bankAccountName} onChange={set("bankAccountName")} /></label>
        <label className="grid gap-1 sm:col-span-2"><span>เลขบัญชีธนาคาร</span><input className={fieldClass} inputMode="numeric" disabled={disabled} value={form.bankAccountNumber} onChange={set("bankAccountNumber")} /></label>
      </fieldset>
      <fieldset className="grid gap-3 sm:grid-cols-2">
        <legend className="mb-1 font-medium">ผู้ออกใบเสร็จ (ใบเสร็จรับเงินธรรมดา ไม่ใช่ใบกำกับภาษี)</legend>
        <label className="grid gap-1"><span>ชื่อผู้ออกใบเสร็จ</span><input className={fieldClass} maxLength={200} disabled={disabled} value={form.issuerName} onChange={set("issuerName")} /></label>
        <label className="grid gap-1"><span>เลขผู้เสียภาษี (ถ้ามี)</span><input className={fieldClass} inputMode="numeric" disabled={disabled} value={form.issuerTaxId} onChange={set("issuerTaxId")} /></label>
        <label className="grid gap-1 sm:col-span-2"><span>ที่อยู่ (ถ้ามี)</span><input className={fieldClass} maxLength={500} disabled={disabled} value={form.issuerAddress} onChange={set("issuerAddress")} /></label>
      </fieldset>
      <label className="flex min-h-11 items-center gap-2"><input type="checkbox" disabled={disabled} checked={form.enabled} onChange={set("enabled")} />เปิดระบบค่าบริการ (ออกใบแจ้งหนี้และแจ้งเตือนร้านทุกวัน 08:05 น.)</label>
      {error ? <p role="alert" className="text-destructive">{error}</p> : null}
      {saved ? <p role="status" className="text-muted-foreground">บันทึกแล้ว</p> : null}
      {canEdit ? (
        <div><Button onClick={submit} disabled={pending}>{pending ? "กำลังบันทึก…" : "บันทึกการตั้งค่า"}</Button></div>
      ) : (
        <p className="text-muted-foreground">ดูได้อย่างเดียว ต้องมีสิทธิ์แก้ไข Merchant จึงจะเปลี่ยนการตั้งค่าได้</p>
      )}
    </div>
  );
}

/** Confirm a store's slip (issues the receipt) or reject it with a reason. */
export function BillingSlipReview({ invoiceId, storeName, amount }: { invoiceId: string; storeName: string; amount: string }) {
  const router = useRouter();
  const [rejecting, setRejecting] = useState(false);
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function act(approve: boolean) {
    if (approve && !window.confirm(`ยืนยันว่าได้รับค่าบริการ ${amount} จากร้าน ${storeName} แล้ว? ระบบจะออกใบเสร็จให้ร้าน`)) return;
    setError(null);
    startTransition(async () => {
      try {
        await reviewBillingInvoice({ invoiceId, approve, note });
        setRejecting(false);
        router.refresh();
      } catch (err) {
        setError(adminBillingError(err, "ทำรายการไม่สำเร็จ"));
      }
    });
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <div className="flex gap-2">
        <Button variant="outline" size="sm" className="min-h-9" disabled={pending} onClick={() => setRejecting(true)}>สลิปไม่ผ่าน</Button>
        <Button size="sm" className="min-h-9" disabled={pending} onClick={() => act(true)}>ยืนยันรับเงิน</Button>
      </div>
      {error ? <p role="alert" className="text-xs text-destructive">{error}</p> : null}
      <Dialog open={rejecting} onOpenChange={setRejecting}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{`สลิปของ ${storeName} ไม่ผ่าน`}</DialogTitle>
            <DialogDescription>ร้านจะเห็นเหตุผลนี้และแนบสลิปใหม่ได้</DialogDescription>
          </DialogHeader>
          <Textarea value={note} maxLength={300} onChange={(e) => setNote(e.target.value)} placeholder="เช่น ยอดในสลิปไม่ตรงกับใบแจ้งหนี้" />
          {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
          <DialogFooter>
            <Button variant="outline" onClick={() => setRejecting(false)} disabled={pending}>ยกเลิก</Button>
            <Button variant="destructive" onClick={() => act(false)} disabled={pending || !note.trim()}>ยืนยันสลิปไม่ผ่าน</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

/** Waive one invoice (a reason is required and audited). */
export function BillingWaive({ invoiceId, storeName, amount }: { invoiceId: string; storeName: string; amount: string }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();

  function act() {
    setError(null);
    startTransition(async () => {
      try {
        await waiveBillingInvoice({ invoiceId, reason });
        setOpen(false);
        router.refresh();
      } catch (err) {
        setError(adminBillingError(err, "ทำรายการไม่สำเร็จ"));
      }
    });
  }

  return (
    <>
      <Button variant="outline" size="sm" className="min-h-9" onClick={() => setOpen(true)}>ยกเว้น</Button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>{`ยกเว้นค่าบริการ ${amount} ของ ${storeName}`}</DialogTitle>
            <DialogDescription>ใบแจ้งหนี้นี้จะปิดโดยไม่ต้องชำระ ร้านจะได้รับแจ้งพร้อมเหตุผล</DialogDescription>
          </DialogHeader>
          <Textarea value={reason} maxLength={300} onChange={(e) => setReason(e.target.value)} placeholder="เหตุผล (จำเป็น)" />
          {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
          <DialogFooter>
            <Button variant="outline" onClick={() => setOpen(false)} disabled={pending}>ยกเลิก</Button>
            <Button onClick={act} disabled={pending || !reason.trim()}>ยืนยันยกเว้น</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
