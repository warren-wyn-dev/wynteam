-- WYN-185 (WYNOS Web Beta1, item 11): Edit Profile gets an external
-- website field. Reuses the existing `profiles.social_links` jsonb column
-- (added by migrations_edit_profile_social_links.sql for Instagram/
-- Twitter/YouTube, never actually built in the web UI until now) with a
-- new `website` key, rather than adding a dedicated column, since the
-- shape (a small map of link-type -> URL) already fits.
--
-- `social_links` has never had any server-side shape/content validation --
-- the "Users can update their own profile row" RLS policy is `using
-- (auth.uid() = id)` with no WITH CHECK content restriction at all, so a
-- raw REST PATCH bypassing the client's own normalizeExternalUrl()
-- (web/lib/external-link.ts) could currently write arbitrary jsonb
-- (any shape, any size, any scheme including javascript:/data:) into this
-- column. This migration closes that with a BEFORE INSERT OR UPDATE
-- trigger (a CHECK constraint can express this, but a trigger gives a
-- clearer per-field error message and is easier to extend if more link
-- types are added later).
--
-- HOW TO APPLY: Supabase Dashboard -> SQL Editor. The Founder runs it; no
-- AI applies production SQL (per AGENTS.md Change Control).

create or replace function public.profiles_validate_social_links()
returns trigger
language plpgsql
as $$
declare
  v_key text;
  v_value text;
  v_allowed_keys text[] := array['website', 'instagram', 'twitter', 'youtube'];
begin
  if new.social_links is null then
    return new;
  end if;
  if jsonb_typeof(new.social_links) <> 'object' then
    raise exception 'social_links must be a JSON object';
  end if;
  if (select count(*) from jsonb_object_keys(new.social_links)) > array_length(v_allowed_keys, 1) then
    raise exception 'social_links has too many entries';
  end if;
  for v_key in select jsonb_object_keys(new.social_links) loop
    if not (v_key = any(v_allowed_keys)) then
      raise exception 'social_links has an unrecognized key: %', v_key;
    end if;
    if jsonb_typeof(new.social_links -> v_key) <> 'string' then
      raise exception 'social_links.% must be a string', v_key;
    end if;
    v_value := new.social_links ->> v_key;
    if char_length(v_value) = 0 then
      raise exception 'social_links.% must not be an empty string (omit the key instead)', v_key;
    end if;
    if char_length(v_value) > 300 then
      raise exception 'social_links.% is too long', v_key;
    end if;
    -- http(s) only, no whitespace/control characters -- blocks
    -- javascript:/data:/file: and embedded newlines alike. Intentionally
    -- coarser than web/lib/external-link.ts's full URL-object validation
    -- (a Postgres regex can't parse a URL the way the browser's URL class
    -- does) -- this is the defense-in-depth backstop, not the primary UX.
    if v_value !~ '^https?://[^\s<>"]+$' then
      raise exception 'social_links.% must be a valid http(s) URL', v_key;
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists profiles_validate_social_links on public.profiles;
create trigger profiles_validate_social_links
  before insert or update on public.profiles
  for each row execute function public.profiles_validate_social_links();
