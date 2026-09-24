"use client";

import { motion } from "framer-motion";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";

import { Avatar } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import type { HomeIdentity } from "@/lib/home-parity-data";

type DrawerPanel = "feedback" | "help" | null;

/** The mobile root drawer: swipe left, tap the backdrop or press Escape to
 * dismiss. The four original destinations keep their existing routes. */
export function HomeDrawer({ identity, onClose }: { identity: HomeIdentity | null; onClose: () => void }) {
  const router = useRouter();
  const [panel, setPanel] = useState<DrawerPanel>(null);
  const [feedback, setFeedback] = useState("");
  const [feedbackMessage, setFeedbackMessage] = useState("");
  const panelBackRef = useRef<HTMLButtonElement>(null);
  const touchStart = useRef<{ x: number; y: number } | null>(null);
  const displayName = identity?.display_name?.trim() || identity?.username || "WYNOS";

  useEffect(() => {
    const originalOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== "Escape") return;
      event.preventDefault();
      if (panel) setPanel(null);
      else onClose();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => {
      document.body.style.overflow = originalOverflow;
      window.removeEventListener("keydown", onKeyDown);
    };
  }, [onClose, panel]);

  useEffect(() => {
    if (panel) panelBackRef.current?.focus();
  }, [panel]);

  const go = (href: string) => {
    onClose();
    router.push(href);
  };

  const copyFeedback = async () => {
    if (!feedback.trim()) return;
    try {
      await navigator.clipboard.writeText(feedback.trim());
      setFeedbackMessage("คัดลอกแล้ว สามารถนำข้อความไปส่งผ่านช่องทางที่คุณสะดวก");
    } catch {
      setFeedbackMessage("คัดลอกอัตโนมัติไม่ได้ กรุณาเลือกและคัดลอกข้อความด้านบน");
    }
  };

  const shareFeedback = async () => {
    if (!feedback.trim()) return;
    if (!navigator.share) {
      await copyFeedback();
      return;
    }
    try {
      await navigator.share({ title: "ข้อเสนอแนะ WYNOS", text: feedback.trim() });
      setFeedbackMessage("เปิดตัวเลือกแชร์เรียบร้อยแล้ว");
    } catch (error) {
      if (error instanceof Error && error.name === "AbortError") return;
      setFeedbackMessage("เปิดการแชร์ไม่ได้ ลองคัดลอกข้อความแทน");
    }
  };

  return (
    <motion.div
      className="home-drawer-backdrop wynos-drawer-backdrop"
      role="presentation"
      onClick={onClose}
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.18 }}
    >
      <motion.aside
        className="home-drawer wynos-drawer-v2"
        role="dialog"
        aria-modal="true"
        aria-label="เมนู WYNOS"
        onClick={(event) => event.stopPropagation()}
        onTouchStart={(event) => {
          const touch = event.touches[0];
          if (!touch) return;
          touchStart.current = { x: touch.clientX, y: touch.clientY };
        }}
        onTouchEnd={(event) => {
          const origin = touchStart.current;
          touchStart.current = null;
          const touch = event.changedTouches[0];
          if (!origin || !touch || panel) return;
          if (origin.x - touch.clientX > 90 && Math.abs(origin.y - touch.clientY) < 55) onClose();
        }}
        initial={{ x: "-100%" }}
        animate={{ x: 0 }}
        exit={{ x: "-100%" }}
        transition={{ duration: 0.22, ease: "easeOut" }}
      >
        <div className="wynos-drawer-main">
          <button
            className="drawer-identity"
            type="button"
            disabled={!identity}
            onClick={() => identity && go("/profile/" + identity.id)}
          >
            <Avatar src={identity?.avatar_url} label={identity?.username || "W"} size={58} />
            <span className="drawer-identity-copy">
              <span className="wynos-drawer-name">
                <strong>{displayName}</strong>
                {identity?.is_verified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}
              </span>
              {identity ? <small>@{identity.username}</small> : null}
              <span className="wynos-drawer-stats">
                <b>{identity?.follower_count ?? 0}</b> ผู้ติดตาม
                <span aria-hidden="true">·</span>
                <b>{identity?.following_count ?? 0}</b> กำลังติดตาม
              </span>
            </span>
            <WynosIcon name="chevronRight" size={20} strokeWidth={2} />
          </button>

          <nav className="drawer-menu-list" aria-label="เมนูหลัก">
            <button className="drawer-menu-row" type="button" onClick={() => go("/clubs")}>
              <span className="drawer-menu-icon"><WynosIcon name="compass" size={22} strokeWidth={1.85} /></span>
              <span>สำรวจ Club</span>
              <WynosIcon name="chevronRight" size={20} strokeWidth={1.9} />
            </button>
            <button className="drawer-menu-row" type="button" onClick={() => go("/clubs/new")}>
              <span className="drawer-menu-icon"><WynosIcon name="post" size={23} strokeWidth={1.8} /></span>
              <span>สร้าง Club</span>
              <WynosIcon name="chevronRight" size={20} strokeWidth={1.9} />
            </button>
            <button className="drawer-menu-row" type="button" onClick={() => go("/clubs?mine=1")}>
              <span className="drawer-menu-icon"><WynosIcon name="club" size={22} strokeWidth={1.85} /></span>
              <span>Club ของฉัน</span>
              <WynosIcon name="chevronRight" size={20} strokeWidth={1.9} />
            </button>
            <button className="drawer-menu-row" type="button" onClick={() => go("/bookmarks")}>
              <span className="drawer-menu-icon"><WynosIcon name="bookmark" size={22} strokeWidth={1.85} /></span>
              <span>บันทึกไว้</span>
              <WynosIcon name="chevronRight" size={20} strokeWidth={1.9} />
            </button>
          </nav>
        </div>

        <footer className="wynos-drawer-footer" aria-label="ติดต่อและการช่วยเหลือ">
          <button type="button" className="wynos-drawer-footer-button" onClick={() => { setFeedbackMessage(""); setPanel("feedback"); }}>
            <WynosIcon name="chat" size={19} strokeWidth={1.9} />
            <span>ข้อเสนอแนะ</span>
          </button>
          <button type="button" className="wynos-drawer-footer-button" onClick={() => setPanel("help")}>
            <WynosIcon name="circleHelp" size={19} strokeWidth={1.9} />
            <span>การช่วยเหลือ</span>
          </button>
        </footer>

        {panel ? (
          <section className="wynos-drawer-panel" aria-label={panel === "help" ? "การช่วยเหลือ" : "ข้อเสนอแนะ"}>
            <header className="wynos-drawer-panel-header">
              <button ref={panelBackRef} type="button" onClick={() => setPanel(null)} aria-label="กลับไปเมนู">
                <WynosIcon name="back" size={23} />
              </button>
              <strong>{panel === "help" ? "การช่วยเหลือ" : "ข้อเสนอแนะ"}</strong>
            </header>
            {panel === "help" ? (
              <div className="wynos-drawer-panel-content">
                <h2>คำถามที่พบบ่อย</h2>
                <div className="wynos-drawer-help-item">
                  <strong>WYNOS คืออะไร?</strong>
                  <p>พื้นที่สำหรับโพสต์ แชร์เรื่องราว และสร้าง Club เพื่อเชื่อมต่อกับผู้คนที่สนใจสิ่งเดียวกัน</p>
                </div>
                <div className="wynos-drawer-help-item">
                  <strong>เพิ่ม WYNOS ไปที่หน้าจอหลักได้อย่างไร?</strong>
                  <p>เปิดคำแนะนำการติดตั้งเพื่อใช้งาน WYNOS ได้สะดวกเหมือนแอป</p>
                  <button type="button" onClick={() => window.open("/add-to-home.html", "_blank", "noopener,noreferrer")}>ดูวิธีเพิ่มที่หน้าจอหลัก</button>
                </div>
                <div className="wynos-drawer-help-item">
                  <strong>ข้อกำหนดและความเป็นส่วนตัวอยู่ที่ไหน?</strong>
                  <p>ดูได้ในหน้าการตั้งค่าบัญชีของคุณ</p>
                  <button type="button" onClick={() => go("/settings")}>ไปที่การตั้งค่า</button>
                </div>
              </div>
            ) : (
              <div className="wynos-drawer-panel-content">
                <h2>แบ่งปันความคิดเห็นของคุณ</h2>
                <p>บอกสิ่งที่อยากให้ WYNOS ปรับปรุง แล้วแชร์ผ่านแอปที่คุณเลือกหรือคัดลอกข้อความได้</p>
                <label htmlFor="wynos-drawer-feedback">ข้อความ</label>
                <textarea
                  id="wynos-drawer-feedback"
                  value={feedback}
                  onChange={(event) => { setFeedback(event.target.value); setFeedbackMessage(""); }}
                  placeholder="อยากให้ WYNOS เพิ่มหรือปรับปรุงอะไร..."
                  maxLength={1000}
                  rows={6}
                />
                <div className="wynos-drawer-feedback-actions">
                  <button type="button" disabled={!feedback.trim()} onClick={() => void copyFeedback()}>คัดลอก</button>
                  <button type="button" disabled={!feedback.trim()} onClick={() => void shareFeedback()}>แชร์ข้อเสนอแนะ</button>
                </div>
                {feedbackMessage ? <p className="wynos-drawer-feedback-status" role="status">{feedbackMessage}</p> : null}
              </div>
            )}
          </section>
        ) : null}
      </motion.aside>
    </motion.div>
  );
}
