"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, useSyncExternalStore, type ChangeEvent, type ReactNode } from "react";

import { Avatar, Button, Input, WynosIcon } from "@/components/ui";
import { useSignupDraft, type SignupDraft } from "@/components/auth-flow/signup-draft-context";
import { PENDING_REFERRAL_KEY } from "@/components/parity-invite-code";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";
import {
  EmailAlreadyRegisteredError,
  UsernameReservedError,
  UsernameTakenError,
  completeOnboarding,
  hasProfileRow,
  isInviteGateEnabled,
  isUsernameFormatValid,
  redeemReferralCode,
  resetPasswordForEmail,
  saveOptionalProfile,
  setDateOfBirth,
  setDisplayName,
  setUsername,
  signInWithEmail,
  signUpWithEmail,
} from "@/lib/auth-repository";

const MIN_ONBOARDING_AGE = 13;

/// Where a session lands right after Google OAuth returns to /welcome, or
/// right after a successful email/password login. Only ever sends a
/// genuinely brand-new account (no `profiles` row at all yet) into the
/// signup flow — see hasProfileRow's doc comment for why
/// `profile_private.onboarding_completed` is not safe to gate this on.
async function resolvePostAuthPath(client: NonNullable<ReturnType<typeof getSupabaseBrowserClient>>): Promise<string> {
  const { data } = await client.auth.getUser();
  const user = data.user;
  if (!user) return "/welcome";
  try {
    const hasProfile = await hasProfileRow(client, user.id);
    return hasProfile ? "/" : "/signup/step-1";
  } catch {
    return "/";
  }
}

function parseBirthDate(raw: string): string | null {
  const digits = raw.replace(/[^0-9]/g, "");
  if (digits.length !== 8) return null;
  const day = Number(digits.slice(0, 2));
  const month = Number(digits.slice(2, 4));
  const year = Number(digits.slice(4, 8));
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  const now = new Date();
  let age = now.getUTCFullYear() - year;
  const hadBirthdayThisYear = now.getUTCMonth() > month - 1 || (now.getUTCMonth() === month - 1 && now.getUTCDate() >= day);
  if (!hadBirthdayThisYear) age -= 1;
  if (age < MIN_ONBOARDING_AGE || date > now) return null;
  return date.toISOString().split("T")[0];
}

/// Auto-inserts the "วว / ดด / ปปปป" separators as the user types digits,
/// so a birth date can be filled with just the numeric keypad instead of
/// typing slashes/spaces by hand. Deleting characters still works normally
/// since this only ever re-derives the display string from the digits
/// already present.
function formatBirthDateInput(raw: string): string {
  const digits = raw.replace(/[^0-9]/g, "").slice(0, 8);
  if (digits.length <= 2) return digits;
  if (digits.length <= 4) return `${digits.slice(0, 2)} / ${digits.slice(2)}`;
  return `${digits.slice(0, 2)} / ${digits.slice(2, 4)} / ${digits.slice(4)}`;
}

/// A `useSyncExternalStore` snapshot never changes on its own (there is
/// nothing to subscribe to), so this reads false during SSR/hydration and
/// true on every client render after — the React-sanctioned way to detect
/// "hydration finished" without calling setState from inside an effect.
function subscribeNever() {
  return () => {};
}

function AuthPhone({ children }: { children: ReactNode }) {
  return (
    <main className="auth-ref-viewport">
      <div className="phone" id="phone">
        {children}
      </div>
    </main>
  );
}

function ErrorText({ children }: { children?: string }) {
  if (!children) return null;
  return <p style={{ color: "var(--red)", fontSize: 12, margin: "8px 0 0" }} role="alert">{children}</p>;
}

function BackTopbar({ href, step, onBack }: { href: string; step?: string; onBack?: () => void }) {
  const router = useRouter();
  return (
    <div className="topbar">
      <button className="ic-btn" onClick={onBack ?? (() => router.push(href))} aria-label="ย้อนกลับ">
        <WynosIcon name="back" size={16} />
      </button>
      {step ? <span style={{ fontSize: 12, color: "var(--text-muted)" }}>{step}</span> : <span />}
    </div>
  );
}

