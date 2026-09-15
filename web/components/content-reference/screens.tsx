"use client";

import { useRouter } from "next/navigation";
import { useState, type ChangeEvent, type ReactNode } from "react";

import { Avatar, BottomNav, Button, Input, PostCard, WynosIcon } from "@/components/ui";
import { getReferencePost, referencePosts, trendingThailand } from "@/lib/reference-feed";

type ComposeMode = "text" | "poll" | "image";

function ReferencePhone({ children }: { children: ReactNode }) {
  return (
    <main className="content-ref-viewport">
      <div className="phone" id="phone">{children}</div>
    </main>
  );
}

function BackTopbar({ title, onBack, right }: { title?: string; onBack: () => void; right?: ReactNode }) {
  return (
    <div className="topbar">
      <button className="ic-btn" onClick={onBack} aria-label="ย้อนกลับ" type="button"><WynosIcon name="back" size={18} /></button>
      {title ? <span className="t">{title}</span> : <span />}
      {right ?? <span />}
    </div>
  );
}

export function HomeReferenceScreen() {
  const router = useRouter();
  const [liked, setLiked] = useState<Record<string, boolean>>(Object.fromEntries(referencePosts.map((post) => [post.id, post.liked])));

  return (
    <ReferencePhone>
      <div className="home-head">
        <div className="home-head-row">
          <button className="ic-btn" onClick={() => router.push("/settings")} aria-label="การตั้งค่า" type="button"><WynosIcon name="menu" size={21} /></button>
          <div className="brand-lockup"><svg height="22" viewBox="0 0 26 26" width="22" aria-label="Wynos"><path d="M2 4 L8 22 L13 9 L18 22 L24 4" fill="none" stroke="#0A0A0A" strokeLinecap="round" strokeLinejoin="round" strokeWidth="3.4" /></svg><span>Wynos</span></div>
          <div className="home-head-actions"><button className="ic-btn" onClick={() => router.push("/search")} aria-label="ค้นหา" type="button"><WynosIcon name="search" size={21} /></button><button className="ic-btn" onClick={() => router.push("/notifications")} aria-label="การแจ้งเตือน" type="button"><WynosIcon name="notifications" size={21} /></button></div>
        </div>
        <div className="home-tabs"><span className="active">สำหรับคุณ</span><span>กำลังติดตาม</span><span>คลับของฉัน</span></div>
      </div>
      <div className="feed-scroll">
        {referencePosts.map((post) => <PostCard key={post.id} layout="feed" authorName={post.authorName} timeLabel={`· ${post.timeLabel}`} text={post.text} liked={liked[post.id]} likeCount={post.likeCount} commentCount={post.commentCount} repostCount={post.repostCount} onOpen={() => router.push(`/post/${post.id}`)} onLike={() => setLiked((current) => ({ ...current, [post.id]: !current[post.id] }))} onComment={() => router.push(`/post/${post.id}`)} />)}
      </div>
      <BottomNav active="home" className="bottomnav" homeHref="/home" clubsHref="/clubs" postHref="/compose-post" chatHref="/chat" profileHref="/profile/me" />
    </ReferencePhone>
  );
}

export function ComposePostReferenceScreen() {
  const router = useRouter();
  const [mode, setMode] = useState<ComposeMode>("text");
  const [imageName, setImageName] = useState("");
  const toggleMode = (next: Exclude<ComposeMode, "text">) => setMode((current) => (current === next ? "text" : next));
  const onImageChange = (event: ChangeEvent<HTMLInputElement>) => setImageName(event.target.files?.[0]?.name ?? "");

  return (
    <ReferencePhone>
      <div className="topbar"><button className="ic-btn" onClick={() => router.push("/home")} aria-label="ปิด" type="button"><WynosIcon name="close" size={20} /></button><span className="draft-label">ฉบับร่าง</span><button className="compose-submit" onClick={() => router.push("/home")} type="button">โพสต์</button></div>
      <div className="compose-body"><Avatar as="div" alt="รูปโปรไฟล์" className="avatar" size={36} /><div className="compose-editor"><textarea placeholder="มีอะไรจะพูดไหม" />{mode === "poll" ? <div className="compose-mode-panel" data-compose-mode="poll"><Input bare aria-label="ตัวเลือกโพล 1" placeholder="ตัวเลือก 1" /><Input bare aria-label="ตัวเลือกโพล 2" placeholder="ตัวเลือก 2" /></div> : null}{mode === "image" ? <div className="compose-mode-panel" data-compose-mode="image"><label className="image-picker"><span>{imageName || "เลือกรูปภาพ"}</span><input accept="image/*" onChange={onImageChange} type="file" /></label></div> : null}</div></div>
      <div className="compose-toolbar"><div className="compose-tools"><button aria-label="แนบรูป" aria-pressed={mode === "image"} onClick={() => toggleMode("image")} type="button"><WynosIcon name="image" size={21} /></button><button aria-label="สร้างโพล" aria-pressed={mode === "poll"} onClick={() => toggleMode("poll")} type="button"><WynosIcon name="poll" size={21} /></button><button aria-label="ตำแหน่ง" onClick={() => setMode("text")} type="button"><WynosIcon name="location" size={21} /></button></div></div>
    </ReferencePhone>
  );
}

