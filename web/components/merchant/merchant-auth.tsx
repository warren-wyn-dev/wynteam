"use client";

import { ArrowLeft, CheckCircle2, Clock3, Store, XCircle } from "lucide-react";
import Link from "next/link";
import { useEffect, useMemo, useState, type ReactNode } from "react";

import {
  fetchMerchantIdentity,
  resetMerchantPasswordForEmail,
  signInMerchantWithEmail,
  signUpMerchantWithEmail,
} from "@/lib/merchant-account";
import {
  fetchMerchantApplication,
  submitMerchantApplication,
  type MerchantApplication,
  type MerchantApplicationDraft,
  type MerchantBusinessType,
} from "@/lib/merchant-application";
import { MIN_SIGNUP_PASSWORD_LENGTH } from "@/lib/signup-password-policy";
import {
  getMerchantSupabaseBrowserClient,
  hasMerchantBrowserConfig,
} from "@/lib/supabase/merchant-browser";

const EMPTY_DRAFT: MerchantApplicationDraft = {
  businessName: "",
  businessType: "food",
  contactName: "",
  phone: "",
  address: "",
  note: "",
};

function MerchantAuthBrand() {
  return (
    <div className="wm-auth-brand" aria-label="WYNOS Merchant">
      <span>WYNOS</span>
      <b>Merchant</b>
    </div>
  );
}

function MerchantAuthShell({ children }: { children: ReactNode }) {
  return <main className="wm-auth-shell"><section className="wm-auth-card">{children}</section></main>;
}

function BackToMerchant() {
  return (
    <Link className="wm-auth-back" href="/merchant" aria-label="กลับ WYNOS Merchant">
      <ArrowLeft size={20} strokeWidth={1.8} />
    </Link>
  );
}

function authErrorMessage(error: unknown) {
  const code = (error as { code?: string })?.code;
  const message = error instanceof Error ? error.message : "";
  if (code === "email_not_confirmed") return "บัญชีนี้ยังไม่ได้ยืนยันอีเมล กรุณากดลิงก์ยืนยันในอีเมลก่อนเข้าสู่ระบบ";
  if (message === "not_merchant_account") return "บัญชีนี้ไม่ใช่บัญชี WYNOS Merchant กรุณาใช้บัญชี Merchant หรือสมัครใหม่";
  if (message === "merchant_email_already_used") return "อีเมลนี้ถูกใช้งานแล้ว กรุณาใช้อีเมลสำหรับ WYNOS Merchant อีกอีเมลหนึ่ง";
  if (message === "merchant_password_too_short") return `รหัสผ่าน Merchant ต้องมีอย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`;
  return "อีเมลหรือรหัสผ่านไม่ถูกต้อง";
}