function Field({
  label,
  name,
  placeholder,
  type,
  value,
  onChange,
  disabled,
}: {
  label: string;
  name: string;
  placeholder: string;
  type?: string;
  value?: string;
  onChange?: (event: ChangeEvent<HTMLInputElement>) => void;
  disabled?: boolean;
}) {
  return (
    <div className="field">
      <label>{label}</label>
      <Input bare name={name} placeholder={placeholder} type={type} value={value} onChange={onChange} disabled={disabled} />
    </div>
  );
}

export function WelcomeScreen() {
  const router = useRouter();
  const [booting, setBooting] = useState(true);
  const [gate, setGate] = useState<"checking" | "blocked" | "open">("checking");
  const [inviteCode, setInviteCode] = useState("");
  const [inviteError, setInviteError] = useState("");
  const [inviteLoading, setInviteLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [error, setError] = useState("");
  const supabase = getSupabaseBrowserClient();

  useEffect(() => {
    let mounted = true;
    void (async () => {
      if (!supabase) {
        if (mounted) {
          setBooting(false);
          setGate("open");
        }
        return;
      }
      const { data } = await supabase.auth.getSession();
      if (!mounted) return;
      if (data.session) {
        const path = await resolvePostAuthPath(supabase);
        if (mounted) router.replace(path);
        return;
      }
      setBooting(false);
      try {
        const enabled = await isInviteGateEnabled(supabase);
        if (!mounted) return;
        setGate(enabled ? "blocked" : "open");
      } catch {
        if (mounted) setGate("open");
      }
    })();
    return () => {
      mounted = false;
    };
  }, [supabase, router]);

  async function submitInviteCode() {
    const value = inviteCode.trim();
    if (!value) {
      setInviteError("กรุณากรอกโค้ดเชิญ");
      return;
    }
    if (!supabase) {
      setInviteError("เชื่อมต่อไม่สำเร็จ ลองใหม่อีกครั้ง");
      return;
    }
    setInviteLoading(true);
    setInviteError("");
    try {
      const result = await supabase.rpc("validate_referral_code", { p_code: value });
      if (result.error) throw result.error;
      if (result.data !== true) {
        setInviteError("โค้ดเชิญไม่ถูกต้อง");
        return;
      }
      window.sessionStorage.setItem(PENDING_REFERRAL_KEY, value);
      setGate("open");
    } catch {
      setInviteError("เชื่อมต่อไม่สำเร็จ ลองใหม่อีกครั้ง");
    } finally {
      setInviteLoading(false);
    }
  }

  async function google() {
    if (googleLoading || !supabase) {
      if (!supabase) setError("ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS สำหรับเว็บ");
      return;
    }
    setGoogleLoading(true);
    setError("");
    const result = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: `${window.location.origin}/welcome`, queryParams: { prompt: "select_account" } },
    });
    if (result.error) {
      setError("เข้าสู่ระบบไม่สำเร็จ ลองใหม่อีกครั้ง");
      setGoogleLoading(false);
    }
  }

  if (booting) return <AuthPhone><div style={{ flex: 1 }} /></AuthPhone>;

  return (
    <AuthPhone>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", justifyContent: "space-between", padding: "40px 24px 32px" }}>
        <div />
        <div style={{ textAlign: "center" }}>
          <svg height="48" style={{ margin: "0 auto 18px" }} viewBox="0 0 26 26" width="48" aria-label="Wynos">
            <path d="M2 4 L8 22 L13 9 L18 22 L24 4" fill="none" stroke="#0A0A0A" strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" />
          </svg>
          <p style={{ fontSize: 17, fontWeight: 600, margin: "0 0 6px" }}>ทุกเรื่องราว มีจุดเริ่มต้น</p>
          <p style={{ fontSize: 14, color: "var(--text-secondary)", margin: 0 }}>Welcome to WYNOS.</p>
        </div>
        <div>
          {gate === "blocked" ? (
            <>
              <p style={{ fontSize: 13, color: "var(--text-secondary)", textAlign: "center", margin: "0 0 12px" }}>
                ตอนนี้ WYNOS เปิดให้เข้าใช้งานเฉพาะผู้ที่มีโค้ดเชิญจากเพื่อนเท่านั้น
              </p>
              <div className="field">
                <label>โค้ดเชิญ</label>
                <Input
                  bare
                  autoCapitalize="characters"
                  value={inviteCode}
                  onChange={(event) => { setInviteCode(event.target.value.toUpperCase()); setInviteError(""); }}
                />
              </div>
              <Button className="btn-primary" disabled={inviteLoading} onClick={() => void submitInviteCode()} style={{ marginBottom: 10 }}>
                {inviteLoading ? "กำลังตรวจสอบ…" : "ดำเนินการต่อ"}
              </Button>
              <ErrorText>{inviteError}</ErrorText>
              <Button className="btn-outline" variant="outline" onClick={() => router.push("/login")} style={{ marginTop: 10 }}>เข้าสู่ระบบ</Button>
            </>
          ) : (
            <>
              <Button className="btn-primary" disabled={gate === "checking"} onClick={() => router.push("/signup/step-1")} style={{ marginBottom: 10 }}>สร้างบัญชีใหม่</Button>
              <Button className="btn-outline" variant="outline" disabled={googleLoading} onClick={() => void google()} style={{ marginBottom: 10 }}>
                {googleLoading ? "กำลังเชื่อมต่อ Google…" : "เข้าสู่ระบบด้วย Google"}
              </Button>
              <Button className="btn-outline" variant="outline" onClick={() => router.push("/login")} style={{ marginBottom: 16 }}>เข้าสู่ระบบ</Button>
              <ErrorText>{error}</ErrorText>
              <p style={{ fontSize: 11, color: "var(--text-muted)", textAlign: "center", lineHeight: 1.5, margin: 0 }}>
                การสร้างบัญชีถือว่ายอมรับ<br />
                <b style={{ color: "var(--text-primary)" }}>ข้อกำหนดการใช้งาน</b> และ <b style={{ color: "var(--text-primary)" }}>นโยบายความเป็นส่วนตัว</b>
              </p>
            </>
          )}
        </div>
      </div>
    </AuthPhone>
  );
}

