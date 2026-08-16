# Design Spec — DS-005 (Club — community identity)

> โดย AI Design — 2026-08-16 | ต่อจาก DS-003 (Home Feed divider) + DS-004 (Drop audit-only)

## Audit ก่อนออกแบบ (เปลี่ยนขอบเขตงานนี้เหมือน DS-004)

อ่านทั้ง 13 ไฟล์ presentation ของ Club แล้วพบว่า community identity ถูกออกแบบไว้ครบตั้งแต่ WYN-014/WYN-015 อยู่แล้ว:

| องค์ประกอบ identity | ที่อยู่ | สถานะ |
|---|---|---|
| Cover + avatar ซ้อนกัน (community header) | `club_page.dart` `_buildHeader` | มีแล้ว — cover การ์ดมุมมนสูงจำกัด 140px + avatar วงกลมซ้อนทับขอบล่าง ตาม Design spec เดิม |
| Category chip | `club_page.dart`, `club_discovery_card.dart` | มีแล้ว |
| Role badge (Owner/Admin/Moderator) | `club_members_tab.dart` `_buildRoleBadge` | มีแล้ว — Chip แยกสีตาม role |
| Pin indicator | `club_posts_tab.dart` | มีแล้ว — label "ปักหมุด" เหนือโพสต์ที่ปักหมุดอันดับแรก |
| Card-less rows | ทุกไฟล์ (`club_discovery_card`/`club_mini_card`/`club_post_card`) | มีแล้ว — `grep "Card("` ทั้งโฟลเดอร์เจอแค่ชื่อ widget (`ClubDiscoveryCard` ฯลฯ) ไม่มี Material `Card` จริงเลย |

## การตัดสินใจ — ช่องว่างเดียวที่พบจริง

`club_posts_tab.dart`'s Posts tab เป็น chronological feed แบบเดียวกับ Home Feed เป๊ะ (การ์ดตระกูลเดียวกัน — `ClubPostCard` มี layout เหมือน `HomeDropCard`/`HomePopCard` ตามที่ comment ในโค้ดยืนยัน) แต่ยังใช้ `ListView.builder` ไม่มีเส้นคั่นระหว่างโพสต์ — ไม่สอดคล้องกับ DS-003 ที่เพิ่งกำหนด "เส้นคั่นบางระหว่างโพสต์" เป็นภาษาภาพของ continuous feed ไปแล้ว

แก้เหมือน DS-003 เป๊ะ: `ListView.builder` → `ListView.separated` พร้อม `Divider(height: 1)` ระหว่างโพสต์ (ไม่รวมก่อน spinlike/หลัง spinner) — ไม่ hardcode สี ให้ `colorScheme.outlineVariant` กำหนดเอง

**สิ่งที่ตัดสินใจไม่ทำ**: เพิ่มเส้นคั่นใน `my_clubs_screen.dart` (รายการ Club ที่เข้าร่วม, ใช้ `ListTile`) และ `club_discovery_card.dart` rows ใน `explore_clubs_screen.dart` — ทั้งสองเป็น **entity-browse list** (คล้าย FollowListScreen) ไม่ใช่ chronological content feed เหมือน Home/Club Posts จึงไม่อยู่ใน scope ของภาษาภาพ "continuous feed" ที่ DS-003 กำหนดไว้ การใส่เพิ่มจะเป็นการเปลี่ยนโดยไม่มีเหตุผลรองรับ

## Requirements

R1. `club_posts_tab.dart`: `ListView.builder` → `ListView.separated` พร้อม `Divider(height: 1)` ระหว่างโพสต์ mirror `home_feed_screen.dart` เป๊ะ
R2. ไม่แตะ `club_post_card.dart` เลย เหมือนที่ DS-003 ไม่แตะ `home_drop_card.dart`/`home_pop_card.dart`
R3. ไม่เพิ่มเส้นคั่นในรายการที่เป็น entity-browse (My Clubs, Explore Clubs)

## Acceptance Criteria

- [x] Club Posts tab มีเส้นคั่นบางระหว่างโพสต์ เหมือน Home Feed
- [x] ไม่มีเส้นคั่นก่อนรายการแรก/หลังรายการสุดท้ายก่อน spinner
- [x] `flutter analyze`/`flutter test` ผ่านสะอาด
- [x] ไม่มีการแก้ไข My Clubs/Explore Clubs (นอกขอบเขต)

## Handoff

ส่งต่อ AI Coding: แก้เฉพาะ `club_posts_tab.dart` — mirror DS-003's diff เป๊ะ
