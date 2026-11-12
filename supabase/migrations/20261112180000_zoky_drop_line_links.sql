-- ZOKY-LINE-REMOVAL-001 (L3): LINE is removed from ZOKY.
--
-- Founder decision 2026-11-12: "ไม่มีใครเคยใช้ไลน์ นอกจากผม ... เอาออกได้เลย"
-- (nobody except the Founder ever used LINE; remove it). The Edge Functions
-- line-link / line-webhook, the LINE delivery in send-push-notification and
-- all LINE web/Merchant UI are already removed (PRs #1344, #1345).
--
-- DESTRUCTIVE: drops every stored LINE link. Applying this to production
-- needs the Founder's explicit go-ahead at apply time (see
-- supabase/rollbacks/20261031120000_zoky_line_links_rollback.sql).
-- Rollback: re-run 20261031120000_zoky_line_links.sql (structure only; link
-- rows are not restored, a LINE link can be recreated by the user).

drop table if exists public.line_links;
