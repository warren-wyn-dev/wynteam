"use client";

import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

import { DeveloperRouteGate } from "@/components/developer-route-gate";
import { SettingsChangePassword } from "@/components/settings-change-password";
import { AppChrome, EmptyState, LoadingState, ProfileRowView } from "@/components/phase3-ui";
import { WynosIcon } from "@/components/ui/wynos-icon";
import { getMountCache, setMountCache } from "@/lib/mount-cache";
import { isCurrentDevicePushEnabled, pushSupported, subscribeToPushNotifications, unsubscribeFromPushNotifications } from "@/lib/push-notifications";
import {
  deleteMyAccount,
  exportMyData,
  fetchBlockedUsers,
  fetchLegalDocument,
  fetchMutedUsers,
  fetchNotificationSettings,
  fetchProfile,
  fetchShowOnlineStatus,
  setShowOnlineStatus,
  unblockUser,
  unmuteUser,
  updateNotificationSetting,
  updateProfilePrivacySetting,
  type LegalDocument,
  type NotificationSettings,
  type ProfileRow,
} from "@/lib/phase3-data";

const notificationLabels: Array<[keyof NotificationSettings, string]> = [
  ["likes", "ถูกใจ"],
  ["comments", "ความคิดเห็น"],
  ["follows", "การติดตาม"],
  ["messages", "ข้อความ"],
  ["club", "Club"],
  ["trending", "กำลังนิยม"],
  ["system", "ระบบ"],
];

const legalTypes: Array<[string, string]> = [
  ["terms_of_service", "ข้อกำหนดการให้บริการ"],
  ["privacy_policy", "นโยบายความเป็นส่วนตัว"],
  ["community_guidelines", "แนวทางชุมชน"],
  ["copyright_policy", "นโยบายลิขสิทธิ์"],
  ["report_policy", "นโยบายการรายงาน"],
  ["appeal_policy", "นโยบายการอุทธรณ์"],
];

function SettingRow({
  title,
  description,
  leading,
  trailing,
  onClick,
  danger,
}: {
  title: string;
  description?: string;
  leading?: React.ReactNode;
  trailing?: React.ReactNode;
  onClick?: () => void;
  danger?: boolean;
}) {
  const Tag = onClick ? "button" : "div";
  // A row with no onClick but a `trailing` control (Toggle, PermissionSelect)
  // is still interactive -- the switch/select itself handles it, the row
  // just isn't a button. Treating it as "disabled" here (as onClick-only
  // used to) applied --wyn-text-muted (#9a9a9a, ~2.8:1 on white -- fails
  // WCAG AA) to every toggle-based settings row's title, e.g. the whole
  // Notifications category list. Founder-reported: pale/faded row labels.
  const isInteractive = Boolean(onClick || trailing);
  return (
    <Tag
      className={`settings-row ${isInteractive ? "enabled" : "disabled"} ${danger ? "danger" : ""}`}
      {...(onClick ? { type: "button" as const, onClick } : {})}
    >
      {leading ? <span className="settings-leading-icon">{leading}</span> : null}
      <span className="settings-row-copy">
        <strong>{title}</strong>
        {description ? <small>{description}</small> : null}
      </span>
      {trailing ?? (onClick ? <WynosIcon name="chevronRight" className="settings-chevron" size={20} strokeWidth={2} /> : null)}
    </Tag>
  );
}

function Toggle({ checked, disabled, onChange }: { checked: boolean; disabled?: boolean; onChange: (value: boolean) => void }) {
  return <label className="switch"><input type="checkbox" checked={checked} disabled={disabled} onChange={(e) => onChange(e.target.checked)} /><span /></label>;
}

function PermissionSelect({ value, onChange, kind = "interaction" }: { value: string; onChange: (value: string) => void; kind?: "interaction" | "likes" }) {
  const options = kind === "likes"
    ? [["everyone", "ทุกคน"], ["friends", "เพื่อน"], ["only_me", "เฉพาะฉัน"]]
    : [["everyone", "ทุกคน"], ["people_i_follow", "คนที่ฉันติดตาม"], ["no_one", "ไม่มีใคร"]];
  return <select className="settings-select" value={value} onChange={(e) => onChange(e.target.value)}>{options.map(([wire, label]) => <option value={wire} key={wire}>{label}</option>)}</select>;
}