export function SinglePostReferenceScreen({ postId }: { postId: string }) {
  const router = useRouter();
  const post = getReferencePost(postId);
  if (!post) return <ReferencePhone><BackTopbar title="โพสต์" onBack={() => router.push("/home")} /><div className="missing-post">ไม่พบโพสต์นี้</div></ReferencePhone>;
  const profileId = post.username.slice(1).replaceAll("_", "-");

  return (
    <ReferencePhone>
      <BackTopbar title="โพสต์" onBack={() => router.push("/home")} right={<button className="ic-btn" aria-label="ตัวเลือกเพิ่มเติม" type="button"><WynosIcon name="more" size={20} /></button>} />
      <div className="single-scroll">
        <div className="single-post">
          <button className="single-author single-author-link" onClick={() => router.push(post.username === "@ploy_journey" ? "/profile/me" : `/profile/${profileId}`)} type="button"><Avatar as="div" alt={`รูปโปรไฟล์ของ ${post.authorName}`} className="avatar" size={38} /><div className="single-author-copy"><div>{post.authorName}</div><span>{post.username}</span></div></button>
          <p className="single-post-text">{post.detailText}</p>
          <div className="post-actions single-actions"><span className={`action${post.liked ? " liked" : ""}`}><WynosIcon name="like" size={18} />{post.likeCount}</span><span className="action"><WynosIcon name="comment" size={18} />{post.commentCount}</span><span className="action"><WynosIcon name="repost" size={18} />{post.repostCount}</span></div>
        </div>
        {post.comments.map((comment) => <div className="single-comment" key={`${post.id}-${comment.authorName}`}><Avatar as="div" alt={`รูปโปรไฟล์ของ ${comment.authorName}`} className="avatar" size={32} /><div><div className="comment-meta"><b>{comment.authorName}</b> <span>· {comment.timeLabel}</span></div><p>{comment.text}</p></div></div>)}
      </div>
      <div className="comment-composer"><Avatar as="div" alt="รูปโปรไฟล์ของคุณ" className="avatar" size={30} /><div>แสดงความคิดเห็น...</div></div>
    </ReferencePhone>
  );
}

export function NotificationsReferenceScreen() {
  const router = useRouter();
  return <ReferencePhone><BackTopbar title="การแจ้งเตือน" onBack={() => router.push("/home")} /><div className="notification-list"><div className="notification-row unread"><WynosIcon className="notification-kind liked" name="like" size={18} /><Avatar as="div" alt="ต้น สายเทค" className="avatar" size={30} /><div className="notification-copy"><p><b>ต้น สายเทค</b> กดใจโพสต์ของคุณ</p></div><span className="notification-time">2 ชม.</span></div><div className="notification-row"><WynosIcon className="notification-kind" name="userPlus" size={18} /><Avatar as="div" alt="มายด์ กาแฟรัก" className="avatar" size={30} /><div className="notification-copy"><p><b>มายด์ กาแฟรัก</b> เริ่มติดตามคุณ</p></div><Button className="follow-back" variant="outline">ติดตามกลับ</Button></div></div></ReferencePhone>;
}

export function SearchReferenceScreen() {
  const router = useRouter();
  return <ReferencePhone><BackTopbar title="ค้นหา" onBack={() => router.push("/home")} /><div className="search-wrap"><div className="search-box"><WynosIcon name="search" size={16} /><input placeholder="ค้นหาคน, แฮชแท็ก, คลับ" /></div></div><div className="trends-wrap"><div className="trends-title">กำลังมาแรงในไทย</div><div className="trend-list" aria-label="กำลังมาแรงในไทย">{trendingThailand.map((trend, index) => <div className="trend-row" key={trend}><span className={index === 0 ? "rank rank-first" : "rank"}>{index + 1}</span><span className="trend-name">{trend}</span></div>)}</div></div></ReferencePhone>;
}
