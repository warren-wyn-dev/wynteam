# WYN-219 Phase 2 Step 2 — Admin Check Migration Checklist

Status: **preparation** — ใช้หลังจาก foundation (#1078) ถูก apply กับ production แล้ว · production dump ตรวจแล้ว 2026-10-10 (ดูหัวข้อ "Production comparison")
Spec: `.wyn/docs/engineering/wyn-219-phase2-admin-permissions-proposal.md` (mapping section 3.4, Founder answers Q1–Q3)

## วิธีใช้

1. รัน `wyn219-dump-admin-check-definitions.yml` (read-only) เพื่อดึงนิยามจริงจาก production — `schema.sql` อาจ drift
2. ย้ายทีละระบบตามลำดับ Maps → Merchant → Food → Social → Account → ส่วนกลาง (1 migration + 1 PR ต่อระบบ)
3. ทุกแถวในระบบนั้นต้องถูกย้าย และมี SQL regression test ครอบคลุม: super admin, edit, view, ไม่มีสิทธิ์, moderator เดิม, user ธรรมดา
4. แต่ละ migration มีไฟล์ rollback ที่คืนนิยามเดิมจาก dump

## Mapping rule

- `Today = admin` (`<> 'admin'`, `= 'admin'`, `food_is_platform_admin()`) → `<system>:edit`
- `Today = staff` (`not in ('admin','moderator')`, `<> 'user'`) → `<system>:view`, ยกเว้น action ของ moderator ใน Social → `social:edit` (Q2)
- Dashboard/metrics → ผ่านเมื่อมีสิทธิ์อย่างน้อย 1 ระบบ; Audit log → super admin เท่านั้น (Q3)
- แถว "not an admin gate" ใช้ `platform_role` เพื่อ logic ของ product (เช่น กรองเฉพาะ user) — ไม่ย้าย แต่ยืนยันกับ dump อีกครั้ง

## Inventory (generated from repository SQL, 2026-10-10)

| # | Kind | Object | Source file | Today | System | Proposed check |
|---|---|---|---|---|---|---|
| 1 | function | `internal.inactive_reminder_recipients` | `migrations_admin_inactive_reminders.sql` | other | account | not an admin gate (selects platform_role = 'user' recipients) — leave as is |
| 2 | function | `public.admin_count_inactive_users` | `migrations_admin_inactive_reminders.sql` | admin | account | account:edit |
| 3 | function | `public.admin_send_inactive_reminder` | `migrations_admin_inactive_reminders.sql` | admin | account | account:edit |
| 4 | function | `public.admin_user_directory` | `schema.sql` | staff | account | account:view |
| 5 | view | `public.admin_user_moderation_history` | `schema.sql` | staff | account | account:view |
| 6 | view | `public.admin_audit_log` | `schema.sql` | staff | central | super admin only (Q3) |
| 7 | function | `public.admin_dashboard_metrics` | `schema.sql` | staff | central | any permission |
| 8 | function | `public.admin_dashboard_trends` | `schema.sql` | staff | central | any permission |
| 9 | function | `public.admin_signup_counts` | `schema.sql` | staff | central | any permission |
| 10 | policy | `Food private readable by WYNOS admin ON storage.objects` | `migrations_wynos_admin_food_ops_v1.sql` | admin | food | food:edit |
| 11 | function | `public.admin_ad_overview` | `migrations_wynos_food_ads_v1.sql` | admin | food | food:edit |
| 12 | function | `public.admin_food_coupon_list` | `20261008161000_food_admin_coupons.sql` | admin | food | food:edit |
| 13 | function | `public.admin_food_coupon_set_active` | `20261008161000_food_admin_coupons.sql` | admin | food | food:edit |
| 14 | function | `public.admin_food_first_order_set_active` | `20261009230000_food_first_order_100_40.sql` | admin | food | food:edit |
| 15 | function | `public.admin_food_issue_coupon` | `20261008161000_food_admin_coupons.sql` | admin | food | food:edit |
| 16 | function | `public.admin_food_order_detail` | `migrations_wynos_admin_food_ops_v1.sql` | admin | food | food:edit |
| 17 | function | `public.admin_food_orders` | `migrations_wynos_admin_merchant_polish_v1.sql` | admin | food | food:edit |
| 18 | function | `public.admin_food_overview` | `migrations_wynos_admin_food_ops_v1.sql` | staff | food | food:view |
| 19 | function | `public.admin_food_promo_cancel` | `20261008161100_food_promo_notifications.sql` | admin | food | food:edit |
| 20 | function | `public.admin_food_promo_list` | `20261008161100_food_promo_notifications.sql` | staff | food | food:view |
| 21 | function | `public.admin_food_promo_schedule` | `20261008161100_food_promo_notifications.sql` | admin | food | food:edit |
| 22 | function | `public.admin_food_store_detail` | `migrations_wynos_admin_merchant_polish_v1.sql` | staff | food | food:view |
| 23 | function | `public.admin_food_stores` | `migrations_wynos_admin_food_ops_v1.sql` | staff | food | food:view |
| 24 | function | `public.admin_platform_campaigns` | `migrations_wynos_platform_campaigns_v1.sql` | staff | food | food:view |
| 25 | function | `public.admin_platform_owed` | `migrations_wynos_platform_campaigns_v1.sql` | admin | food | food:edit |
| 26 | function | `public.admin_review_ad_topup` | `migrations_wynos_food_ads_v1.sql` | admin | food | food:edit |
| 27 | function | `public.admin_set_ad_account_status` | `migrations_wynos_food_ads_v1.sql` | admin | food | food:edit |
| 28 | function | `public.admin_set_food_store_member_active` | `migrations_wynos_admin_food_ops_v1.sql` | admin | food | food:edit |
| 29 | function | `public.admin_set_food_store_suspension` | `migrations_wynos_admin_food_ops_v1.sql` | admin | food | food:edit |
| 30 | function | `public.admin_settle_platform_store` | `migrations_wynos_platform_campaigns_v1.sql` | admin | food | food:edit |
| 31 | function | `public.admin_update_ad_settings` | `migrations_wynos_food_ads_v1.sql` | admin | food | food:edit |
| 32 | function | `public.admin_upsert_platform_campaign` | `migrations_wynos_platform_campaigns_v1.sql` | admin | food | food:edit |
| 33 | function | `public.food_store_location_quality` | `migrations_wynos_merchant_production_readiness_v1.sql` | admin | food | food:edit |
| 34 | function | `public.food_store_publish_readiness` | `migrations_wynos_merchant_production_readiness_v1.sql` | admin | food | food:edit |
| 35 | policy | `Place photos delete own or admin ON storage.objects` | `migrations_wynos_maps_place_photos_v1.sql` | admin | maps | maps:edit |
| 36 | policy | `Place photos readable when approved ON storage.objects` | `migrations_wynos_maps_place_photos_v1.sql` | other | maps | verify on production: storage read policy with an admin branch → expected maps:view |
| 37 | function | `public.admin_import_wynos_places` | `migrations_wynos_places_manager_v1.sql` | admin | maps | maps:edit |
| 38 | function | `public.admin_review_wynos_place_photo` | `migrations_wynos_maps_place_photos_v1.sql` | admin | maps | maps:edit |
| 39 | function | `public.admin_review_wynos_place_suggestion` | `migrations_wynos_maps_place_suggestions_v1.sql` | admin | maps | maps:edit |
| 40 | function | `public.admin_set_wynos_place_active` | `migrations_wynos_places_manager_v1.sql` | admin | maps | maps:edit |
| 41 | function | `public.admin_upsert_wynos_place` | `migrations_wynos_places_manager_v1.sql` | admin | maps | maps:edit |
| 42 | function | `public.admin_wynos_place_for_store` | `migrations_wynos_places_manager_v1.sql` | staff | maps | maps:view |
| 43 | function | `public.admin_wynos_place_photos` | `migrations_wynos_maps_place_photos_v1.sql` | staff | maps | maps:view |
| 44 | function | `public.admin_wynos_place_suggestions` | `migrations_wynos_maps_place_suggestions_v1.sql` | staff | maps | maps:view |
| 45 | function | `public.admin_wynos_places` | `migrations_wynos_places_manager_v1.sql` | staff | maps | maps:view |
| 46 | function | `public.admin_merchant_applications` | `migrations_wynos_merchant_admin_review_v1.sql` | staff | merchant | merchant:view |
| 47 | function | `public.admin_review_merchant_application` | `migrations_wynos_merchant_admin_review_v1.sql` | admin | merchant | merchant:edit |
| 48 | function | `public.merchant_store_audit_history` | `migrations_wynos_merchant_production_readiness_v1.sql` | admin | merchant | merchant:edit |
| 49 | policy | `Appellants and moderators can view appeal evidence ON storage.objects` | `schema.sql` | staff | social | social:view |
| 50 | policy | `Moderators can view all appeals ON public.appeals` | `schema.sql` | staff | social | social:view |
| 51 | policy | `Moderators can view moderation action history ON public.moderation_actions` | `schema.sql` | staff | social | social:view |
| 52 | function | `public.admin_apply_user_action` | `schema.sql` | staff | social | social:edit (Q2) |
| 53 | function | `public.admin_feed_algorithm_dashboard` | `migrations_wyn146_feed_algorithm_v1.sql` | staff | social | social:view |
| 54 | function | `public.admin_get_drop` | `schema.sql` | staff | social | social:view |
| 55 | function | `public.admin_remove_drop` | `schema.sql` | staff | social | social:edit (Q2) |
| 56 | function | `public.admin_restore_drop` | `schema.sql` | staff | social | social:edit (Q2) |
| 57 | function | `public.admin_search_drops` | `schema.sql` | staff | social | social:view |
| 58 | function | `public.admin_send_announcement` | `schema.sql` | admin | social | social:edit |
| 59 | function | `public.admin_unban_user` | `schema.sql` | staff | social | social:edit (Q2) |
| 60 | function | `public.apply_moderation_action` | `migrations_wyn128_club_channel_messages.sql` | other | social | verify on production: reviewer-role check (`select platform_role into …`) → expected social:edit (Q2) |
| 61 | function | `public.decide_appeal` | `schema.sql` | other | social | verify on production: reviewer-role check → expected social:edit (Q2) |
| 62 | function | `public.get_message_for_moderation` | `schema.sql` | staff | social | social:view |
| 63 | view | `public.moderation_queue` | `schema.sql` | staff | social | social:view |
| 64 | function | `public.send_system_notification` | `schema.sql` | admin | social | social:edit |
| 65 | policy | `Users can insert their own profile ON public.profiles` | `schema.sql` | other | — | not an admin gate (reads platform_role for product logic) — leave as is, confirm |
| 66 | policy | `Users can update their own notification settings ON public.notification_settings` | `schema.sql` | other | — | not an admin gate (reads platform_role for product logic) — leave as is, confirm |
| 67 | function | `public.authors_posting_blocked` | `schema.sql` | other | — | not an admin gate (reads platform_role for product logic) — leave as is, confirm |
| 68 | view | `public.home_feed` | `schema.sql` | other | — | not an admin gate (reads platform_role for product logic) — leave as is, confirm |
| 69 | function | `public.search_profiles_ranked` | `20260929132826_web_people_search_ranked.sql` | other | — | not an admin gate (reads platform_role for product logic) — leave as is, confirm |

Total: 69

> รายการนี้สร้างจาก SQL ใน repository — รายการที่เชื่อถือได้คือ dump จาก production; ถ้า dump มี function ที่ไม่อยู่ในตารางนี้ ต้องเพิ่มก่อนเริ่มระบบนั้น

## Production comparison (2026-10-10)

Dump: `wyn219-dump-admin-check-definitions.yml` run [38059388028](https://github.com/warren-wyn-dev/wynteam/actions/runs/38059388028) (artifact `wyn219-admin-check-definitions`, kept until 2026-11-09) — 60 functions, 7 policies, 3 views

| ผล | Object | ข้อสรุป |
|---|---|---|
| **มีใน production แต่ไม่มีใน repo เลย** | `public.admin_activity_trend` | drift: สร้างนอก repo; ตรวจ `not in ('admin','moderator')` → เพิ่มเข้า **ส่วนกลาง: any permission** และต้องเก็บนิยามจาก dump ลง migration ของ step 2 (ไม่มีไฟล์ใน repo ให้อ้างอิง) |
| มีใน repo inventory แต่ production ไม่อ้าง `platform_role` แล้ว | `public.home_feed`, `public.authors_posting_blocked`, policy `Users can update their own notification settings` | เป็นแถว "not an admin gate" อยู่แล้ว — ตัดออกจากงาน step 2 |
| ตรงกัน | ที่เหลือทั้งหมด รวม 7 policies (appeals, moderation_actions, profiles insert, storage: appeal evidence, food-private, place photos ×2) | ใช้ mapping ตามตาราง |

ยังไม่มี object ของ WYN-219 foundation ใน production (ถูกต้อง — ยังไม่ apply)
