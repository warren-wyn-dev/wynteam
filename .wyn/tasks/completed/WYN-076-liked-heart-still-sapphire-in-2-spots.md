# Bug Report — WYN-076

Status: **completed** — deployed to production (2026-09-01)
Reported by: Founder, 2026-09-01 (screenshot on production, Home feed, circled the like/comment/redrop/view row)
Severity: Low (visual consistency, no functional impact)

## Symptom
Founder circled a post's action-bar row on Home and asked for the heart to be red ("ใจอยากได้สีแดง").

## Root cause
Prior task (deployed before this session) established the convention "the liked heart icon is always `Colors.red`, never sapphire" and fixed 5 spots. Two more spots had the same `WynColors.sapphire` mistake and were missed:
- `app/lib/features/home/presentation/widgets/home_drop_card.dart:390` (the action bar Founder circled)
- `app/lib/features/home/presentation/widgets/home_pop_card.dart:245` (sibling widget, explicitly designed to mirror `HomeDropCard`)

## Fix
Both: `color: item.likedByMe ? WynColors.sapphire : WynColors.graphite` → `color: item.likedByMe ? Colors.red : WynColors.graphite`, matching every other liked-heart spot in the app (`club_post_card.dart`, `drop_detail_screen.dart`, `drop_image_viewer.dart`, `pop_clip_view.dart`, `pop_comment_sheet.dart`, `club_post_detail_screen.dart`, `notification_list_screen.dart`).

`flutter analyze`: 0 issues. `flutter test`: 871/871 passing.

Handoff: ready to deploy, no schema change.

## Deploy (AI Deploy & DevOps, 2026-09-01) — SUCCESS

Founder อนุมัติ ("Deploy เลย") — merge PR #204 → `main` (commit `7a7234a9aafd22a96c4af801760de01d8aa099a9`) → trigger `deploy-web.yml` (run [`33533323875`](https://github.com/warren-wyn-dev/wynteam/actions/runs/33533323875), completed/success) → verify production: ทุก endpoint HTTP 200, `main.dart.js` ขนาดเท่าเดิม (4,088,406 bytes ตรงกับ WYN-075 ตามคาด เพราะเปลี่ยนแค่สี ไม่มี dependency เปลี่ยน)

รายละเอียดเต็ม: `.wyn/logs/deployments/2026-09-01-wyn-076-real-deploy.md`