function VersionFooter() {
  // Was two different, both-stale labels ("V1.0.0 Beta4" for everyone,
  // "V1.0.0 Beta5 [พัฒนาอยู่]" for developer accounts only) left over from
  // before the web's official baseline naming (2026-09-16, see
  // .wyn/logs/deployments/2026-09-16-wynos-web-beta1-baseline.md) settled
  // on "WYNOS Web Beta1" — neither matched that, and showing a different
  // version to different accounts was itself confusing. One label for
  // everyone now; no RPC call needed to decide it.
  return <p className="settings-version-footer">Web Beta1</p>;
}

type SettingsSnapshot = { profile: ProfileRow; notifications: NotificationSettings; online: boolean; blocked: ProfileRow[]; muted: ProfileRow[] };

function SettingsInner({ client, userId, signOut }: { client: SupabaseClient; userId: string; signOut: () => Promise<void> }) {
  const cacheKey = `settings:${userId}`;
  const cached = getMountCache<SettingsSnapshot>(cacheKey);
  const [profile, setProfile] = useState<ProfileRow | null>(cached?.profile ?? null);
  const [online, setOnline] = useState(cached?.online ?? true);
  const [notifications, setNotifications] = useState<NotificationSettings | null>(cached?.notifications ?? null);
  const [blocked, setBlocked] = useState<ProfileRow[]>(cached?.blocked ?? []);
  const [muted, setMuted] = useState<ProfileRow[]>(cached?.muted ?? []);
  const [loading, setLoading] = useState(!cached);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [section, setSection] = useState<"root" | "privacy" | "notifications" | "account" | "password" | "legal">("root");
  const [document, setDocument] = useState<LegalDocument | null>(null);
  const [pushAvailable, setPushAvailable] = useState(false);
  const [pushEnabled, setPushEnabled] = useState(false);
  const [pushBusy, setPushBusy] = useState(false);
  const [showInstallShortcut, setShowInstallShortcut] = useState(false);

  useEffect(() => {
    const standalone = window.matchMedia("(display-mode: standalone)");
    const refresh = () => {
      const iosInstalled = (navigator as Navigator & { standalone?: boolean }).standalone === true;
      setShowInstallShortcut(!standalone.matches && !iosInstalled);
    };
    refresh();
    const onInstalled = () => setShowInstallShortcut(false);
    standalone.addEventListener("change", refresh);
    window.addEventListener("appinstalled", onInstalled);
    return () => {
      standalone.removeEventListener("change", refresh);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, []);

  useEffect(() => {
    let active = true;
    void pushSupported().then(async (supported) => {
      if (!active) return;
      setPushAvailable(supported);
      if (supported) {
        const enabled = await isCurrentDevicePushEnabled(client, userId);
        if (active) setPushEnabled(enabled);
      }
    });
    return () => { active = false; };
  }, [client, userId]);

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const [nextProfile, nextNotifications, showOnline, blockRows, muteRows] = await Promise.all([
        fetchProfile(client, userId), fetchNotificationSettings(client), fetchShowOnlineStatus(client, userId), fetchBlockedUsers(client, 0), fetchMutedUsers(client, 0),
      ]);
      setProfile(nextProfile); setNotifications(nextNotifications); setOnline(showOnline); setBlocked(blockRows); setMuted(muteRows);
      if (nextProfile && nextNotifications) setMountCache(cacheKey, { profile: nextProfile, notifications: nextNotifications, online: showOnline, blocked: blockRows, muted: muteRows });
    } catch (e) { setError(e instanceof Error ? e.message : "โหลดการตั้งค่าไม่สำเร็จ"); }
    finally { setLoading(false); }
  }, [client, userId, cacheKey]);
  useEffect(() => { void load(); }, [load]);

  const privacy = async (field: "is_private" | "dm_permission" | "mention_permission" | "comment_permission" | "likes_visibility", value: boolean | string) => {
    if (!profile || busy) return;
    const previous = profile; setProfile({ ...profile, [field]: value } as ProfileRow); setBusy(true); setError("");
    try { await updateProfilePrivacySetting(client, userId, field, value); }
    catch (e) { setProfile(previous); setError(e instanceof Error ? e.message : "บันทึกไม่สำเร็จ"); }
    finally { setBusy(false); }
  };

  const notification = async (key: keyof NotificationSettings, value: boolean) => {
    if (!notifications || busy) return;
    const previous = notifications; setNotifications({ ...notifications, [key]: value }); setBusy(true);
    try { await updateNotificationSetting(client, userId, key, value); }
    catch { setNotifications(previous); setError("บันทึกการแจ้งเตือนไม่สำเร็จ"); }
    finally { setBusy(false); }
  };

  const pushToggle = async (value: boolean) => {
    if (pushBusy) return;
    setPushBusy(true); setError("");
    try {
      if (value) {
        const result = await subscribeToPushNotifications(client, userId);
        if (!result.ok) {
          setError(
            result.reason === "denied"
              ? "ต้องอนุญาตการแจ้งเตือนในเบราว์เซอร์ก่อน"
              : "เปิดการแจ้งเตือนไม่สำเร็จ ลองใหม่อีกครั้ง",
          );
          setPushEnabled(false);
          return;
        }
        setPushEnabled(true);
      } else {
        const removed = await unsubscribeFromPushNotifications(client);
        if (!removed) {
          setError("ปิดการแจ้งเตือนไม่สำเร็จ กรุณาลองอีกครั้ง");
          return;
        }
        setPushEnabled(false);
      }
    } finally {
      setPushBusy(false);
    }
  };

  const onlineToggle = async (value: boolean) => {
    const previous = online; setOnline(value); setBusy(true);
    try { await setShowOnlineStatus(client, userId, value); }
    catch { setOnline(previous); setError("บันทึกสถานะออนไลน์ไม่สำเร็จ"); }
    finally { setBusy(false); }
  };

  const exportData = async () => {
    setBusy(true); setError("");
    try {
      const json = await exportMyData(client);
      const url = URL.createObjectURL(new Blob([json], { type: "application/json" }));
      const anchor = window.document.createElement("a"); anchor.href = url; anchor.download = `wynos-data-${new Date().toISOString().slice(0, 10)}.json`; anchor.click(); URL.revokeObjectURL(url);
    } catch (e) { setError(e instanceof Error ? e.message : "ส่งออกข้อมูลไม่สำเร็จ"); }
    finally { setBusy(false); }
  };

  const deleteAccount = async () => {
    if (!window.confirm("ลบบัญชี WYNOS แบบถาวร? การดำเนินการนี้ย้อนกลับไม่ได้")) return;
    if (!window.confirm("ยืนยันอีกครั้งว่าต้องการลบบัญชีและข้อมูลทั้งหมด")) return;
    setBusy(true); setError("");
    try { await deleteMyAccount(client); await signOut(); }
    catch (e) { setError(e instanceof Error ? e.message : "ลบบัญชีไม่สำเร็จ"); setBusy(false); }
  };

  const openDoc = async (type: string) => {
    setBusy(true); setError("");
    try { setDocument(await fetchLegalDocument(client, type)); }
    catch { setError("โหลดเอกสารไม่สำเร็จ"); }
    finally { setBusy(false); }
  };

  if (loading && !profile) return <AppChrome title="ตั้งค่า" userId={userId} backHref={`/profile/${userId}`} showBottomNav={false}><LoadingState /></AppChrome>;
  if (!profile || !notifications) return <AppChrome title="ตั้งค่า" userId={userId} backHref={`/profile/${userId}`} showBottomNav={false}><EmptyState>{error || "ไม่พบการตั้งค่า"}</EmptyState></AppChrome>;

  const title = section === "root" ? "ตั้งค่า" : section === "privacy" ? "ความเป็นส่วนตัว" : section === "notifications" ? "การแจ้งเตือน" : section === "account" ? "บัญชี" : section === "password" ? "เปลี่ยนรหัสผ่าน" : "ข้อกำหนดและความเป็นส่วนตัว";
  const back = section === "root" ? `/profile/${userId}` : undefined;

  return (
    <AppChrome
      title={title}
      userId={userId}
      backHref={back}
      showBottomNav={false}
      actions={section !== "root" ? <button className="route-icon-button" type="button" aria-label="กลับ" onClick={() => setSection(section === "password" ? "account" : "root")}><WynosIcon name="back" size={26} strokeWidth={2} /></button> : null}
    >
      {error ? <p className="route-error route-pad">{error}</p> : null}
      {section === "root" ? (
        <div className="settings-page">
          <h2>บัญชี</h2>
          <div className="settings-group">
            <SettingRow leading={<WynosIcon name="profile" size={19} strokeWidth={2} />} title="บัญชี" onClick={() => setSection("account")} />
            <SettingRow leading={<WynosIcon name="lockKeyhole" size={19} strokeWidth={2} />} title="ความเป็นส่วนตัว" onClick={() => setSection("privacy")} />
          </div>
          <h2>การตั้งค่าแอป</h2>
          <div className="settings-group">
            {showInstallShortcut ? <SettingRow leading={<WynosIcon name="smartphone" size={19} strokeWidth={2} />} title="ติดตั้ง WYNOS" description="เพิ่มลงหน้าจอหลักและเปิดแบบแอป" onClick={() => window.dispatchEvent(new Event("wynos:open-install"))} /> : null}
            <SettingRow leading={<WynosIcon name="notifications" size={19} strokeWidth={2} />} title="การแจ้งเตือน" onClick={() => setSection("notifications")} />
            <SettingRow leading={<WynosIcon name="moon" size={19} strokeWidth={2} />} title="ธีมเข้ม" />
          </div>
          <h2>ช่วยเหลือ</h2>
          <div className="settings-group">
            <SettingRow leading={<WynosIcon name="circleHelp" size={19} strokeWidth={2} />} title="ช่วยเหลือ" />
            <SettingRow leading={<WynosIcon name="fileText" size={19} strokeWidth={2} />} title="ข้อกำหนดและความเป็นส่วนตัว" onClick={() => setSection("legal")} />
          </div>
          <div className="settings-group separated">
            <SettingRow leading={<WynosIcon name="logOut" size={19} strokeWidth={2} />} title="ออกจากระบบ" danger onClick={() => { if (window.confirm("ออกจากระบบบัญชีของคุณใช่ไหม")) void signOut(); }} />
          </div>
          <VersionFooter />
        </div>
      ) : null}
      {section === "privacy" ? <div className="settings-page"><h2>บัญชี</h2><div className="settings-group"><SettingRow title="บัญชีส่วนตัว" description="อนุมัติผู้ติดตามก่อนเห็นโพสต์" trailing={<Toggle checked={profile.is_private} disabled={busy} onChange={(value) => void privacy("is_private", value)} />} /></div><h2>การโต้ตอบ</h2><div className="settings-group"><SettingRow title="ใครส่งข้อความได้" trailing={<PermissionSelect value={profile.dm_permission} onChange={(value) => void privacy("dm_permission", value)} />} /><SettingRow title="ใครกล่าวถึงคุณได้" trailing={<PermissionSelect value={profile.mention_permission} onChange={(value) => void privacy("mention_permission", value)} />} /><SettingRow title="ใครแสดงความคิดเห็นได้" trailing={<PermissionSelect value={profile.comment_permission} onChange={(value) => void privacy("comment_permission", value)} />} /><SettingRow title="ใครเห็นสิ่งที่คุณถูกใจ" trailing={<PermissionSelect kind="likes" value={profile.likes_visibility} onChange={(value) => void privacy("likes_visibility", value)} />} /></div><h2>สถานะ</h2><div className="settings-group"><SettingRow title="แสดงสถานะออนไลน์" trailing={<Toggle checked={online} disabled={busy} onChange={(value) => void onlineToggle(value)} />} /></div></div> : null}
      {section === "notifications" ? <div className="settings-page">{pushAvailable ? <><h2>อุปกรณ์นี้</h2><div className="settings-group"><SettingRow title="การแจ้งเตือนแบบพุช" description="รับการแจ้งเตือนแม้ปิดแท็บนี้อยู่" trailing={<Toggle checked={pushEnabled} disabled={pushBusy} onChange={(value) => void pushToggle(value)} />} /></div></> : null}<h2>แจ้งเตือนเมื่อ</h2><div className="settings-group">{notificationLabels.map(([key, label]) => <SettingRow title={label} key={key} trailing={<Toggle checked={notifications[key]} disabled={busy} onChange={(value) => void notification(key, value)} />} />)}</div></div> : null}
      {section === "account" ? <div className="settings-page"><h2>ความปลอดภัย</h2><div className="settings-group"><SettingRow title="เปลี่ยนรหัสผ่าน" description="ยืนยันรหัสผ่านเดิมก่อนตั้งรหัสผ่านใหม่" leading={<WynosIcon name="lockKeyhole" size={19} strokeWidth={2} />} onClick={() => setSection("password")} /><div className="settings-subsection"><strong>บัญชีที่บล็อก</strong>{blocked.length ? blocked.map((item) => <ProfileRowView profile={item} key={item.id} trailing={<button className="route-pill soft" type="button" onClick={() => void unblockUser(client, item.id).then(() => setBlocked((rows) => rows.filter((row) => row.id !== item.id)))}>ปลดบล็อก</button>} />) : <small>ไม่มี</small>}</div><div className="settings-subsection"><strong>บัญชีที่ปิดเสียง</strong>{muted.length ? muted.map((item) => <ProfileRowView profile={item} key={item.id} trailing={<button className="route-pill soft" type="button" onClick={() => void unmuteUser(client, userId, item.id).then(() => setMuted((rows) => rows.filter((row) => row.id !== item.id)))}>เปิดเสียง</button>} />) : <small>ไม่มี</small>}</div></div><h2>ข้อมูลของฉัน</h2><div className="settings-group"><SettingRow title="ส่งออกข้อมูลของฉัน" onClick={() => void exportData()} trailing={<WynosIcon name="download" size={19} strokeWidth={2} />} /><SettingRow title="ลบบัญชี" danger onClick={() => void deleteAccount()} trailing={<WynosIcon name="trash" size={19} strokeWidth={2} />} /></div><p className="settings-safety"><WynosIcon name="shieldCheck" size={16} strokeWidth={2} /> การจัดการข้อมูลทั้งหมดใช้สิทธิ์ RLS/RPC ของบัญชีที่เข้าสู่ระบบอยู่เท่านั้น</p></div> : null}
      {section === "password" ? <SettingsChangePassword client={client} userId={userId} onBack={() => setSection("account")} /> : null}
      {section === "legal" ? <div className="settings-page"><div className="settings-group">{legalTypes.map(([type, label]) => <SettingRow title={label} key={type} onClick={() => void openDoc(type)} />)}</div></div> : null}
      {document ? <div className="route-modal-backdrop" role="presentation" onClick={() => setDocument(null)}><section className="route-modal legal-modal" role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}><header><strong>{document.title}</strong><button className="route-icon-button" type="button" onClick={() => setDocument(null)}><WynosIcon name="close" size={24} strokeWidth={2} /></button></header><div className="legal-content"><small>เวอร์ชัน {document.version}</small><p>{document.content}</p></div></section></div> : null}
    </AppChrome>
  );
}

export function SettingsRoute() {
  return <DeveloperRouteGate>{({ client, userId, signOut }) => <SettingsInner client={client} userId={userId} signOut={signOut} />}</DeveloperRouteGate>;
}
