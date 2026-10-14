-- Disable the new API while preserving reports and immutable review evidence.
revoke all on function public.wynos_my_map_reports(integer),public.submit_wynos_map_report(text,text,text),
 public.admin_wynos_map_reports(text,integer),public.admin_wynos_map_report_history(uuid),
 public.admin_update_wynos_map_report(uuid,integer,text,text) from public,anon,authenticated;
revoke all on public.wynos_map_reports,public.wynos_map_report_events from public,anon,authenticated;
-- Reapply the forward migration to restore API access. Do not drop stored reports,
-- event history or the harmless added audit event type during rollback.
