# WYNOS v1.0.0 Beta2 — Full Product Audit (Phase 1)

> วันที่ตรวจ: 2026-09-03
> Baseline ที่ตรวจ: `main` @ `e67c4e9`
> ขอบเขต: **Wynos = `app/` เท่านั้น** (Flutter consumer social app) + `supabase/schema.sql` ที่ Wynos ใช้จริง
> นอกขอบเขต: `admin/` (Next.js panel), `seller_app/` (ZOKY seller — คนละ track ตาม `RELEASE_NOTES.md`)
> วิธีตรวจ: อ่าน source code ทั้งหมด 245 ไฟล์ Dart (52,980 บรรทัด) + schema 12,397 บรรทัด + รัน `flutter analyze` / `flutter test` จริงบน Flutter 3.47.1 (SDK เดียวกับที่ CI/production build ใช้)

**สถานะ baseline ที่วัดได้จริง (ไม่ใช่การคาดเดา):**

| การตรวจ | ผล |
|---|---|
| `flutter analyze` | ✅ No issues found (24.6s) |
| `flutter test` | ✅ All tests passed — 1,048 tests |
| `python3 supabase/check_schema_ordering.py` | ✅ OK |

**สรุปหนึ่งบรรทัด:** WYNOS Beta2 ไม่ใช่ product ที่ "ยังไม่เสร็จ" — มันเสร็จในเชิงฟีเจอร์แล้วอย่างน่าประทับใจ (60+ ฟีเจอร์, RLS ครบ 195 policy, test 1,048 ตัว) สิ่งที่ยังขาดคือ **ชั้นความสมบูรณ์** ที่แยกแอปที่ "ใช้ได้" ออกจากแอปที่ "รู้สึกเป็นมืออาชีพ": ความเร็วของ feed, การใช้หน่วยความจำของรูปภาพ, ความถูกต้องของ state เมื่อผู้ใช้กดเร็ว/เน็ตช้า, index ของฐานข้อมูล, และรายละเอียดเล็ก ๆ ที่สม่ำเสมอทั้งแอป

---

## 1. สถาปัตยกรรมปัจจุบันของ WYNOS

### 1.1 ภาพรวม

```
Flutter (Dart 3.13.1 / Flutter 3.47.1)
  └── app/lib/
        ├── main.dart              → Supabase.initialize + Firebase (try/catch) + WynApp → AuthGate
        ├── core/                  → design tokens (WynColors/WynSpacing/WynTypography/WynTheme),
        │                            navigation, shared widgets (9 ตัว), text utils
        └── features/<feature>/
              ├── data/            → model + Repository (คุยกับ Supabase ตรง ๆ ไม่มี service layer คั่น)
              └── presentation/    → Screen (StatefulWidget) + widgets/
                                     state = setState ล้วน ไม่มี state management package

Backend: Supabase (PostgreSQL + Auth + Storage + Realtime + 2 Edge Functions)
  ├── 54 tables, 195 RLS policies, 29 indexes, views (home_feed ฯลฯ), RPC (SECURITY DEFINER) จำนวนมาก
  ├── Storage buckets: drop-images / avatars / club-* / chat / appeal evidence
  └── Edge Functions: location-search (LocationIQ), send-push-notification (FCM)

Deploy: Flutter Web → Vercel (https://wynos.online) ; CI: GitHub Actions (analyze+test ทุก PR)
```

### 1.2 รูปแบบสถาปัตยกรรมที่ใช้จริง (ค้นพบจากโค้ด ไม่ใช่จากเอกสาร)

| รูปแบบ | รายละเอียด | ประเมิน |
|---|---|---|
| Feature-first folder | `features/<name>/{data,presentation}` สม่ำเสมอ 100% ทุกฟีเจอร์ | ✅ ดีมาก |
| Repository pattern | 1 repository ต่อ 1 domain, inject ผ่าน constructor, ทุกตัว optional + default เป็น Supabase instance เพื่อให้ test แทนได้ | ✅ ดีมาก — เป็นเหตุผลที่มี test 1,048 ตัวได้ |
| State management | `setState` ล้วน ไม่มี Provider/Riverpod/Bloc | ⚠️ ยอมรับได้ที่ scale นี้ แต่เป็นสาเหตุรากของปัญหา "state ไม่ sync ข้ามหน้าจอ" (ดู §4.3) |
| Server-side authorization | RLS + SECURITY DEFINER RPC เป็นหลัก ไม่พึ่ง client | ✅ แข็งแรงมาก |
| Design system | token-based (`WynColors`/`WynSpacing`/`WynTypography`) + `design-reference/*.tsx` เป็น visual source | ✅ มีจริง แต่บังคับใช้ไม่ครบ (ดู §4.5) |

### 1.3 จุดแข็งเชิงสถาปัตยกรรมที่ต้องรักษาไว้

1. **Authorization อยู่ฝั่ง server จริง** — audience (`can_view_drop_audience`), block (`is_blocked_either_way`), private account, moderation sanction, soft-delete ทั้งหมดบังคับใน RLS policy ไม่ใช่ if ในโค้ด Dart
2. **ข้อมูลส่วนตัวแยกตาราง** — `profile_private` (วันเกิด, สถานะ password, onboarding) แยกจาก `profiles` ที่อ่านได้สาธารณะ ทำถูกต้องตามหลัก
3. **Test coverage สูงผิดปกติสำหรับ Flutter app** — 117 ไฟล์ test / 1,048 test ครอบคลุมทั้ง widget behavior และ model parsing
4. **Comment ในโค้ดอธิบาย "ทำไม" ไม่ใช่ "ทำอะไร"** — มีบันทึกเหตุผล/ประวัติการแก้ทุกจุดสำคัญ ทำให้ audit ครั้งนี้ทำได้ลึกโดยไม่ต้องเดา

---

## 2. Feature Inventory ทั้งหมด (จากโค้ดจริง)

