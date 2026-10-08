"use client";

import { useState, useTransition, type FormEvent } from "react";
import { createClient } from "@/lib/supabase/client";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import { signIn } from "./actions";

export function LoginForm() {
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  // Sandbox-only email verification. Never use the existing Production
  // password in the independent QA Supabase project.
  const sandboxOnly = process.env.NEXT_PUBLIC_SUPABASE_URL ===
    "https://pcatuxtenluqzjzzwsvl.supabase.co";
  const [qaEmail, setQaEmail] = useState("");
  const [sendingLink, setSendingLink] = useState(false);
  const [qaNotice, setQaNotice] = useState("");

  async function requestQaEmailLink(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!sandboxOnly || sendingLink) return;
    setError(null);
    setQaNotice("");
    const email = qaEmail.trim();
    if (!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$/.test(email)) {
      setError("กรุณากรอกอีเมลให้ถูกต้อง");
      return;
    }
    setSendingLink(true);
    try {
      const supabase = createClient();
      const { error: signInError } = await supabase.auth.signInWithOtp({
        email,
        options: {
          shouldCreateUser: true,
          emailRedirectTo: window.location.origin + "/auth/callback",
        },
      });
      if (signInError) throw signInError;
      setQaNotice("หากส่งลิงก์สำเร็จ ให้เปิดอีเมลและกดลิงก์ยืนยัน จากนั้นกลับมาหน้านี้อีกครั้ง");
    } catch {
      setError("ส่งลิงก์เข้าสู่ระบบ Sandbox ไม่สำเร็จ กรุณาลองใหม่หรือติดต่อผู้ดูแล");
    } finally {
      setSendingLink(false);
    }
  }

  if (sandboxOnly) {
    return (
      <form onSubmit={requestQaEmailLink} className="flex flex-col gap-4">
        <p className="rounded-lg border p-3 text-sm">
          WYNOS GP Sandbox — ใช้อีเมลยืนยันตัวตนเท่านั้น
          ไม่ต้องกรอกรหัสผ่าน WYNOS Admin จริง
        </p>
        <div className="flex flex-col gap-2">
          <Label htmlFor="qa-email">อีเมล WYNOS Admin ของคุณ</Label>
          <Input id="qa-email" name="email" type="email" autoComplete="email"
            value={qaEmail} onChange={(e) => setQaEmail(e.target.value)}
            required disabled={sendingLink} />
        </div>
        {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
        {qaNotice ? <p role="status" className="text-sm">{qaNotice}</p> : null}
        <Button type="submit" className="w-full" disabled={sendingLink}>
          {sendingLink ? "กำลังส่งลิงก์..." : "ส่งลิงก์ยืนยันอีเมล Sandbox"}
        </Button>
        <p className="text-xs text-muted-foreground">
          หลังยืนยันอีเมล WYNOS GP ยังต้องรอผู้ดูแลกำหนดสิทธิ์ QA แยกต่างหาก
          อัตรา GP ยังไม่ได้กำหนด และไม่มีการหักเงินจริง
        </p>
      </form>
    );
  }

  function handleSubmit(formData: FormData) {
    setError(null);
    startTransition(async () => {
      const result = await signIn(formData);
      if (result.error) {
        setError(result.error);
      }
      // On success, signIn() itself redirects server-side -- nothing
      // else to do here.
    });
  }

  return (
    <form action={handleSubmit} className="flex flex-col gap-4">
      <div className="flex flex-col gap-2">
        <Label htmlFor="email">อีเมล</Label>
        <Input
          id="email"
          name="email"
          type="email"
          autoComplete="email"
          required
          disabled={isPending}
        />
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor="password">รหัสผ่าน</Label>
        <Input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          required
          disabled={isPending}
        />
      </div>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      <Button type="submit" className="w-full" disabled={isPending} aria-busy={isPending}>
        {isPending ? "กำลังเข้าสู่ระบบ..." : "เข้าสู่ระบบ"}
      </Button>
    </form>
  );
}
