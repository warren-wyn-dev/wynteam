-- Applied separately to production after testing the WYN-185 member-count RPCs.
-- Supabase project defaults include explicit anon EXECUTE grants. Revoking
-- PUBLIC alone does not revoke explicit anon EXECUTE on a new function.
revoke execute on function public.club_member_count(uuid) from anon;
revoke execute on function public.club_member_counts(uuid[]) from anon;
revoke execute on function public.club_member_count(uuid) from public;
revoke execute on function public.club_member_counts(uuid[]) from public;
