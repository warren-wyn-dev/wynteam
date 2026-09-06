# Product Task — WYN-115

Status: completed -- schema gap (club_post_polls never applied to production) found and fixed same day via `wyn115-apply-club-poll-schema.yml` (see DECISIONS.md, 2026-09-06), Founder confirmed real Club posts load correctly in production
Owner: AI Product Manager

Feature: Club Poll — ให้สมาชิกสร้างโพลภายในโพสต์ของ Club ได้

Goal: เพิ่ม engagement ในกลุ่มด้วยวิธีที่ต้นทุนต่ำที่สุด (ถามความเห็น/โหวตกิจกรรม/ตัดสินใจร่วมกันของ Club) โดยต่อยอดระบบ Poll ที่มีอยู่แล้วบน Drop (WYN-035, `create_poll_drop()`) แทนที่จะสร้างระบบโพลใหม่ทั้งหมด

Target User: สมาชิก/Owner/Admin ของ Club ที่ต้องการถามความเห็นหรือให้สมาชิกโหวตเรื่องใดเรื่องหนึ่ง

Problem: ตอนนี้ Club Post รองรับแค่ Text/Image/Link (ตาม Founder Brief เดิม) — ไม่มีวิธีให้สมาชิกโหวต/แสดงความเห็นแบบมีตัวเลือกได้เลย ต้องพิมพ์คอมเมนต์แยกกันเอง ซึ่งนับผลไม่ได้และอ่านยากเมื่อมีคนตอบเยอะ

Requirements:
- เพิ่มตัวเลือก "สร้างโพล" ใน `CreateClubPostScreen` (คู่ขนานกับ text/image ที่มีอยู่ ไม่ใช่แทนที่)
- โครงสร้างข้อมูล/กติกาเดียวกับ Poll ของ Drop ให้มากที่สุด (จำนวนตัวเลือกขั้นต่ำ-สูงสุด, โหวตได้ครั้งเดียว, เปลี่ยนใจได้ก่อนปิดโพล ฯลฯ) — ใช้ pattern เดิมที่ผ่าน QA แล้วจาก WYN-035 ไม่ออกแบบกติกาใหม่โดยไม่มีเหตุผล
- ผลโหวตแสดงเฉพาะสมาชิกที่ approved ของ Club นั้น (ตาม trust model ของ Club ที่มีอยู่แล้ว)
- Pinned Post ที่เป็นโพลได้ตามปกติ (ไม่ต้องมีข้อจำกัดพิเศษ)

Acceptance Criteria:
- สมาชิกที่ approved ของ Club สร้างโพลในโพสต์ Club ได้ พร้อมเห็นผลโหวตแบบเรียลไทม์เหมือน Poll บน Drop
- สมาชิกที่ pending/ไม่ใช่สมาชิกของ Club private เห็น/โหวตโพลไม่ได้ (ตาม RLS เดิมของ Club post)
- โหวตซ้ำ/เปลี่ยนใจทำงานตรงกับกติกาเดียวกับ Poll ของ Drop เป๊ะ (regression test อ้างอิงชุดเดิมของ WYN-035 ปรับมาใช้กับ Club)

Dependencies: ไม่มี — Poll infra (WYN-035) deploy อยู่แล้ว, ทำคู่ขนานกับ WYN-114 ได้ (ไม่เกี่ยวข้องกัน)

Priority: P1 — Founder เลือกให้เริ่มก่อนใน Club Growth Roadmap (effort ต่ำสุดในกลุ่ม 4 ตัว)

Risks: ต่ำ — data model/RLS pattern มีต้นแบบที่ผ่าน QA แล้ว (Drop Poll) ความเสี่ยงหลักคือถ้า Design ตัดสินใจกติกาโพลของ Club ให้ต่างจาก Drop โดยไม่มีเหตุผลรองรับ (เช่น อนุญาต multi-select) จะเพิ่ม scope โดยไม่จำเป็น

Recommendation: เริ่ม Design ได้เลย — ให้ AI Design ตรวจ `create_poll_drop()`/Poll UI ของ Drop ให้ครบก่อนออกแบบ เพื่อ reuse ให้มากที่สุดแทนออกแบบใหม่

Handoff: AI Design → AI Coding → AI QA & Security

---

## AI Design Output

ดู `.wyn/docs/design/wyn-115-club-poll.md` — mirror `wyn-035-poll-in-drop.md` เกือบทั้งหมด ต่างกัน 3 จุด: (1) multi-image (`image_urls`) แทน single image (2) มี `link_url` ที่ Drop ไม่มี — ตัดสินใจซ่อนช่องลิงก์ทั้งหมดตอนอยู่โหมดโพล ไม่ใช่ปล่อยให้กรอกคู่กัน (3) ไม่ต้องมี Screen 3 (Grid Fallback) เพราะ Club post ไม่ปรากฏใน grid ใดในระบบ

## AI Coding Output

