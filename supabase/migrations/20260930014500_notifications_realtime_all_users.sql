-- WYNOS Web — release Notifications Realtime to every signed-in account.
-- The web client still filters by recipient_id and the notifications table's
-- existing RLS remains authoritative. Push/poll/focus fallbacks stay active.

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'notifications'
     ) then
    execute 'alter publication supabase_realtime add table public.notifications';
  end if;
end
$$;
