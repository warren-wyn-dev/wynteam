"use client";

import { ArrowLeft, CheckCircle2, Clock3, Store, XCircle } from "lucide-react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState, type ReactNode } from "react";

import { signInWithEmail } from "@/lib/auth-repository";
import {
  fetchMerchantApplication,
  submitMerchantApplication,
  type MerchantApplication,
  type MerchantApplicationDraft,
  type MerchantBusinessType,
} from "@/lib/merchant-application";
import { consumeReturnPath, rememberReturnPath } from "@/lib/return-to";
import { getSupabaseBrowserClient, hasSupabaseBrowserConfig } from "@/lib/supabase/browser";

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
  return (
    <main className="wm-auth-shell">
      <section className="wm-auth-card">{children}</section>
    </main>
  );
}

function BackToMerchant() {
  return (
    <Link className="wm-auth-back" href="/merchant" aria-label="กลับ WYNOS Merchant">
      <ArrowLeft size={20} strokeWidth={1.8} />
    </Link>
  );
}

export function MerchantLoginScreen() {
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [checking, setChecking] = useState(true);
  const [message, setMessage] = useState("");

  useEffect(() => {
    let mounted = true;
    if (!client) {
      setChecking(false);
      return;
    }
    void client.auth.getSession().then(({ data, error }) => {
      if (!mounted) return;
      if (!error && data.session) {
        window.location.replace(consumeReturnPath() ?? "/merchant");
        return;
      }
      setChecking(false);
    }).catch(() => {
      if (mounted) setChecking(false);
    });
    return () => { mounted = false; };
  }, [client]);

  async function submit() {
    if (loading) return;
    setMessage("");
    const normalized = email.trim();
    if (!normalized || !password) {
      setMessage("กรุณากรอกอีเมลและรหัสผ่าน");
      return;
    }
    if (!client) {
      setMessage("ยังไม่ได้ตั้งค่าการเชื่อมต่อ WYNOS Merchant");
      return;
    }

    setLoading(true);
    try {
      const active = await client.auth.getSession();
      if (active.error) throw active.error;
      if (active.data.session) {
        window.location.replace(consumeReturnPath() ?? "/merchant");
        return;
      }
      await signInWithEmail(client, normalized, password);
      window.location.replace(consumeReturnPath() ?? "/merchant");
    } catch (error) {
      const code = (error as { code?: string })?.code;
      setMessage(code === "email_not_confirmed"
        ? "บัญชีนี้ยังไม่ได้ยืนยันอีเมล กรุณากดลิงก์ยืนยันในอีเมลก่อนเข้าสู่ระบบ"
        : "อีเมลหรือรหัสผ่านไม่ถูกต้อง");
    } finally {
      setLoading(false);
    }
  }

  if (checking) {
    return <MerchantAuthShell><div className="wm-auth-loading"><div className="wm-loader" /><span>กำลังตรวจสอบบัญชี…</span></div></MerchantAuthShell>;
  }

  return (
    <MerchantAuthShell>
      <div className="wm-auth-top"><BackToMerchant /><MerchantAuthBrand /><span className="wm-auth-top-spacer" /></div>
      <div className="wm-auth-hero">
        <div className="wm-auth-mark"><Store size={30} strokeWidth={1.7} /></div>
        <h1>เข้าสู่ระบบ Merchant</h1>
        <p>จัดการร้าน ออเดอร์ เมนู ยอดขาย และการจัดส่งจากบัญชี WYNOS ของคุณ</p>
      </div>
      <div className="wm-auth-form">
        <label>อีเมล<input type="email" autoComplete="email" autoCapitalize="none" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="you@example.com" /></label>
        <label>รหัสผ่าน<input type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} placeholder="รหัสผ่านของคุณ" /></label>
        <div className="wm-auth-inline"><Link href="/forgot-password">ลืมรหัสผ่าน?</Link></div>
        {message ? <p className="wm-auth-error" role="alert">{message}</p> : null}
        <button className="wm-primary wm-full" type="button" disabled={loading} onClick={() => void submit()}>{loading ? "กำลังเข้าสู่ระบบ…" : "เข้าสู่ระบบ"}</button>
      </div>
      <p className="wm-auth-switch">ยังไม่มี Merchant? <Link href="/merchant/signup">สมัคร WYNOS Merchant</Link></p>
      <p className="wm-auth-footnote">ใช้บัญชี WYNOS เดียวกันได้ ไม่ต้องสร้างบัญชีซ้ำ</p>
    </MerchantAuthShell>
  );
}

