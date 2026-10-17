-- Disable ingestion/report APIs first. Keep private receipts/aggregates for a
-- reviewed forward re-apply; no customer content or telemetry is destroyed.
drop function if exists public.food_record_home_placement_event(text,uuid,uuid,text);
drop function if exists public.admin_food_home_placement_analytics(text,integer);
revoke all on internal.food_home_placement_receipts, internal.food_home_placement_daily,
  internal.food_home_analytics_budget from public,anon,authenticated;
