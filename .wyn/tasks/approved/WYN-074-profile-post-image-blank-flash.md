# Bug Report — WYN-074

Reported by: Founder, 2026-09-01 (screen recording on production, หน้าโปรไฟล์)
Severity: Medium (visual/UX — no data loss, no crash, but reads as a broken feed)

## Symptom
Founder: "หน้าโปรไฟล์ ดูโพสต์ได้แค่ครึ่งเดียว" (on the Profile page, posts can only be seen halfway).

## Investigation
Recording extracted to frames via ffmpeg (no code guess — reproduced from the actual video):
- At one captured frame, the post header ("WARREN · 24/8/2026") renders, but the entire image area below it is **completely blank white** — no image, no placeholder, no spinner.
- ~0.3s later (next captured frame), the same post's image (person standing on a rock) is fully rendered, in the same scroll position.
- This is the visual signature of an unbuffered network image load: the widget shows nothing while bytes are downloading, then pops in abruptly once decoded.

## Root cause
`HomeDropCard` (`app/lib/features/home/presentation/widgets/home_drop_card.dart:331`) renders post images with plain `Image.network(item.imageUrl!, fit: BoxFit.cover)` — no `loadingBuilder`, no `frameBuilder`, no placeholder, and the app has **no disk-caching image package** (`cached_network_image` is not in `pubspec.yaml`, confirmed via grep — no hits anywhere in `app/lib` or `pubspec.lock`).

Effect:
1. First time an image scrolls into view, there's a blank gap while it downloads — during fast scrolling (as in the recording) this reads as "the post is only half there."
2. No disk cache — every fresh app session re-downloads every image from scratch, even ones already viewed.

`HomeDropCard` is shared between the Home feed and the Profile "โพสต์" tab (`ProfileDropGridTab` — see file header comment), so this bug also exists on Home, just less visible there since Founder scrolled faster on Profile in the recording.

## Scope of fix
In scope: `HomeDropCard`'s post image (fixes both Profile posts tab and Home feed, since it's the same shared widget).
Out of scope (not requested, and would be a much larger diff): the ~28 other `Image.network(...)` call sites across the app (club covers, Zoky product images, saved-grid tiles, etc.) have the same underlying pattern but were not reported as broken — flagged as a known follow-up, not fixed in this task.

## Recommended fix
Add `cached_network_image` (well-maintained, standard Flutter package) and use `CachedNetworkImage` in `HomeDropCard` with:
- `placeholder`: a neutral gray/faint box (design-system `WynColors.faint` or similar) instead of blank white
- `fadeInDuration`: short crossfade so the pop-in isn't jarring
- disk cache: re-scrolling to an already-seen post shows instantly, no re-download

## Implementation (AI Coding, 2026-09-01)
- Added `cached_network_image: ^3.4.1` to `pubspec.yaml` (`flutter pub get` resolved cleanly, `pubspec.lock` updated).
- `home_drop_card.dart`: replaced `Image.network(item.imageUrl!, fit: BoxFit.cover)` with `CachedNetworkImage` — `placeholder`/`errorWidget` both use `colorScheme.surfaceContainerHighest` (existing app convention, same token used in `saved_grid_tile.dart`/`order_summary_card.dart`), `fadeInDuration: 150ms` for a smooth pop-in instead of an abrupt blank→image jump. Disk+memory caching now means a post already viewed this session renders instantly on re-scroll.
- Scoped to `HomeDropCard` only (shared by Home feed + Profile posts tab) — the other ~28 `Image.network` call sites elsewhere in the app were not touched (not reported, out of scope for this bug).

## QA (2026-09-01) — PASS
ตรวจซ้ำอิสระ ไม่เชื่อตัวเลขที่ Coding รายงานเฉยๆ:
- `flutter analyze`: 0 issues (รันเอง คนละรอบจาก Coding)
- `flutter test` เต็ม suite: **871/871 ผ่านหมด** (รันเอง คนละรอบจาก Coding)
- ตรวจโค้ดจริง: grep ยืนยันไม่มี `Image.network` เหลือใน `home_drop_card.dart`, มี `CachedNetworkImage` แทนที่ถูกต้อง
- ตรวจ `pubspec.lock`: `cached_network_image` resolve เป็น `direct main` dependency จริง ไม่ใช่แค่เขียนใน `pubspec.yaml` เฉยๆ
- ยืนยันโครงสร้าง: `ProfileDropGridTab` (แท็บโพสต์หน้าโปรไฟล์) เรียกใช้ `HomeDropCard` จริง → fix นี้ครอบคลุมทั้ง Home feed และ Profile ตามที่วิเคราะห์ไว้

**Final Status: PASS**

Handoff: ส่งต่อ AI Deploy & DevOps — ไม่มี schema change ในรอบนี้ (แก้แค่ Flutter widget + เพิ่ม package) จึงไม่มีความเสี่ยง schema-drift