| # | ฟีเจอร์ | ไฟล์หลัก | สถานะ |
|---|---|---|---|
| 1 | Authentication (Email/Password, Google, Apple, Phone OTP) | `auth/` 18 ไฟล์ | COMPLETE (Apple/Phone ปิดรอ provider) |
| 2 | Onboarding 6 ขั้น (Birthday→Username→DisplayName→Password→Profile→Finish) resumable | `auth/presentation/onboarding/` | COMPLETE |
| 3 | Home Feed (For You ranked / Following / From your Clubs) | `home/` 21 ไฟล์ | **NEEDS POLISH** (ดู §5) |
| 4 | Drop (โพสต์รูป 1–9 + ข้อความล้วน + Poll + Location + Audience) | `drop/` 22 ไฟล์ | MOSTLY COMPLETE |
| 5 | Pop (คลิปสั้น) | `pop/` 9 ไฟล์ | **ซ่อนอยู่** (WYN-102 Founder สั่งพักเก็บ — โค้ดยังอยู่ครบ) |
| 6 | Like / Comment / Reply / Comment Like | `drop/`, `pop/`, `club/` | **NEEDS POLISH** (ดู §7) |
| 7 | Save / Bookmarks | `saved/` 4 ไฟล์ | COMPLETE |
| 8 | ReDrop (Standard) + Quote ReDrop | `drop/`, `home/` | COMPLETE |
| 9 | Profile (view/edit/photo crop/8 แท็บ) | `profile/` 14 ไฟล์ | MOSTLY COMPLETE |
| 10 | Follow / Unfollow / Follower / Following / Remove follower | `follow/` 8 ไฟล์ | COMPLETE |
| 11 | Private Account + Follow Request (approve/reject/cancel) | `follow/` | COMPLETE |
| 12 | Close Friends + Audience exclusion | `follow/`, `drop/` | COMPLETE |
| 13 | Block / Unblock | `block/` 4 ไฟล์ | COMPLETE |
| 14 | Mute / Unmute | `mute/` 2 ไฟล์ | COMPLETE |
| 15 | Search (User/Drop/Club) + Discovery + Top 100 | `search/` 10 ไฟล์ | MOSTLY COMPLETE |
| 16 | Hashtag + Mention | `hashtag/`, `core/widgets/mention_input.dart` | COMPLETE |
| 17 | Notification (17 ประเภท + settings) | `notification/` 3 ไฟล์ | MOSTLY COMPLETE |
| 18 | Push Notification (FCM) | `push/` 2 ไฟล์ | PLACEHOLDER (รอ Firebase config จริงจาก Founder) |
| 19 | Chat 1:1 + Message Request + Share to Chat | `chat/` 10 ไฟล์ | MOSTLY COMPLETE |
| 20 | Club (สร้าง/เข้าร่วม/โพสต์/สมาชิก/discovery) | `club/` 20 ไฟล์ | MOSTLY COMPLETE |
| 21 | Report + Moderation Queue + Appeal | `moderation/`, `report/` 20 ไฟล์ | COMPLETE |
| 22 | Draft + Recently Deleted | `drop/` | COMPLETE |
| 23 | Settings + Privacy Controls + Notification Settings | `settings/` 5 ไฟล์ | COMPLETE |
| 24 | Data Rights (export/delete account, PDPA) | `settings/data/data_rights_repository.dart` | COMPLETE |
| 25 | Platform Documents + Acceptance Gate | `legal/` 3 ไฟล์ | COMPLETE (**เนื้อหายังเป็น placeholder — ดู APPROVALS.md**) |
| 26 | Multi-account Switcher | `account_switcher/` 3 ไฟล์ | COMPLETE |
| 27 | Guest Browsing + Guest Gate | `auth/presentation/widgets/guest_gate.dart` | COMPLETE |
| 28 | Analytics events | `analytics/` 1 ไฟล์ | MOSTLY COMPLETE |
| 29 | ZOKY marketplace (ในแอป Wynos) | `zoky/` 30 ไฟล์ | นอกขอบเขต audit นี้ |

**ข้อสังเกตสำคัญ:** ไม่พบฟีเจอร์ไหนที่ "มีปุ่มแต่ไม่ทำงาน" หรือเป็น dead code เลย — ทุกหน้าจอที่มีอยู่ต่อไปยัง repository จริงและ table จริง นี่คือคุณภาพที่สูงกว่าค่าเฉลี่ยของ product ระดับ Beta มาก

---

## 3. Feature Completeness Matrix

เกณฑ์ที่ใช้: Core function / Loading / Empty / Error+Retry / Optimistic UI / Duplicate-tap guard / Pagination / a11y

| ฟีเจอร์ | Core | Loading | Empty | Error+Retry | Optimistic | Dup-tap guard | Pagination | สถานะรวม | Priority งานที่เหลือ |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|---|---|
| Home Feed | ✅ | ⚠️ spinner (ไม่ใช่ skeleton) | ✅ | ✅ | ✅ | ❌ | ⚠️ offset + ไม่ dedupe | NEEDS POLISH | **P1** |
| For-You ranking | ⚠️ **index เพี้ยน** | — | — | — | — | — | ⚠️ ยิง RPC ซ้ำทุกหน้า | **BROKEN (เงียบ)** | **P1** |
| Drop create | ✅ | ✅ progress ต่อรูป | — | ✅ | — | ✅ | — | MOSTLY COMPLETE | P2 |
| Drop detail | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ | ❌ comment โหลดทั้งหมด | NEEDS POLISH | **P1** |
| Like/Save/ReDrop | ✅ | — | — | ⚠️ rollback เงียบ | ✅ | ❌ | — | NEEDS POLISH | **P1** |
| Comment | ✅ | ✅ | ✅ | ✅ | ⚠️ | ⚠️ | ❌ **ไม่มีเลย** | PARTIALLY COMPLETE | **P1** |
| Profile view | ✅ | ✅ skeleton | ✅ | ✅ | ✅ | ✅ | ✅ | MOSTLY COMPLETE | P1 (waterfall) |
| Follow/Unfollow | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | COMPLETE | — |
| Follow Request | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | COMPLETE | — |
| Block/Mute | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | COMPLETE | — |
| Search | ✅ | ✅ | ✅ | ✅ | — | ✅ | ✅ | MOSTLY COMPLETE | **P0 (injection)** |
| Notification | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ offset | MOSTLY COMPLETE | P2 |
| Chat | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | MOSTLY COMPLETE | P2 |
| Club | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | MOSTLY COMPLETE | P2 |
| Auth/Onboarding | ✅ | ✅ | — | ✅ | — | ✅ | — | COMPLETE | — |
| Moderation/Appeal | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | COMPLETE | — |
| Image pipeline | ✅ | ⚠️ | — | ⚠️ | — | — | — | **NEEDS POLISH** | **P1** |

---

## 4. UX Audit — จุดอ่อนที่ใหญ่ที่สุด

### 4.1 [P1] เปิดโพสต์แล้วกลับมา → feed รีเซ็ตทั้งหมด + เด้งกลับบนสุด

