"use client";

import { BellRing, Clock3, Radio, Smartphone, Volume2, Vibrate } from "lucide-react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useEffect, useState } from "react";

import { MerchantNotificationTest } from "@/components/merchant/merchant-notification-test";
import { MerchantOrderScreenCard } from "@/components/merchant/merchant-order-screen";
import { previewMerchantOrderSound } from "@/components/merchant/merchant-order-alert";
import type { FoodStore } from "@/lib/food-merchant";
import {
  readMerchantAlertPreferences,
  saveMerchantAlertPreferences,
  type MerchantAlertPreferences,
} from "@/lib/merchant-notification-preferences";
import {
  isCurrentDevicePushEnabled,
  pushReasonDescription,
  setPushChosen,
  subscribeToPushNotifications,
  unsubscribeFromPushNotifications,
} from "@/lib/push-notifications";

function Toggle({ checked, disabled, label, onChange }: {
  checked: boolean;
  disabled?: boolean;
  label: string;
  onChange: (value: boolean) => void;
}) {
  return (
    <button
      className={`wm-switch wm-notification-toggle ${checked ? "is-on" : ""}`}
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!checked)}
    ><i /></button>
  );
}

export function MerchantNotificationSettings({
  client,
  store,
  userId,
  onMessage,
  onPushChange,
  onReload,
}: {
  client: SupabaseClient;
  store: FoodStore;
  userId: string;
  onMessage: (message: string) => void;
  onPushChange: (enabled: boolean) => void;
  onReload: () => Promise<void> | void;
}) {
  const [prefs, setPrefs] = useState<MerchantAlertPreferences>(readMerchantAlertPreferences);
  const [pushEnabled, setPushEnabled] = useState(false);
  const [checkingPush, setCheckingPush] = useState(true);
  const [pushBusy, setPushBusy] = useState(false);

  useEffect(() => {
    let live = true;
    void isCurrentDevicePushEnabled(client, userId).then((enabled) => {
      if (!live) return;
      setPushEnabled(enabled === true);
      setCheckingPush(false);
    });
    return () => { live = false; };
  }, [client, userId]);

  const updatePrefs = (patch: Partial<MerchantAlertPreferences>) => {
    const next = { ...prefs, ...patch };
    setPrefs(next);
    saveMerchantAlertPreferences(next);
  };

  const togglePush = async (next: boolean) => {
    if (pushBusy) return;
    setPushBusy(true);
    try {
      if (next) {
        const result = await subscribeToPushNotifications(client, userId);
        if (!result.ok) {
          onMessage(pushReasonDescription(result.reason));
          return;
        }
        setPushChosen(userId, true);
        setPushEnabled(true);
        onPushChange(true);
        onMessage("เปิด Web Push สำหรับ WYNOS Merchant แล้ว");
      } else {
        const ok = await unsubscribeFromPushNotifications(client);
        if (!ok) {
          onMessage("ปิด Web Push ไม่สำเร็จ กรุณาลองอีกครั้ง");
          return;
        }
        setPushChosen(userId, false);
        setPushEnabled(false);
        onPushChange(false);
        onMessage("ปิด Web Push บนอุปกรณ์นี้แล้ว");
      }
    } finally {
      setPushBusy(false);
    }
  };

  const previewSound = async () => {
    const played = await previewMerchantOrderSound();
    onMessage(played ? "กำลังเล่นเสียงออเดอร์ทดสอบ" : "เปิดเสียงไม่ได้ ตรวจว่ามือถือไม่ได้ปิดเสียงอยู่");
  };

  return (
    <>
      <div className="wm-page-heading"><div><small>WYNOS Merchant</small><h1>การแจ้งเตือน</h1></div></div>

      <section className="wm-notification-card">
        <div className="wm-notification-card-head">
          <span className="wm-notification-card-icon"><Smartphone size={21} /></span>
          <span><strong>Web Push บนอุปกรณ์นี้</strong><small>รับออเดอร์และเหตุการณ์สำคัญ แม้ไม่ได้เปิด Merchant อยู่</small></span>
          <Toggle checked={pushEnabled} disabled={checkingPush || pushBusy} label="Web Push" onChange={(value) => void togglePush(value)} />
        </div>
      </section>

      <section className="wm-notification-card">
        <div className="wm-notification-card-head">
          <span className="wm-notification-card-icon"><BellRing size={21} /></span>
          <span><strong>ออเดอร์ใหม่</strong><small>ตั้งค่าเสียงและการสั่นของหน้าต่างออเดอร์ใน Merchant</small></span>
        </div>
        <div className="wm-notification-setting-row">
          <span><Volume2 size={18} /><span><strong>เสียงออเดอร์</strong><small>ดังซ้ำจนกว่าจะเปิดออเดอร์</small></span></span>
          <Toggle checked={prefs.sound_enabled} label="เสียงออเดอร์" onChange={(value) => updatePrefs({ sound_enabled: value })} />
        </div>
        <div className="wm-notification-setting-row">
          <span><Vibrate size={18} /><span><strong>การสั่น</strong><small>สั่นเมื่อมีออเดอร์ที่ต้องจัดการ</small></span></span>
          <Toggle checked={prefs.vibration_enabled} label="การสั่น" onChange={(value) => updatePrefs({ vibration_enabled: value })} />
        </div>
        <button className="wm-secondary wm-full wm-notification-sound-test" type="button" onClick={() => void previewSound()}>
          <Volume2 size={18} /> ลองเสียงออเดอร์
        </button>
      </section>

      <MerchantOrderScreenCard onMessage={onMessage} />

      <section className="wm-notification-card" aria-label="ไม่พลาดออเดอร์">
        <div className="wm-notification-card-head">
          <span className="wm-notification-card-icon"><BellRing size={21} /></span>
          <span><strong>ไม่ให้พลาดออเดอร์</strong><small>มือถือเล่นเสียง WYNOS ได้เฉพาะตอนเปิด Merchant อยู่ ตอนปิดแอปจะได้แจ้งเตือนเสียงปกติของเครื่องแทน</small></span>
        </div>
        <ul className="wm-notification-tips">
          <li>เปิด &quot;หน้าจอรับออเดอร์&quot; แล้ววางเครื่องไว้หน้าร้าน</li>
          <li>iPhone: เพิ่มเสียงให้ดัง (iOS 17 ขึ้นไป เสียง WYNOS ดังได้แม้เปิดโหมดเงียบ ตอนเปิด Merchant อยู่)</li>
          <li>เสียบชาร์จไว้ และอย่าปัดปิดแอป Merchant ทิ้ง</li>
          <li>เปิด Web Push ด้านบนไว้ ออเดอร์ที่ยังไม่มีใครรับ ระบบจะเตือนซ้ำทุก 1 นาที สูงสุด 5 ครั้ง</li>
          <li>ติดตั้ง WYNOS Merchant ไว้บนหน้าจอโฮม</li>
        </ul>
      </section>

      <section className="wm-notification-card">
        <div className="wm-notification-card-head">
          <span className="wm-notification-card-icon"><Clock3 size={21} /></span>
          <span><strong>Quiet Hours</strong><small>ช่วงนี้ยังเห็นออเดอร์บนหน้าจอ แต่ Merchant จะไม่ส่งเสียงหรือสั่น</small></span>
          <Toggle checked={prefs.quiet_enabled} label="Quiet Hours" onChange={(value) => updatePrefs({ quiet_enabled: value })} />
        </div>
        {prefs.quiet_enabled ? (
          <div className="wm-notification-time-grid">
            <label>เริ่ม<input type="time" value={prefs.quiet_start} onChange={(event) => updatePrefs({ quiet_start: event.target.value })} /></label>
            <label>สิ้นสุด<input type="time" value={prefs.quiet_end} onChange={(event) => updatePrefs({ quiet_end: event.target.value })} /></label>
          </div>
        ) : null}
      </section>

      <section className="wm-notification-card">
        <div className="wm-notification-card-head">
          <span className="wm-notification-card-icon"><Radio size={21} /></span>
          <span><strong>Merchant แจ้งเรื่องอะไรบ้าง</strong><small>ระบบสำคัญที่เชื่อมกับออเดอร์และร้านค้า</small></span>
        </div>
        <div className="wm-notification-types">
          <span>ออเดอร์ใหม่</span><span>ลูกค้าส่งสลิป</span><span>ชำระเงินแล้ว</span><span>ลูกค้ายกเลิกออเดอร์</span><span>ระบบร้านค้า</span><span>ประกาศสำคัญ</span>
        </div>
      </section>

      <MerchantNotificationTest client={client} store={store} userId={userId} onMessage={onMessage} onReload={onReload} />
    </>
  );
}
