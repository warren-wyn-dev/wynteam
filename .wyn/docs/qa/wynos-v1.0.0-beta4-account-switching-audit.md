# WYNOS v1.0.0 Beta4 — Account Switching & State Isolation Audit

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta4-master-implementation-j5lke8` — **ยังไม่เปิด PR · ยังไม่ merge · ยังไม่ deploy**
> ขอบเขต: Beta4 §13 (Account Switching Safety), §11.5 (Notification Account Isolation), §19 (Security & Account QA)
> Environment: Flutter 3.47.1 · อ่าน `supabase/schema.sql` จาก repo (ไม่มี production credential ใน session นี้)

---

## 0. สรุปสั้น

**พบบั๊กจริง 1 ตัว ระดับสูง แก้แล้ว** — เป็นบั๊กเดียวที่ Beta4 audit จัดเป็น "ข้อมูลของบัญชี A รั่วไปยังบัญชี B" ตามตัวอักษร

| | |
|---|---|
| บั๊กที่พบ | **B4-A1** — `_RootShellState` เดิมรอดข้ามการสลับบัญชี |
| ผลกระทบ | Badge, Feed, Notifications, Profile และ **push registration** ของ A ตกทอดไปยัง B |
| สาเหตุ | `const RootShell()` ถูก canonicalize โดย Dart |
| แก้ | key ด้วย user id |
| บั๊กรอง | **B4-A2** — push token ของ A ค้างชี้ที่ A หลังสลับไป B (RLS บล็อกไม่ให้ B แก้) |
| แก้ | ลบ token ตอนที่ยังเป็น A อยู่ ก่อน `switchTo` |

---

## 1. B4-A1 — `_RootShellState` รอดข้ามการสลับบัญชี

### กลไก

`AuthGate` เดิม:

```dart
late final Widget Function() _buildRootShell =
    widget.rootShellBuilder ?? () => const RootShell();
```

`const RootShell()` เป็น **canonicalized const** — Dart คืน *instance เดียวกัน* ทุกครั้งที่ประเมิน expression นี้ Flutter ตัดสินใจว่าจะเก็บ `State` เดิมไว้หรือไม่ด้วย `Widget.canUpdate(old, new)` ซึ่งเทียบ `runtimeType` และ `key` — instance เดียวกันแปลว่าผ่านทั้งคู่เสมอ

นี่เป็นเจตนาเดิมและถูกต้องสำหรับ rebuild ธรรมดา: `RootShell.initState` สร้าง repository ทั้ง 12 ตัว การทิ้งทุกครั้งที่ `AuthGate` rebuild จะเป็นการ refetch ทั้งแอป

**แต่การสลับบัญชีก็คือ `AuthGate` rebuild เหมือนกัน และ `canUpdate` แยกสองกรณีนี้ไม่ออก**

### สิ่งที่ B ได้รับตกทอดมาจาก A (อ่านจาก `root_shell.dart` โดยตรง)

| state | ผลที่ผู้ใช้เห็น |
|---|---|
| `_unreadNotificationCount` | เลข badge ของ A ค้างบนกระดิ่งของ B |
| `_profileVisitKey`, `_notificationsVisitKey`, `_homeVersion` | ไม่ถูก bump → `IndexedStack` ทั้ง 4 ลูกไม่ remount → **feed ของ A, ลิสต์แจ้งเตือนของ A, โปรไฟล์ของ A ยังอยู่บนจอใต้ session ของ B** |
| `ViewProfileScreen` | แม้ `RootShell.build()` จะอ่าน `currentUser!.id` ใหม่เป็น id ของ B แต่ `ValueKey('profile_$_profileVisitKey')` ไม่เปลี่ยน + type เดิม → `State` เดิมถูกเก็บไว้ และ `_ViewProfileScreenState` **ไม่มี `didUpdateWidget`** ที่จะสังเกตว่า `widget.userId` เปลี่ยน → `_loadFuture` ยังเป็นของ A |
| repository ทั้ง 12 ตัว | ตัวอย่างที่ *ไม่* เป็นปัญหา: ทุกตัวถือ `Supabase.instance.client` ซึ่งเป็น singleton ที่ session เปลี่ยนไปแล้ว query ใหม่จึงยิงในนามของ B ถูกต้อง — ปัญหาอยู่ที่ข้อมูล *ที่โหลดมาแล้ว* ไม่ใช่ข้อมูลที่จะโหลดต่อไป |
| `PushNotificationService(...).initialize()` | อยู่ใน `initState` → ไม่รันซ้ำ → device นี้ยังลงทะเบียนในนามของ A (ดู B4-A2) |

### การแก้

```dart
late final Widget Function(Session) _buildRootShell =
    widget.rootShellBuilder ??
        (session) => RootShell(key: ValueKey(session.user.id));
