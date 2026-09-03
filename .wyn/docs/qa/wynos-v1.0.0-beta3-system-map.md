# WYNOS v1.0.0 Beta3 — System Map

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta3-polish-performance-aes6ld` — push ขึ้น feature branch แล้ว · **ยังไม่เปิด PR · ยังไม่ merge · ยังไม่ deploy**
> ขอบเขต: Phase 0–1 ของ Beta3 (Repository Audit + System Map) — อ่านระบบให้เข้าใจ **ก่อน** แก้
> Environment: Flutter 3.47.1 (SDK เดียวกับ CI และ production build) · PostgreSQL 16.13 ในเครื่อง
> **ไม่มี Supabase production credential ใน session นี้** — ทุกข้อความในเอกสารชุด Beta3 ติดป้ายว่าตรวจที่ไหน

เอกสารนี้อธิบายระบบ **ตามที่มันเป็นก่อน Beta3** พร้อมชี้จุดที่เป็นปัญหาจริง
รายละเอียดของสิ่งที่แก้อยู่ใน `wynos-v1.0.0-beta3-ux-audit.md` และ `wynos-v1.0.0-beta3-performance.md`

---

## 1. ภาพรวมสถาปัตยกรรม

```
Flutter app (app/)                 Supabase
┌──────────────────────┐          ┌─────────────────────────┐
│ presentation/        │          │ views                   │
│   *_screen.dart      │          │   home_feed (UNION ALL) │
│   widgets/*.dart     │  REST/   │   saved_feed            │
│         ▲            │  RPC     │                         │
│         │            │ ───────► │ tables + RLS            │
│ data/                │          │   drops, drop_images    │
│   *_repository.dart  │          │   drop_likes, saves     │
│   *.dart (models)    │          │   redrops, follows, ... │
└──────────────────────┘          │ RPC (SECURITY DEFINER)  │
                                  │   get_wynos_ranked_feed │
                                  │   get_poll_results, ... │
                                  └─────────────────────────┘
```

3 แอปใน repo เดียว: `app/` (WYNOS — ตัวที่ Beta3 พูดถึง), `seller_app/` (ZOKY), `admin/`
Beta3 แตะเฉพาะ `app/` เท่านั้น

**Layering** — feature-first, 2 ชั้นต่อ feature: `data/` (repository + model) และ `presentation/` (screen + widget)
ไม่มี state-management library ทั้ง repo: ทุกหน้าใช้ `StatefulWidget` + `setState`
repository ถูกสร้างที่ `RootShell` แล้วส่งลงมาทาง constructor
**นี่ไม่ใช่ปัญหา และ Beta3 ไม่แตะ** — 249 ไฟล์ Dart, 54,095 บรรทัด, การเปลี่ยน state management คือ rewrite architecture ซึ่งข้อ 0 ห้ามไว้

---

## 2. Routes หลัก

`RootShell` ถือ 4 tab ใน `IndexedStack` (state คงอยู่ข้ามการสลับ tab) + ปุ่ม "+" ที่ push ทับ

| Bottom nav | Widget | Key / การ remount |
|---|---|---|
| 0 Home | `HomeFeedScreen` | `ValueKey('home_$_homeVersion')` — remount **เฉพาะ** หลังโพสต์ใหม่สำเร็จ |
| 1 Search | `SearchScreen` | ไม่มี key — state คงอยู่ตลอด session |
| 2 (+) | `CreateDropScreen` | push route ไม่ใช่ tab |
| 3 Notifications | `NotificationListScreen` | `ValueKey('notifications_$_notificationsVisitKey')` — remount **ทุกครั้งที่กด tab** (ตั้งใจ: initState คือจุดที่ mark read) |
| 4 Profile | `ViewProfileScreen` | `ValueKey('profile_$_profileVisitKey')` — remount ทุกครั้งที่กด tab |

**Route ที่ push ทับ** (Navigator เดียว, ไม่มี nested navigator ต่อ tab):
`DropDetailScreen` · `ViewProfileScreen` (คนอื่น) · `ClubPage` · `ClubPostDetailScreen` · `HashtagFeedScreen` · `BookmarksScreen` · `DropImageViewer` · `QuoteRedropScreen` · `ChatInboxScreen` · `SettingsScreen`

---

## 3. Feed flow

```
HomeFeedScreen                    HomeRepository
  _feedMode ─┬─ forYou    ──────► fetchRankedFeed(page)
             │                      page 0 → _buildRankedWindow()
             │                        rpc get_wynos_ranked_feed  (200 candidates)
             │                        → rankedCandidateRows()  (กรอง pop, พก score)
             │                        → _fetchViewerState()
             │                        → applyFeedDiversity()
             │                        → cache ที่ _rankedWindow
             │                      page 1..n → slice จาก window เดิม (ไม่ยิงซ้ำ)
             ├─ following ──────► fetchFollowingFeed(page)
             │                      follows → home_feed .or(author|redropper) .range()
             └─ fromYourClubs ─► FromYourClubsFeed (widget แยก, state ของตัวเอง)
```

* `pageSize = 10` · เพดาน ranked window = 200 รายการ (`_rankedCandidateLimit`)
* **Pagination เป็นแบบ offset** ทั้งระบบ ไม่ใช่ cursor — ผลที่ตามมาอยู่ใน §8
* `_seenKeys` ใน `HomeFeedScreen` กันแถวซ้ำข้ามหน้า — key คือ `'$id:${redropId ?? ""}'`
  เพราะ Drop เดียวปรากฏได้ 2 ครั้ง (ตัวมันเอง + ReDrop ของใครสักคน)

**Back จาก Detail:** `_openDrop()` → `await push` → `_refreshRow(item)` → `fetchItemById()`
รีเฟรชแถวเดียว ไม่แตะ scroll / ไม่แตะหน้าที่โหลดมาแล้ว (แก้ไปแล้วตั้งแต่ Beta2)

---

## 4. Post flow (1 โพสต์)

โครงสร้างที่ทุกจอควรใช้ร่วมกัน — และก่อน Beta3 ยังไม่ใช่:

```
Profile row  →  Text (caption)  →  Media  →  Actions  →  [Comments เฉพาะ Detail]
```

| จอ | Widget | Media |
|---|---|---|
| Home feed (รูปเดียว) | `HomeDropCard` | สัดส่วนจริง clamp 4:5..1.91:1, สูงไม่เกิน 75% ของจอ |
| Home feed (หลายรูป) | `HomeFeedImagePeekCarousel` | ListView แนวนอน, การ์ดกว้าง 82%, 4:5, มุมโค้ง 16 |
| Post Detail | `DropImageGallery` | **1:1 ตายตัว + BoxFit.cover** ← ต้นตอข้อ 4/5 ของ Founder |
| Profile — โพสต์ / รีโพสต์ / ถูกใจ | `HomeDropCard` (ตัวเดียวกับ Feed) | **เหมือน Feed ทุกอย่าง** — เป็น ListView ของการ์ดเต็มความกว้าง ไม่ใช่ Grid มาตั้งแต่ WYN-013 |
| Profile — Saved / Draft | `SavedGridTile` / `DraftGridTile` | Grid 3 คอลัมน์ (เข้าจากแถวไอคอน ไม่ใช่แท็บหลัก) |
| Search — แท็บโพสต์ | `DropGridTile` → `NetworkThumbnail` | Grid 3 คอลัมน์ จัตุรัส |
| Club post | `ClubPostImages` | 1:1 (`club_posts` ไม่เก็บ dimension เลย จึงไม่มีอะไรให้คำนวณ) |
| Full screen | `DropImageViewer` | pinch-to-zoom |

---

## 5. Image flow

```
CreateDropScreen
  เลือกรูป (1-9) → บีบเป็น 1600x1600 (WYN-103) → upload storage
  → drops.image_url = รูปแรก, drops.image_width/height = ขนาดจริงของรูปแรก
  → drop_images: 1 แถวต่อรูป (position 0..8) + image_width/height ต่อรูป

อ่านกลับ
  home_feed.image_count = (select count(*) from drop_images where drop_id = d.id)
  URL ของรูปที่ 2-9  →  DropRepository.fetchDropImages(dropId)  ← เรียกทีละโพสต์
```

`drop_images.image_width/image_height` มีข้อมูลอยู่ **แต่ยังไม่มีใครอ่าน** (บันทึกไว้ใน future ideas)
`drops` ที่สร้างก่อน WYN-093 ไม่มี dimension → ทุกจุดใช้ fallback 1:1

---

## 6. Auth flow

```
main() → Supabase.initialize → AuthGate
  ├─ ไม่มี session → AuthScreen (Google / email OTP)
  ├─ มี session แต่ยัง onboard ไม่จบ → OnboardingFlow
  └─ พร้อม → RootShell (สร้าง repository ทุกตัวที่นี่ที่เดียว)
Guest mode: anonymous session + requireRealAccount() ที่จุดที่ต้องมีตัวตนจริง
```

---

## 7. Database dependencies

`public.home_feed` = `drops ∪ pops ∪ redrops-of-drops` (`security_invoker = true` → RLS ของตารางต้นทางบังคับใช้)
Column ถูก **ต่อท้ายเท่านั้น** ทุกครั้ง (WYN-093 → image_width/height, WYN-097/098 → audience/location, WYN-092 → image_count) — เป็นกติกาที่มาจากเหตุการณ์จริงใน `DECISIONS.md` ห้ามแทรกกลาง

`schema.sql` มี `create or replace view public.home_feed` **สะสม 6 ครั้ง** ในไฟล์เดียว
คำนิยามที่มีผลจริงคืออันสุดท้าย (บรรทัด 12063) — อ่านผิดครั้งเดียวคือแก้ผิดตัว

**ตรวจแล้วใน session นี้:** โหลด `schema.sql` เข้า PostgreSQL 16.13 สดพร้อม Supabase stub → **0 ERROR**

---

## 8. จุดที่เป็นปัญหาจริง (พบใน Phase 0–1)

จัดลำดับตามผลที่ผู้ใช้เจอ ไม่ใช่ตามความยากในการแก้

| # | จุด | อาการ | ข้อของ Founder |
|---|---|---|---|
| B3-1 | `DropImageGallery` บังคับ 1:1 + cover | รูปตั้ง 4:5 โดนตัดหัวตัดท้ายทันทีที่เปิดโพสต์ ทั้งที่ Feed แสดงเต็ม | 4, 5 |
| B3-2 | `DropDetailScreen` ใช้ `Scaffold appBar:` ตรึง | กินจอ ~57px ที่ไม่เคยคืน บนหน้าที่มีหน้าที่แสดงโพสต์เดียวให้ใหญ่ที่สุด | 5 |
| B3-3 | 4 จอเรียก `_loadInitial()`/`_load()` หลัง pop จาก Detail | `_isLoadingInitial = true` → ลิสต์กลายเป็น spinner, ListView ถูกทำลาย, scroll หาย, หน้าที่ page มาแล้วถูกทิ้ง | 6, 15 |
| B3-4 | `HomeFeedImagePeekCarousel._load()` ใน `initState` | N+1: หน้าที่มีโพสต์หลายรูป 8 โพสต์ = 8 request เพิ่ม ยิงหลังหน้าขึ้นแล้ว รูปสลับเป็น carousel ใต้นิ้วทีละอัน | 9, 25 |
| B3-5 | `DropRepository` ทุก fetch path `await` 4 lookup เรียงกัน | 4 round trip ก่อนการ์ดแรกจะขึ้น ทั้งที่ 4 query ไม่ขึ้นต่อกันเลย (`HomeRepository` แก้ปัญหาเดียวกันนี้ไปแล้ว) | 9, 25 |
| B3-6 | `Image.network` ดิบใน Feed / Detail / Club carousel | decode เต็ม 1600x1600 = bitmap ~10MB/รูป ไม่ว่ากล่องจะเล็กแค่ไหน | 10 |
| B3-7 | 4 ลิสต์ append หน้าใหม่แบบไม่กันซ้ำ ทั้งที่ใส่ `ValueKey` | ถ้ามีคนโพสต์ระหว่างเลื่อน แถวสุดท้ายของหน้าเดิมกลับมาเป็นแถวแรกของหน้าใหม่ → key ซ้ำใน ListView เดียว → **Flutter throw** ไม่ใช่แค่แสดงซ้ำ | 8 |
| B3-8 | `ClubPage._buildBanner` สลับระหว่าง cover ที่อัปโหลดกับพื้นหลังที่สร้างเอง | หัว Club เป็นคนละดีไซน์กันขึ้นกับว่าเจ้าของเผอิญอัปรูปไว้ไหม และชื่อ Club หายไปในกรณีที่อัป | 12 |

## 9. จุดที่ตรวจแล้ว **ไม่พบปัญหา** — ไม่แตะ

บันทึกไว้เพราะ "ตรวจแล้วไม่มีอะไร" มีค่าเท่ากับ "เจอแล้วแก้" ในงาน audit

| จุด | ผลการตรวจ |
|---|---|
| โครงสร้าง Post (Profile → Text → Media → Actions) | ถูกต้องแล้วทั้ง `HomeDropCard` และ `DropDetailScreen` ตั้งแต่ WYN-086 |
| Post Detail: header + comments อยู่ใน scroll เดียวกัน | จริงอยู่แล้ว (`ListView(children: [header, ...comments])`) — ปัญหาอยู่ที่ AppBar ตรึง ไม่ใช่ nested scroll |
| Feed หลายรูป = Horizontal Carousel | ใช่อยู่แล้ว (WYN-092) ไม่ใช่ Grid |
| Home: Back จาก Detail | รีเฟรชแถวเดียวอยู่แล้ว (Beta2) — scroll ไม่หาย |
| Notifications: Back จาก Detail | ไม่ reload อะไรเลย — state ถูกต้องอยู่แล้ว |
| Search | เป็น submit-based (`onSubmitted`/ปุ่มค้นหา) ไม่ใช่ type-ahead → **ไม่ต้องมี debounce** ไม่มี duplicate request จากการพิมพ์ |
| Optimistic UI (like/save/redrop) ใน Home | มี rollback ครบ + `_serializeWrite` จัดคิว write ต่อแถวไม่ให้ทับกัน |
| `_fetchViewerState` ของ `HomeRepository` | ขนานอยู่แล้วด้วย `Future.wait` |
| Index บนตารางที่ query ร้อน | ครบทุกตัวที่ Beta3 ต้องใช้ — **ไม่ต้องเพิ่ม index ใหม่แม้แต่ตัวเดียว** (ดู performance doc §4) |
| `schema.sql` | โหลดสด 0 ERROR |

---

## 10. จุดเสี่ยง regression ที่ต้องเฝ้า

| ความเสี่ยง | ทำไมถึงเสี่ยง | กันไว้อย่างไร |
|---|---|---|
| `home_feed` view | `create or replace` สะสม 6 ครั้งในไฟล์เดียว แก้ผิดอันคือเงียบ ๆ ทำ column หาย | **Beta3 ไม่แตะ view เลย** — batch image query ทำฝั่ง Dart ล้วน ไม่ต้อง migration |
| `HomeDropCard` ถูกใช้ซ้ำ 5 ที่ | Home feed, Profile 3 แท็บ, hashtag feed — แก้ที่เดียวกระทบทุกที่ | ไม่เปลี่ยน API ของ widget เลย เปลี่ยนเฉพาะภายในส่วน media |
| `Drop`/`HomeFeedItem` เป็น immutable value type ที่ copy ด้วยมือ | `copyWith` ที่ลืม field = field นั้นถูก reset เงียบ ๆ (เคยเกิดจริงตอน WYN-034) | field `imageUrls` ที่เพิ่ม ถูกร้อยผ่าน `copyWith` / `withEditedCaption` / `toDrop` / `fromDrop` ครบทุกทาง |
| `SliverAppBar` แทน `Scaffold appBar:` | ถ้าพลาด ปุ่มย้อนกลับอาจหายถาวร | `floating: true, snap: true` — ปัดขึ้นครั้งเดียวกลับมาเสมอ · test เดิม 1,086 ตัวยังผ่านหมด |
| RLS ของ `drop_images` | policy re-check ผ่าน `drops` — ถ้า batch query ทำ plan แย่ลงจะช้ากว่าเดิม | วัดจริงด้วย `EXPLAIN ANALYZE` ใต้ role `authenticated` (performance doc §2) |