`home_feed_screen.dart:539` และ `:553` — หลัง `Navigator.push` ของ DropDetail/PopSingle กลับมา จะเรียก `_loadInitial()` เสมอ ซึ่ง `_items.clear()` + โหลดหน้า 0 ใหม่

ผลกระทบจริง: ผู้ใช้ scroll ลงไป 40 โพสต์ → เปิดดูโพสต์หนึ่ง → กด back → กลับมาอยู่บนสุด สิ่งที่เพิ่งดูหายไป นี่คือพฤติกรรมที่ไม่มีแอปโซเชียลระดับ mature ตัวไหนทำ (Facebook/IG/X/Threads คืน scroll position ทุกตัว)

Comment ในโค้ดยอมรับตรง ๆ ว่าเลือก "reload แทนการ sync state กลับ" เพื่อความง่าย — เป็น trade-off ที่ควรทบทวนใน Beta2

### 4.2 [P1] Feed อาจแสดงโพสต์ซ้ำ

`_loadMore()` ทำ `_items.addAll(items)` โดยไม่ dedupe และ pagination เป็น offset-based (`range(from, to)` เรียงตาม `created_at desc`) — ถ้ามีคนโพสต์ใหม่ระหว่างที่ผู้ใช้ scroll ทุก item จะเลื่อน offset ไป 1 ตำแหน่ง ทำให้ item สุดท้ายของหน้า N โผล่ซ้ำเป็น item แรกของหน้า N+1

ผลกระทบจริง: เห็นโพสต์เดียวกันสองครั้งติดกัน + `ValueKey` ซ้ำใน SliverList เดียวกัน (Flutter assert "Duplicate keys" ใน debug, state reuse ผิดตัวใน release)

### 4.3 [P2] state ไม่ sync ข้ามหน้าจอ

กด Like ในหน้า Home → เปิด Profile ตัวเอง → แท็บ "ถูกใจ" ไม่มีโพสต์นั้น จนกว่าจะ refresh เพราะแต่ละหน้าจอถือ state ของตัวเองแยกกัน ไม่มี shared cache/store

นี่เป็นผลโดยตรงจากการใช้ `setState` ล้วน — **ไม่แนะนำให้แก้ด้วยการเพิ่ม state management package ใน Beta2** (เป็น architectural rewrite ต้องขออนุมัติ) แต่ควรบันทึกไว้เป็นข้อจำกัดที่รู้ตัว

### 4.4 [P2] Loading state ไม่สม่ำเสมอ

- Profile: มี `ProfileSkeleton` เต็มรูปแบบ ✅
- Home feed: `CircularProgressIndicator` กลางจอเปล่า ❌
- หน้าอื่น ๆ: ผสมกันทั้งสองแบบ

Home คือหน้าจอที่ผู้ใช้เห็นบ่อยที่สุด แต่กลับได้ loading state ที่ด้อยที่สุด — ผิดลำดับความสำคัญ

### 4.5 [P2] Touch target ต่ำกว่ามาตรฐานของ design system ตัวเอง

`WynSpacing.touchTargetMin = 44.0` ถูกใช้ใน 27 จุดทั่วแอป **แต่ไม่ถูกใช้ใน `ActionMetric`** ซึ่งเป็นปุ่ม Like/Comment/ReDrop บนทุกการ์ดใน feed

คำนวณจริงจาก `action_metric.dart:64-68`: icon 17px + padding แนวตั้ง `space1` (4px) × 2 = **~25px** — ต่ำกว่ามาตรฐานของตัวเอง 43% บนปุ่มที่ผู้ใช้กดบ่อยที่สุดในทั้งแอป

### 4.6 [P2] ไม่มีการแยก "เน็ตหลุด" ออกจาก "server พัง"

ข้อความ error ทั้ง 20 แบบในแอปเป็นรูป "โหลด X ไม่สำเร็จ" ทั้งหมด ไม่มีจุดไหนบอกผู้ใช้ว่า "ไม่มีอินเทอร์เน็ต" — ผู้ใช้ที่เน็ตหลุดจะเข้าใจว่าแอปพัง

### 4.7 [P3] Motion แทบไม่มี

ทั้งแอป 245 ไฟล์ มี implicit animation แค่ 8 จุด (`AnimatedSwitcher` 3, `AnimatedContainer` 2, `AnimatedSize` 1, `AnimatedOpacity` 1, `AnimatedBuilder` 1) และ `HapticFeedback` แค่ 3 จุด

การกด Like บน feed ไม่มี animation และไม่มี haptic เลย — หัวใจแค่เปลี่ยนสีทันที ในแอประดับ mature ทุกตัว การกด Like คือ micro-interaction ที่ถูกขัดเกลาที่สุด

---

## 5. Performance Audit

### 5.1 [P1] 🔴 ปัญหาที่ใหญ่ที่สุด: รูปในตารางถูก decode ที่ขนาดเต็ม

- รูปที่อัปโหลดถูกบีบไว้ที่ **1600×1600** (`create_drop_screen.dart:413`) — ถูกต้องแล้วสำหรับหน้า detail
- แต่ grid ทั้งแอปเป็น **3 คอลัมน์** (`crossAxisCount: 3`) → ช่องละ ~130px บนจอ 390px
- ไม่มี `cacheWidth`/`cacheHeight` แม้แต่จุดเดียวในโค้ดทั้งหมด (ตรวจแล้ว: 39 จุดที่ใช้ `Image.network`, 0 จุดที่ใช้ `cacheWidth`)

**ผลกระทบเชิงตัวเลข:** รูป 1600×1600 decode เป็น bitmap = 1600 × 1600 × 4 bytes ≈ **10.2 MB ต่อรูป** — แต่แสดงผลจริงแค่ 130×130 (ต้องการ ~0.07 MB) เปลืองหน่วยความจำ **145 เท่า** ต่อรูป

หนึ่งหน้าของ Profile grid = 21 รูป ≈ **215 MB** ของ bitmap ที่ไม่จำเป็น → เป็นสาเหตุที่น่าจะทำให้แอปกระตุก/ถูกระบบฆ่าบนมือถือรุ่นกลาง และเป็นสาเหตุที่ตรงที่สุดกับข้อ 13 ของ audit brief ("Do not load unnecessarily large original images into the Feed")

### 5.2 [P1] Network waterfall — request ที่เป็นอิสระต่อกันถูกยิงเรียงกัน

