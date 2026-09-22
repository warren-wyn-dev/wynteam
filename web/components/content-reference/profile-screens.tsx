"use client";

import { useRouter } from "next/navigation";
import { useState, type ReactNode } from "react";

import { Avatar, BottomNav, Button, Input, WynosIcon } from "@/components/ui";
import {
  currentReferenceUser,
  mindReferenceUser,
  referenceFollowers,
  referenceFollowing,
  type ReferenceProfile,
} from "@/lib/reference-profile";

type FollowersTab = "following" | "followers";

function ReferencePhone({ children }: { children: ReactNode }) {
  return (
    <main className="content-ref-viewport">
      <div className="phone" id="phone">{children}</div>
    </main>
  );
}

function BackTopbar({ title, onBack, right }: { title: string; onBack: () => void; right?: ReactNode }) {
  return (
    <div className="topbar">
      <button className="ic-btn" onClick={onBack} aria-label="ย้อนกลับ" type="button">
        <WynosIcon name="back" size={18} />
      </button>
      <span className="t">{title}</span>
      {right ?? <span />}
    </div>
  );
}

export function ProfileHeader({
  profile,
  isOwnProfile,
  onEdit,
  onShare,
  onMessage,
  onFollowing,
  onFollowers,
}: {
  profile: ReferenceProfile;
  isOwnProfile: boolean;
  onEdit?: () => void;
  onShare?: () => void;
  onMessage?: () => void;
  onFollowing: () => void;
  onFollowers: () => void;
}) {
  const [isFollowing, setIsFollowing] = useState(false);

  return (
    <div className="profile-header" data-profile-header data-own-profile={isOwnProfile ? "true" : "false"}>
      <div className="profile-intro">
        <Avatar as="div" alt={`รูปโปรไฟล์ของ ${profile.displayName}`} className="avatar" size={64} />
        <div className="profile-copy">
          <div className="profile-name">{profile.displayName}</div>
          <p className="profile-bio">{profile.bio}</p>
          {profile.website ? (
            <div className="profile-link-row">
              <WynosIcon name="link" size={14} />
              <span>{profile.website}</span>
            </div>
          ) : null}
        </div>
      </div>

      <div className="profile-stats">
        <button className="profile-stat" onClick={onFollowing} type="button">
          <b>{profile.followingCount}</b> <span>กำลังติดตาม</span>
        </button>
        <button className="profile-stat" onClick={onFollowers} type="button">
          <b>{profile.followerCount}</b> <span>ผู้ติดตาม</span>
        </button>
      </div>

      <div className="profile-actions">
        {isOwnProfile ? (
          <>
            <Button className="profile-action-primary" onClick={onEdit}>แก้ไขโปรไฟล์</Button>
            <Button className="profile-action-secondary" onClick={onShare} variant="outline">แชร์โปรไฟล์</Button>
          </>
        ) : (
          <>
            <Button
              className={isFollowing ? "profile-action-secondary" : "profile-action-primary"}
              onClick={() => setIsFollowing((value) => !value)}
              variant={isFollowing ? "outline" : "primary"}
            >
              {isFollowing ? "กำลังติดตาม" : "ติดตาม"}
            </Button>
            <Button className="profile-action-secondary" onClick={onMessage} variant="outline">ส่งข้อความ</Button>
          </>
        )}
      </div>
    </div>
  );
}

function ProfileTabs() {
  return <div className="profile-tabs"><span className="active">โพสต์</span><span>รีโพสต์</span><span>ถูกใจ</span></div>;
}

function ProfilePost({ authorName, timeLabel, text, onOpen, likeCount }: { authorName: string; timeLabel: string; text: string; onOpen?: () => void; likeCount?: number }) {
  return (
    <button className="profile-post" onClick={onOpen} type="button">
      <Avatar as="div" alt={`รูปโปรไฟล์ของ ${authorName}`} className="avatar" size={36} />
      <div className="profile-post-body">
        <div className="profile-post-meta"><span>{authorName}</span><span> · {timeLabel}</span></div>
        <p>{text}</p>
        {likeCount !== undefined ? <div className="profile-post-actions"><span><WynosIcon name="like" size={18} />{likeCount}</span></div> : null}
      </div>
    </button>
  );
}

export function OwnProfileReferenceScreen() {
  const router = useRouter();
  const profile = currentReferenceUser;
  return (
    <ReferencePhone>
      <BackTopbar
        title={`@${profile.username}`}
        onBack={() => router.push("/home")}
        right={<button className="ic-btn" onClick={() => router.push("/settings")} aria-label="ตั้งค่า" type="button"><WynosIcon name="more" size={20} /></button>}
      />
      <div className="profile-scroll">
        <ProfileHeader
          profile={profile}
          isOwnProfile
          onEdit={() => router.push("/profile/edit")}
          onShare={() => undefined}
          onFollowing={() => router.push("/followers?tab=following")}
          onFollowers={() => router.push("/followers?tab=followers")}
        />
        <ProfileTabs />
        <ProfilePost authorName={profile.displayName} timeLabel="2 ชม." text="เพิ่งลองร้านกาแฟใหม่แถวบ้าน รสชาติดีเกินคาด" likeCount={48} onOpen={() => router.push("/post/ploy-profile-001")} />
      </div>
      <BottomNav active="profile" className="bottomnav" homeHref="/home" clubsHref="/clubs" postHref="/compose-post" chatHref="/chat" profileHref="/profile/me" />
    </ReferencePhone>
  );
}

