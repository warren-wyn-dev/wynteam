# WYNOS v1.0.0 Beta3 — Security Audit

> วันที่: 2026-09-03
> Branch: `claude/wynos-beta3-polish-performance-aes6ld` — **ยังไม่ push · ยังไม่ deploy**
> Environment: PostgreSQL 16.13 ในเครื่อง + Supabase stub · **ไม่มี production credential ใน session นี้**

---

## 0. ขอบเขตของเอกสารนี้ — อ่านก่อน

Beta3 คือ Deep Polish ไม่ใช่ security review รอบใหม่ — การ audit ความปลอดภัยเต็มรูปแบบทำไปแล้วใน
`wynos-v1.0.0-beta2-full-audit.md` เอกสารนี้ตอบสองคำถามที่แคบกว่านั้น:

1. **Beta3 ทำให้อะไรแย่ลงหรือเปล่า** — ตรวจทุกบรรทัดที่แก้ เทียบกับผิวสัมผัสด้านความปลอดภัย
2. **หัวข้อในข้อ 26 อยู่ในสถานะไหน** — Authentication, Authorization, RLS, IDOR, Ownership, Storage, Input validation

ตามข้อ 26 ทุกข้อถูกแยกเป็น **Confirmed vulnerability** กับ **Potential hardening** อย่างชัดเจน
และตามข้อ 26 อีกครั้ง: **ไม่มีการแก้ security แบบเดาสุ่มใน Beta3 — ไม่มีการแก้ security เลย**

---

## 1. Confirmed vulnerability

**ไม่พบ — 0 รายการ**

ทั้งจากการตรวจ diff ของ Beta3 และจากการรัน RLS test ที่ §3

⚠️ ข้อความนี้หมายความว่า *"ไม่พบในขอบเขตที่ตรวจ"* ไม่ได้หมายความว่า *"ไม่มี"*
ยังไม่เคยมี penetration test โดยมนุษย์ และ session นี้ไม่มี production credential

---

## 2. Beta3 แตะอะไรที่เกี่ยวกับความปลอดภัยบ้าง

| สิ่งที่แก้ | ผิวสัมผัสด้านความปลอดภัย | ประเมิน |
|---|---|---|
| `post_media.dart` (widget ใหม่) | ไม่มี — เป็น layout + decode ล้วน ไม่แตะข้อมูล | ไม่มีผล |
| `HomeRepository._fetchImageUrls()` (query ใหม่ 1 ตัว) | **อ่าน `drop_images` เพิ่ม** — ผิวสัมผัสเดียวที่ Beta3 สร้างขึ้น | ทดสอบแล้ว §3 |
| `DropRepository._fetchViewerState()` | รวม 4 query เดิมเข้าด้วยกัน — **query เดิมทุกตัว ไม่เปลี่ยนเงื่อนไข** | ไม่มีผล |
| `Drop.imageUrls` / `HomeFeedItem.imageUrls` | field ใหม่พก URL ที่ RLS อนุญาตแล้วเท่านั้น | ไม่มีผล |
| `_refreshRow()` 4 จอ | เรียก `fetchById`/`fetchItemById` ซึ่งอยู่ใต้ RLS เหมือนเดิม | ไม่มีผล |
| `_seenKeys` 4 ลิสต์ | กรองฝั่ง client ล้วน | ไม่มีผล |
| `SliverAppBar` ที่ Post Detail | layout ล้วน | ไม่มีผล |
| `ClubPage._buildBanner` | **แสดงน้อยลง** ไม่ได้แสดงมากขึ้น | ลดผิวสัมผัส |

**Beta3 ไม่มี:** schema change · migration · RLS policy ใหม่หรือแก้ไข · RPC ใหม่ · การเปลี่ยน storage policy · การเปลี่ยน auth flow · endpoint ใหม่

---

## 3. RLS — ทดสอบ query เดียวที่ Beta3 เพิ่ม

`_fetchImageUrls()` ยิง `select drop_id, image_url from drop_images where drop_id in (...)`
คำถามที่ต้องตอบคือ: **ถ้ามี id ของโพสต์ที่ผู้ใช้ไม่มีสิทธิ์ดูหลุดเข้าไปในลิสต์ จะรั่วไหม**

รันบน PostgreSQL 16.13 ใต้ role `authenticated` พร้อม `request.jwt.claim.sub` จริง:

**ตั้งต้น** — Alice โพสต์ 2 โพสต์ โพสต์ละ 3 รูป
* `...0001` audience = `everyone`
* `...0002` audience = `only_me`

**Bob ยิง batch query โดยใส่ id ทั้งสองอันในลิสต์:**

```
              drop_id               | images_bob_can_read
--------------------------------------+---------------------
 aaaaaaaa-0000-0000-0000-000000000001 |                   3
(1 row)
```

