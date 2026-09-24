-- Run only in an isolated throwaway PostgreSQL database after loading
-- schema.sql, WYN-155 privilege hardening, and the Beta1 privacy migration.
-- Never run these fixture INSERTs against production.
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email) values
 ('91919191-9191-4191-8191-919191919191', 'invite-preview-qa@example.invalid');

insert into public.profiles (id, username, display_name, platform_role) values
 ('91919191-9191-4191-8191-919191919191', 'invite_preview_qa', 'Invite Preview QA', 'user');

insert into public.clubs (id, name, privacy, owner_id, icon_url) values
 ('92929292-9292-4292-8292-929292929292', 'Private Invite Preview QA', 'private',
 '91919191-9191-4191-8191-919191919191', 'clubs/private-qa.png');

insert into public.club_invite_links
 (id, club_id, code, created_by, expires_at, max_uses, use_count, revoked_at)
values
 ('93939393-9393-4393-8393-939393939391',
  '92929292-9292-4292-8292-929292929292',
  'beta1-qa-valid', '91919191-9191-4191-8191-919191919191',
  now() + interval '1 day', null, 0, null),
 ('93939393-9393-4393-8393-939393939392',
  '92929292-9292-4292-8292-929292929292',
  'beta1-qa-revoked', '91919191-9191-4191-8191-919191919191',
  null, null, 0, now() - interval '1 minute'),
 ('93939393-9393-4393-8393-939393939393',
  '92929292-9292-4292-8292-929292929292',
  'beta1-qa-expired', '91919191-9191-4191-8191-919191919191',
  now() - interval '1 day', null, 0, null),
 ('93939393-9393-4393-8393-939393939394',
  '92929292-9292-4292-8292-929292929292',
  'beta1-qa-exhausted', '91919191-9191-4191-8191-919191919191',
  null, 1, 1, null);

-- Probe the actual public-facing RPC as the real PostgREST anonymous role,
-- NOT just via postgres (which bypasses the execute grant).
set role anon;
do $$
declare
  bad_count integer;
begin
  select count(*) into bad_count
  from (values
    ('beta1-qa-valid', 'valid'),
    ('beta1-qa-revoked', 'revoked'),
    ('beta1-qa-expired', 'expired'),
    ('beta1-qa-exhausted', 'exhausted'),
    ('beta1-qa-unknown', 'not_found')
  ) expected(code, expected_status)
  left join lateral public.preview_club_invite_link(expected.code) preview on true
  where preview.status is distinct from expected.expected_status
    or (
      expected.expected_status = 'valid'
      and (
        preview.club_id is distinct from '92929292-9292-4292-8292-929292929292'::uuid
        or preview.club_name is distinct from 'Private Invite Preview QA'
        or preview.club_privacy is distinct from 'private'
        or preview.club_icon_url is distinct from 'clubs/private-qa.png'
      )
    )
    or (
      expected.expected_status <> 'valid'
      and num_nonnulls(preview.club_id, preview.club_name,
                       preview.club_privacy, preview.club_icon_url) <> 0
    );

  if bad_count <> 0 then
    raise exception 'Public invite preview privacy check failed: % mismatched statuses or leaked club fields',
                    bad_count;
  end if;
end;
$$;
reset role;
rollback;