**ตัวอย่างที่ชัดที่สุด — `view_profile_screen.dart:241-256`:**
```dart
final profile        = await fetchProfile(...);        // RTT 1
final followerCount  = await countFollowers(...);      // RTT 2
final followingCount = await countFollowing(...);      // RTT 3
final dropCount      = await countByAuthor(...);       // RTT 4
```
ทั้ง 4 ตัวไม่ขึ้นต่อกันเลย แต่ถูก await เรียงกัน → บนเน็ตมือถือ 200ms RTT = **800ms** แทนที่จะเป็น ~200ms

**จุดเดียวกันใน `home_repository.dart`** ทุก method (`fetchFeed`/`fetchTrending`/`fetchTopContent`/`fetchRankedFeed`/`fetchFollowingFeed`/`fetchRedropsByUser`) ยิง 5–6 request เรียงกัน (liked drops → liked pops → saved → redropped → poll votes → poll results) ทั้งที่เป็นอิสระต่อกันทั้งหมด → **feed ทุกหน้าช้ากว่าที่ควรเป็น 5–6 เท่าในส่วน round-trip**

### 5.3 [P1] For-You feed ยิง RPC หนักซ้ำทุกครั้งที่ scroll

`fetchRankedFeed()` เรียก `get_wynos_ranked_feed()` (คำนวณคะแนน 200 candidate ฝั่ง server) **ใหม่ทุกหน้า** — scroll 10 หน้า = คำนวณ 200 candidate ซ้ำ 10 รอบ = งาน server 2,000 candidate เพื่อแสดง 100 โพสต์

ซ้ำร้าย: ถ้าผลลัพธ์ระหว่างสองครั้งต่างกัน (มีคนโพสต์ใหม่/คะแนนเปลี่ยน) การ slice หน้า N จาก window ใหม่จะทำให้ item ซ้ำหรือหาย — ขัดกับ comment ในโค้ดเองที่อ้างว่า "paging เป็น deterministic"

### 5.4 [P1] Index ที่ขาดในฐานข้อมูล

มี index อยู่ 29 ตัว แต่ **ไม่มีตัวไหนอยู่บนตารางหลักของ social feed เลย** ตรวจแล้วทั้งไฟล์:

| Query ที่ใช้จริง | Index ที่มี | ผล |
|---|---|---|
| `home_feed` order by `created_at desc` | ❌ ไม่มี index บน `drops.created_at` | Seq Scan + Sort ทั้งตารางทุกครั้งที่โหลด feed |
| Profile grid: `drops where author_id = ? order by created_at desc` | ❌ | Seq Scan |
| `fetchFollowers`: `follows where following_id = ?` | ❌ (PK คือ `(follower_id, following_id)` ใช้ไม่ได้กับคอลัมน์ที่สอง) | Seq Scan ทั้งตาราง follow |
| `follower_count()` RPC | ❌ เหมือนกัน | Seq Scan |
| `fetchComments`: `drop_comments where drop_id = ?` | ❌ | Seq Scan |
| `fetchLikedByAuthor`: `drop_likes where user_id = ?` | ❌ (PK `(drop_id, user_id)`) | Seq Scan |
| block check `blocks where blocked_id = ?` | ❌ (PK `(blocker_id, blocked_id)`) | Seq Scan — **ถูกเรียกในทุก RLS policy ของทุกแถว** |
| `mutes where muted_id = ?` (อยู่ใน `home_feed` view เอง) | ❌ | Seq Scan ต่อแถว |
| `follow_requests where target_id = ?` | ❌ | Seq Scan |

ตอนนี้ยังไม่เจ็บเพราะข้อมูลน้อย แต่ **นี่คือระเบิดเวลาที่แน่นอน** — ทั้ง 9 query นี้จะช้าลงเป็นเชิงเส้นตามจำนวนผู้ใช้ และ `blocks`/`mutes` จะเจ็บก่อนเพื่อนเพราะถูกเรียกซ้ำในทุกแถวของทุก query

### 5.5 [P2] `home_feed` view หนักโดยโครงสร้าง

view นี้มี correlated subquery **8 ตัวต่อแถว** (like_count, liked_by top-3 + join profiles, comment_count, top_reply + join + นับ like ของ comment, redrop_count, image_count, `drop_view_count()`, `not exists mutes`) แล้ว `union all` กับฝั่ง Pop ที่มีชุดเดียวกัน

การแก้ที่ถูกต้องคือ denormalized counter column + trigger (เช่น `drops.like_count`) ซึ่งเป็น **architectural change ต้องขออนุมัติ Founder** → จัดเป็นข้อเสนอ ไม่ใช่งานที่ทำใน Beta2 นี้

### 5.6 [P2] `fetchComments()` ไม่มี pagination เลย

`drop_repository.dart:1035` — `select(...).eq('drop_id', dropId).order('created_at')` ไม่มี `.range()`/`.limit()` โพสต์ที่มี 5,000 comment จะโหลดทั้งหมดในคำขอเดียว แล้วส่ง id ทั้ง 5,000 ตัวไปเป็น query string ใน `_fetchLikedCommentIds` → **URL ยาวเกินขีดจำกัด → request ล้มเหลว → หน้า comment พังทั้งหน้า**

### 5.7 [P2] Storage ไม่ตั้ง cache header

ไม่มีจุดไหนใน 11 จุดที่ upload ที่ส่ง `cacheControl` → Supabase ใช้ default `max-age=3600` (1 ชั่วโมง) ทั้งที่ path ของรูป Drop เป็น unique/immutable (`{userId}/{timestamp}_{i}.{ext}`) และ avatar มี `?v=` cache-buster อยู่แล้ว → รูปเดิมถูกดาวน์โหลดซ้ำทุกชั่วโมงโดยไม่จำเป็น

---

## 6. Backend / API Audit

### 6.1 [P0] 🔴 PostgREST filter injection ใน Search

`profile_repository.dart:262`
```dart
.or('username.ilike.%$query%,display_name.ilike.%$query%')
```
`query` มาจากช่องค้นหาของผู้ใช้โดยตรง ถูกต่อดิบ ๆ เข้าไปใน **filter grammar ของ PostgREST**

- **บั๊กที่เห็นได้ทันที:** ค้นหาคำที่มี `,` `(` `)` เช่น "John, Jane" → filter พังทั้งชุด → 400 → ผู้ใช้เห็น "ค้นหาไม่สำเร็จ" ทั้งที่ระบบไม่ได้ล่ม
- **ความเสี่ยงด้านความปลอดภัย:** ผู้ใช้กำหนดเงื่อนไข filter เพิ่มเองได้ เช่นค้นหา `x,id.eq.<uuid>` เพื่อ enumerate ทีละแถว หรือ probe คอลัมน์อื่นบน `profiles`

