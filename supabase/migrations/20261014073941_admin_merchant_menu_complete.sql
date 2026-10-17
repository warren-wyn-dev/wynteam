-- Admin merchant menu completion. Additive only: order snapshots and media
-- objects are never changed or deleted. Restored menus require a later,
-- explicit availability edit before customers can buy them again.
begin;

-- Preserve every existing audit type, including the ANY(array) form used by
-- earlier merchant migrations. Rollback keeps these values for audit history.
do $$
declare v_name text; v_def text; v_values text[];
  v_new text[]:=array['merchant_menu_created','merchant_menu_updated','merchant_menu_archived','merchant_menu_restored','merchant_menu_categories_updated'];
begin
  select c.conname,pg_get_constraintdef(c.oid) into v_name,v_def from pg_constraint c
  where c.conrelid='public.audit_log'::regclass and c.contype='c'
    and pg_get_constraintdef(c.oid) like '%event_type%' limit 1;
  if v_def is null then raise exception 'audit_log event_type check constraint not found'; end if;
  select array_agg(distinct x.m[1] order by x.m[1]) into v_values
    from regexp_matches(v_def,'''([a-z0-9_]+)''','g') x(m);
  if v_values is null then
    select array_agg(distinct btrim(v) order by btrim(v)) into v_values
      from regexp_matches(v_def,'''\{([^}]*)\}''') x(m),unnest(string_to_array(x.m[1],',')) v;
  end if;
  if v_values is null or cardinality(v_values)<2
    or exists(select 1 from unnest(v_values) v where v !~ '^[a-z0-9_]+$') then raise exception 'Cannot read audit event types'; end if;
  if not v_new <@ v_values then
    select array_agg(distinct v order by v) into v_values from unnest(v_values||v_new) v;
    execute format('alter table public.audit_log drop constraint %I',v_name);
    execute format('alter table public.audit_log add constraint %I check (event_type = any (%L::text[]))',v_name,v_values);
  end if;
end $$;

alter table public.food_menu_items add column if not exists archived_at timestamptz;
do $$ begin
  if not exists (select 1 from pg_constraint where conrelid='public.food_menu_items'::regclass and conname='food_menu_items_archive_unavailable') then
    alter table public.food_menu_items add constraint food_menu_items_archive_unavailable
      check (archived_at is null or not is_available);
  end if;
end $$;

-- Retain this lifecycle invariant with archived rows on rollback. Merchant
-- owners keep their existing table permissions, but restoring a menu cannot
-- also publish it in the same update; availability needs a later explicit edit.
create or replace function internal.food_menu_restore_unavailable()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.is_available then
    raise exception 'Restored menu must remain unavailable until a separate availability update'
      using errcode = '23514';
  end if;
  return new;
end $$;
revoke all on function internal.food_menu_restore_unavailable() from public, anon, authenticated;
drop trigger if exists food_menu_restore_unavailable on public.food_menu_items;
create trigger food_menu_restore_unavailable before update on public.food_menu_items
for each row when (old.archived_at is not null and new.archived_at is null)
execute function internal.food_menu_restore_unavailable();

-- Existing touch triggers use now(), which is constant within a transaction.
-- Run last so a version never repeats, including writes from older clients.
create or replace function internal.admin_menu_monotonic_version()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at:=greatest(clock_timestamp(),old.updated_at+interval '1 microsecond');
  return new;
end $$;
revoke all on function internal.admin_menu_monotonic_version() from public, anon, authenticated;
drop trigger if exists zz_admin_menu_monotonic_version on public.food_menu_items;
create trigger zz_admin_menu_monotonic_version before update on public.food_menu_items
for each row execute function internal.admin_menu_monotonic_version();
drop trigger if exists zz_admin_menu_catalog_version on public.food_stores;
create trigger zz_admin_menu_catalog_version before update on public.food_stores
for each row execute function internal.admin_menu_monotonic_version();