export function SignupStep1Screen() {
  const router = useRouter();
  const { draft, setDraft } = useSignupDraft();
  const fieldsRef = useRef<HTMLDivElement>(null);
  const supabase = getSupabaseBrowserClient();
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  // These fields are SSR'd with an empty controlled value (the signup draft
  // is client-only state). If a keystroke lands in the gap between the
  // static HTML becoming interactive and React finishing hydration, React
  // has no record of it and silently resets the field back to that empty
  // value once hydration catches up — losing whatever was typed with no
  // visible error. Keeping the fields disabled until mount closes that gap:
  // disabled inputs don't accept keystrokes at all, and Playwright's own
  // actionability check already waits for a field to become enabled before
  // it will interact with it, so this needs no test-side change either.
  const mounted = useSyncExternalStore(subscribeNever, () => true, () => false);
  const update = (key: keyof SignupDraft) => (event: ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value;
    setDraft((current) => ({ ...current, [key]: value }));
  };
  const updateBirthDate = (event: ChangeEvent<HTMLInputElement>) => {
    setDraft((current) => ({ ...current, birthDate: formatBirthDateInput(event.target.value) }));
  };

  async function goNext() {
    if (loading) return;
    const read = (name: string) => fieldsRef.current?.querySelector<HTMLInputElement>(`input[name="${name}"]`)?.value ?? "";
    const username = (read("username") || draft.username).trim().toLowerCase();
    const displayName = (read("displayName") || draft.displayName).trim();
    const birthDateRaw = read("birthDate") || draft.birthDate;
    setDraft((current) => ({ ...current, username, displayName, birthDate: birthDateRaw }));

    setError("");
    if (!isUsernameFormatValid(username)) {
      setError("ชื่อผู้ใช้ต้องมี 3-20 ตัว เป็นตัวพิมพ์เล็ก a-z, 0-9 หรือ _ เท่านั้น");
      return;
    }
    if (!displayName) {
      setError("กรุณากรอกชื่อที่แสดง");
      return;
    }
    const isoBirthDate = parseBirthDate(birthDateRaw);
    if (!isoBirthDate) {
      setError(`กรุณากรอกวันเกิดให้ถูกต้อง (อายุอย่างน้อย ${MIN_ONBOARDING_AGE} ปี)`);
      return;
    }

    if (!supabase) {
      router.push("/signup/step-2");
      return;
    }

    setLoading(true);
    try {
      const { data } = await supabase.auth.getSession();
      if (!data.session) {
        // No session yet (fresh email sign-up path) — collect email/password next.
        router.push("/signup/step-2");
        return;
      }
      // Already signed in (arrived via Google) — commit directly and skip the password step.
      const userId = data.session.user.id;
      await setUsername(supabase, userId, username);
      await setDisplayName(supabase, userId, displayName);
      await setDateOfBirth(supabase, userId, isoBirthDate);
      const pendingCode = window.sessionStorage.getItem(PENDING_REFERRAL_KEY);
      if (pendingCode) {
        try {
          await redeemReferralCode(supabase, pendingCode);
        } catch {
          // Best-effort — see AuthRepository.redeemReferralCode.
        } finally {
          window.sessionStorage.removeItem(PENDING_REFERRAL_KEY);
        }
      }
      router.push("/onboarding/profile");
    } catch (err) {
      if (err instanceof UsernameTakenError || err instanceof UsernameReservedError) {
        setError("ชื่อผู้ใช้นี้ถูกใช้แล้ว ลองชื่ออื่น");
      } else {
        setError("เกิดข้อผิดพลาด ลองใหม่อีกครั้ง");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthPhone>
      <BackTopbar href="/welcome" step="1/2" />
      <div ref={fieldsRef} style={{ padding: "16px 20px", flex: 1 }}>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 6 }}>สร้างบัญชี</div>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "0 0 20px" }}>มาทำความรู้จักคุณกันก่อน</p>
        <div className="field">
          <label>ชื่อผู้ใช้</label>
          <div style={{ display: "flex", alignItems: "center", height: 44, border: "1px solid var(--border-strong)", borderRadius: 10, padding: "0 14px" }}>
            <span style={{ color: "var(--text-muted)" }}>@</span>
            <Input bare autoCapitalize="none" autoComplete="username" autoCorrect="off" name="username" placeholder="username" value={draft.username} onChange={update("username")} disabled={!mounted} style={{ border: "none", outline: "none", flex: 1, fontSize: 14 }} />
          </div>
        </div>
        <Field label="ชื่อที่แสดง" name="displayName" placeholder="ชื่อของคุณ" value={draft.displayName} onChange={update("displayName")} disabled={!mounted} />
        <div className="field">
          <label>วันเกิด</label>
          <Input bare inputMode="numeric" name="birthDate" placeholder="วว / ดด / ปปปป" value={draft.birthDate} onChange={updateBirthDate} disabled={!mounted} />
        </div>
        <Button className="btn-primary" disabled={loading} onClick={() => void goNext()} style={{ marginTop: 10 }}>{loading ? "กำลังดำเนินการ…" : "หน้าถัดไป"}</Button>
        <ErrorText>{error}</ErrorText>
      </div>
    </AuthPhone>
  );
}