**สิ่งที่ยืนยันว่านี่คือความผิดพลาด ไม่ใช่การออกแบบ:** `zoky_repository.dart:143-144` เขียน comment ไว้เองว่าเลือกใช้ `.ilike()` ตรง ๆ "แทนที่จะพับเข้า `.or()` filter DSL string เพื่อให้ query ถูก parameterize อย่างปลอดภัย" — คือทีมรู้หลักการนี้อยู่แล้ว แต่หน้า Search ของ Wynos ยังไม่ได้แก้ตาม

### 6.2 [P1] 🔴 Bug: For-You feed จับคู่คะแนนผิดตัว

`home_repository.dart:339-431`
```dart
final rawRows = await _client.rpc('get_wynos_ranked_feed');   // ยังไม่กรอง Pop
final rows = rawRows.map(...).where((row) => row['content_type'] != 'pop');  // กรองแล้ว
final items = rows.map(...).toList();                         // มาจาก rows (กรองแล้ว)
...
for (var i = 0; i < items.length; i++)
  FeedDiversityCandidate(
    key: keyFor(items[i]),                                    // index ของ list ที่กรองแล้ว
    wynosScore: (rawRows[i]['wynos_score'] as num).toDouble(), // 🔴 index ของ list ที่ยังไม่กรอง
    isDiscovery: rawRows[i]['is_discovery'] as bool,           // 🔴
  );
```
ทันทีที่มี Pop สักแถวเดียวใน 200 candidate ทุก item หลังจากนั้นจะได้ `wynos_score`/`is_discovery` ของ item อื่น → **ลำดับของฟีด "สำหรับคุณ" ผิดทั้งหมด** และ Feed Diversity ทำงานบนข้อมูลผิด

เป็นบั๊กแบบเงียบ 100% (ไม่ throw, ไม่มี log, ฟีดยังแสดงผลปกติ) จึงไม่มีทางเจอจากการทดสอบด้วยตา — และ WYN-102 (ซ่อน Pop) คือ commit ที่สร้างบั๊กนี้ขึ้นมา

### 6.3 [P1] Like/Save/ReDrop ไม่กันการกดซ้ำ และไม่ idempotent

`drop_repository.dart:933` — `toggleLike` แปลง state เป็น INSERT หรือ DELETE ตรง ๆ ส่วนฝั่ง UI (`home_feed_screen.dart:305`) ไม่มี in-flight guard เลย

sequence ที่เกิดจริงเมื่อผู้ใช้กดรัว 3 ครั้ง:
1. tap 1 → UI liked → `INSERT`
2. tap 2 → UI unliked → `DELETE` (request 1 อาจยังไม่ถึง server)
3. tap 3 → UI liked → `INSERT` ที่ 2

ถ้า request ถึงไม่เรียงลำดับ → DB จบที่ unliked แต่ UI แสดง liked ; หรือ INSERT ซ้ำชน PK `(drop_id, user_id)` → error 23505 → `catch` ย้อน UI กลับเป็น "ยังไม่ถูกใจ" ทั้งที่ **server มีข้อมูล liked อยู่จริง** → UI กับ server ไม่ตรงกันจนกว่าจะ refresh

หมายเหตุ: `view_profile_screen.dart` มี `_isFollowActionInFlight` guard ทำถูกต้องแล้ว — คือ pattern ที่ถูกมีอยู่ในโค้ดนี้แล้ว แค่ไม่ได้ใช้ที่ปุ่มที่ถูกกดบ่อยที่สุด

### 6.4 [P2] `setState` หลัง `await` โดยไม่เช็ค `mounted` — 18 จุด

สแกนพบ 18 จุดใน 15 ไฟล์ (มากสุด: `create_drop_screen.dart` 3 จุด) รวมถึงใน `home_feed_screen._loadInitial/_loadMore` และ `notification_list_screen._loadInitial/_loadMore`

ผลกระทบ: ถ้าผู้ใช้กด back หรือสลับแท็บระหว่างที่ request ค้างอยู่ → `setState() called after dispose()` → exception ขึ้น console (release: ถูกกลืน แต่เป็น error ที่ไม่ควรมี) เป็น pattern ที่ส่วนใหญ่ของโค้ดทำถูกแล้ว แต่ 18 จุดนี้หลุด

### 6.5 [P2] Offset pagination ทุกที่

ทุก repository ใช้ `.range(from, to)` — โดยธรรมชาติจะซ้ำ/ข้ามเมื่อมีข้อมูลใหม่แทรกด้านบน (feed, notification, comment) การย้ายไป cursor pagination เป็นงานที่ถูกต้องแต่กระทบหลาย layer → เสนอเป็น Beta3

---

## 7. Database Audit

| หัวข้อ | ผล |
|---|---|
| Schema ordering (SCHEMA-001 regression) | ✅ ผ่าน |
| Foreign key | ✅ ครบทุกความสัมพันธ์ |
| Check constraint (ความยาวข้อความ, ค่าที่อนุญาต) | ✅ มีครบและตรงกับ client validation |
| RLS เปิดใช้งาน | ✅ ทุกตาราง |
| จำนวน policy | 195 (SELECT 77 / INSERT 71 / DELETE 28 / UPDATE 18 / ALL 1) |
| **UPDATE policy ที่ขาด `WITH CHECK`** | ❌ **6 ตัว** — ดู §8.1 |
| Index บนตารางหลักของ social graph/feed | ❌ ขาดทั้งหมด — ดู §5.4 |
| Denormalized counter | ❌ ไม่มี (นับด้วย subquery ทุกครั้ง) — ดู §5.5 |
| Soft delete | ✅ มี (`deleted_at` + RLS ซ่อน) |

---

## 8. Security Audit

โดยรวม **ท่าทีด้านความปลอดภัยของ WYNOS แข็งแรงกว่ามาตรฐานของแอประดับนี้มาก** — authorization อยู่ฝั่ง server จริง, ข้อมูลส่วนตัวแยกตาราง, ไม่มี secret ใน repo (`Env` ใช้ `String.fromEnvironment` ล้วน), storage policy จำกัดโฟลเดอร์ตาม `auth.uid()`, moderation ใช้ SECURITY DEFINER RPC ที่คืนเฉพาะ id ไม่คืนเหตุผล/ผู้ตรวจ

พบ 3 ประเด็นที่ต้องแก้:

### 8.1 [P0] UPDATE policy 6 ตัวไม่มี `WITH CHECK` → ย้ายความเป็นเจ้าของแถวได้