-- Lock the store BEFORE an inserted tuple exists, preventing a phantom menu
-- during a category rename. Existing row updates/deletes are covered by the
-- exact item-version snapshot and must not acquire a parent lock: UPDATE has
-- already locked the item when a row trigger runs, reversing the admin order.
create or replace function internal.admin_menu_touch_store()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='UPDATE' and new.store_id is distinct from old.store_id then
    raise exception 'Menu items cannot move between stores';
  end if;
  if tg_op='INSERT' then
    update public.food_stores set updated_at=clock_timestamp() where id=new.store_id;
  end if;
  return new;
end $$;
revoke all on function internal.admin_menu_touch_store() from public, anon, authenticated;
drop trigger if exists admin_menu_touch_store on public.food_menu_items;
create trigger admin_menu_touch_store before insert or update on public.food_menu_items
for each row execute function internal.admin_menu_touch_store();

-- Explicit response fields keep future schema additions out of this API.
create or replace function internal.admin_menu_row(p_item public.food_menu_items,p_store_name text)
returns jsonb language sql immutable set search_path = '' as $$
  select jsonb_build_object('id',(p_item).id,'store_id',(p_item).store_id,'store_name',p_store_name,
    'name',(p_item).name,'category',(p_item).category,'description',(p_item).description,'price',(p_item).price,
    'is_available',(p_item).is_available,'daily_stock_limit',(p_item).daily_stock_limit,'sold_out_until',(p_item).sold_out_until,
    'image_path',(p_item).image_path,'options',(p_item).options,'sort_order',(p_item).sort_order,
    'created_at',(p_item).created_at,'updated_at',(p_item).updated_at,'archived_at',(p_item).archived_at);
$$;
revoke all on function internal.admin_menu_row(public.food_menu_items,text) from public, anon, authenticated;