export function SignupStep2Screen() {
  const router = useRouter();
  const { draft, setDraft } = useSignupDraft();
  const supabase = getSupabaseBrowserClient();
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const update = (key: keyof SignupDraft) => (event: ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value;
    setDraft((current) => ({ ...current, [key]: value }));
  };

  async function createAccount() {
    if (loading) return;
    setError("");
    const email = draft.email.trim();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      setError("กรุณากรอกอีเมลให้ถูกต้อง");
      return;
    }
    if (draft.password.length < 6) {
      setError("รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร");
      return;
    }
    if (draft.password !== draft.confirmPassword) {
      setError("รหัสผ่านไม่ตรงกัน");
      return;
    }
    const isoBirthDate = parseBirthDate(draft.birthDate);
    if (!isoBirthDate) {
      router.push("/signup/step-1");
      return;
    }
    if (!supabase) {
      setError("ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS สำหรับเว็บ");
      return;
    }

    setLoading(true);
    try {
      const result = await signUpWithEmail(supabase, email, draft.password);
      const userId = result.user?.id;
      if (!userId) {
        setError(`ส่งอีเมลยืนยันไปที่ ${email} แล้ว กรุณากดลิงก์ในอีเมลก่อนเข้าสู่ระบบ`);
        return;
      }
      await setUsername(supabase, userId, draft.username);
      await setDisplayName(supabase, userId, draft.displayName);
      await setDateOfBirth(supabase, userId, isoBirthDate);
      const pendingCode = window.sessionStorage.getItem(PENDING_REFERRAL_KEY);
      if (pendingCode) {
        try {
          await redeemReferralCode(supabase, pendingCode);
        } catch {
          // Best-effort — see AuthRepository.redeemReferralCode.
        } finally {
          window.sessionStorage.removeItem(PENDING_REFERRAL_KEY);
        }
      }
      router.push("/onboarding/profile");
    } catch (err) {
      if (err instanceof EmailAlreadyRegisteredError) {
        setError("อีเมลนี้มีบัญชีอยู่แล้ว ลองเข้าสู่ระบบแทน");
      } else if (err instanceof UsernameTakenError || err instanceof UsernameReservedError) {
        setError("ชื่อผู้ใช้นี้ถูกใช้แล้ว กรุณาย้อนกลับไปเปลี่ยนชื่อผู้ใช้");
      } else {
        setError("สมัครสมาชิกไม่สำเร็จ ลองใหม่อีกครั้ง");
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthPhone>
      <BackTopbar href="/signup/step-1" step="2/2" />
      <div style={{ padding: "16px 20px", flex: 1 }}>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 6 }}>ตั้งรหัสผ่าน</div>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "0 0 20px" }}>ใช้สำหรับเข้าสู่ระบบครั้งต่อไป</p>
        <Field label="อีเมล" name="email" placeholder="you@example.com" value={draft.email} onChange={update("email")} />
        <Field label="รหัสผ่าน" name="password" placeholder="อย่างน้อย 6 ตัวอักษร" type="password" value={draft.password} onChange={update("password")} />
        <Field label="ยืนยันรหัสผ่าน" name="confirmPassword" placeholder="พิมพ์รหัสผ่านอีกครั้ง" type="password" value={draft.confirmPassword} onChange={update("confirmPassword")} />
        <Button className="btn-primary" disabled={loading} onClick={() => void createAccount()} style={{ marginTop: 10 }}>{loading ? "กำลังสร้างบัญชี…" : "สร้างบัญชี"}</Button>
        <ErrorText>{error}</ErrorText>
        <p style={{ fontSize: 12, color: "var(--text-secondary)", textAlign: "center", marginTop: 16 }}>
          มีบัญชีอยู่แล้ว? <b onClick={() => router.push("/login")} style={{ color: "var(--text-primary)", cursor: "pointer" }}>เข้าสู่ระบบ</b>
        </p>
      </div>
    </AuthPhone>
  );
}