**Alice (เจ้าของ) ยิง query เดียวกัน:**

```
              drop_id               | images_alice_can_read
--------------------------------------+-----------------------
 aaaaaaaa-0000-0000-0000-000000000001 |                     3
 aaaaaaaa-0000-0000-0000-000000000002 |                     3
(2 rows)
```

**ผล: RLS ตัดสินเหมือนเดิมทุกประการ** ลิสต์ `IN` เป็นแค่ตัวกรอง ไม่ใช่ตัวให้สิทธิ์
policy `"Drop images inherit their Drop's visibility"` re-check ผ่าน `drops` เอง จึงได้เงื่อนไขครบชุด
(deleted_at, block ทั้งสองทาง, `can_view_author_content`, `can_view_drop_audience`) โดยไม่ต้องคัดลอกมาเขียนซ้ำ

ยืนยันจาก `EXPLAIN` ว่า policy ทำงานจริง ไม่ได้ถูก optimize ทิ้ง:

```
Filter: (SubPlan 1)
  SubPlan 1
    -> Index Scan using drops_pkey on drops d (actual rows=1 loops=24)
       Filter: ((deleted_at IS NULL) OR (auth.uid() = author_id))
           AND (NOT internal.is_blocked_either_way(auth.uid(), author_id))
           AND internal.can_view_author_content(auth.uid(), author_id)
           AND internal.can_view_drop_audience(auth.uid(), d.*)
```

---

## 4. IDOR / Ownership

| จุด | สิทธิ์ถูกบังคับที่ไหน | Beta3 เปลี่ยนไหม |
|---|---|---|
| เปิดโพสต์ด้วย id (`fetchById`) | RLS ของ `drops` | ไม่ — เปลี่ยนแค่ให้ 4 lookup ยิงขนานกัน |
| อ่านรูปของโพสต์ (`drop_images`) | RLS re-check ผ่าน `drops` | ไม่ — ทดสอบแล้ว §3 |
| ลบ/แก้โพสต์ | policy ต้อง `author_id = auth.uid()` + UI ซ่อนเมนู | ไม่แตะ |
| ลบ ReDrop ของตัวเอง | `_isOwnRedrop` + RLS | ไม่แตะ |
| ลบคอมเมนต์ | เจ้าของคอมเมนต์ หรือเจ้าของโพสต์ | ไม่แตะ |
| แท็บ "ถูกใจ" ของคนอื่น | `likes_visibility` + RPC กรองฝั่ง server (WYN-099) | ไม่แตะ — `_refreshRow` เรียก `fetchById` ซึ่งอยู่ใต้ RLS ของ `drops` เหมือนกัน |
| Club: ลบโพสต์ / จัดการสมาชิก | role ใน `club_members` | ไม่แตะ |

**ข้อสังเกตที่ตรวจเป็นพิเศษ:** `_refreshRow` ที่เพิ่มใน 4 จอ ยิง `fetchById(dropId)` ด้วย id ที่ผู้ใช้ *เห็นอยู่แล้ว*
ไม่ได้เปิดทางให้ยิง id อะไรก็ได้ และต่อให้ยิงได้ RLS ก็ตอบ null — ไม่ใช่ IDOR

---

## 5. Input validation

Beta3 ไม่รับ input ใหม่จากผู้ใช้เลย ไม่มี form ใหม่ ไม่มี query parameter ใหม่ที่มาจากผู้ใช้

`_fetchImageUrls()` รับเฉพาะ id ที่มาจาก row ที่เซิร์ฟเวอร์เพิ่งส่งกลับมา ไม่ใช่จาก input ผู้ใช้
และส่งผ่าน `.inFilter()` ของ supabase client ซึ่ง parameterize ให้ — ไม่ได้ต่อ string เอง
(ต่างจากบั๊ก search injection ที่ Beta2 เจอและแก้ไปแล้ว ซึ่งเกิดจากการต่อ string ตรง ๆ)

---

## 6. Potential hardening — พบแล้ว แต่ **ไม่แก้ใน Beta3**

ทั้งหมดเป็นเรื่องที่มีอยู่ก่อน Beta3 ไม่ใช่ของใหม่ และไม่มีอันไหนเป็นช่องโหว่ที่ยืนยันได้

### H-1 · RLS ของ `drop_images` re-check ต่อ "แถวรูป" ไม่ใช่ต่อ "โพสต์"

`EXPLAIN` แสดง `loops=24` สำหรับ 8 โพสต์ (3 รูปต่อโพสต์) — subplan ยิง 24 ครั้งเพื่อตรวจ 8 คำตอบ
เป็นเรื่อง performance ล้วน ไม่ใช่ช่องโหว่ (คำตอบถูกต้องเสมอ) และเป็นพฤติกรรมเดิมมาตั้งแต่ WYN-071
การแก้ต้องแตะ RLS policy ซึ่ง Beta3 ห้ามตัวเองไว้ — **ต้องขออนุมัติ Founder ก่อน**