ใน PostgreSQL `USING` คุมว่า "แถวไหนถูกแก้ได้" ส่วน `WITH CHECK` คุมว่า "แถวหลังแก้ต้องหน้าตาอย่างไร" — ถ้าไม่มี `WITH CHECK` ผู้ใช้แก้แถวของตัวเองให้กลายเป็นของคนอื่นได้

| ตาราง | policy | สิ่งที่ทำได้ |
|---|---|---|
| `public.profiles` | Users can update their own profile | เปลี่ยน `id` ของโปรไฟล์ตัวเองไปเป็น uuid ของ auth user ที่ยังไม่มีแถว profile → ยึดตัวตน |
| `public.profile_private` | Users can update their own private profile fields | เหมือนกัน กับข้อมูลวันเกิด/สถานะ onboarding |
| `public.cart_items` | Users can update their own cart items | ย้ายสินค้าในตะกร้าตัวเองไปใส่ตะกร้าคนอื่น (`user_id` ใหม่) |
| `public.clubs` | Club owners and admins can update club info | — |
| `public.club_posts` | Club staff can pin or unpin club posts | ย้ายโพสต์ไป Club อื่นที่ตัวเองไม่มีสิทธิ์ |
| `storage.objects` | Users can update their own avatar | ย้ายไฟล์ออกจากโฟลเดอร์ตัวเอง |

การแก้เป็นการ **เพิ่มความเข้มงวด** ล้วน ไม่มีทางทำให้ flow ที่ถูกต้องพัง — แต่เป็น "สถาปัตยกรรมความปลอดภัย" ตาม `RULES.md` → **ต้องขออนุมัติ Founder ก่อนนำขึ้น production**

### 8.2 [P0] Search filter injection — ดู §6.1

### 8.3 [P2] ไม่มี rate limit ฝั่ง client และไม่มี global error boundary

- ไม่มี debounce/throttle บนปุ่มที่ยิง write (`main.dart` ไม่ตั้ง `FlutterError.onError` / `ErrorWidget.builder`)
- exception ที่หลุดใน `build()` จะกลายเป็นกล่องแดง/เทาบนหน้าจอผู้ใช้จริง
- `record_drop_view` มี velocity cap ฝั่ง server แล้ว ✅ แต่ like/comment/follow ยังไม่มี — เป็นความพร้อมสำหรับ rate limit (`rate-limit readiness`) ที่ยังขาด

---

## 9. รายละเอียดเล็ก ๆ ที่ขาดในฟีเจอร์ที่มีอยู่ (สำคัญที่สุดต่อความรู้สึก "สมบูรณ์")

รายการนี้คือคำตอบตรง ๆ ของคำถาม "อะไรทำให้ฟีเจอร์เดียวกันในแอประดับ mature รู้สึกเสร็จกว่า":

| # | รายละเอียดที่ขาด | ที่ไหน | ทำไมสำคัญ | P |
|---|---|---|---|---|
| 1 | Like ไม่มี animation และไม่มี haptic | `ActionMetric` ทุกการ์ด | เป็น interaction ที่ถูกกดบ่อยที่สุดในแอป — ทุกแอปคู่แข่งขัดเกลาจุดนี้ที่สุด | P3 |
| 2 | ปุ่มใน feed เล็กกว่ามาตรฐานตัวเอง 43% | `ActionMetric` | กดพลาดบ่อยบนมือถือ | P2 |
| 3 | โหลดหน้าถัดไปไม่สำเร็จแล้วเงียบสนิท | `_loadMore()` ทุกหน้าจอ | ผู้ใช้เห็น spinner ค้างแล้วไม่มีอะไรเกิดขึ้น ไม่รู้ว่าต้องทำอะไร | P2 |
| 4 | รูปในตารางไม่มี loading/error placeholder | `drop_grid_tile.dart:73` และ grid อื่น | ตารางกะพริบขาวตอน scroll เร็ว, รูปเสียกลายเป็นช่องว่างเปล่า | P2 |
| 5 | Avatar โหลดไม่ขึ้น = วงกลมสีเปล่า ไม่มีตัวอักษรย่อ | `avatar_circle.dart:37` (fallback ทำงานเฉพาะตอน url เป็น null ไม่ใช่ตอนโหลดล้มเหลว) | หน้า follower list เต็มไปด้วยวงกลมเปล่าเมื่อเน็ตไม่ดี | P2 |
| 6 | ไม่มี skeleton บน Home | `home_feed_screen._buildBodySlivers` | หน้าที่ใช้บ่อยที่สุดได้ loading ที่ด้อยที่สุด ในขณะที่ Profile มี skeleton เต็มรูปแบบแล้ว | P2 |
| 7 | scroll position หายหลังกลับจาก detail | §4.1 | ทำลาย flow การไถฟีดทั้งหมด | P1 |
| 8 | ไม่แยก "เน็ตหลุด" จาก "server error" | ทั้งแอป | ผู้ใช้โทษแอปทั้งที่เป็นเน็ตตัวเอง | P2 |
| 9 | ไม่มีข้อความยืนยันหลังทำสำเร็จในบางที่ | like/save (มีแค่ hide ที่มี snackbar + undo) | ไม่จำเป็นสำหรับ like แต่ save ควรมี | P3 |
| 10 | comment โหลดทั้งหมดไม่มี "ดูเพิ่มเติม" | §5.6 | พังจริงเมื่อโพสต์ดัง | P1 |

---

## 10. Beta2 Improvements ที่แนะนำ (อยู่ในขอบเขตปัจจุบัน)

ทั้งหมดเป็น **การปรับปรุงฟีเจอร์ที่มีอยู่แล้ว (ประเภท A)** ไม่มีฟีเจอร์ใหม่ ไม่มีการเปลี่ยนสถาปัตยกรรม

