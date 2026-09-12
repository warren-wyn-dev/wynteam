-- WYN-156 / system audit: sensitive SECURITY DEFINER-style views are read-only
-- API projections. Historical/default grants left anon/authenticated with DML
-- privileges on these views even though every application use is SELECT-only.
--
-- Keep the current view definitions and their row/role filters intact. The
-- admin views intentionally need creator privileges to read protected source
-- tables after internal.current_platform_role() authorizes staff; switching
-- them to security_invoker here would break those reads. This migration fixes
-- the concrete privilege leak without changing view semantics.

revoke all on table public.moderation_queue
  from public, anon, authenticated;
revoke all on table public.admin_user_moderation_history
  from public, anon, authenticated;
revoke all on table public.admin_audit_log
  from public, anon, authenticated;
revoke all on table public.my_effective_affinities
  from public, anon, authenticated;

-- Signed-in callers may read the projections. The three admin projections
-- still enforce their existing staff-role predicates; my_effective_affinities
-- still filters to auth.uid(). No client role may insert/update/delete through
-- the views after this migration.
grant select on table public.moderation_queue to authenticated;
grant select on table public.admin_user_moderation_history to authenticated;
grant select on table public.admin_audit_log to authenticated;
grant select on table public.my_effective_affinities to authenticated;
