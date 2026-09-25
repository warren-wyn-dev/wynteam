"use client";

import Image from "next/image";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState, useSyncExternalStore, type ChangeEvent, type ReactNode } from "react";

import { Avatar, Button, Input, WynosIcon } from "@/components/ui";
import { ProfilePhotoCropper } from "@/components/ui/profile-photo-cropper";
import { uploadProfileImage } from "@/lib/phase3-data";
import { useSignupDraft, type SignupDraft } from "@/components/auth-flow/signup-draft-context";
import { PENDING_REFERRAL_KEY } from "@/components/parity-invite-code";
import { createPasswordRecoveryClient, getSupabaseBrowserClient } from "@/lib/supabase/browser";
import { GOOGLE_PWA_COMPLETED_CHANNEL, isInstalledIosWebApp, startGoogleOAuth } from "@/lib/google-pwa-oauth";
import { parsePasswordRecoveryLink } from "@/lib/password-recovery-link";
import { MIN_SIGNUP_PASSWORD_LENGTH } from "@/lib/signup-password-policy";
import {
  EmailAlreadyRegisteredError,
  SignupPasswordTooShortError,
  UsernameReservedError,
  UsernameTakenError,
  checkSignupUsernameAvailability,
  completeOnboarding,
  hasProfileRow,
  isInviteGateEnabled,
  isUsernameFormatValid,
  redeemReferralCode,
  reservedUsernames,
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

const THAI_MONTHS = [
  "มกราคม",
  "กุมภาพันธ์",
  "มีนาคม",
  "เมษายน",
  "พฤษภาคม",
  "มิถุนายน",
  "กรกฎาคม",
  "สิงหาคม",
  "กันยายน",
  "ตุลาคม",
  "พฤศจิกายน",
  "ธันวาคม",
];

const BUDDHIST_ERA_OFFSET = 543;
const MIN_BIRTH_YEAR = 1900;

/// `raw` is the "YYYY-MM-DD" string assembled from the 3 วัน/เดือน/ปี select
/// boxes below — always well-formed digit-wise once all 3 are chosen (the
/// select options only ever offer zero-padded numeric values), but this
/// still re-validates defensively (format, real calendar date, age, not in
/// the future) since `raw` can also be a still-incomplete "-MM-" /
/// "YYYY--" string while the user hasn't finished picking all 3 yet, or a
/// re-read of stale draft state (e.g. after navigating back from step 2).
function parseBirthDate(raw: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(raw)) return null;
  const [year, month, day] = raw.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  const now = new Date();
  let age = now.getUTCFullYear() - year;
  const hadBirthdayThisYear = now.getUTCMonth() > month - 1 || (now.getUTCMonth() === month - 1 && now.getUTCDate() >= day);
  if (!hadBirthdayThisYear) age -= 1;
  if (age < MIN_ONBOARDING_AGE || date > now) return null;
  return raw;
}