### H-2 · `dropShareLink()` ยังชี้ไปโดเมนที่ไม่มีจริง

`https://wyn.app/drop/$id` — ยังไม่มี hosting/โดเมนจริง ปุ่ม "แชร์" จึงส่งลิงก์ที่เปิดไม่ได้
ไม่ใช่ช่องโหว่ แต่เป็นการรั่วของ id โพสต์ออกไปนอกแอปโดยที่ปลายทางยังไม่มีการควบคุมสิทธิ์อะไรรออยู่
มีบันทึกไว้แล้วใน `WYN-005` Risks — **ต้องรอ Founder ยืนยันโดเมนจริงก่อน Deploy**

### H-3 · Monitoring ยังไม่ต่อ

`ErrorWidget.builder` ใน release แสดงกล่อง error ที่อ่านรู้เรื่อง แต่ **ไม่มี crash reporter**
ความผิดพลาดในมือผู้ใช้จริงจึงไม่มีใครรู้ — ยกมาจาก Beta2 audit ยังไม่ได้แก้

---

## 7. Supabase test suite — 27/33 (ไม่เปลี่ยนจาก Beta2)

รันครบทั้ง 33 ไฟล์บน PostgreSQL 16.13 ในเครื่อง

**Beta3 ไม่แตะ SQL แม้แต่บรรทัดเดียว ผลจึงเท่ากับ baseline ของ Beta2 พอดี — ไม่มี regression**

| ที่ fail | สาเหตุ | ประเภท |
|---|---|---|
| `wyn_041_trending_engine` | fixture สร้าง profile username `'moderator'` ซึ่งชน constraint `profiles_username_not_reserved` ที่เพิ่มมาทีหลัง | **Existing failure — fixture เก่า ไม่ใช่บั๊กผลิตภัณฑ์** |
| `wyn_043_notification_types` | เหมือนกัน — username `'admin'` | Existing failure — fixture เก่า |
| `wyn_051_admin_user_management` | เหมือนกัน | Existing failure — fixture เก่า |
| `wyn_052_admin_content_moderation` | เหมือนกัน | Existing failure — fixture เก่า |
| `wyn_054_055_audit_log_announcements` | เหมือนกัน | Existing failure — fixture เก่า |
| `wyn_038_view_counting` | ความคาดหวังของ test ถูกแทนที่โดย WYN-083 ซึ่งเปลี่ยนกติกาการนับ view — **`wyn_083_view_count_owner_and_repeat_test.sh` ที่ครอบพฤติกรรมปัจจุบัน ผ่าน** | Existing failure — test เก่าที่ถูก supersede |

ทั้ง 6 ตัวเป็น **stale test fixture ไม่ใช่ช่องโหว่และไม่ใช่บั๊กผลิตภัณฑ์** — แต่ควรซ่อมให้เขียว
เพราะ suite ที่แดงเป็นปกติคือ suite ที่คนเลิกอ่าน (บันทึกไว้ใน future ideas)

---

## 8. สรุป

| หัวข้อข้อ 26 | สถานะ | หมายเหตุ |
|---|:--:|---|
| Authentication | ✅ ไม่แตะ | AuthGate / Google / OTP / guest — Beta3 ไม่เปลี่ยนอะไร |
| Authorization | ✅ ไม่แตะ | บังคับที่ RLS เป็นหลัก UI เป็นชั้นรอง |
| RLS | ✅ ทดสอบแล้ว | query เดียวที่เพิ่ม ถูกทดสอบตรง ๆ §3 · schema โหลด 0 ERROR |
| IDOR | ✅ ตรวจแล้ว | `_refreshRow` ใช้ id ที่ผู้ใช้เห็นอยู่แล้ว และอยู่ใต้ RLS |
| Ownership | ✅ ไม่แตะ | โพสต์ / คอมเมนต์ / ReDrop / Club |
| API access | ✅ ไม่แตะ | ไม่มี endpoint หรือ RPC ใหม่ |
| Input validation | ✅ ไม่มี input ใหม่ | `.inFilter()` parameterize ให้ ไม่ได้ต่อ string |
| Storage access | ✅ ไม่แตะ | ไม่แตะ policy ของ storage |
| Privilege escalation | ✅ ไม่พบทาง | Beta3 ไม่เพิ่ม SECURITY DEFINER และไม่แก้ตัวที่มี |

**Confirmed vulnerability: 0 · Potential hardening: 3 (H-1, H-2, H-3) — ทั้งสามมีอยู่ก่อน Beta3 และไม่ได้แก้ใน Beta3**