function statusContent(application: MerchantApplication) {
  if (application.status === "approved") {
    return {
      icon: <CheckCircle2 size={34} strokeWidth={1.7} />,
      title: "คำขอได้รับการอนุมัติแล้ว",
      detail: "บัญชีของคุณได้รับอนุมัติสำหรับ WYNOS Merchant แล้ว หากร้านถูกผูกกับบัญชีเรียบร้อย คุณสามารถเข้า Dashboard ได้ทันที",
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
  const router = useRouter();
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [checking, setChecking] = useState(true);
  const [userId, setUserId] = useState<string | null>(null);
  const [application, setApplication] = useState<MerchantApplication | null>(null);
  const [draft, setDraft] = useState<MerchantApplicationDraft>(EMPTY_DRAFT);
  const [editingRejected, setEditingRejected] = useState(false);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    let mounted = true;
    if (!client) {
      setChecking(false);
      return;
    }

    void (async () => {
      try {
        const session = await client.auth.getSession();
        if (!mounted) return;
        if (session.error || !session.data.session) {
          setChecking(false);
          return;
        }

        const id = session.data.session.user.id;
        setUserId(id);

        const access = await client.rpc("food_has_merchant_access", { p_store_id: null });
        if (!mounted) return;
        if (!access.error && access.data === true) {
          window.location.replace("/merchant");
          return;
        }

        const current = await fetchMerchantApplication(client, id);
        if (!mounted) return;
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
      } catch {
        if (mounted) setMessage("โหลดข้อมูลสมัคร Merchant ไม่สำเร็จ กรุณาลองใหม่");
      } finally {
        if (mounted) setChecking(false);
      }
    })();

    return () => { mounted = false; };
  }, [client]);

  function startAccountSignup() {
    rememberReturnPath("/merchant/signup");
    router.push("/signup/step-1");
  }

  function startMerchantLogin() {
    rememberReturnPath("/merchant/signup");
    router.push("/merchant/login");
  }

  async function submit() {
    if (!client || !userId || loading) return;
    setLoading(true);
    setMessage("");
    try {
      await submitMerchantApplication(client, userId, draft, application);
      const next = await fetchMerchantApplication(client, userId);
      setApplication(next);
      setEditingRejected(false);
      setMessage("ส่งคำขอ WYNOS Merchant เรียบร้อยแล้ว");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "ส่งคำขอไม่สำเร็จ กรุณาลองใหม่");
    } finally {
      setLoading(false);
    }
  }

  if (!hasSupabaseBrowserConfig()) {
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
          <h1>สมัคร WYNOS Merchant</h1>
          <p>เปิดร้านบน WYNOS ด้วยบัญชีเดียวกับ WYNOS ปกติ แต่มีพื้นที่สมัครและจัดการ Merchant แยกโดยเฉพาะ</p>
        </div>
        <div className="wm-auth-benefits">
          <span><CheckCircle2 size={18} />ใช้บัญชี WYNOS เดิมได้</span>
          <span><CheckCircle2 size={18} />สมัครร้านและติดตามสถานะแยก</span>
          <span><CheckCircle2 size={18} />ข้อมูล Merchant ไม่ปะปนกับหน้า Social</span>
        </div>
        <button className="wm-primary wm-full" type="button" onClick={startAccountSignup}>สร้างบัญชีเพื่อสมัคร Merchant</button>
        <button className="wm-auth-secondary wm-full" type="button" onClick={startMerchantLogin}>มีบัญชี WYNOS แล้ว</button>
        <p className="wm-auth-footnote">การสร้างบัญชีถือว่ายอมรับข้อกำหนดการใช้งานและนโยบายความเป็นส่วนตัวของ WYNOS</p>
      </MerchantAuthShell>
    );
  }

  if (application && application.status !== "rejected") {
    const status = statusContent(application);
    return (
      <MerchantAuthShell>
        <div className="wm-auth-top"><BackToMerchant /><MerchantAuthBrand /><span className="wm-auth-top-spacer" /></div>
        <div className={"wm-application-status wm-application-status--" + status.tone}>
          {status.icon}
          <h1>{status.title}</h1>
          <p>{status.detail}</p>
        </div>
        <div className="wm-application-summary">
          <span><small>ชื่อธุรกิจ</small><strong>{application.business_name}</strong></span>
          <span><small>เบอร์ติดต่อ</small><strong>{application.phone}</strong></span>
          <span><small>ส่งคำขอเมื่อ</small><strong>{new Intl.DateTimeFormat("th-TH", { dateStyle: "medium" }).format(new Date(application.created_at))}</strong></span>
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
            {rejected.icon}
            <h1>{rejected.title}</h1>
            <p>{rejected.detail}</p>
          </div>
          <button className="wm-primary wm-full" type="button" onClick={() => setEditingRejected(true)}>แก้ไขและส่งใหม่</button>
        </>
      ) : null}

      {showForm ? (
        <>
          <div className="wm-auth-heading">
            <h1>{application ? "แก้ไขคำขอ Merchant" : "ข้อมูลร้านของคุณ"}</h1>
            <p>ข้อมูลนี้ใช้สำหรับตรวจสอบและเปิดสิทธิ์ WYNOS Merchant</p>
          </div>
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
          <p className="wm-auth-footnote">การส่งคำขอไม่ได้เปิดสิทธิ์ร้านโดยอัตโนมัติ WYNOS จะตรวจสอบก่อนเปิด Merchant Dashboard</p>
        </>
      ) : null}
    </MerchantAuthShell>
  );
}