/// Gregorian birth years eligible under MIN_ONBOARDING_AGE, newest first
/// (most users' birth years are closer to today than to 1900, so this
/// keeps the common case near the top of the dropdown). Each option's
/// visible label is the Buddhist-era year (Founder-approved 2026-09-19,
/// WYN-166 follow-up) — the stored/validated value stays Gregorian, the
/// same as every other date in this codebase.
function eligibleBirthYears(): number[] {
  const maxYear = new Date().getUTCFullYear() - MIN_ONBOARDING_AGE;
  const years: number[] = [];
  for (let year = maxYear; year >= MIN_BIRTH_YEAR; year--) years.push(year);
  return years;
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

/// The official multi-color Google "G" mark, per Google's Sign In branding
/// guideline (https://developers.google.com/identity/branding-guidelines) —
/// used only on the "เข้าสู่ระบบด้วย Google" button, never redrawn or
/// recolored to match the button's own black/white/gray palette.
export function GoogleGlyph() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden="true" style={{ flexShrink: 0, marginRight: 8 }}>
      <path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.92c1.7-1.57 2.68-3.88 2.68-6.62z" />
      <path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.92-2.26c-.8.54-1.83.86-3.04.86-2.34 0-4.32-1.58-5.03-3.7H.96v2.33A9 9 0 0 0 9 18z" />
      <path fill="#FBBC05" d="M3.97 10.72a5.4 5.4 0 0 1 0-3.44V4.95H.96a9 9 0 0 0 0 8.1l3.01-2.33z" />
      <path fill="#EA4335" d="M9 3.58c1.32 0 2.51.46 3.44 1.35l2.59-2.59C13.46.89 11.43 0 9 0A9 9 0 0 0 .96 4.95l3.01 2.33C4.68 5.16 6.66 3.58 9 3.58z" />
    </svg>
  );
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
  const [sessionCheckFailed, setSessionCheckFailed] = useState(false);
  const [checkAttempt, setCheckAttempt] = useState(0);
  const [gate, setGate] = useState<"checking" | "blocked" | "open">("checking");
  const [inviteCode, setInviteCode] = useState("");
  const [inviteError, setInviteError] = useState("");
  const [inviteLoading, setInviteLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [error, setError] = useState("");
  const googlePwaPending = useRef(false);
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
      let result: Awaited<ReturnType<typeof supabase.auth.getSession>>;
      try {
        result = await supabase.auth.getSession();
      } catch {
        if (mounted) { setBooting(false); setSessionCheckFailed(true); }
        return;
      }
      if (!mounted) return;
      if (result.error) {
        setBooting(false);
        setSessionCheckFailed(true);
        return;
      }
      if (result.data.session) {
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
  }, [supabase, router, checkAttempt]);

  useEffect(() => {
    if (!supabase || !isInstalledIosWebApp()) return;
    let mounted = true;
    let checking = false;
    const resume = async () => {
      if (!mounted || !googlePwaPending.current || checking) return;
      checking = true;
      try {
        // The popup's callback only broadcasts after the Supabase session has
        // been verified. Retry briefly to allow iOS to flush shared cookies.
        for (let attempt = 0; attempt < 4; attempt++) {
          const { data, error: authError } = await supabase.auth.getSession();
          if (!mounted) return;
          if (!authError && data.session) {
            googlePwaPending.current = false;
            router.replace(await resolvePostAuthPath(supabase));
            return;
          }
          await new Promise((resolve) => window.setTimeout(resolve, 350));
        }
        if (mounted) {
          setError("Google ยังไม่ได้ส่งข้อมูลเข้าสู่ WYNOS กรุณากลับมาที่แอปแล้วลองใหม่");
          setGoogleLoading(false);
        }
      } catch {
        if (mounted) {
          setError("ตรวจสอบการเข้าสู่ระบบ Google ไม่สำเร็จ กรุณาลองใหม่");
          setGoogleLoading(false);
        }
      } finally {
        checking = false;
      }
    };
    const onMessage = (event: MessageEvent) => {
      if (event.origin === window.location.origin && event.data?.type === "google-oauth-verified") void resume();
    };
    const channel = typeof BroadcastChannel !== "undefined" ? new BroadcastChannel(GOOGLE_PWA_COMPLETED_CHANNEL) : null;
    if (channel) channel.onmessage = (event) => {
      if (event.data?.type === "google-oauth-verified") void resume();
    };
    const onFocus = () => {
      if (document.visibilityState === "visible") void resume();
    };
    window.addEventListener("message", onMessage);
    window.addEventListener("focus", onFocus);
    document.addEventListener("visibilitychange", onFocus);
    return () => {
      mounted = false;
      channel?.close();
      window.removeEventListener("message", onMessage);
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("visibilitychange", onFocus);
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
    try {
      const result = await startGoogleOAuth(supabase, `${window.location.origin}/welcome`);
      if (!result.started) {
        setError(result.error ?? "เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาลองใหม่");
        setGoogleLoading(false);
      } else if (isInstalledIosWebApp()) {
        // Keep the button disabled while the popup owns the PKCE flow:
        // a second tap would overwrite the verifier and break the first
        // callback. Focus/visibility resumes the parent or shows retry.
        googlePwaPending.current = true;
      }
    } catch {
      setError("เปิด Google ไม่สำเร็จ กรุณาลองใหม่");
      setGoogleLoading(false);
    }
  }

  if (booting) return <AuthPhone><div style={{ flex: 1 }} /></AuthPhone>;
  if (sessionCheckFailed) {
    return <AuthPhone><div className="route-state" style={{ flex: 1 }}>
      <h1>WYNOS</h1>
      <p role="alert">ตรวจสอบการเข้าสู่ระบบไม่สำเร็จ กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่</p>
      <Button className="btn-primary" onClick={() => {
        setSessionCheckFailed(false);
        setBooting(true);
        setCheckAttempt((value) => value + 1);
      }}>ลองใหม่</Button>
    </div></AuthPhone>;
  }

  return (
    <AuthPhone>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", justifyContent: "space-between", padding: "40px 24px 32px" }}>
        <div />
        <div style={{ textAlign: "center" }}>
          <Image src="/wynos_logo_mark.png" alt="Wynos" width={170} height={110} style={{ height: 110, width: "auto", margin: "0 auto 18px", display: "block" }} priority />
          <p style={{ fontSize: 28, fontWeight: 800, letterSpacing: "-0.02em", margin: "0 0 6px" }}>ทุกเรื่องราว มีจุดเริ่มต้น</p>
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
              <Button className="btn-outline" variant="outline" onClick={() => router.push("/login")} style={{ marginBottom: 10 }}>เข้าสู่ระบบ</Button>
              <Button
                className="btn-outline"
                variant="outline"
                disabled={googleLoading}
                onClick={() => void google()}
                leadingIcon={googleLoading ? undefined : <GoogleGlyph />}
                style={{ marginBottom: 16 }}
              >
                {googleLoading ? "กำลังเชื่อมต่อ Google…" : "เข้าสู่ระบบด้วย Google"}
              </Button>
              <ErrorText>{error}</ErrorText>
              <p style={{ fontSize: 12, color: "var(--text-muted)", textAlign: "center", lineHeight: 1.5, margin: 0 }}>
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
  const [availability, setAvailability] = useState<{ username: string; state: "checking" | "available" | "taken" | "error" } | null>(null);
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
  // draft.birthDate is always the 3-part "YYYY-MM-DD" join, even while
  // incomplete (e.g. "-05-" after only picking a month) — see
  // parseBirthDate's doc comment. Deriving the 3 select values straight
  // from draft.birthDate on every render (instead of separate local state)
  // means they stay correct after a route remount (e.g. the "ย้อนกลับ" flow
  // from step 2) and after signup-draft-context's own sessionStorage-resume
  // effect runs, the same way the plain username/displayName inputs already do.
  const normalizedUsername = draft.username.trim().toLowerCase();
  const validUsername = isUsernameFormatValid(normalizedUsername);
  const reservedUsername = reservedUsernames.has(normalizedUsername);
  // Never display an old result for a different username while a request is pending.
  const usernameState = !normalizedUsername ? "idle"
    : !validUsername ? "invalid"
    : reservedUsername ? "taken"
    : !supabase ? "idle"
    : availability?.username === normalizedUsername ? availability.state : "checking";

  useEffect(() => {
    if (!mounted || !supabase || !validUsername || reservedUsername) return;
    let active = true;
    const timer = window.setTimeout(() => {
      setAvailability({ username: normalizedUsername, state: "checking" });
      void checkSignupUsernameAvailability(supabase, normalizedUsername)
        .then((available) => {
          if (active) setAvailability({ username: normalizedUsername, state: available ? "available" : "taken" });
        })
        .catch(() => {
          if (active) setAvailability({ username: normalizedUsername, state: "error" });
        });
    }, 400);
    return () => { active = false; window.clearTimeout(timer); };
  }, [mounted, normalizedUsername, reservedUsername, supabase, validUsername]);

  const [birthYear, birthMonth, birthDay] = draft.birthDate.split("-");
  const updateBirthDatePart = (part: "year" | "month" | "day") => (event: ChangeEvent<HTMLSelectElement>) => {
    const [y, m, d] = draft.birthDate.split("-");
    const year = part === "year" ? event.target.value : (y ?? "");
    const month = part === "month" ? event.target.value : (m ?? "");
    const day = part === "day" ? event.target.value : (d ?? "");
    setDraft((current) => ({ ...current, birthDate: `${year}-${month}-${day}` }));
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
    if (reservedUsernames.has(username)) {
      setError("ชื่อผู้ใช้นี้ไม่สามารถใช้ได้ กรุณาเลือกชื่ออื่น");
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
      let available: boolean;
      try {
        available = await checkSignupUsernameAvailability(supabase, username);
      } catch {
        setError("ตรวจสอบชื่อผู้ใช้ไม่ได้ กรุณาลองอีกครั้ง");
        return;
      }
      setAvailability({ username, state: available ? "available" : "taken" });
      if (!available) {
        setError("ชื่อผู้ใช้นี้ถูกใช้แล้ว กรุณาเลือกชื่ออื่น");
        return;
      }
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
        <div style={{ fontSize: 32, fontWeight: 800, letterSpacing: "-0.02em", marginBottom: 6 }}>สร้างบัญชี</div>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "0 0 20px" }}>มาทำความรู้จักคุณกันก่อน</p>
        <div className="field">
          <label>ชื่อผู้ใช้</label>
          <div style={{ display: "flex", alignItems: "center", height: 56, border: "1px solid var(--border-strong)", borderRadius: 18, padding: "0 18px" }}>
            <span style={{ color: "var(--text-muted)" }}>@</span>
            <Input bare autoCapitalize="none" autoComplete="username" autoCorrect="off" name="username" placeholder="username" value={draft.username} onChange={update("username")} disabled={!mounted} aria-describedby="signup-username-status" style={{ border: "none", outline: "none", background: "transparent", height: "100%", padding: 0, borderRadius: 0, flex: 1, fontSize: 16 }} />
          </div>
          <p id="signup-username-status" role="status" aria-live="polite" style={{ fontSize: 12, lineHeight: 1.5, minHeight: 18, margin: "6px 2px 0", color: usernameState === "available" ? "#15803d" : usernameState === "taken" || usernameState === "invalid" || usernameState === "error" ? "#dc2626" : "var(--text-secondary)" }}>
            {usernameState === "invalid" ? "ใช้ a-z, 0-9 หรือ _ จำนวน 3–20 ตัวอักษร"
              : usernameState === "taken" ? "ชื่อผู้ใช้นี้ถูกใช้แล้ว กรุณาเลือกชื่ออื่น"
              : usernameState === "available" ? "ชื่อผู้ใช้นี้ใช้ได้"
              : usernameState === "error" ? "ตรวจสอบชื่อผู้ใช้ไม่ได้ กรุณาลองอีกครั้ง"
              : usernameState === "checking" ? "กำลังตรวจสอบชื่อผู้ใช้…" : ""}
          </p>
        </div>
        <Field label="ชื่อที่แสดง" name="displayName" placeholder="ชื่อของคุณ" value={draft.displayName} onChange={update("displayName")} disabled={!mounted} />
        <div className="field">
          <label>วันเกิด</label>
          <div style={{ display: "flex", gap: 8 }}>
            <select
              aria-label="วัน"
              className="wyn-select"
              value={birthDay ?? ""}
              onChange={updateBirthDatePart("day")}
              disabled={!mounted}
              style={{ flex: "0 0 74px" }}
            >
              <option value="">วัน</option>
              {Array.from({ length: 31 }, (_, i) => String(i + 1).padStart(2, "0")).map((day) => (
                <option key={day} value={day}>{Number(day)}</option>
              ))}
            </select>
            <select
              aria-label="เดือน"
              className="wyn-select"
              value={birthMonth ?? ""}
              onChange={updateBirthDatePart("month")}
              disabled={!mounted}
              style={{ flex: 1 }}
            >
              <option value="">เดือน</option>
              {THAI_MONTHS.map((label, i) => (
                <option key={label} value={String(i + 1).padStart(2, "0")}>{label}</option>
              ))}
            </select>
            <select
              aria-label="ปี"
              className="wyn-select"
              value={birthYear ?? ""}
              onChange={updateBirthDatePart("year")}
              disabled={!mounted}
              style={{ flex: "0 0 92px" }}
            >
              <option value="">ปี</option>
              {eligibleBirthYears().map((year) => (
                <option key={year} value={year}>{year + BUDDHIST_ERA_OFFSET}</option>
              ))}
            </select>
          </div>
        </div>
        <p className="wyn-official-autofollow-disclosure" style={{ fontSize: 12, lineHeight: 1.6, color: "var(--text-secondary)", margin: "8px 2px 12px" }}>เมื่อสมัครบัญชีใหม่ คุณจะติดตามบัญชี Official @wynos_s โดยอัตโนมัติ และสามารถเลิกติดตามได้ทุกเมื่อ</p>
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
  const [awaitingConfirmation, setAwaitingConfirmation] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  // Keep all signup fields non-interactive until React hydration completes.
  // Otherwise the first keystrokes can be lost on mobile Safari or Chromium.
  const mounted = useSyncExternalStore(subscribeNever, () => true, () => false);
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
    if (draft.password.length < MIN_SIGNUP_PASSWORD_LENGTH) {
      setError(`รหัสผ่านต้องมีอย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`);
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
      // Recheck immediately before Auth creates an account: another person may
      // have claimed the name since step 1. The database UNIQUE constraint
      // remains authoritative for the final race with the profile write.
      let usernameAvailable: boolean;
      try {
        usernameAvailable = await checkSignupUsernameAvailability(supabase, draft.username);
      } catch {
        setError("ตรวจสอบชื่อผู้ใช้ไม่ได้ กรุณาลองอีกครั้ง");
        return;
      }
      if (!usernameAvailable) {
        setError("ชื่อผู้ใช้นี้ถูกใช้แล้ว กรุณาย้อนกลับไปเปลี่ยนชื่อผู้ใช้");
        return;
      }
      const result = await signUpWithEmail(supabase, email, draft.password);
      if (!result.session) {
        // Email confirmation is enabled. There is no authenticated session yet,
        // so RLS correctly rejects profile writes until the user confirms.
        // Step-1 fields are already persisted (passwords never are).
        setDraft((current) => ({ ...current, password: "", confirmPassword: "" }));
        setAwaitingConfirmation(email);
        return;
      }
      const userId = result.session.user.id;
      setDraft((current) => ({ ...current, password: "", confirmPassword: "" }));
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
      if (err instanceof SignupPasswordTooShortError) {
        setError(`รหัสผ่านต้องมีอย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`);
      } else if (err instanceof EmailAlreadyRegisteredError) {
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

  if (awaitingConfirmation) {
    return (
      <AuthPhone>
        <BackTopbar href="/login" />
        <div style={{ padding: "32px 20px", flex: 1 }} role="status">
          <h1 style={{ fontSize: 28, fontWeight: 800, marginBottom: 12 }}>ตรวจสอบอีเมลของคุณ</h1>
          <p style={{ color: "var(--text-secondary)", lineHeight: 1.7 }}>
            หากสมัครสำเร็จ เราได้ส่งลิงก์ยืนยันไปที่ {awaitingConfirmation} แล้ว
            กรุณากดลิงก์บนอุปกรณ์นี้เพื่อกลับมาตั้งค่าโปรไฟล์ให้เสร็จ
          </p>
          <Button className="btn-primary" onClick={() => router.push("/login")} style={{ marginTop: 20 }}>ไปหน้าเข้าสู่ระบบ</Button>
        </div>
      </AuthPhone>
    );
  }

  return (
    <AuthPhone>
      <BackTopbar href="/signup/step-1" step="2/2" />
      <div style={{ padding: "16px 20px", flex: 1 }}>
        <div style={{ fontSize: 32, fontWeight: 800, letterSpacing: "-0.02em", marginBottom: 6 }}>ตั้งรหัสผ่าน</div>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "0 0 20px" }}>ใช้สำหรับเข้าสู่ระบบครั้งต่อไป</p>
        <Field label="อีเมล" name="email" placeholder="you@example.com" value={draft.email} onChange={update("email")} disabled={!mounted} />
        <Field label="รหัสผ่าน" name="password" placeholder={`อย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`} type="password" value={draft.password} onChange={update("password")} disabled={!mounted} />
        <Field label="ยืนยันรหัสผ่าน" name="confirmPassword" placeholder="พิมพ์รหัสผ่านอีกครั้ง" type="password" value={draft.confirmPassword} onChange={update("confirmPassword")} disabled={!mounted} />
        <Button className="btn-primary" disabled={loading || !mounted} onClick={() => void createAccount()} style={{ marginTop: 10 }}>{loading ? "กำลังสร้างบัญชี…" : "สร้างบัญชี"}</Button>
        <ErrorText>{error}</ErrorText>
        <p style={{ fontSize: 13, color: "var(--text-secondary)", textAlign: "center", marginTop: 16 }}>
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
  const [avatarToCrop, setAvatarToCrop] = useState<File | null>(null);
  const [croppedAvatar, setCroppedAvatar] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);
  const previewRef = useRef<string | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  useEffect(() => () => {
    if (previewRef.current) URL.revokeObjectURL(previewRef.current);
  }, []);

  const selectAvatar = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.currentTarget.files?.[0];
    event.currentTarget.value = ""; // Allow re-selecting the same photo.
    if (!file) return;
    if (file.size > 10 * 1024 * 1024 || file.size === 0) {
      setError("รูปภาพต้องมีขนาดไม่เกิน 10MB");
      return;
    }
    if (!file.type.startsWith("image/") && !/\.(heic|heif)$/i.test(file.name)) {
      setError("กรุณาเลือกไฟล์รูปภาพ");
      return;
    }
    setError("");
    setAvatarToCrop(file);
  };

  async function finish(skipAvatar = false) {
    if (loading) return;
    setLoading(true);
    setError("");
    try {
      if (!supabase) throw new Error("Supabase is not configured");
      const { data, error: authError } = await supabase.auth.getUser();
      if (authError || !data.user) throw new Error("Session unavailable");
      if (!skipAvatar && croppedAvatar) await uploadProfileImage(supabase, data.user.id, "avatar", croppedAvatar);
      if (bio.trim()) await saveOptionalProfile(supabase, data.user.id, { bio: bio.trim() });
      await completeOnboarding(supabase, data.user.id);
      router.push("/");
    } catch {
      setError("บันทึกโปรไฟล์ไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthPhone>
      <div style={{ display: "flex", justifyContent: "flex-end", padding: "16px 20px 0" }}>
        <button type="button" disabled={loading} onClick={() => void finish(true)} style={{ fontSize: 13, color: "var(--text-secondary)", cursor: "pointer", border: 0, background: "transparent", padding: 0 }}>ข้าม</button>
      </div>
      <div style={{ padding: "0 20px", flex: 1 }}>
        <div style={{ textAlign: "center", marginBottom: 24 }}>
          <div style={{ fontSize: 32, fontWeight: 800, letterSpacing: "-0.02em" }}>เพิ่มรูปโปรไฟล์</div>
          <p style={{ fontSize: 13, color: "var(--text-secondary)", margin: "6px 0 0" }}>ให้คนอื่นรู้จักคุณมากขึ้น</p>
        </div>
        <div style={{ display: "flex", justifyContent: "center", marginBottom: 24 }}>
          <button className="wyn-onboarding-avatar-button" type="button" aria-label="เลือกรูปโปรไฟล์" disabled={loading} onClick={() => fileInput.current?.click()}>
            <Avatar as="div" src={avatarPreview} alt="รูปโปรไฟล์" className="avatar" size={96} />
            <span className="wyn-onboarding-camera-badge" aria-hidden="true"><WynosIcon name="camera" size={15} color="var(--bg)" /></span>
          </button>
          <input ref={fileInput} type="file" accept="image/*,.heic,.heif" aria-label="อัปโหลดรูปโปรไฟล์" hidden onChange={selectAvatar} disabled={loading} />
        </div>
        <div className="field">
          <label htmlFor="onboarding-bio">แนะนำตัวสั้นๆ (ไม่บังคับ)</label>
          <textarea id="onboarding-bio" placeholder="ชอบเที่ยว ชอบถ่ายรูป..." value={bio} onChange={(event) => setBio(event.target.value)} />
        </div>
        <ErrorText>{error}</ErrorText>
      </div>
      <div style={{ padding: "16px 20px" }}>
        <Button className="btn-primary" disabled={loading || Boolean(avatarToCrop)} onClick={() => void finish()}>{loading ? "กำลังบันทึก…" : "เริ่มใช้งาน Wynos"}</Button>
      </div>
      {avatarToCrop ? <ProfilePhotoCropper file={avatarToCrop} onCancel={() => setAvatarToCrop(null)} onConfirm={(file) => {
        if (previewRef.current) URL.revokeObjectURL(previewRef.current);
        const url = URL.createObjectURL(file);
        previewRef.current = url;
        setAvatarPreview(url);
        setCroppedAvatar(file);
        setAvatarToCrop(null);
      }} /> : null}
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
          <Image src="/wynos_logo_mark.png" alt="Wynos" width={99} height={64} style={{ height: 64, width: "auto", margin: "0 auto 14px", display: "block" }} priority />
          <div style={{ fontSize: 32, fontWeight: 800, letterSpacing: "-0.02em" }}>เข้าสู่ระบบ</div>
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
        <div style={{ fontSize: 32, fontWeight: 800, letterSpacing: "-0.02em", marginBottom: 6 }}>ลืมรหัสผ่าน?</div>
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

/**
 * Recovery is a separate, one-time authenticated flow. Visiting this page
 * while already signed in never grants reset access without a valid link.
 * Credentials are consumed immediately and removed from browser history.
 */
export function ResetPasswordScreen() {
  const router = useRouter();
  const recoveryClient = useRef<ReturnType<typeof createPasswordRecoveryClient>>(null);
  const pendingRecoveryHash = useRef<string | null>(null);
  const started = useRef(false);
  const [phase, setPhase] = useState<"checking" | "confirm" | "ready" | "invalid" | "saved">("checking");
  const [accountEmail, setAccountEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    const link = parsePasswordRecoveryLink(window.location.href);
    // Never leave an access token, verifier code or recovery hash in browser
    // history, analytics, or subsequent navigation URLs.
    window.history.replaceState(window.history.state, "", "/reset-password");

    if (link.kind === "token_hash") {
      // Mail clients and preview bots can GET this page harmlessly. Only a
      // real user clicking the button below consumes the one-time token.
      pendingRecoveryHash.current = link.tokenHash;
      void Promise.resolve().then(() => setPhase("confirm"));
      return;
    }

    const client = link.kind === "invalid" ? null : createPasswordRecoveryClient();

    void (async () => {
      // An async boundary avoids setState during the mount effect itself.
      await Promise.resolve();
      if (link.kind === "invalid" || !client) {
        setPhase("invalid");
        return;
      }
      try {
        let session;
        if (link.kind === "code") {
          const result = await client.auth.exchangeCodeForSession(link.code);
          if (result.error) throw result.error;
          session = result.data.session;
        } else {
          const result = await client.auth.setSession({
            access_token: link.accessToken,
            refresh_token: link.refreshToken,
          });
          if (result.error) throw result.error;
          session = result.data.session;
        }

        if (!session) throw new Error("No session for recovery");
        // Verify against Supabase Auth instead of trusting browser storage.
        const userResult = await client.auth.getUser();
        if (userResult.error || !userResult.data.user) throw userResult.error ?? new Error("Invalid recovery user");
        recoveryClient.current = client;
        setAccountEmail(userResult.data.user.email ?? "");
        setPhase("ready");
      } catch {
        setPhase("invalid");
      }
    })();
  }, []);

  async function continueFromEmail() {
    if (phase !== "confirm" || loading || !pendingRecoveryHash.current) return;
    const tokenHash = pendingRecoveryHash.current;
    pendingRecoveryHash.current = null;
    setLoading(true);
    try {
      const client = createPasswordRecoveryClient();
      if (!client) throw new Error("Recovery client unavailable");
      const result = await client.auth.verifyOtp({ token_hash: tokenHash, type: "recovery" });
      if (result.error || !result.data.session) throw result.error ?? new Error("No recovery session");
      const userResult = await client.auth.getUser();
      if (userResult.error || !userResult.data.user) throw userResult.error ?? new Error("Invalid recovery user");
      recoveryClient.current = client;
      setAccountEmail(userResult.data.user.email ?? "");
      setPhase("ready");
    } catch {
      setPhase("invalid");
    } finally {
      setLoading(false);
    }
  }

  async function submit() {
    if (loading || phase !== "ready" || !recoveryClient.current) return;
    setError("");
    if (password.length < MIN_SIGNUP_PASSWORD_LENGTH) {
      setError(`รหัสผ่านใหม่ต้องมีอย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`);
      return;
    }
    if (password !== confirmPassword) {
      setError("รหัสผ่านทั้งสองช่องไม่ตรงกัน");
      return;
    }

    setLoading(true);
    try {
      const client = recoveryClient.current;
      const result = await client.auth.updateUser({ password });
      if (result.error) throw result.error;
      setPassword("");
      setConfirmPassword("");
      // The one-time recovery session must not remain logged in after reset.
      // A failed local sign-out must not hide a successfully saved password.
      await client.auth.signOut({ scope: "local" }).catch(() => undefined);
      recoveryClient.current = null;
      setPhase("saved");
    } catch {
      setError("เปลี่ยนรหัสผ่านไม่สำเร็จ กรุณาลองใหม่หรือขอลิงก์รีเซ็ตอีกครั้ง");
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthPhone>
      <BackTopbar href="/login" />
      <div style={{ padding: "16px 20px", flex: 1 }}>
        <div style={{ textAlign: "center", marginBottom: 28 }}>
          <Image src="/wynos_logo_mark.png" alt="Wynos" width={99} height={64}
            style={{ height: 64, width: "auto", margin: "0 auto 14px", display: "block" }} priority />
          <h1 style={{ fontSize: 32, fontWeight: 800, letterSpacing: "-0.02em" }}>ตั้งรหัสผ่านใหม่</h1>
        </div>

        {phase === "checking" ? <p role="status">กำลังตรวจสอบลิงก์รีเซ็ตรหัสผ่าน…</p> : null}
        {phase === "confirm" ? (
          <>
            <p style={{ fontSize: 14, lineHeight: 1.6, marginBottom: 20 }}>กดปุ่มด้านล่างเพื่อยืนยันลิงก์และตั้งรหัสผ่านใหม่</p>
            <Button className="btn-primary" disabled={loading} onClick={() => void continueFromEmail()}>
              {loading ? "กำลังยืนยัน…" : "ยืนยันและตั้งรหัสผ่านใหม่"}
            </Button>
          </>
        ) : null}
        {phase === "invalid" ? (
          <>
            <p role="alert" style={{ fontSize: 14, lineHeight: 1.6 }}>ลิงก์รีเซ็ตรหัสผ่านไม่ถูกต้องหรือหมดอายุ กรุณาขอลิงก์ใหม่</p>
            <Button className="btn-primary" onClick={() => router.replace("/forgot-password")}>ขอลิงก์ใหม่</Button>
          </>
        ) : null}
        {phase === "ready" ? (
          <>
            {accountEmail ? (
              <p style={{ fontSize: 13, color: "var(--text-secondary)", marginBottom: 20 }}>
                บัญชี: {accountEmail}
              </p>
            ) : null}
            <Field label="รหัสผ่านใหม่" name="newPassword"
              placeholder={`อย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`}
              type="password" value={password} onChange={(event) => setPassword(event.target.value)} />
            <Field label="ยืนยันรหัสผ่านใหม่" name="confirmNewPassword"
              placeholder="พิมพ์รหัสผ่านใหม่อีกครั้ง"
              type="password" value={confirmPassword}
              onChange={(event) => setConfirmPassword(event.target.value)} />
            <Button className="btn-primary" disabled={loading} onClick={() => void submit()}
              style={{ marginTop: 10 }}>{loading ? "กำลังบันทึก…" : "บันทึกรหัสผ่านใหม่"}</Button>
            <ErrorText>{error}</ErrorText>
          </>
        ) : null}
        {phase === "saved" ? (
          <>
            <p role="status" style={{ fontSize: 14, marginBottom: 20 }}>เปลี่ยนรหัสผ่านสำเร็จแล้ว กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่</p>
            <Button className="btn-primary" onClick={() => router.replace("/login")}>ไปหน้าเข้าสู่ระบบ</Button>
          </>
        ) : null}
      </div>
    </AuthPhone>
  );
}
