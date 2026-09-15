"use client";

import { useRouter } from "next/navigation";
import { useRef, useState, type ReactNode } from "react";

import { Avatar, BottomNav, Button, Input, WynosIcon } from "@/components/ui";
import { useCreateClubDraft } from "@/components/content-reference/club-create-context";

type ClubTab = "feed" | "chat" | "members";

function ClubReferencePhone({ children }: { children: ReactNode }) {
  return <main className="content-ref-viewport"><div className="phone" id="phone">{children}</div></main>;
}

export function ClubsListReferenceScreen() {
  const router = useRouter();
  return (
    <ClubReferencePhone>
      <div className="topbar"><span className="t">คลับ</span><button className="ic-btn" onClick={() => router.push("/clubs/new")} aria-label="สร้างคลับ" type="button"><WynosIcon name="post" size={20} /></button></div>
      <div className="club-list-scroll">
        <div className="club-section-title">คลับของฉัน</div>
        <button className="club-list-row" onClick={() => router.push("/club/wynos-community")} type="button">
          <span className="club-icon club-list-icon"><WynosIcon name="coffee" size={20} /></span>
          <span className="club-list-copy"><span className="club-list-name">คลับคนรักกาแฟ</span><span className="club-list-count">3.1K สมาชิก</span></span>
        </button>
      </div>
      <BottomNav active="clubs" className="bottomnav" homeHref="/home" clubsHref="/clubs" postHref="/compose-post" chatHref="/chat" profileHref="/profile/me" />
    </ClubReferencePhone>
  );
}

function ClubVoiceOverlay({ onClose }: { onClose: () => void }) {
  return (
    <div className="club-voice-overlay" role="dialog" aria-modal="true" aria-label="ห้องพูดคุย">
      <div className="club-voice-modal">
        <div className="topbar">
          <button className="ic-btn" onClick={onClose} aria-label="ปิดห้องเสียง" type="button"><WynosIcon name="chevronDown" size={18} /></button>
          <div className="club-voice-title"><div>🔊 ห้องพูดคุย</div><span>● กำลังใช้งาน · 6 คน</span></div><span />
        </div>
        <div className="club-voice-grid">
          <div className="club-voice-person"><Avatar as="div" alt="มายด์" className="avatar club-speaking-avatar" size={56} /><div className="club-voice-name strong">มายด์</div></div>
          <div className="club-voice-person"><Avatar as="div" alt="ต้น" className="avatar" size={56} /><div className="club-voice-name">ต้น</div></div>
          <div className="club-voice-person"><Avatar as="div" alt="คุณ" className="avatar" size={56} /><div className="club-voice-name">คุณ</div></div>
        </div>
        <div className="club-voice-controls">
          <button className="club-voice-control" aria-label="ไมโครโฟน" type="button"><WynosIcon name="mic" size={21} /></button>
          <button className="club-voice-control club-voice-leave" onClick={onClose} aria-label="ออกจากห้องเสียง" type="button"><WynosIcon name="hangup" size={21} /></button>
        </div>
      </div>
    </div>
  );
}