export function OnboardingProfileScreen() {
  const router = useRouter();
  const supabase = getSupabaseBrowserClient();
  const [bio, setBio] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function finish() {
    if (loading) return;
    setLoading(true);
    setError("");
    try {
      if (supabase) {
        const { data } = await supabase.auth.getUser();
        if (data.user) {
          if (bio.trim()) await saveOptionalProfile(supabase, data.user.id, { bio: bio.trim() });
          await completeOnboarding(supabase, data.user.id);
        }
      }
      router.push("/");
    } catch {
      setError("เกิดข้อผิดพลาด ลองใหม่อีกครั้ง");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthPhone>
      <div style={{ display: "flex", justifyContent: "flex-end", padding: "16px 20px 0" }}>
        <span onClick={() => void finish()} style={{ fontSize: 13, color: "var(--text-secondary)", cursor: "pointer" }}>ข้าม</span>
      </div>
      <div style={{ padding: "0 20px", flex: 1 }}>
        <div style={{ textAlign: "center", marginBottom: 24 }}>
          <div style={{ fontSize: 20, fontWeight: 700 }}>เพิ่มรูปโปรไฟล์</div>
          <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "6px 0 0" }}>ให้คนอื่นรู้จักคุณมากขึ้น</p>
        </div>
        <div style={{ display: "flex", justifyContent: "center", marginBottom: 24 }}>
          <div style={{ position: "relative" }}>
            <Avatar as="div" alt="รูปโปรไฟล์" className="avatar" size={96} />
            <div style={{ position: "absolute", bottom: -4, right: -4, width: 32, height: 32, borderRadius: "50%", background: "var(--text-primary)", border: "3px solid var(--bg)", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <WynosIcon name="camera" size={15} color="var(--bg)" />
            </div>
          </div>
        </div>
        <div className="field">
          <label>แนะนำตัวสั้นๆ (ไม่บังคับ)</label>
          <textarea placeholder="ชอบเที่ยว ชอบถ่ายรูป..." value={bio} onChange={(event) => setBio(event.target.value)} />
        </div>
        <ErrorText>{error}</ErrorText>
      </div>
      <div style={{ padding: "16px 20px" }}>
        <Button className="btn-primary" disabled={loading} onClick={() => void finish()}>{loading ? "กำลังบันทึก…" : "เริ่มใช้งาน Wynos"}</Button>
      </div>
    </AuthPhone>
  );
}

export function LoginScreen() {
  const router = useRouter();
  const supabase = getSupabaseBrowserClient();
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function submit() {
    if (loading) return;
    setError("");
    const email = identifier.trim();
    if (!email || !password) {
      setError("กรุณากรอกอีเมลและรหัสผ่าน");
      return;
    }
    if (!supabase) {
      setError("ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS สำหรับเว็บ");
      return;
    }
    setLoading(true);
    try {
      await signInWithEmail(supabase, email, password);
      const path = await resolvePostAuthPath(supabase);
      router.push(path);
    } catch (err) {
      const code = (err as { code?: string })?.code;
      setError(code === "email_not_confirmed" ? "บัญชีนี้ยังไม่ได้ยืนยันอีเมล กรุณากดลิงก์ยืนยันในอีเมลก่อนเข้าสู่ระบบ" : "อีเมลหรือรหัสผ่านไม่ถูกต้อง");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthPhone>
      <BackTopbar href="/welcome" />
      <div style={{ padding: "16px 20px", flex: 1 }}>
        <div style={{ textAlign: "center", marginBottom: 28 }}>
          <svg height="36" style={{ margin: "0 auto 14px" }} viewBox="0 0 26 26" width="36" aria-label="Wynos">
            <path d="M2 4 L8 22 L13 9 L18 22 L24 4" fill="none" stroke="#0A0A0A" strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" />
          </svg>
          <div style={{ fontSize: 20, fontWeight: 700 }}>เข้าสู่ระบบ</div>
        </div>
        <Field label="อีเมล" name="loginIdentifier" placeholder="you@example.com" value={identifier} onChange={(event) => setIdentifier(event.target.value)} />
        <Field label="รหัสผ่าน" name="loginPassword" placeholder="รหัสผ่านของคุณ" type="password" value={password} onChange={(event) => setPassword(event.target.value)} />
        <div style={{ textAlign: "right", marginBottom: 8 }}>
          <span onClick={() => router.push("/forgot-password")} style={{ fontSize: 13, fontWeight: 500, cursor: "pointer" }}>ลืมรหัสผ่าน?</span>
        </div>
        <Button className="btn-primary" disabled={loading} onClick={() => void submit()}>{loading ? "กำลังเข้าสู่ระบบ…" : "เข้าสู่ระบบ"}</Button>
        <ErrorText>{error}</ErrorText>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", textAlign: "center", marginTop: 16 }}>
          ยังไม่มีบัญชี? <b onClick={() => router.push("/signup/step-1")} style={{ color: "var(--text-primary)", cursor: "pointer" }}>สร้างบัญชีใหม่</b>
        </p>
      </div>
    </AuthPhone>
  );
}

export function ForgotPasswordScreen() {
  const supabase = getSupabaseBrowserClient();
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [sent, setSent] = useState(false);

  async function submit() {
    if (loading) return;
    setError("");
    const value = email.trim();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value)) {
      setError("กรุณากรอกอีเมลให้ถูกต้อง");
      return;
    }
    if (!supabase) {
      setError("ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS สำหรับเว็บ");
      return;
    }
    setLoading(true);
    try {
      await resetPasswordForEmail(supabase, value);
      setSent(true);
    } catch {
      setError("ส่งลิงก์ไม่สำเร็จ ลองใหม่อีกครั้ง");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthPhone>
      <BackTopbar href="/login" />
      <div style={{ padding: "16px 20px", flex: 1 }}>
        <div style={{ fontSize: 20, fontWeight: 700, marginBottom: 6 }}>ลืมรหัสผ่าน?</div>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "0 0 20px", lineHeight: 1.5 }}>กรอกอีเมลที่ใช้สมัคร เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ให้</p>
        {sent ? (
          <p style={{ fontSize: 13, color: "var(--text-primary)" }}>ส่งลิงก์ไปที่ {email.trim()} แล้ว ตรวจสอบกล่องอีเมลของคุณ</p>
        ) : (
          <>
            <Field label="อีเมล" name="resetEmail" placeholder="you@example.com" value={email} onChange={(event) => setEmail(event.target.value)} />
            <Button className="btn-primary" disabled={loading} onClick={() => void submit()} style={{ marginTop: 10 }}>{loading ? "กำลังส่ง…" : "ส่งลิงก์รีเซ็ตรหัสผ่าน"}</Button>
            <ErrorText>{error}</ErrorText>
          </>
        )}
      </div>
    </AuthPhone>
  );
}