**Files Changed**:
- `supabase/schema.sql` — `club_post_polls`/`club_post_poll_votes` + RLS, `validate_club_poll_vote()` trigger, `create_poll_club_post()`/`get_club_poll_results()` RPC (มิเรอร์ `create_poll_drop()`/`get_poll_results()` ของ WYN-035 เป๊ะ เพิ่มเงื่อนไข "เป็นสมาชิก approved" ที่ Drop ไม่ต้องมี)
- `supabase/tests/wyn_115_club_poll_test.sh` — regression 24 checks (real Postgres, RLS ผ่าน `set role authenticated`)
- `app/lib/features/club/data/club_post.dart`, `club_post_repository.dart` — poll fields/`votedPoll()`/`createPollClubPost()`/`votePoll()`/batch results fetch
- `app/lib/features/club/presentation/widgets/club_poll_card.dart` (ใหม่) — มิเรอร์ Drop's `PollCard` เป๊ะ (ใช้ `Theme.of(context).colorScheme.primary` ซึ่ง resolve เป็น Sapphire อยู่แล้วทั้งแอป ไม่ต้องแก้สี)
- `club_post_card.dart`/`club_post_detail_screen.dart` — เพิ่ม branch `if (post.isPoll) ClubPollCard(...)` แทนที่รูป/ลิงก์
- `club_posts_tab.dart`/`from_your_clubs_feed.dart`/`hashtag_feed_screen.dart` — เพิ่ม `_votePoll` optimistic-update handler
- `create_club_post_screen.dart` — toggle โหมดรูปภาพ/โพล, poll composer (ตัวเลือก 2-4 ช่อง, ระยะเวลา 1/3/7 วัน), ซ่อนช่องลิงก์ตอนอยู่โหมดโพล
- Tests ใหม่/แก้: `club_poll_card_test.dart` (ใหม่), `create_club_post_screen_test.dart`, `club_posts_tab_test.dart`

**Tests**: `flutter analyze` clean, `flutter test` ทั้งชุด 1263/1263 PASS, `wyn_115_club_poll_test.sh` 24/24 PASS, `wyn_035_poll_in_drop_test.sh`/`wyn_122_chat_lockdown_test.sh` re-run ยืนยันไม่มี regression (schema.sql ผ่าน merge conflict ระหว่างย้าย branch ต้อง splice ด้วยมือ), `check_schema_ordering.py` OK

**Handoff**: ส่งต่อ AI QA & Security

## AI QA & Security Output

**Feature**: WYN-115 (Club Poll) — schema, data layer, UI

**Environment**: Local PostgreSQL 16 จริง (RLS ผ่าน `authenticated` role/JWT claim ไม่ใช่ superuser bypass) + Flutter SDK เต็มชุด

**Test Cases**:
1. `check_schema_ordering.py` — ไม่มี forward reference
2. `wyn_115_club_poll_test.sh` — 24 checks รันซ้ำอิสระ
3. `wyn_035_poll_in_drop_test.sh` — 23 checks (regression Poll ของ Drop)
4. `wyn_122_chat_lockdown_test.sh` — 18 checks (regression ฟีเจอร์ล่าสุดอื่น)
5. `flutter analyze` + `flutter test` เต็มชุด
6. ตรวจ RLS/trigger/RPC ตรงๆ ด้วยตัวเอง โดยเฉพาะ bypass angle: insert ตรงเข้า `club_post_poll_votes` โดยไม่ผ่าน RPC ใดๆ
7. ตรวจทุกจุดที่ non-null-assert `post.poll*` ว่าอยู่ใน `isPoll`-guarded branch ครบทุกจุด
8. เทียบ Design doc's "จุดที่ต่างจาก WYN-035" ว่า implement ครบจริง
9. สแกน secret ใน commit diff

**Passed**: ครบทุกจุด — 65/65 SQL regression checks, `flutter analyze` clean, `flutter test` 1263/1263 PASS, ไม่พบ secret

**Failed**: ไม่มี

**Severity**: N/A

**Security Findings**: ไม่พบช่องโหว่ — `validate_club_poll_vote()` เป็น `BEFORE INSERT/UPDATE` trigger ที่ fire ทุก write path รวมถึง raw PostgREST insert ไม่ใช่แค่ทาง RPC จึงปิด bypass angle ที่ตั้งข้อสงสัยไว้ได้ครบ (ยืนยันด้วย CHECK15-17); `get_club_poll_results()` กรอง non-member ออกทั้งแถว (CHECK19) ไม่ใช่แค่ `visible=false`; `create_poll_club_post()` insert `image_urls=null, link_url=null` เสมอจริงตามที่อ่านโค้ดโดยตรง

**Recommendation**: อนุมัติ deploy ได้ (มี 2 minor note ไม่ block: (1) `array_agg` ใน `create_poll_club_post()` ไม่มี `ORDER BY` explicit แต่เป็น pattern เดิมที่ใช้อยู่แล้วใน `create_poll_drop()` — ไม่ใช่ความเสี่ยงใหม่ (2) `ClubPostCard` ใช้ 2 `if` อิสระแทน `if/else-if` สำหรับรูป/โพล ปลอดภัยเพราะ DB การันตี mutually exclusive อยู่แล้ว)

**Final Status: PASS**

**Handoff**: ส่งต่อ AI Deploy & DevOps