```

`ValueKey` บน user id:

* **คงที่สำหรับบัญชีเดิม** → rebuild ธรรมดายังเก็บ `State` ไว้เหมือนเดิมทุกประการ (ซึ่งเป็นสิ่งที่ทำให้ shell นี้ถูก)
* **เปลี่ยนเมื่อบัญชีเปลี่ยน** → subtree ทั้งก้อนถูกรื้อและสร้างใหม่จาก `initState`: repository ใหม่, badge ใหม่, ทั้ง 4 tab ใหม่, push registration ใหม่

**ทำไมแก้ที่ key ไม่ใช่ไล่เคลียร์ทีละตัว:** key คือสิ่งที่ Flutter ใช้ตัดสินจริง การแก้ที่นั่นครอบคลุม state ทุกตัวที่ shell ถือ *รวมถึงตัวที่จะถูกเพิ่มในอนาคต* ส่วนการไล่ `setState(() => _unreadCount = 0)` ทีละจุดจะพลาดตัวที่ 13 เสมอ

### หลักฐาน

`test/auth_gate_test.dart` — group "Beta4 §13 -- RootShell is keyed per account":

1. `RootShell` ได้ `ValueKey` ของ user id ที่ signed in
2. key ไม่เปลี่ยนข้าม rebuild ของบัญชีเดิม (ยืนยันว่าไม่ได้ทำให้ shell remount ทุก frame)

ทดสอบที่ key ไม่ใช่ที่ internals ของ `RootShell` — key คือกลไกจริงที่ Flutter อ่าน

### สิ่งที่ §13 ขอ vs. สิ่งที่ key ครอบคลุม

| §13 รายการ | ครอบคลุมโดย |
|---|---|
| Profile | `ViewProfileScreen` remount |
| Posts | tab เดียวกัน remount |
| Followers / Following | โหลดใหม่พร้อมโปรไฟล์ |
| Saved | `BookmarksScreen` เป็น pushed route — ปิดไปแล้วตอน `AuthGate` `popUntil(isFirst)` |
| Draft | เหมือน Saved — pushed route |
| Notifications | `NotificationListScreen` remount |
| Notification Badge | `_unreadNotificationCount` เกิดใหม่เป็น 0 แล้ว fetch ใหม่ |
| Push Subscription | `initialize()` รันใหม่ + ดู B4-A2 |
| Auth / Session | Supabase client singleton — `switchTo` เปลี่ยน session ก่อนแล้ว |
| Local State | ทั้งหมดอยู่ใน `_RootShellState` หรือ State ของลูก → รื้อทั้งก้อน |
| Cache / Query State | `HomeRepository._rankedWindow` อยู่ใน repository instance ที่สร้างใน `initState` → instance ใหม่ |

---

## 2. B4-A2 — Push token ค้างชี้บัญชีเดิม

### ปัญหา

`push_tokens` มี unique constraint บน `token` และ RLS (อ่านจาก `schema.sql` บรรทัด ~3083):

```sql
create policy "Users can update their own push tokens"
  on public.push_tokens for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

ลำดับเหตุการณ์บนเครื่องเดียว:

1. A ลงชื่อเข้าใช้ → `upsert(token=T, user_id=A)` → มีแถว `(T, A)`
2. สลับไป B
3. B เรียก `upsert(token=T, user_id=B)` → PostgREST พยายาม `update ... where token = T` → **RLS ปฏิเสธ** เพราะแถวนั้นเป็นของ A
4. การ upsert เป็น fire-and-forget (ไม่ await ไม่ catch) → **ล้มเงียบ**
5. แถวยังเป็น `(T, A)` → **push ของ A เด้งขึ้นบนเครื่องที่ B กำลังใช้อยู่**

นี่คือ §11.5 "Subscription A ถูกใช้ผิด Account" และ §11.8 "Push Subscription Ownership" ตรงๆ

### การแก้

`AccountSwitcherSheet._switchTo` ลบ token **ก่อน** `switchTo()`:

```dart
await PushNotificationService(...).unregisterCurrentDevice();  // ยังเป็น A อยู่
await _repository.switchTo(account, client);                    // ค่อยกลายเป็น B
```

นาทีที่ยังเป็น A คือนาทีเดียวที่ใครก็ตามได้รับอนุญาตให้ลบแถวนั้น (`delete` policy ก็ `using (auth.uid() = user_id)` เช่นกัน) หลัง `switchTo` คืนค่า client เป็น B แล้วและแถวเป็นของ A ตลอดไป

