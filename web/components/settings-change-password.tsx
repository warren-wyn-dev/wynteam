"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import type { SupabaseClient } from "@supabase/supabase-js";

import { AccountPasswordError, changeAccountPassword, validatePasswordChange } from "@/lib/account-password";
import { MIN_SIGNUP_PASSWORD_LENGTH } from "@/lib/signup-password-policy";

/** Mounted only while Settings > Account > Change password is open. */
export function SettingsChangePassword({
  client,
  userId,
  onBack,
}: {
  client: SupabaseClient;
  userId: string;
  onBack: () => void;
}) {
  const router = useRouter();
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [saved, setSaved] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy || saved) return;
    setError("");

    const validation = validatePasswordChange(current, next, confirmation);
    if (validation) {
      setError(validation);
      return;
    }

    setBusy(true);
    try {
      await changeAccountPassword(client, userId, current, next);
      setCurrent("");
      setNext("");
      setConfirmation("");
      setSaved(true);
    } catch (failure) {
      if (failure instanceof AccountPasswordError) {
        if (failure.code === "WRONG_PASSWORD") {
          setError("รหัสผ่านปัจจุบันไม่ถูกต้อง หากยังไม่มีรหัสผ่านหรือจำไม่ได้ ให้ใช้ลืมรหัสผ่าน");
          setCurrent("");
        } else if (failure.code === "ACCOUNT_CHANGED") {
          setError("บัญชีที่เข้าสู่ระบบมีการเปลี่ยนแปลง กรุณาเปิดหน้านี้ใหม่");
          setCurrent("");
          setNext("");
          setConfirmation("");
        } else if (failure.code === "NO_EMAIL" || failure.code === "REAUTHENTICATION_REQUIRED") {
          setError("บัญชีนี้ต้องยืนยันตัวตนผ่านอีเมลก่อน กรุณาใช้ระบบลืมรหัสผ่าน");
        } else {
          setError("ไม่สามารถเปลี่ยนรหัสผ่านได้ กรุณาลองใหม่อีกครั้ง");
        }
      } else {
        setError("เชื่อมต่อระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="settings-page">
      {saved ? (
        <div className="settings-password-panel" role="status">
          <h2>เปลี่ยนรหัสผ่านสำเร็จ</h2>
          <p>คุณสามารถใช้รหัสผ่านใหม่ในการเข้าสู่ระบบครั้งถัดไปได้</p>
          <button className="settings-password-submit" type="button" onClick={onBack}>กลับไปหน้าบัญชี</button>
        </div>
      ) : (
        <>
          <h2>ความปลอดภัยของบัญชี</h2>
          <form className="settings-password-panel" onSubmit={(event) => void submit(event)} noValidate>
            <p className="settings-password-hint">กรอกรหัสผ่านปัจจุบันเพื่อยืนยันตัวตน ก่อนตั้งรหัสผ่านใหม่</p>
            <label htmlFor="settings-current-password">รหัสผ่านปัจจุบัน</label>
            <input id="settings-current-password" name="currentPassword" type="password"
              autoComplete="current-password" value={current} disabled={busy}
              onChange={(event) => setCurrent(event.target.value)} />
            <label htmlFor="settings-new-password">รหัสผ่านใหม่</label>
            <input id="settings-new-password" name="newPassword" type="password"
              autoComplete="new-password" minLength={MIN_SIGNUP_PASSWORD_LENGTH}
              value={next} disabled={busy} onChange={(event) => setNext(event.target.value)} />
            <p className="settings-password-hint">อย่างน้อย {MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร และต้องไม่ซ้ำกับรหัสผ่านเดิม</p>
            <label htmlFor="settings-confirm-password">ยืนยันรหัสผ่านใหม่</label>
            <input id="settings-confirm-password" name="confirmPassword" type="password"
              autoComplete="new-password" value={confirmation} disabled={busy}
              onChange={(event) => setConfirmation(event.target.value)} />
            {error ? <p className="settings-password-error" role="alert">{error}</p> : null}
            <button className="settings-password-submit" type="submit" disabled={busy}>
              {busy ? "กำลังตรวจสอบ…" : "บันทึกรหัสผ่านใหม่"}
            </button>
            <button className="settings-password-forgot" type="button" disabled={busy}
              onClick={() => router.push("/forgot-password")}>ลืมรหัสผ่านปัจจุบัน?</button>
          </form>
        </>
      )}
    </div>
  );
}
