"use client";

import {
  Bell,
  Heart,
  Home,
  Menu,
  MessageCircle,
  MoreHorizontal,
  Plus,
  Repeat2,
  Search,
  UserRound,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { Session } from "@supabase/supabase-js";

import { authorLabel, rankedDropRows, relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import { getSupabaseBrowserClient, hasSupabaseBrowserConfig } from "@/lib/supabase/browser";

type GateState = "loading" | "missing-config" | "signed-out" | "regular" | "developer" | "error";

function Caption({ value }: { value: string }) {
  const parts = value.split(/(#[\p{L}\p{N}_]+)/gu);
  return (
    <p className="caption">
      {parts.map((part, index) =>
        part.startsWith("#") ? (
          <span className="hashtag" key={`${part}-${index}`}>
            {part}
          </span>
        ) : (
          part
        ),
      )}
    </p>
  );
}

function Avatar({ row }: { row: HomeFeedRow }) {
  const [failed, setFailed] = useState(false);
  const label = authorLabel(row);
  if (!row.author_avatar_url || failed) {
    return <div className="avatar avatar-fallback">{label.slice(0, 1).toUpperCase()}</div>;
  }
  return (
    // Browser-native <img> is intentional: no Flutter CanvasKit decode/texture path.
    // eslint-disable-next-line @next/next/no-img-element
    <img
      className="avatar"
      src={row.author_avatar_url}
      alt=""
      width={42}
      height={42}
      loading="lazy"
      decoding="async"
      onError={() => setFailed(true)}
    />
  );
}

function FeedPost({ row }: { row: HomeFeedRow }) {
  return (
    <article className="post">
      <Avatar row={row} />
      <div className="post-main">
        {row.redrop_id && row.redropper_username ? (
          <p className="redrop-label">รีโพสต์โดย @{row.redropper_username}</p>
        ) : null}
        <div className="post-header">
          <span className="author">{authorLabel(row)}</span>
          {row.author_is_verified ? <span className="verified" aria-label="บัญชีที่ยืนยันแล้ว">●</span> : null}
          <span className="timestamp">{relativeTimeTh(row.created_at)}</span>
          <button className="icon-button more-button" type="button" aria-label="ตัวเลือกเพิ่มเติม">
            <MoreHorizontal size={20} strokeWidth={1.8} />
          </button>
        </div>
        {row.quote_text ? <Caption value={row.quote_text} /> : null}
        {row.caption ? <Caption value={row.caption} /> : null}
        {row.image_url ? (
          // Native browser image rendering is part of the migration goal.
          // eslint-disable-next-line @next/next/no-img-element
          <img
            className="post-media"
            src={row.image_url}
            alt=""
            loading="lazy"
            decoding="async"
          />
        ) : null}
        <div className="action-row" aria-label="กิจกรรมโพสต์">
          <span className="metric"><Heart aria-hidden="true" strokeWidth={1.75} />{row.like_count ? <span>{row.like_count}</span> : null}</span>
          <span className="metric"><MessageCircle aria-hidden="true" strokeWidth={1.75} />{row.comment_count ? <span>{row.comment_count}</span> : null}</span>
          <span className="metric"><Repeat2 aria-hidden="true" strokeWidth={1.75} />{row.redrop_count ? <span>{row.redrop_count}</span> : null}</span>
          <span className="metric metric-more"><MoreHorizontal aria-hidden="true" strokeWidth={1.75} /></span>
        </div>
      </div>
    </article>
  );
}

function SignedOut({ onGoogle }: { onGoogle: () => Promise<void> }) {
  return (
    <main className="center-state">
      <h1>WYNOS</h1>
      <p>Next.js Web รุ่นทดสอบภายใน ใช้ Supabase เดิมและฟอนต์ระบบของอุปกรณ์ผ่าน browser โดยตรง</p>
      <button className="primary-button" type="button" onClick={() => void onGoogle()}>
        เข้าสู่ระบบด้วย Google
      </button>
    </main>
  );
}

export function HomeMigrationPreview() {
  const [gate, setGate] = useState<GateState>("loading");
  const [session, setSession] = useState<Session | null>(null);
  const [rows, setRows] = useState<HomeFeedRow[]>([]);
  const [message, setMessage] = useState<string>("");
  const [activeTab, setActiveTab] = useState("สำหรับคุณ");
  const [activeMode, setActiveMode] = useState("ทั้งหมด");

  const supabase = useMemo(() => getSupabaseBrowserClient(), []);

  const loadDeveloperPreview = useCallback(async (nextSession: Session | null) => {
    setSession(nextSession);
    setRows([]);
    setMessage("");

    if (!hasSupabaseBrowserConfig() || !supabase) {
      setGate("missing-config");
      return;
    }
    if (!nextSession) {
      setGate("signed-out");
      return;
    }

    setGate("loading");
    const developerResult = await supabase.rpc("is_developer_account");
    if (developerResult.error || developerResult.data !== true) {
      setGate("regular");
      return;
    }

    const feedResult = await supabase.rpc("get_wynos_ranked_feed");
    if (feedResult.error) {
      setMessage("โหลดฟีดไม่สำเร็จ กรุณาลองใหม่");
      setGate("error");
      return;
    }

    setRows(rankedDropRows(feedResult.data));
    setGate("developer");
  }, [supabase]);

  useEffect(() => {
    if (!supabase) {
      setGate("missing-config");
      return;
    }

    let mounted = true;
    void supabase.auth.getSession().then(({ data }) => {
      if (mounted) void loadDeveloperPreview(data.session);
    });

    const { data: authSubscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      if (mounted) void loadDeveloperPreview(nextSession);
    });

    return () => {
      mounted = false;
      authSubscription.subscription.unsubscribe();
    };
  }, [loadDeveloperPreview, supabase]);

  const signInWithGoogle = useCallback(async () => {
    if (!supabase) return;
    const redirectTo = `${window.location.origin}/`;
    const { error } = await supabase.auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo },
    });
    if (error) {
      setMessage("เริ่มเข้าสู่ระบบไม่สำเร็จ");
      setGate("error");
    }
  }, [supabase]);

  const signOut = useCallback(async () => {
    if (!supabase) return;
    await supabase.auth.signOut();
  }, [supabase]);

  if (gate === "loading") {
    return <main className="center-state"><h1>WYNOS</h1><p>กำลังเปิด Web รุ่นใหม่…</p></main>;
  }

  if (gate === "missing-config") {
    return <main className="center-state"><h1>WYNOS</h1><p>Preview นี้ยังไม่ได้ตั้งค่า Supabase environment variables</p></main>;
  }

  if (gate === "signed-out") return <SignedOut onGoogle={signInWithGoogle} />;

  if (gate === "regular") {
    return (
      <main className="center-state">
        <h1>WYNOS</h1>
        <p>Web รุ่นใหม่นี้ยังเปิดเฉพาะบัญชีนักพัฒนาตาม staged rollout ผู้ใช้ทั่วไปยังใช้ WYNOS เวอร์ชันปัจจุบันเหมือนเดิม</p>
        <button className="secondary-button" type="button" onClick={() => void signOut()}>ออกจากระบบ</button>
      </main>
    );
  }

  if (gate === "error") {
    return (
      <main className="center-state">
        <h1>WYNOS</h1>
        <p>{message || "เกิดข้อผิดพลาด"}</p>
        <button className="primary-button" type="button" onClick={() => void loadDeveloperPreview(session)}>ลองใหม่</button>
      </main>
    );
  }

  return (
    <div className="wynos-app">
      <main className="wynos-main">
        <header className="top-shell">
          <div className="wordmark-row">
            <h1 className="wordmark">WYNOS</h1>
            <div className="icon-row">
              <button className="icon-button" type="button" aria-label="ค้นหา"><Search size={25} strokeWidth={1.8} /></button>
              <button className="icon-button" type="button" aria-label="เมนู"><Menu size={27} strokeWidth={1.8} /></button>
            </div>
          </div>
          <div className="primary-tabs" role="tablist" aria-label="ฟีด">
            {["สำหรับคุณ", "กำลังติดตาม"].map((tab) => (
              <button
                className={`primary-tab ${activeTab === tab ? "active" : ""}`}
                type="button"
                role="tab"
                aria-selected={activeTab === tab}
                onClick={() => setActiveTab(tab)}
                key={tab}
              >
                {tab}
              </button>
            ))}
          </div>
          <div className="mode-strip" aria-label="ประเภทฟีด">
            {["ทั้งหมด", "Drop", "กำลังนิยม"].map((mode) => (
              <button
                className={`mode-pill ${activeMode === mode ? "active" : ""}`}
                type="button"
                aria-pressed={activeMode === mode}
                onClick={() => setActiveMode(mode)}
                key={mode}
              >
                {mode}
              </button>
            ))}
          </div>
        </header>

        {activeTab !== "สำหรับคุณ" || activeMode !== "ทั้งหมด" ? (
          <p className="status-note">Phase 1 ย้ายฟีด “สำหรับคุณ / ทั้งหมด” ก่อน โดยยังไม่เปลี่ยน behavior ของ Production เดิม</p>
        ) : rows.length ? (
          rows.map((row) => <FeedPost row={row} key={`${row.id}:${row.redrop_id ?? "plain"}`} />)
        ) : (
          <p className="status-note">ยังไม่มีโพสต์ที่แสดงได้ในฟีดนี้</p>
        )}
      </main>

      <nav className="bottom-nav" aria-label="เมนูหลัก">
        <button className="nav-button active" type="button" aria-label="หน้าหลัก"><Home size={25} strokeWidth={1.9} /></button>
        <button className="nav-button" type="button" aria-label="ค้นหา"><Search size={25} strokeWidth={1.8} /></button>
        <button className="nav-button" type="button" aria-label="สร้างโพสต์"><span className="create-button"><Plus size={24} strokeWidth={2} /></span></button>
        <button className="nav-button" type="button" aria-label="การแจ้งเตือน"><Bell size={25} strokeWidth={1.8} /></button>
        <button className="nav-button" type="button" aria-label="โปรไฟล์"><UserRound size={25} strokeWidth={1.8} /></button>
      </nav>
    </div>
  );
}