create or replace function internal.admin_menu_image_valid(p_store_id uuid,p_path text)
returns boolean language sql stable set search_path = '' as $$
  select (p_path ~ ('^stores/' || p_store_id::text || '/menu/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp)$')
      or p_path ~ ('^admin-menu/' || p_store_id::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.webp$'))
    and exists (
      select 1 from storage.objects o
      where o.bucket_id='food-public' and o.name=p_path
        and jsonb_typeof(o.metadata->'size')='number'
        and case when o.metadata->>'size' ~ '^[0-9]{1,8}$'
          then (o.metadata->>'size')::bigint between 1 and
            case when p_path like 'admin-menu/%' then 4194304 else 8388608 end else false end
        and o.metadata->>'mimetype'=case
          when p_path ~ '\.(jpg|jpeg)$' then 'image/jpeg'
          when p_path ~ '\.png$' then 'image/png'
          when p_path ~ '\.webp$' then 'image/webp' end
    );
$$;
revoke all on function internal.admin_menu_image_valid(uuid,text) from public, anon, authenticated;

-- Keep this reserved namespace immutable to every ordinary Storage caller,
-- even if an older or additional permissive policy still allows broad writes.
-- Service-role publishing uses its existing RLS bypass after trusted processing.
-- These restrictive guards are retained with objects/references on rollback.
drop policy if exists "Food admin menu trusted insert guard" on storage.objects;
create policy "Food admin menu trusted insert guard" on storage.objects
as restrictive for insert to public
with check (bucket_id is distinct from 'food-public' or split_part(name,'/',1) is distinct from 'admin-menu');
drop policy if exists "Food admin menu trusted update guard" on storage.objects;
create policy "Food admin menu trusted update guard" on storage.objects
as restrictive for update to public
using (bucket_id is distinct from 'food-public' or split_part(name,'/',1) is distinct from 'admin-menu')
with check (bucket_id is distinct from 'food-public' or split_part(name,'/',1) is distinct from 'admin-menu');
drop policy if exists "Food admin menu trusted delete guard" on storage.objects;
create policy "Food admin menu trusted delete guard" on storage.objects
as restrictive for delete to public
using (bucket_id is distinct from 'food-public' or split_part(name,'/',1) is distinct from 'admin-menu');

-- Storage's existing store-owned write policies intentionally reject the
-- admin-menu namespace. Only the trusted image-processing Edge Function writes
-- immutable objects there. Merchant owners keep their menu permissions, but
-- cannot attach another store's trusted image through a direct table write.
-- Unchanged references remain usable even if a historical object is missing.
-- Retain this guard and its validator with persisted image references on rollback.
create or replace function internal.food_menu_image_reference_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='UPDATE' and new.image_path is not distinct from old.image_path
    and new.store_id is not distinct from old.store_id then return new; end if;
  if new.image_path is null then return new; end if;
  -- getPublicUrl() builds a URL: dot segments or URL-shaped input can otherwise
  -- resolve outside the literal path checked below. Existing legacy references
  -- are exempt above; changed references must be safe relative object names.
  if new.image_path ~ '[[:cntrl:]]' or new.image_path like '/%'
    or position(chr(92) in new.image_path)>0
    or new.image_path ~ '^[A-Za-z][A-Za-z0-9+.-]*:'
    or new.image_path ~ '(^|/)\.{1,2}(/|$)' then
    raise exception 'Invalid menu image path' using errcode='23514';
  end if;
  if new.image_path ~ '(^|/)admin-menu(/|$)'
    and not coalesce(internal.admin_menu_image_valid(new.store_id,new.image_path),false) then
    raise exception 'Invalid menu image' using errcode='23514';
  end if;
  return new;
end $$;
revoke all on function internal.food_menu_image_reference_guard() from public, anon, authenticated;
drop trigger if exists food_menu_image_reference_guard on public.food_menu_items;
create trigger food_menu_image_reference_guard before insert or update of image_path,store_id on public.food_menu_items
for each row execute function internal.food_menu_image_reference_guard();

-- One bounded budget row per existing actor, shared across all stores. No
-- Storage privileges or membership changes are granted by this authorization.
create table if not exists internal.admin_menu_upload_budgets (
  actor_id uuid primary key references public.profiles(id) on delete cascade,
  window_started_at timestamptz not null,
  attempts smallint not null check (attempts between 1 and 10)
);
alter table internal.admin_menu_upload_budgets enable row level security;
revoke all on table internal.admin_menu_upload_budgets from public, anon, authenticated;

create or replace function public.admin_authorize_merchant_menu_upload(p_store_id uuid)
returns boolean language plpgsql volatile security definer set search_path = '' as $$
declare v_actor uuid:=(select auth.uid()); v_now timestamptz:=clock_timestamp(); v_attempts smallint;
begin
  if v_actor is null or not internal.has_admin_permission('merchant','edit') then raise exception 'Not authorized'; end if;
  if p_store_id is null or not exists(select 1 from public.food_stores where id=p_store_id) then raise exception 'Store not found'; end if;
  -- ON CONFLICT locks the actor row and tests the latest committed counter,
  -- including overlapping uploads to different stores. Rejected calls do not
  -- increase the counter, and expired windows reset without accumulating rows.
  insert into internal.admin_menu_upload_budgets as b(actor_id,window_started_at,attempts)
  values(v_actor,v_now,1)
  on conflict(actor_id) do update set
    window_started_at=case when b.window_started_at<=excluded.window_started_at-interval '10 minutes'
      then excluded.window_started_at else b.window_started_at end,
    attempts=case when b.window_started_at<=excluded.window_started_at-interval '10 minutes'
      then 1 else b.attempts+1 end
  where b.window_started_at<=excluded.window_started_at-interval '10 minutes' or b.attempts<10
  returning attempts into v_attempts;
  if not found then raise exception 'Menu image upload limit reached'; end if;
  return true;
end $$;
revoke all on function public.admin_authorize_merchant_menu_upload(uuid) from public, anon;
grant execute on function public.admin_authorize_merchant_menu_upload(uuid) to authenticated;

create or replace function internal.admin_menu_options(p_options jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare
  v_group jsonb; v_choice jsonb; v_groups jsonb := '[]'; v_choices jsonb;
  v_group_ids text[] := '{}'; v_choice_ids text[]; v_id text; v_name text;
  v_group_id text; v_group_name text; v_max integer; v_price numeric;
begin
  if p_options is null or jsonb_typeof(p_options)<>'array' then raise exception 'Invalid menu options'; end if;
  if jsonb_array_length(p_options)>20 then raise exception 'Invalid menu options'; end if;
  for v_group in select value from jsonb_array_elements(p_options) loop
    if jsonb_typeof(v_group)<>'object'
      or jsonb_typeof(v_group->'id') is distinct from 'string'
      or jsonb_typeof(v_group->'name') is distinct from 'string'
      or jsonb_typeof(v_group->'required') is distinct from 'boolean'
      or jsonb_typeof(v_group->'max_select') is distinct from 'number'
      or jsonb_typeof(v_group->'choices') is distinct from 'array' then raise exception 'Invalid menu options'; end if;
    v_group_id:=btrim(v_group->>'id'); v_group_name:=btrim(v_group->>'name');
    if char_length(v_group_id) not between 1 and 80 or char_length(v_group_name) not between 1 and 160
      or v_group_id=any(v_group_ids) or (v_group->>'max_select') !~ '^[0-9]{1,2}$'
      or jsonb_array_length(v_group->'choices') not between 1 and 50 then raise exception 'Invalid menu options'; end if;
    v_max:=(v_group->>'max_select')::integer;
    if v_max not between 1 and least(20,jsonb_array_length(v_group->'choices')) then raise exception 'Invalid menu options'; end if;
    v_group_ids:=array_append(v_group_ids,v_group_id); v_choice_ids:='{}'; v_choices:='[]';
    for v_choice in select value from jsonb_array_elements(v_group->'choices') loop
      if jsonb_typeof(v_choice)<>'object'
        or jsonb_typeof(v_choice->'id') is distinct from 'string'
        or jsonb_typeof(v_choice->'name') is distinct from 'string'
        or jsonb_typeof(v_choice->'price') is distinct from 'number' then raise exception 'Invalid menu options'; end if;
      v_id:=btrim(v_choice->>'id'); v_name:=btrim(v_choice->>'name'); v_price:=(v_choice->>'price')::numeric;
      if char_length(v_id) not between 1 and 80 or char_length(v_name) not between 1 and 160
        or v_id=any(v_choice_ids) or v_price<0 or v_price>100000 or v_price<>round(v_price,2) then raise exception 'Invalid menu options'; end if;
      v_choice_ids:=array_append(v_choice_ids,v_id);
      v_choices:=v_choices||jsonb_build_array(jsonb_build_object('id',v_id,'name',v_name,'price',round(v_price,2)));
    end loop;
    v_groups:=v_groups||jsonb_build_array(jsonb_build_object('id',v_group_id,'name',v_group_name,
      'required',v_group->'required','max_select',v_max,'choices',v_choices));
  end loop;
  return v_groups;
end $$;
revoke all on function internal.admin_menu_options(jsonb) from public, anon, authenticated;

create or replace function public.admin_merchant_menu_catalog(p_store_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_stores jsonb; v_items jsonb; v_images jsonb;
begin
  if auth.uid() is null or not internal.has_admin_permission('merchant','view') then raise exception 'Not authorized'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name,
    'menu_category_order',s.menu_category_order,'updated_at',s.updated_at) order by s.name,s.id),'[]') into v_stores
  from public.food_stores s where p_store_id is null or s.id=p_store_id;
  select coalesce(jsonb_agg(internal.admin_menu_row(m,s.name)
    order by s.name,m.category,m.sort_order,m.name,m.id),'[]') into v_items
  from public.food_menu_items m join public.food_stores s on s.id=m.store_id
  where p_store_id is null or m.store_id=p_store_id;
  select coalesce(jsonb_agg(jsonb_build_object('store_id',i.store_id,'path',i.name) order by i.name),'[]') into v_images
  from (select s.id store_id,o.name from public.food_stores s join storage.objects o
    on o.bucket_id='food-public' and (o.name like 'stores/'||s.id::text||'/menu/%'
      or o.name like 'admin-menu/'||s.id::text||'/%')
    where (p_store_id is null or s.id=p_store_id) and internal.admin_menu_image_valid(s.id,o.name)
    order by o.name limit 500) i;
  return jsonb_build_object('stores',v_stores,'items',v_items,'images',v_images);
end $$;
revoke all on function public.admin_merchant_menu_catalog(uuid) from public, anon;
grant execute on function public.admin_merchant_menu_catalog(uuid) to authenticated;

create or replace function public.admin_merchant_menu_items(p_store_id uuid default null)
returns jsonb language sql stable security definer set search_path = '' as $$
  select public.admin_merchant_menu_catalog(p_store_id)->'items';
$$;
revoke all on function public.admin_merchant_menu_items(uuid) from public, anon;
grant execute on function public.admin_merchant_menu_items(uuid) to authenticated;

create or replace function public.admin_save_merchant_menu_item(
  p_item_id uuid,p_store_id uuid,p_expected_updated_at timestamptz,p_values jsonb,p_reason text
)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  v_item public.food_menu_items%rowtype; v_saved public.food_menu_items%rowtype;
  v_store_name text; v_name text; v_category text; v_description text; v_image text;
  v_price numeric; v_stock integer; v_sold_out timestamptz; v_available boolean; v_options jsonb;
  v_before jsonb; v_after jsonb; v_reason text:=btrim(coalesce(p_reason,''));
begin
  if auth.uid() is null or not internal.has_admin_permission('merchant','edit') then raise exception 'Not authorized'; end if;
  if char_length(v_reason) not between 5 and 300 then raise exception 'A reason of 5-300 characters is required'; end if;
  if p_store_id is null or p_values is null or jsonb_typeof(p_values)<>'object'
    or not (p_values ?& array['name','category','description','price','is_available','daily_stock_limit','sold_out_until','image_path','options'])
    or p_values - array['name','category','description','price','is_available','daily_stock_limit','sold_out_until','image_path','options'] <> '{}'::jsonb
    or jsonb_typeof(p_values->'name') is distinct from 'string'
    or jsonb_typeof(p_values->'category') is distinct from 'string'
    or jsonb_typeof(p_values->'description') not in ('string','null')
    or jsonb_typeof(p_values->'price') is distinct from 'number'
    or jsonb_typeof(p_values->'is_available') is distinct from 'boolean'
    or jsonb_typeof(p_values->'daily_stock_limit') not in ('number','null')
    or jsonb_typeof(p_values->'sold_out_until') not in ('string','null')
    or jsonb_typeof(p_values->'image_path') not in ('string','null') then raise exception 'Invalid menu settings'; end if;
  v_name:=btrim(p_values->>'name'); v_category:=btrim(p_values->>'category');
  v_description:=nullif(btrim(p_values->>'description'),''); v_image:=nullif(btrim(p_values->>'image_path'),'');
  v_price:=(p_values->>'price')::numeric; v_available:=(p_values->>'is_available')::boolean;
  if char_length(v_name) not between 1 and 160 or char_length(v_category) not between 1 and 60
    or char_length(v_description)>1000 or v_price<0 or v_price>100000 or v_price<>round(v_price,2)
    or (p_values->>'daily_stock_limit' is not null and (p_values->>'daily_stock_limit') !~ '^[0-9]{1,4}$') then raise exception 'Invalid menu settings'; end if;
  v_stock:=(p_values->>'daily_stock_limit')::integer;
  if v_stock is not null and v_stock not between 1 and 9999 then raise exception 'Invalid menu settings'; end if;
  begin v_sold_out:=(p_values->>'sold_out_until')::timestamptz;
  exception when invalid_datetime_format or datetime_field_overflow then raise exception 'Invalid sold out time'; end;
  if v_sold_out is not null and not isfinite(v_sold_out) then raise exception 'Invalid sold out time'; end if;
  v_options:=internal.admin_menu_options(p_values->'options');
  select name into v_store_name from public.food_stores where id=p_store_id for update;
  if not found then raise exception 'Store not found'; end if;
  if p_item_id is not null then
    select * into v_item from public.food_menu_items where id=p_item_id and store_id=p_store_id for update;
    if not found then raise exception 'Menu item not found'; end if;
    if v_item.archived_at is not null then raise exception 'Restore archived menu before editing'; end if;
    if p_expected_updated_at is null or v_item.updated_at is distinct from p_expected_updated_at then raise exception 'Menu item changed; refresh before saving'; end if;
    v_before:=internal.admin_menu_row(v_item,v_store_name);
  elsif p_expected_updated_at is not null then raise exception 'New menu cannot have an existing version'; end if;
  -- Retaining a legacy image needs no new media authorization. Every changed
  -- link must name an existing object of this store with exact supported metadata.
  if v_image is not null and (p_item_id is null or v_image is distinct from v_item.image_path)
    and not internal.admin_menu_image_valid(p_store_id,v_image) then raise exception 'Invalid menu image'; end if;
  if p_item_id is null then
    insert into public.food_menu_items(store_id,name,category,description,price,is_available,daily_stock_limit,sold_out_until,image_path,options)
    values(p_store_id,v_name,v_category,v_description,round(v_price,2),v_available,v_stock,v_sold_out,v_image,v_options)
    returning * into v_saved;
  else
    v_after:=jsonb_build_object('name',v_name,'category',v_category,'description',v_description,'price',round(v_price,2),
      'is_available',v_available,'daily_stock_limit',v_stock,'sold_out_until',v_sold_out,'image_path',v_image,'options',v_options);
    if v_after=v_before - array['id','store_id','store_name','sort_order','created_at','updated_at','archived_at'] then raise exception 'No changes to save'; end if;
    update public.food_menu_items set name=v_name,category=v_category,description=v_description,price=round(v_price,2),
      is_available=v_available,daily_stock_limit=v_stock,sold_out_until=v_sold_out,image_path=v_image,options=v_options,updated_at=clock_timestamp()
    where id=p_item_id returning * into v_saved;
  end if;
  v_after:=internal.admin_menu_row(v_saved,v_store_name);
  perform internal.log_audit_event(auth.uid(),case when p_item_id is null then 'merchant_menu_created' else 'merchant_menu_updated' end,null,
    jsonb_build_object('admin_menu_override',true,'store_id',p_store_id,'store_name',v_store_name,'item_id',v_saved.id,
      'reason',v_reason,'before',v_before,'after',v_after));
  return internal.admin_menu_row(v_saved,v_store_name);
end $$;
revoke all on function public.admin_save_merchant_menu_item(uuid,uuid,timestamptz,jsonb,text) from public, anon;
grant execute on function public.admin_save_merchant_menu_item(uuid,uuid,timestamptz,jsonb,text) to authenticated;

create or replace function public.admin_set_merchant_menu_item_archived(
  p_item_id uuid,p_expected_updated_at timestamptz,p_archived boolean,p_reason text
)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_item public.food_menu_items%rowtype; v_saved public.food_menu_items%rowtype; v_store_id uuid; v_store_name text;
  v_reason text:=btrim(coalesce(p_reason,''));
begin
  if auth.uid() is null or not internal.has_admin_permission('merchant','edit') then raise exception 'Not authorized'; end if;
  if char_length(v_reason) not between 5 and 300 then raise exception 'A reason of 5-300 characters is required'; end if;
  if p_archived is null then raise exception 'Archive state is required'; end if;
  select store_id into v_store_id from public.food_menu_items where id=p_item_id;
  if not found then raise exception 'Menu item not found'; end if;
  select name into v_store_name from public.food_stores where id=v_store_id for update;
  select * into v_item from public.food_menu_items where id=p_item_id and store_id=v_store_id for update;
  if not found then raise exception 'Menu item not found'; end if;
  if p_expected_updated_at is null or v_item.updated_at is distinct from p_expected_updated_at then raise exception 'Menu item changed; refresh before saving'; end if;
  if (v_item.archived_at is not null)=p_archived then raise exception 'No changes to save'; end if;
  update public.food_menu_items set archived_at=case when p_archived then clock_timestamp() else null end,
    is_available=false,updated_at=clock_timestamp() where id=p_item_id returning * into v_saved;
  perform internal.log_audit_event(auth.uid(),case when p_archived then 'merchant_menu_archived' else 'merchant_menu_restored' end,null,
    jsonb_build_object('admin_menu_override',true,'store_id',v_store_id,'store_name',v_store_name,'item_id',p_item_id,
      'reason',v_reason,'before',internal.admin_menu_row(v_item,v_store_name),'after',internal.admin_menu_row(v_saved,v_store_name)));
  return internal.admin_menu_row(v_saved,v_store_name);
end $$;
revoke all on function public.admin_set_merchant_menu_item_archived(uuid,timestamptz,boolean,text) from public, anon;
grant execute on function public.admin_set_merchant_menu_item_archived(uuid,timestamptz,boolean,text) to authenticated;

create or replace function public.admin_save_merchant_menu_categories(
  p_store_id uuid,p_expected_updated_at timestamptz,p_expected_items jsonb,p_category_order jsonb,p_renames jsonb,p_reason text
)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_store public.food_stores%rowtype; v_before jsonb; v_versions jsonb; v_order jsonb:='[]';
  v_category jsonb; v_name text; v_names text[]:='{}'; v_pair record; v_items jsonb; v_catalog jsonb;
  v_reason text:=btrim(coalesce(p_reason,''));
begin
  if auth.uid() is null or not internal.has_admin_permission('merchant','edit') then raise exception 'Not authorized'; end if;
  if char_length(v_reason) not between 5 and 300 then raise exception 'A reason of 5-300 characters is required'; end if;
  if p_expected_items is null or jsonb_typeof(p_expected_items)<>'object'
    or p_category_order is null or jsonb_typeof(p_category_order)<>'array'
    or p_renames is null or jsonb_typeof(p_renames)<>'object' then raise exception 'Invalid menu categories'; end if;
  if jsonb_array_length(p_category_order)>100 then raise exception 'Invalid menu categories'; end if;
  for v_category in select value from jsonb_array_elements(p_category_order) loop
    if jsonb_typeof(v_category)<>'string' then raise exception 'Invalid menu categories'; end if;
    v_name:=btrim(v_category#>>'{}');
    if char_length(v_name) not between 1 and 60 or v_name=any(v_names) then raise exception 'Invalid menu categories'; end if;
    v_names:=array_append(v_names,v_name); v_order:=v_order||jsonb_build_array(v_name);
  end loop;
  select * into v_store from public.food_stores where id=p_store_id for update;
  if not found then raise exception 'Store not found'; end if;
  if p_expected_updated_at is null or v_store.updated_at is distinct from p_expected_updated_at then raise exception 'Menu categories changed; refresh before saving'; end if;
  perform id from public.food_menu_items where store_id=p_store_id order by id for update;
  select coalesce(jsonb_object_agg(id::text,to_jsonb(updated_at)),'{}'),coalesce(jsonb_agg(internal.admin_menu_row(m,v_store.name) order by id),'[]')
    into v_versions,v_items from public.food_menu_items m where store_id=p_store_id;
  if v_versions is distinct from p_expected_items then raise exception 'Menu items changed; refresh before saving categories'; end if;
  for v_pair in select key,value from jsonb_each(p_renames) loop
    if char_length(v_pair.key) not between 1 and 60 or v_pair.key<>btrim(v_pair.key)
      or jsonb_typeof(v_pair.value)<>'string' or char_length(btrim(v_pair.value#>>'{}')) not between 1 and 60
      or not (btrim(v_pair.value#>>'{}')=any(v_names))
      or not (exists(select 1 from public.food_menu_items where store_id=p_store_id and category=v_pair.key)
        or v_store.menu_category_order ? v_pair.key) then raise exception 'Invalid menu category rename'; end if;
  end loop;
  if exists(select 1 from public.food_menu_items m where m.store_id=p_store_id
    and not (coalesce(btrim(p_renames->>m.category),m.category)=any(v_names))) then raise exception 'Category order must include every menu category'; end if;
  if v_store.menu_category_order=v_order and not exists(select 1 from jsonb_each_text(p_renames) r where r.key<>btrim(r.value)) then raise exception 'No changes to save'; end if;
  v_before:=jsonb_build_object('menu_category_order',v_store.menu_category_order,'items',v_items);
  update public.food_menu_items set category=btrim(p_renames->>category),updated_at=clock_timestamp()
    where store_id=p_store_id and p_renames ? category and category<>btrim(p_renames->>category);
  update public.food_stores set menu_category_order=v_order,updated_at=clock_timestamp() where id=p_store_id;
  v_catalog:=public.admin_merchant_menu_catalog(p_store_id);
  perform internal.log_audit_event(auth.uid(),'merchant_menu_categories_updated',null,
    jsonb_build_object('admin_menu_override',true,'store_id',p_store_id,'store_name',v_store.name,'reason',v_reason,
      'before',v_before,'after',jsonb_build_object('menu_category_order',v_order,'items',v_catalog->'items'),'renames',p_renames));
  return jsonb_build_object('store',v_catalog->'stores'->0,'items',v_catalog->'items');
end $$;
revoke all on function public.admin_save_merchant_menu_categories(uuid,timestamptz,jsonb,jsonb,jsonb,text) from public, anon;
grant execute on function public.admin_save_merchant_menu_categories(uuid,timestamptz,jsonb,jsonb,jsonb,text) to authenticated;

-- Keep existing callers working, with the same six-field stale check. Forward
-- through the new boundary so the former RPC cannot edit an archived menu.
create or replace function public.admin_update_merchant_menu_item(
  p_item_id uuid,p_expected jsonb,p_name text,p_category text,p_description text,p_price numeric,
  p_is_available boolean,p_daily_stock_limit integer,p_reason text
)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare v_item public.food_menu_items%rowtype; v_before jsonb; v_saved jsonb; v_store_id uuid;
begin
  if auth.uid() is null or not internal.has_admin_permission('merchant','edit') then raise exception 'Not authorized'; end if;
  select store_id into v_store_id from public.food_menu_items where id=p_item_id;
  perform id from public.food_stores where id=v_store_id for update;
  select * into v_item from public.food_menu_items where id=p_item_id for update;
  if not found then raise exception 'Menu item not found'; end if;
  if v_item.archived_at is not null then raise exception 'Restore archived menu before editing'; end if;
  v_before:=jsonb_build_object('name',v_item.name,'category',v_item.category,'description',v_item.description,
    'price',v_item.price,'is_available',v_item.is_available,'daily_stock_limit',v_item.daily_stock_limit);
  if p_expected is distinct from v_before then raise exception 'Menu item changed; refresh before saving'; end if;
  v_saved:=public.admin_save_merchant_menu_item(v_item.id,v_item.store_id,v_item.updated_at,
    jsonb_build_object('name',p_name,'category',p_category,'description',p_description,'price',p_price,
      'is_available',p_is_available,'daily_stock_limit',p_daily_stock_limit,'sold_out_until',v_item.sold_out_until,
      'image_path',v_item.image_path,'options',v_item.options),p_reason);
  return jsonb_build_object('name',v_saved->'name','category',v_saved->'category','description',v_saved->'description',
    'price',v_saved->'price','is_available',v_saved->'is_available','daily_stock_limit',v_saved->'daily_stock_limit');
end $$;
revoke all on function public.admin_update_merchant_menu_item(uuid,jsonb,text,text,text,numeric,boolean,integer,text) from public, anon;
grant execute on function public.admin_update_merchant_menu_item(uuid,jsonb,text,text,text,numeric,boolean,integer,text) to authenticated;

commit;
