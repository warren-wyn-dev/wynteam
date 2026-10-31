-- Rollback for 20261031120000_zoky_line_links.sql (ZOKY-LINE-001).
-- Destructive: removes every stored LINE link. Requires Founder approval
-- before running on production. Disable LINE delivery first
-- (unset LINE_NOTIFICATIONS_ENABLED on the Edge Functions).

drop table if exists public.line_links;