export function MerchantLoginScreen() {
  const client = useMemo(() => getMerchantSupabaseBrowserClient(), []);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [checking, setChecking] = useState(() => Boolean(client));
  const [message, setMessage] = useState("");

  useEffect(() => {
    let mounted = true;
    if (!client) return;
    void client.auth.getSession().then(async ({ data, error }) => {
      if (!mounted) return;
      if (!error && data.session) {
        const identity = await fetchMerchantIdentity(client, data.session.user.id).catch(() => null);
        if (identity?.active && identity.identity_mode === "merchant") {
          window.location.replace("/merchant");
          return;
        }
        await client.auth.signOut();
      }
      if (mounted) setChecking(false);
    }).catch(() => { if (mounted) setChecking(false); });
    return () => { mounted = false; };
  }, [client]);

  async function submit() {
    if (loading) return;
    setMessage("");
    if (!email.trim() || !password) {
      setMessage("กรุณากรอกอีเมลและรหัสผ่าน");
      return;
    }
    if (!client) {
      setMessage("ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS Merchant");
      return;
    }

    setLoading(true);
    try {
      await signInMerchantWithEmail(client, email.trim(), password);
      window.location.replace("/merchant");
    } catch (error) {
      setMessage(authErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  if (checking) {
    return <MerchantAuthShell><div className="wm-auth-loading"><div className="wm-loader" /><span>กำลังตรวจสอบบัญชี Merchant…</span></div></MerchantAuthShell>;
  }

  return (
    <MerchantAuthShell>
      <div className="wm-auth-top"><BackToMerchant /><MerchantAuthBrand /><span className="wm-auth-top-spacer" /></div>
      <div className="wm-auth-hero">
        <div className="wm-auth-mark"><Store size={30} strokeWidth={1.7} /></div>
        <h1>เข้าสู่ระบบ Merchant</h1>
        <p>เข้าสู่ระบบด้วยอีเมลและรหัสผ่านของ WYNOS Merchant</p>
      </div>
      <div className="wm-auth-form">
        <label>อีเมล Merchant<input type="email" autoComplete="email" autoCapitalize="none" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="merchant@example.com" /></label>
        <label>รหัสผ่าน<input type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder="รหัสผ่าน Merchant" /></label>
        <div className="wm-auth-inline"><Link href="/merchant/forgot-password">ลืมรหัสผ่าน?</Link></div>
        {message ? <p className="wm-auth-error" role="alert">{message}</p> : null}
        <button className="wm-primary wm-full" type="button" disabled={loading} onClick={() => void submit()}>{loading ? "กำลังเข้าสู่ระบบ…" : "เข้าสู่ระบบ"}</button>
      </div>
      <p className="wm-auth-switch">ยังไม่มีบัญชี Merchant? <Link href="/merchant/signup">สมัคร WYNOS Merchant</Link></p>
      <p className="wm-auth-footnote">บัญชี WYNOS Merchant แยกจากบัญชี WYNOS Social</p>
    </MerchantAuthShell>
  );
}

function statusContent(application: MerchantApplication) {
  if (application.status === "approved") {
    return {
      icon: <CheckCircle2 size={34} strokeWidth={1.7} />,
      title: "คำขอได้รับการอนุมัติแล้ว",
      detail: "บัญชี Merchant ของคุณได้รับอนุมัติแล้ว และพร้อมเข้า Dashboard เมื่อร้านถูก provision",
      tone: "approved",
    };
  }
  if (application.status === "rejected") {
    return {
      icon: <XCircle size={34} strokeWidth={1.7} />,
      title: "คำขอต้องแก้ไข",
      detail: application.rejection_reason || "ข้อมูลบางส่วนยังไม่ผ่านการตรวจสอบ กรุณาแก้ไขและส่งคำขอใหม่",
      tone: "rejected",
    };
  }
  return {
    icon: <Clock3 size={34} strokeWidth={1.7} />,
    title: "ส่งคำขอ Merchant แล้ว",
    detail: "WYNOS ได้รับข้อมูลร้านของคุณแล้ว สถานะปัจจุบันคือรอตรวจสอบ",
    tone: "pending",
  };
}

export function MerchantSignupScreen() {
  const client = useMemo(() => getMerchantSupabaseBrowserClient(), []);
  const [checking, setChecking] = useState(() => Boolean(client));
  const [userId, setUserId] = useState<string | null>(null);
  const [application, setApplication] = useState<MerchantApplication | null>(null);
  const [draft, setDraft] = useState<MerchantApplicationDraft>(EMPTY_DRAFT);
  const [editingRejected, setEditingRejected] = useState(false);
  const [accountEmail, setAccountEmail] = useState("");
  const [accountPassword, setAccountPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [awaitingEmailConfirmation, setAwaitingEmailConfirmation] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  async function loadApplication(id: string) {
    if (!client) return;
    const current = await fetchMerchantApplication(client, id);
    setApplication(current);
    if (current) {
      setDraft({
        businessName: current.business_name,
        businessType: current.business_type,
        contactName: current.contact_name,
        phone: current.phone,
        address: current.address,
        note: current.note ?? "",
      });
    }
  }

  useEffect(() => {
    let mounted = true;
    if (!client) return;
    void (async () => {
      try {
        const session = await client.auth.getSession();
        if (!mounted) return;
        if (!session.data.session) {
          setChecking(false);
          return;
        }
        const identity = await fetchMerchantIdentity(client, session.data.session.user.id);
        if (!mounted) return;
        if (!identity?.active || identity.identity_mode !== "merchant") {
          await client.auth.signOut();
          setChecking(false);
          return;
        }
        const id = session.data.session.user.id;
        setUserId(id);
        await loadApplication(id);
      } catch {
        if (mounted) setMessage("โหลดข้อมูลสมัคร Merchant ไม่สำเร็จ กรุณาลองใหม่");
      } finally {
        if (mounted) setChecking(false);
      }
    })();
    return () => { mounted = false; };
  }, [client]);

  async function createMerchantAccount() {
    if (!client || loading) return;
    if (!accountEmail.trim()) {
      setMessage("กรุณากรอกอีเมล Merchant");
      return;
    }
    if (accountPassword !== confirmPassword) {
      setMessage("รหัสผ่านทั้งสองช่องไม่ตรงกัน");
      return;
    }

    setLoading(true);
    setMessage("");
    try {
      const data = await signUpMerchantWithEmail(client, accountEmail.trim(), accountPassword);
      if (!data.session || !data.user) {
        setAwaitingEmailConfirmation(true);
        setMessage("สร้างบัญชี Merchant แล้ว กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ");
        return;
      }
      setUserId(data.user.id);
      await loadApplication(data.user.id);
      setMessage("สร้างบัญชี WYNOS Merchant เรียบร้อยแล้ว");
    } catch (error) {
      setMessage(authErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  async function submit() {
    if (!client || !userId || loading) return;
    setLoading(true);
    setMessage("");
    try {
      await submitMerchantApplication(client, userId, draft, application);
      await loadApplication(userId);
      setEditingRejected(false);
      setMessage("ส่งคำขอ WYNOS Merchant เรียบร้อยแล้ว");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "ส่งคำขอไม่สำเร็จ กรุณาลองใหม่");
    } finally {
      setLoading(false);
    }
  }

  if (!hasMerchantBrowserConfig()) {
    return <MerchantAuthShell><div className="wm-auth-state"><MerchantAuthBrand /><h1>ยังไม่ได้ตั้งค่าการเชื่อมต่อ</h1><p>WYNOS Merchant ยังเชื่อมต่อระบบบัญชีไม่ได้</p></div></MerchantAuthShell>;
  }
  if (checking) {
    return <MerchantAuthShell><div className="wm-auth-loading"><div className="wm-loader" /><span>กำลังเปิดหน้าสมัคร Merchant…</span></div></MerchantAuthShell>;
  }

  if (!userId) {
    return (
      <MerchantAuthShell>
        <div className="wm-auth-top"><BackToMerchant /><MerchantAuthBrand /><span className="wm-auth-top-spacer" /></div>
        <div className="wm-auth-hero">
          <div className="wm-auth-mark"><Store size={30} strokeWidth={1.7} /></div>
          <h1>สร้างบัญชี WYNOS Merchant</h1>
          <p>บัญชีร้านค้าแยกจาก WYNOS Social ใช้อีเมลและรหัสผ่านสำหรับธุรกิจโดยเฉพาะ</p>
        </div>
        <div className="wm-auth-benefits">
          <span><CheckCircle2 size={18} />บัญชี Merchant แยกจาก Social</span>
          <span><CheckCircle2 size={18} />ร้านมี Merchant Account ของตัวเอง</span>
          <span><CheckCircle2 size={18} />รองรับ Owner และ Staff หลายคน</span>
        </div>
        <div className="wm-auth-form">
          <label>อีเมล Merchant<input type="email" autoComplete="email" autoCapitalize="none" value={accountEmail} onChange={(event) => setAccountEmail(event.target.value)} placeholder="merchant@example.com" /></label>
          <label>รหัสผ่าน<input type="password" autoComplete="new-password" value={accountPassword} onChange={(event) => setAccountPassword(event.target.value)} placeholder={`อย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`} /></label>
          <label>ยืนยันรหัสผ่าน<input type="password" autoComplete="new-password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} placeholder="กรอกรหัสผ่านอีกครั้ง" /></label>
        </div>
        {message ? <p className={awaitingEmailConfirmation ? "wm-auth-success" : "wm-auth-error"} role="status">{message}</p> : null}
        {!awaitingEmailConfirmation ? (
          <button className="wm-primary wm-full" type="button" disabled={loading} onClick={() => void createMerchantAccount()}>{loading ? "กำลังสร้างบัญชี…" : "สร้างบัญชี Merchant"}</button>
        ) : (
          <Link className="wm-primary wm-full wm-link-button" href="/merchant/login">ไปหน้าเข้าสู่ระบบ</Link>
        )}
        <p className="wm-auth-switch">มีบัญชี Merchant แล้ว? <Link href="/merchant/login">เข้าสู่ระบบ</Link></p>
        <p className="wm-auth-footnote">หากอีเมลนี้ใช้กับบัญชี WYNOS Social อยู่แล้ว ให้ใช้อีเมล Merchant อีกอีเมลหนึ่ง</p>
      </MerchantAuthShell>
    );
  }

  if (application && application.status !== "rejected") {
    const status = statusContent(application);
    return (
      <MerchantAuthShell>
        <div className="wm-auth-top"><BackToMerchant /><MerchantAuthBrand /><span className="wm-auth-top-spacer" /></div>
        <div className={"wm-application-status wm-application-status--" + status.tone}>
          {status.icon}<h1>{status.title}</h1><p>{status.detail}</p>
        </div>
        <div className="wm-application-summary">
          <span><small>ชื่อธุรกิจ</small><strong>{application.business_name}</strong></span>
          <span><small>เบอร์ติดต่อ</small><strong>{application.phone}</strong></span>
          <span><small>Merchant Account</small><strong>{application.merchant_account_id ?? "กำลังสร้าง"}</strong></span>
        </div>
        {message ? <p className="wm-auth-success" role="status">{message}</p> : null}
        <Link className="wm-primary wm-full wm-link-button" href="/merchant">ไป WYNOS Merchant</Link>
      </MerchantAuthShell>
    );
  }

  const showForm = !application || application.status === "rejected" && editingRejected;
  const rejected = application?.status === "rejected" ? statusContent(application) : null;

  return (
    <MerchantAuthShell>
      <div className="wm-auth-top"><BackToMerchant /><MerchantAuthBrand /><span className="wm-auth-top-spacer" /></div>
      {rejected && !editingRejected ? (
        <>
          <div className={"wm-application-status wm-application-status--" + rejected.tone}>
            {rejected.icon}<h1>{rejected.title}</h1><p>{rejected.detail}</p>
          </div>
          <button className="wm-primary wm-full" type="button" onClick={() => setEditingRejected(true)}>แก้ไขและส่งใหม่</button>
        </>
      ) : null}

      {showForm ? (
        <>
          <div className="wm-auth-heading"><h1>{application ? "แก้ไขคำขอ Merchant" : "ข้อมูลธุรกิจ"}</h1><p>ข้อมูลนี้จะผูกกับ Merchant Account ของร้าน</p></div>
          <div className="wm-auth-form">
            <label>ชื่อร้าน / ชื่อธุรกิจ<input value={draft.businessName} onChange={(event) => setDraft({ ...draft, businessName: event.target.value })} placeholder="เช่น ร้าน WYNOS Cafe" /></label>
            <label>ประเภทธุรกิจ<select value={draft.businessType} onChange={(event) => setDraft({ ...draft, businessType: event.target.value as MerchantBusinessType })}><option value="food">อาหาร / เครื่องดื่ม</option><option value="retail">ร้านค้าสินค้า</option><option value="service">บริการ</option><option value="other">อื่น ๆ</option></select></label>
            <label>ชื่อผู้ติดต่อ<input value={draft.contactName} onChange={(event) => setDraft({ ...draft, contactName: event.target.value })} placeholder="ชื่อเจ้าของร้านหรือผู้ดูแล" /></label>
            <label>เบอร์โทร<input inputMode="tel" value={draft.phone} onChange={(event) => setDraft({ ...draft, phone: event.target.value })} placeholder="08x-xxx-xxxx" /></label>
            <label>ที่อยู่ร้าน / ธุรกิจ<textarea value={draft.address} onChange={(event) => setDraft({ ...draft, address: event.target.value })} placeholder="ที่อยู่หรือพื้นที่ให้บริการ" /></label>
            <label>ข้อมูลเพิ่มเติม (ไม่บังคับ)<textarea value={draft.note} onChange={(event) => setDraft({ ...draft, note: event.target.value })} placeholder="รายละเอียดที่ต้องการแจ้ง WYNOS" /></label>
          </div>
          {message ? <p className={message.includes("เรียบร้อย") ? "wm-auth-success" : "wm-auth-error"} role="status">{message}</p> : null}
          <button className="wm-primary wm-full" type="button" disabled={loading} onClick={() => void submit()}>{loading ? "กำลังส่งคำขอ…" : application ? "ส่งคำขอใหม่" : "ส่งคำขอสมัคร Merchant"}</button>
          <p className="wm-auth-footnote">Owner จะเป็นสมาชิกคนแรกของ Merchant Account และสามารถเพิ่ม Staff ได้ในระบบทีมงานภายหลัง</p>
        </>
      ) : null}
    </MerchantAuthShell>
  );
}

export function MerchantForgotPasswordScreen() {
  const client = useMemo(() => getMerchantSupabaseBrowserClient(), []);
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  async function submit() {
    if (!client || loading || !email.trim()) return;
    setLoading(true);
    try {
      await resetMerchantPasswordForEmail(client, email.trim());
      setMessage("ส่งลิงก์รีเซ็ตรหัสผ่าน Merchant แล้ว กรุณาตรวจสอบอีเมล");
    } catch {
      setMessage("ส่งลิงก์รีเซ็ตรหัสผ่านไม่สำเร็จ กรุณาลองใหม่");
    } finally {
      setLoading(false);
    }
  }

  return (
    <MerchantAuthShell>
      <div className="wm-auth-top"><Link className="wm-auth-back" href="/merchant/login"><ArrowLeft size={20} /></Link><MerchantAuthBrand /><span className="wm-auth-top-spacer" /></div>
      <div className="wm-auth-heading"><h1>ลืมรหัสผ่าน Merchant</h1><p>เราจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปยังอีเมล Merchant</p></div>
      <div className="wm-auth-form"><label>อีเมล Merchant<input type="email" value={email} onChange={(event) => setEmail(event.target.value)} /></label></div>
      {message ? <p className="wm-auth-success" role="status">{message}</p> : null}
      <button className="wm-primary wm-full" type="button" disabled={loading || !email.trim()} onClick={() => void submit()}>{loading ? "กำลังส่ง…" : "ส่งลิงก์รีเซ็ต"}</button>
    </MerchantAuthShell>
  );
}

export function MerchantResetPasswordScreen() {
  const client = useMemo(() => getMerchantSupabaseBrowserClient(), []);
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [ready, setReady] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!client) return;
    let mounted = true;
    const sync = async () => {
      const { data } = await client.auth.getSession();
      if (mounted) setReady(Boolean(data.session));
    };
    void sync();
    const { data } = client.auth.onAuthStateChange((event, session) => {
      if (!mounted) return;
      if (event === "PASSWORD_RECOVERY" || session) setReady(Boolean(session));
    });
    return () => { mounted = false; data.subscription.unsubscribe(); };
  }, [client]);

  async function submit() {
    if (!client || loading) return;
    if (password.length < MIN_SIGNUP_PASSWORD_LENGTH) {
      setMessage(`รหัสผ่านต้องมีอย่างน้อย ${MIN_SIGNUP_PASSWORD_LENGTH} ตัวอักษร`);
      return;
    }
    if (password !== confirmPassword) {
      setMessage("รหัสผ่านทั้งสองช่องไม่ตรงกัน");
      return;
    }
    setLoading(true);
    try {
      const { error } = await client.auth.updateUser({ password });
      if (error) throw error;
      setMessage("เปลี่ยนรหัสผ่าน Merchant เรียบร้อยแล้ว");
      window.setTimeout(() => window.location.replace("/merchant/login"), 700);
    } catch {
      setMessage("เปลี่ยนรหัสผ่านไม่สำเร็จ ลิงก์อาจหมดอายุ");
    } finally {
      setLoading(false);
    }
  }

  return (
    <MerchantAuthShell>
      <div className="wm-auth-top"><Link className="wm-auth-back" href="/merchant/login"><ArrowLeft size={20} /></Link><MerchantAuthBrand /><span className="wm-auth-top-spacer" /></div>
      <div className="wm-auth-heading"><h1>ตั้งรหัสผ่าน Merchant ใหม่</h1><p>{ready ? "ตั้งรหัสผ่านใหม่สำหรับบัญชี Merchant" : "กำลังตรวจสอบลิงก์รีเซ็ต…"}</p></div>
      <div className="wm-auth-form">
        <label>รหัสผ่านใหม่<input type="password" autoComplete="new-password" value={password} onChange={(event) => setPassword(event.target.value)} /></label>
        <label>ยืนยันรหัสผ่าน<input type="password" autoComplete="new-password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} /></label>
      </div>
      {message ? <p className={message.includes("เรียบร้อย") ? "wm-auth-success" : "wm-auth-error"} role="status">{message}</p> : null}
      <button className="wm-primary wm-full" type="button" disabled={!ready || loading} onClick={() => void submit()}>{loading ? "กำลังบันทึก…" : "บันทึกรหัสผ่านใหม่"}</button>
    </MerchantAuthShell>
  );
}