| # | งาน | ประเภท | P | สถานะ (2026-09-03) |
|---|---|---|---|---|
| B2-01 | แก้ PostgREST filter injection ใน `searchProfiles` | A | P0 | ✅ ทำแล้ว + test |
| B2-02 | เพิ่ม `WITH CHECK` ใน UPDATE policy 6 ตัว | A | P0 | ⏸️ **รออนุมัติ Founder** — SQL พร้อมที่ `supabase/pending_approval_rls_with_check.sql` |
| B2-03 | แก้ index mismatch ใน `fetchRankedFeed` | A | P1 | ✅ ทำแล้ว + test |
| B2-04 | cache ranked window ต่อรอบการโหลด | A | P1 | ✅ ทำแล้ว |
| B2-05 | `Future.wait` แทน await เรียงกัน | A | P1 | ✅ ทำแล้ว (profile + ทุก fetch ของ home) |
| B2-06 | `cacheWidth` ให้ grid/thumbnail/avatar | A | P1 | ✅ ทำแล้ว + test (`NetworkThumbnail`) |
| B2-07 | dedupe item ตอน `_loadMore` | A | P1 | ✅ ทำแล้ว + test |
| B2-08 | กันการกดซ้ำ + idempotent write | A | P1 | ✅ ทำแล้ว + test (serialize ต่อแถว ไม่ทิ้ง tap) |
| B2-09 | เพิ่ม index ที่ขาด | A | P1 | ✅ เขียนใน `schema.sql` แล้ว — **ต้อง apply เอง** |
| B2-10 | pagination ให้ comment | A | P1 | ✅ ทำแล้ว + test (50 ต่อหน้า) |
| B2-11 | คืน scroll position หลังกลับจาก detail | A | P1 | ✅ ทำแล้ว + test |
| B2-12 | ขยาย touch target ของ `ActionMetric` เป็น 44 | A | P2 | ✅ ทำแล้ว |
| B2-13 | skeleton ให้ Home feed | A | P2 | ✅ ทำแล้ว + test |
| B2-14 | retry ที่มองเห็นได้เมื่อ `_loadMore` ล้มเหลว | A | P2 | ✅ ทำแล้ว + test |
| B2-15 | loading/error placeholder ให้รูป | A | P2 | ⚠️ ทำแล้วบางส่วน — grid tile + avatar เสร็จ ส่วน club card/trending tile/saved row ยังเป็น `Image.network` เปล่า |
| B2-16 | `mounted` guard | A | P2 | ⚠️ ทำแล้ว 11 จุดฝั่ง Wynos — เหลือ 4 จุดใน `features/zoky/` (คนละ track) |
| B2-17 | `cacheControl` ตอน upload | A | P2 | ✅ ทำแล้ว (ทุก path ที่ immutable — ไม่แตะ avatar โดยตั้งใจ) |
| B2-18 | แยกข้อความ error เน็ตหลุด/server | A | P2 | ❌ ยังไม่ทำ |
| B2-19 | global error boundary | A | P2 | ✅ ทำแล้ว (release only) |
| B2-20 | animation + haptic ตอนกด Like | A | P3 | ✅ ทำแล้ว |

### ตารางเดิม (รายละเอียดความเสี่ยงตอนวางแผน)

| # | งาน | ประเภท | P | ความเสี่ยง |
|---|---|---|---|---|
| B2-01 | แก้ PostgREST filter injection ใน `searchProfiles` | A | P0 | ต่ำ |
| B2-02 | เพิ่ม `WITH CHECK` ใน UPDATE policy 6 ตัว | A | P0 | ต่ำ (ต้องขออนุมัติ) |
| B2-03 | แก้ index mismatch ใน `fetchRankedFeed` | A | P1 | ต่ำ |
| B2-04 | cache ranked window ต่อรอบการโหลด (เลิกยิง RPC ซ้ำทุกหน้า) | A | P1 | ต่ำ |
| B2-05 | `Future.wait` แทน await เรียงกัน (profile + home repository) | A | P1 | ต่ำ |
| B2-06 | `cacheWidth` ให้ทุก grid/thumbnail/avatar | A | P1 | ต่ำ |
| B2-07 | dedupe item ตอน `_loadMore` | A | P1 | ต่ำ |
| B2-08 | in-flight guard + idempotent write สำหรับ like/save/redrop | A | P1 | ต่ำ |
| B2-09 | เพิ่ม index ที่ขาด 9 ตัว | A | P1 | ต่ำ (additive) |
| B2-10 | pagination ให้ comment | A | P1 | กลาง (แตะ UI) |
| B2-11 | คืน scroll position หลังกลับจาก detail | A | P1 | กลาง |
| B2-12 | ขยาย touch target ของ `ActionMetric` เป็น 44 | A | P2 | ต่ำ |
| B2-13 | skeleton ให้ Home feed | A | P2 | ต่ำ |
| B2-14 | retry ที่มองเห็นได้เมื่อ `_loadMore` ล้มเหลว | A | P2 | ต่ำ |
| B2-15 | loading/error placeholder ให้รูปใน grid + avatar | A | P2 | ต่ำ |
| B2-16 | `mounted` guard ครบ 18 จุด | A | P2 | ต่ำ |
| B2-17 | `cacheControl` ตอน upload | A | P2 | ต่ำ |
| B2-18 | แยกข้อความ error เน็ตหลุด/server | A | P2 | ต่ำ |
| B2-19 | global error boundary (`ErrorWidget.builder` + `FlutterError.onError`) | A | P2 | ต่ำ |
| B2-20 | animation + haptic ตอนกด Like | A | P3 | ต่ำ |

---

## 10.1 ผลการ implement (Phase 3) และการตรวจ regression

**Gate ที่รันจริงทุกครั้งหลังแก้ (ไม่ใช่การอ้างลอย ๆ):**

| การตรวจ | ก่อนเริ่ม | หลังจบ |
|---|---|---|
| `flutter analyze` | ✅ 0 issues | ✅ 0 issues |
| `flutter test` | ✅ 1,048 ผ่าน | ✅ **1,078 ผ่าน** (+30 test ใหม่) |
| `flutter build web --release` | — | ✅ build สำเร็จ (main.dart.js 4.2 MB) |
| `python3 supabase/check_schema_ordering.py` | ✅ OK | ✅ OK |

**ไม่มี test เดิมตัวไหนถูกแก้หรือลบ ยกเว้น 1 ตัว:** `avatar_circle_test.dart` ที่ assert ว่า `backgroundImage` เป็น `NetworkImage` ตรง ๆ — เปลี่ยนเป็น assert `ResizeImage` ที่ห่อ `NetworkImage` เพราะการห่อคือตัวการแก้ปัญหาหน่วยความจำโดยเจตนา (ยังคง assert ว่าข้างในเป็น `NetworkImage` เหมือนเดิม)

**สิ่งที่ทดสอบไว้เป็น regression protection ของงานรอบนี้ (30 test):**

