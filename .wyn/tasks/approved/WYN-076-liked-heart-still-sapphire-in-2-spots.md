# Bug Report — WYN-076

Status: fixed, ready to deploy
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
