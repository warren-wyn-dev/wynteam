-- WYNOS Food short share links (Founder 2026-10-05: "ชื่อลิ้งยาว แก้ได้ไหม" ->
-- "รหัสสั้น 6 ตัว"). Every store gets a random 6-character code so the shared
-- link is food.wynos.online/s/<code> instead of /?store=<uuid>.
-- * The code is assigned by the database on insert and can never be changed
--   by anyone through the API (merchants cannot squat or rename codes).
-- * food_store_id_by_share_code resolves a code only for a published,
--   non-suspended store and returns nothing but its id; the store profile
--   still comes from food_store_share_preview.
-- * food_store_share_preview also returns share_code for the preview URL.
-- Additive only; old /?store=<uuid> links keep working.
-- ROLLBACK:
--   drop function public.food_store_id_by_share_code(text);
--   drop trigger food_stores_share_code on public.food_stores;
--   drop function internal.food_stores_share_code();
--   drop function internal.food_new_share_code();
--   alter table public.food_stores drop column share_code;
--   then re-run migrations_wynos_food_share_preview_v1.sql.

alter table public.food_stores add column if not exists share_code text;

do $$ begin
  alter table public.food_stores
    add constraint food_stores_share_code_format check (share_code ~ '^[a-hjkmnp-z2-9]{6}$');
exception when duplicate_object then null; end $$;

create unique index if not exists food_stores_share_code_key on public.food_stores (share_code);

-- No 0/o, 1/l/i: easy to read aloud and type. 31^6 ~ 887M codes.
-- Security definer so the uniqueness check sees every store, not just the
-- rows the caller's RLS allows, and so the trigger works for API inserts.
create or replace function internal.food_new_share_code()
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_alphabet constant text := 'abcdefghjkmnpqrstuvwxyz23456789';
  v_code text;
begin
  loop
    select string_agg(substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1), '')
      into v_code
      from generate_series(1, 6);
    exit when not exists (select 1 from public.food_stores where share_code = v_code);
  end loop;
  return v_code;
end;
$$;

create or replace function internal.food_stores_share_code()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.share_code := internal.food_new_share_code();
  else
    new.share_code := coalesce(old.share_code, internal.food_new_share_code());
  end if;
  return new;
end;
$$;

revoke all on function internal.food_new_share_code() from public, anon, authenticated;
revoke all on function internal.food_stores_share_code() from public, anon, authenticated;

drop trigger if exists food_stores_share_code on public.food_stores;
create trigger food_stores_share_code
before insert or update on public.food_stores
for each row execute function internal.food_stores_share_code();

-- Existing stores get their code from the trigger.
update public.food_stores set share_code = share_code where share_code is null;

alter table public.food_stores alter column share_code set not null;

create or replace function public.food_store_id_by_share_code(p_code text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
  from public.food_stores s
  where s.share_code = lower(btrim(coalesce(p_code, '')))
    and s.is_published
    and s.admin_suspended_at is null
$$;

revoke all on function public.food_store_id_by_share_code(text) from public;
grant execute on function public.food_store_id_by_share_code(text) to anon, authenticated;

-- Same as migrations_wynos_food_share_preview_v1.sql, plus share_code.
drop function if exists public.food_store_share_preview(uuid);
create function public.food_store_share_preview(p_store_id uuid)
returns table (
  id uuid,
  name text,
  description text,
  logo_path text,
  cover_path text,
  share_code text
)
language sql
stable
security definer
set search_path = ''
as $$
  select s.id,
         s.name,
         left(nullif(btrim(coalesce(s.description, '')), ''), 160),
         s.logo_path,
         s.cover_path,
         s.share_code
  from public.food_stores s
  where s.id = p_store_id
    and s.is_published
    and s.admin_suspended_at is null
$$;

revoke all on function public.food_store_share_preview(uuid) from public;
grant execute on function public.food_store_share_preview(uuid) to anon, authenticated;