export function ClubDetailReferenceScreen() {
  const router = useRouter();
  const [tab, setTab] = useState<ClubTab>("feed");
  const [voiceOpen, setVoiceOpen] = useState(false);

  return (
    <ClubReferencePhone>
      <div className="topbar"><button className="ic-btn" onClick={() => router.push("/clubs")} aria-label="ย้อนกลับ" type="button"><WynosIcon name="back" size={18} /></button><span className="t">WYNOS Community</span><button className="ic-btn" onClick={() => router.push("/club/wynos-community/invite")} aria-label="เชิญเข้าคลับ" type="button"><WynosIcon name="more" size={20} /></button></div>
      <div className="club-cover" />
      <div className="club-detail-summary"><div>WYNOS Community</div><span>12.8K สมาชิก</span></div>
      <div className="club-tabs" role="tablist" aria-label="คลับ">
        <button className={`club-tab${tab === "feed" ? " active" : ""}`} onClick={() => setTab("feed")} role="tab" aria-selected={tab === "feed"} type="button">ฟีด</button>
        <button className={`club-tab${tab === "chat" ? " active" : ""}`} onClick={() => setTab("chat")} role="tab" aria-selected={tab === "chat"} type="button">แชท</button>
        <button className={`club-tab${tab === "members" ? " active" : ""}`} onClick={() => setTab("members")} role="tab" aria-selected={tab === "members"} type="button">สมาชิก</button>
      </div>
      <div className="club-detail-scroll" data-club-tab={tab}>
        {tab === "feed" ? <div id="clubFeed"><div className="club-post"><Avatar as="div" alt="มายด์ กาแฟรัก" className="avatar" size={36} /><div className="club-post-body"><div className="club-post-meta"><b>มายด์ กาแฟรัก</b> <span>· 2 ชม.</span></div><p>ยินดีต้อนรับสมาชิกใหม่ทุกคนครับ 👋</p></div></div><button className="club-compose-fab" onClick={() => router.push("/compose-post")} aria-label="สร้างโพสต์" type="button"><WynosIcon name="post" size={22} /></button></div> : null}
        {tab === "chat" ? <div id="clubChat"><div className="club-chat-heading">ทั่วไป</div><div className="club-channel-row"><span>#</span><b>ทั่วไป</b></div><div className="club-channel-row"><span>#</span><b>แนะนำตัว</b></div><div className="club-chat-heading club-chat-heading-spaced">พูดคุย</div><button className="club-channel-row club-voice-row" onClick={() => setVoiceOpen(true)} type="button"><WynosIcon name="voice" size={15} /><b>ห้องพูดคุย</b><span className="club-live-count">● 6 คนกำลังคุย</span></button></div> : null}
        {tab === "members" ? <div id="clubMembers"><div className="club-members-title">สมาชิก 12,842</div><div className="club-member-row"><Avatar as="div" alt="มายด์ กาแฟรัก" className="avatar" size={30} /><b>มายด์ กาแฟรัก</b></div><div className="club-member-row"><Avatar as="div" alt="ต้น สายเทค" className="avatar" size={30} /><b>ต้น สายเทค</b></div></div> : null}
      </div>
      {voiceOpen ? <ClubVoiceOverlay onClose={() => setVoiceOpen(false)} /> : null}
    </ClubReferencePhone>
  );
}

export function InviteClubReferenceScreen() {
  const router = useRouter();
  return (
    <ClubReferencePhone>
      <div className="topbar"><button className="ic-btn" onClick={() => router.push("/club/wynos-community")} aria-label="ปิด" type="button"><WynosIcon name="close" size={19} /></button><span className="t">เชิญเข้าคลับ</span><span /></div>
      <div className="club-invite-body"><div className="club-invite-name">คลับคนรักกาแฟ</div><div className="club-qr"><WynosIcon name="qr" size={80} /></div><div className="club-invite-link"><span>wynos.app/invite/coffeeclub</span><b>คัดลอก</b></div></div>
    </ClubReferencePhone>
  );
}

export function CreateClubReferenceScreen() {
  const router = useRouter();
  const { draft, setDraft } = useCreateClubDraft();
  const fieldsRef = useRef<HTMLDivElement>(null);
  const goNext = () => {
    const name = fieldsRef.current?.querySelector<HTMLInputElement>('input[name="clubName"]')?.value ?? draft.name;
    const description = fieldsRef.current?.querySelector<HTMLTextAreaElement>('textarea[name="clubDescription"]')?.value ?? draft.description;
    setDraft({ name, description });
    router.push("/clubs/new/invite");
  };

  return (
    <ClubReferencePhone>
      <div className="topbar"><button className="ic-btn" onClick={() => router.push("/clubs")} aria-label="ปิด" type="button"><WynosIcon name="close" size={19} /></button><span className="t">สร้างคลับ</span><button className="club-text-action" onClick={goNext} type="button">ถัดไป</button></div>
      <div className="club-create-scroll"><div className="club-create-cover" /><div className="club-create-fields" ref={fieldsRef}><div className="field"><label htmlFor="clubName">ชื่อคลับ</label><Input bare id="clubName" name="clubName" placeholder="เช่น คลับคนรักกาแฟ" value={draft.name} onChange={(event) => setDraft((current) => ({ ...current, name: event.target.value }))} /></div><div className="field"><label htmlFor="clubDescription">คำอธิบาย</label><textarea id="clubDescription" name="clubDescription" placeholder="คลับนี้เกี่ยวกับอะไร" value={draft.description} onChange={(event) => setDraft((current) => ({ ...current, description: event.target.value }))} /></div></div></div>
    </ClubReferencePhone>
  );
}

export function CreateClubInviteReferenceScreen() {
  const router = useRouter();
  const { draft } = useCreateClubDraft();
  const clubName = draft.name.trim() || "คลับคนรักกาแฟ";
  return (
    <ClubReferencePhone>
      <div className="topbar"><button className="ic-btn" onClick={() => router.push("/clubs/new")} aria-label="ย้อนกลับ" type="button"><WynosIcon name="back" size={18} /></button><span className="t">เชิญสมาชิก</span><button className="club-text-action" onClick={() => router.push("/clubs")} type="button">เสร็จสิ้น</button></div>
      <div className="club-created-summary"><div>{clubName} พร้อมแล้ว!</div><p>ชวนเพื่อนเข้ามาคุยกันได้เลย</p></div>
      <div className="club-created-list"><div className="club-created-row"><Avatar as="div" alt="ต้น สายเทค" className="avatar" size={38} /><span>ต้น สายเทค</span><Button className="club-invite-button" variant="outline">เชิญ</Button></div></div>
    </ClubReferencePhone>
  );
}