- `quotePostgrestFilterValue` — comma/quote/backslash/วงเล็บ (6)
- `rankedCandidateRows` — คะแนนไม่เลื่อนตำแหน่งเมื่อมีแถวถูกกรองออก (5)
- `decodeWidthFor` + `NetworkThumbnail` — ขนาด decode และ placeholder เมื่อโหลดล้มเหลว (10)
- `AvatarCircle` — decode ตามขนาดจริง + fallback ตัวอักษรเมื่อรูปโหลดไม่สำเร็จ (2)
- Home feed — ไม่แสดงโพสต์ซ้ำ, tap ซ้อนถูก queue ไม่ race, กลับจาก detail แล้ว scroll position คงเดิม, retry เมื่อ load-more ล้ม, skeleton ตอนโหลดครั้งแรก (5)
- Drop detail — comment pagination ทั้งกรณีมีหน้าถัดไปและไม่มี (2)

**สิ่งที่ยัง "ยังไม่เสร็จ" อย่างตรงไปตรงมา:**

1. **B2-02 (P0)** — ยังไม่ apply เพราะเป็น security architecture ต้องรออนุมัติ Founder ตาม `RULES.md` ช่องโหว่ยังเปิดอยู่จนกว่าจะได้รับอนุมัติและ apply
2. **B2-09 (P1)** — index เขียนลง `schema.sql` แล้วแต่ **ยังไม่ได้รันกับ production** (session นี้ไม่มี credential ของ Supabase) ต้องมีคนรันไฟล์ให้
3. **B2-15/B2-16** — ทำบางส่วนตามที่ระบุในตาราง
4. **B2-18** — ยังไม่ทำ
5. **ZOKY (`app/lib/features/zoky/`)** — ไม่แตะเลยตามขอบเขต audit แต่พบว่ามีปัญหาแบบเดียวกันอยู่ 4 จุด (`setState` หลัง `await` โดยไม่เช็ค `mounted` ที่ `zoky_order_detail_screen.dart` 2 จุด, `review_form_sheet.dart`, `zoky_product_results_tab.dart`) และรูปสินค้าใน grid 2 คอลัมน์ก็ไม่มี `cacheWidth` เช่นกัน — ส่งต่อให้เจ้าของ track นั้น

⸻

## 11. ข้อเสนอที่อยู่นอกขอบเขต Beta2 (ห้าม implement ตอนนี้)

| # | ข้อเสนอ | ประเภท | เหตุผลที่ไม่ทำตอนนี้ |
|---|---|---|---|
| O-01 | Denormalized counter (`drops.like_count` + trigger) แทน correlated subquery ใน `home_feed` | B | เปลี่ยน schema หลัก + ต้อง backfill ข้อมูล production → ต้องอนุมัติ |
| O-02 | Cursor-based pagination ทั้งแอป | B | กระทบทุก repository + ทุกหน้าจอ = rewrite |
| O-03 | State management (Riverpod/Bloc) เพื่อ sync state ข้ามหน้าจอ | C | Major architecture change |
| O-04 | List virtualization ขั้นสูง / `flutter_cache_manager` | B | `CachedNetworkImage` เคยลองแล้วพังบน Flutter Web (ดู comment `home_drop_card.dart:426`) |
| O-05 | Image CDN transform (resize ฝั่ง server ผ่าน Supabase Image Transformation) | B | เป็นทางแก้ที่ถูกต้องกว่า `cacheWidth` แต่ต้องเปิดฟีเจอร์เสียเงินฝั่ง Supabase → Founder ตัดสิน |
| O-06 | Offline mode / local cache | C | ฟีเจอร์ใหม่ นอกขอบเขต |
| O-07 | Rate limiting ฝั่ง server สำหรับ like/comment/follow | B | ต้องออกแบบ policy ร่วมกับ Founder |
| O-08 | Video/Pop กลับมา | C | Founder สั่งพักไว้ (WYN-102) |
| O-09 | เนื้อหาเอกสารกฎหมายจริง | — | ต้องใช้ทนายความ (มี APPROVAL_REQUIRED ค้างอยู่แล้ว) |

---

## 12. ลำดับการ implement ที่แนะนำ

**P0 — ต้องแก้ก่อน (ความปลอดภัย + ข้อมูล)**
1. B2-01 Search filter injection
2. B2-02 `WITH CHECK` ทั้ง 6 policy *(ต้องได้อนุมัติ Founder ก่อน apply ขึ้น production)*

**P1 — ผลกระทบสูงต่อความถูกต้องและความเร็ว**
3. B2-03 index mismatch ใน ranked feed
4. B2-08 in-flight guard + idempotent write
5. B2-07 dedupe feed
6. B2-06 `cacheWidth` (ผลตอบแทนต่อความเสี่ยงสูงที่สุดในรายการทั้งหมด)
7. B2-05 `Future.wait`
8. B2-04 cache ranked window
9. B2-09 index ที่ขาด
10. B2-11 คืน scroll position
11. B2-10 comment pagination

**P2 — คุณภาพและความสม่ำเสมอ**
12. B2-16 → B2-12 → B2-15 → B2-13 → B2-14 → B2-17 → B2-18 → B2-19

**P3 — ขัดเงา**
13. B2-20 motion + haptic

---

## 13. Final Quality Gate — สถานะ ณ ตอนจบ Phase 1

| คำถาม | คำตอบตรง ๆ |
|---|---|
| ทุกฟีเจอร์ที่มีรู้สึกสมบูรณ์ไหม | ส่วนใหญ่ใช่ — ยกเว้น Home feed, comment, และ image pipeline |
| ทุก interaction หลักมี loading/success/empty/error ครบไหม | ครบ 49 หน้าจอมี error state + 72 จุดมีปุ่มลองใหม่ — ขาดแค่ `_loadMore` ที่เงียบ |
| แอปยังลื่นระหว่าง scroll ไหม | **ไม่ — นี่คือจุดอ่อนที่ใหญ่ที่สุด** (§5.1 รูป 1600px ในช่อง 130px) |
| request ที่ล้มเหลวกู้คืนได้ไหม | ได้ในระดับหน้าจอ แต่ไม่ได้ในระดับ optimistic write (§6.3) |
| client state ตรงกับ server ไหม | ไม่เสมอไป — like ที่กดรัวและการเปลี่ยนแปลงข้ามหน้าจอ |
| permission บังคับฝั่ง server ไหม | **ใช่ แข็งแรงมาก** — ยกเว้น `WITH CHECK` 6 จุด |
| ใช้งานบนมือถือได้ดีไหม | ได้ — ยกเว้น touch target ของปุ่มหลักใน feed |
| ทุกหน้าจอรู้สึกเป็น product เดียวกันไหม | ใช่ 85% — loading state และ motion คือส่วนที่ยังไม่สม่ำเสมอ |
