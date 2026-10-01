-- WYNOS Web Beta 1 — private pg_cron -> Edge Function authentication.
-- The raw scheduler token is generated inside Postgres and stored only in Vault.
-- Edge Functions validate its SHA-256 hash through a service-role-only RPC.

create table if not exists internal.web_reactivation_cron_auth (
  singleton boolean primary key default true check (singleton),
  token_hash text not null,
  updated_at timestamptz not null default now()
);

revoke all on table internal.web_reactivation_cron_auth from public, anon, authenticated;

do $$
declare
  v_secret_id uuid;
  v_token text;
begin
  select id
  into v_secret_id
  from vault.secrets
  where name = 'wynos_reactivation_cron_token'
  limit 1;

  if v_secret_id is null then
    v_token := encode(extensions.gen_random_bytes(32), 'hex');
    perform vault.create_secret(
      v_token,
      'wynos_reactivation_cron_token',
      'Private token for the WYNOS Web Beta1 reactivation scheduler'
    );
  else
    select decrypted_secret
    into v_token
    from vault.decrypted_secrets
    where id = v_secret_id;
  end if;

  insert into internal.web_reactivation_cron_auth (
    singleton,
    token_hash,
    updated_at
  )
  values (
    true,
    encode(extensions.digest(v_token, 'sha256'), 'hex'),
    now()
  )
  on conflict (singleton) do update
  set
    token_hash = excluded.token_hash,
    updated_at = excluded.updated_at;
end;
$$;

create or replace function public.validate_web_reactivation_cron_token(p_token text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hash text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'service role required';
  end if;

  if p_token is null or length(p_token) < 32 then
    return false;
  end if;

  select token_hash
  into v_hash
  from internal.web_reactivation_cron_auth
  where singleton = true;

  return v_hash is not null
    and v_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
end;
$$;

revoke all on function public.validate_web_reactivation_cron_token(text) from public, anon, authenticated;
grant execute on function public.validate_web_reactivation_cron_token(text) to service_role;