export function OtherProfileReferenceScreen() {
  const router = useRouter();
  const profile = mindReferenceUser;
  return (
    <ReferencePhone>
      <BackTopbar title={`@${profile.username}`} onBack={() => router.push("/home")} right={<button className="ic-btn" aria-label="ตัวเลือกเพิ่มเติม" type="button"><WynosIcon name="more" size={20} /></button>} />
      <div className="profile-scroll">
        <ProfileHeader
          profile={profile}
          isOwnProfile={false}
          onMessage={() => router.push("/chat")}
          onFollowing={() => router.push("/followers?tab=following")}
          onFollowers={() => router.push("/followers?tab=followers")}
        />
        <ProfileTabs />
        <ProfilePost authorName={profile.displayName} timeLabel="1 วัน" text="ร้านนี้บรรยากาศดีมาก เหมาะนั่งทำงาน" onOpen={() => router.push("/post/mind-profile-001")} />
      </div>
    </ReferencePhone>
  );
}

export function EditProfileReferenceScreen() {
  const router = useRouter();
  const user = currentReferenceUser;
  const [displayName, setDisplayName] = useState(user.displayName);
  const [username, setUsername] = useState(user.username);
  const [bio, setBio] = useState(user.bio);
  const [website, setWebsite] = useState(user.website ?? "");

  return (
    <ReferencePhone>
      <BackTopbar
        title="แก้ไขโปรไฟล์"
        onBack={() => router.push("/profile/me")}
        right={<button className="edit-save" onClick={() => router.push("/profile/me")} type="button">บันทึก</button>}
      />
      <div className="edit-profile-body">
        <div className="edit-avatar"><Avatar as="div" alt="รูปโปรไฟล์ของคุณ" className="avatar" size={80} /></div>
        <div className="field"><label htmlFor="edit-display-name">ชื่อที่แสดง</label><Input bare id="edit-display-name" value={displayName} onChange={(event) => setDisplayName(event.target.value)} /></div>
        <div className="field"><label htmlFor="edit-username">ชื่อผู้ใช้</label><Input bare id="edit-username" value={username} onChange={(event) => setUsername(event.target.value)} /></div>
        <div className="field"><label htmlFor="edit-bio">แนะนำตัว</label><textarea id="edit-bio" value={bio} onChange={(event) => setBio(event.target.value)} /></div>
        <div className="field"><label htmlFor="edit-website">ลิงก์เว็บไซต์</label><Input bare id="edit-website" value={website} onChange={(event) => setWebsite(event.target.value)} /></div>
      </div>
    </ReferencePhone>
  );
}

export function SettingsReferenceScreen() {
  const router = useRouter();
  return (
    <ReferencePhone>
      <BackTopbar title="ตั้งค่า" onBack={() => router.push("/profile/me")} />
      <div className="settings-scroll">
        <div className="settings-section">บัญชี</div>
        <button className="settings-row" onClick={() => router.push("/profile/edit")} type="button">แก้ไขโปรไฟล์</button>
        <div className="settings-row">เปลี่ยนรหัสผ่าน</div>
        <div className="settings-section settings-section-spaced">ความเป็นส่วนตัว</div>
        <div className="settings-row">บัญชีส่วนตัว</div>
        <div className="settings-section settings-section-spaced">อื่นๆ</div>
        <button className="settings-row settings-logout" onClick={() => router.push("/welcome")} type="button">ออกจากระบบ</button>
      </div>
    </ReferencePhone>
  );
}

function RelationRow({ displayName, username, actionLabel }: { displayName: string; username: string; actionLabel: string }) {
  return (
    <div className="relation-row">
      <Avatar as="div" alt={`รูปโปรไฟล์ของ ${displayName}`} className="avatar" size={40} />
      <div className="relation-copy"><div>{displayName}</div><span>{username}</span></div>
      <Button className="relation-action" variant="outline">{actionLabel}</Button>
    </div>
  );
}

export function FollowersReferenceScreen({ initialTab = "followers" }: { initialTab?: FollowersTab }) {
  const router = useRouter();
  const [tab, setTab] = useState<FollowersTab>(initialTab);
  const rows = tab === "followers" ? referenceFollowers : referenceFollowing;
  return (
    <ReferencePhone>
      <BackTopbar title={currentReferenceUser.displayName} onBack={() => router.push("/profile/me")} />
      <div className="followers-tabs" role="tablist" aria-label="ความสัมพันธ์">
        <button aria-selected={tab === "following"} className={tab === "following" ? "active" : ""} onClick={() => setTab("following")} role="tab" type="button">กำลังติดตาม</button>
        <button aria-selected={tab === "followers"} className={tab === "followers" ? "active" : ""} onClick={() => setTab("followers")} role="tab" type="button">ผู้ติดตาม</button>
      </div>
      <div className="relations-list" role="tabpanel" data-followers-tab={tab}>{rows.map((row) => <RelationRow key={row.username} {...row} />)}</div>
    </ReferencePhone>
  );
}
