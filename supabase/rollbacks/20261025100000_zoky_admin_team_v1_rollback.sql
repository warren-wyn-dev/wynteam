-- Rollback for 20261025100000_zoky_admin_team_v1.sql (ZOKY-ADMIN-001).
--
-- Removes the ZOKY Team Lead objects only. public.admin_permissions is left
-- untouched: every food/merchant permission a Lead granted stays in force
-- (and visible to the super admin in WYNOS Admin -> Roles & Permissions) and
-- can be revoked there. The two extra audit_log event types are harmless and
-- stay, as in the WYN-219 foundation rollback.

drop function if exists public.admin_zoky_revoke_permission(uuid, text);
drop function if exists public.admin_zoky_grant_permission(uuid, text, text);
drop function if exists public.admin_zoky_list_team();
drop function if exists public.admin_zoky_find_user(text);
drop function if exists public.admin_set_zoky_team_lead(uuid, boolean);
drop function if exists public.zoky_admin_my_access();
drop function if exists internal.zoky_assert_can_manage(uuid, text);
drop function if exists internal.is_zoky_team_lead();
drop table if exists internal.zoky_team_leads;