**Best-effort โดยตั้งใจ และไม่ใช่เหตุให้ยกเลิกการสลับ:** ห่อด้วย try/catch ของตัวเอง — การล้างทะเบียน push ไม่สำเร็จต้องไม่ทำให้คนติดอยู่กับบัญชีที่เขาขอออก กรณีแย่สุดคือพฤติกรรมเท่ากับก่อน Beta4 และ server จะทิ้ง token ที่ FCM ไม่รู้จักเองอยู่แล้ว (`UNREGISTERED` handling ใน Edge Function)

---

## 3. Sign-out path — ตรวจแล้ว ถูกต้องอยู่แล้ว

| เส้นทาง | ล้าง push token? |
|---|---|
| Settings → ออกจากระบบ | ✅ มีอยู่แล้ว |
| `AuthGate._leaveBlockedScreen` (Suspend/Ban) | ✅ มีอยู่แล้ว |
| `forgetAndSwitchToNextIfAny` (logout แล้วเด้งไปบัญชีถัดไป) | ⚠️ ดู K-1 |

---

## 4. Guest mode

`session.user.isAnonymous` → `_buildRootShell(session)` เหมือนกัน key ก็ใช้ user id ของ guest จึงได้ isolation แบบเดียวกัน

Guest ไม่มีแถวใน `profiles` เลย และ Drop("+")/Notifications/Profile ถูก gate ด้วย `requireRealAccount()` — ไม่เปลี่ยนใน Beta4

---

## 5. ตรวจแล้ว **ไม่พบปัญหา**

| จุด | ผล |
|---|---|
| `switchTo()` ไม่เรียก `signOut()` | ถูกต้องและตั้งใจ — มีคอมเมนต์อธิบายว่าแม้ `SignOutScope.local` ก็ revoke refresh token ฝั่ง server |
| refresh token เก็บที่ไหน | Keychain/Keystore ผ่าน `flutter_secure_storage` ไม่ใช่ `shared_preferences` ถูกต้อง |
| `startSyncingActiveSession` | sync เฉพาะบัญชีที่ capture แล้ว, ข้าม anonymous — ถูกต้อง |
| `upsertAccount` เพดาน 5 บัญชี | นับเฉพาะบัญชี *ใหม่* การอัปเดตบัญชีเดิมไม่นับ — ถูกต้อง |
| `captureCurrentAccount` null-guard username | มีแล้ว (บัญชีที่ `completed` แต่ไม่มี username จะข้าม ไม่ crash) |
| RLS ของ `notifications` | `select` ใช้ `auth.uid() = recipient_id` — ไม่มีทางเห็นของคนอื่น ไม่มี insert policy ฝั่ง client |
| RLS ของ `push_tokens` | ทั้ง 4 policy ผูกกับ `auth.uid() = user_id` ครบ |
| Deep link authorization | `_openFromPushData` fetch เนื้อหาผ่าน repository ปกติ → RLS บังคับใช้ ถ้า B ได้ push เก่าของ A เนื้อหาจะ fetch ไม่ได้และ no-op |

---

## 6. Known Issues

| # | เรื่อง | ความรุนแรง | รายละเอียด |
|---|---|---|---|
| K-1 | `forgetAndSwitchToNextIfAny` ไม่ล้าง push token ของบัญชีที่กำลังออก | ต่ำ-กลาง | เส้นทางนี้ถูกเรียกหลัง sign-out จริงเกิดขึ้นแล้ว (`SettingsScreen`/`DeleteAccountScreen` ซึ่งล้าง token ไปก่อนแล้ว) จึงไม่รั่วในทางปฏิบัติ แต่ทั้งสองจุดพึ่งพากันโดยไม่มีอะไรบังคับ ควรรวมเป็นทางเดียวใน round หน้า |
| K-2 | ยังไม่ได้ทดสอบการสลับบัญชีจริงบนอุปกรณ์ | — | ต้องมี 2 บัญชีจริง + Firebase ที่ตั้งค่าแล้ว ซึ่ง session นี้ไม่มี ผลข้างบนมาจากการอ่าน RLS ใน `schema.sql` + widget test ที่พิสูจน์กลไก key |
| K-3 | ถ้า Founder เพิ่ม state ระดับ app นอก `RootShell` ในอนาคต key นี้จะไม่ครอบคลุม | ต่ำ | บันทึกไว้เป็นข้อควรระวัง: state ที่ต้องแยกตามบัญชี ควรอยู่ใต้ `RootShell` เสมอ |
