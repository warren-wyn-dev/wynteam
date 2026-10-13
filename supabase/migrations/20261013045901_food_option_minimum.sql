-- Extend the canonical server resolver; preserve legacy required/max semantics.
-- Offline migration filename: Supabase CLI could not start in this executor.
begin;
create or replace function internal.food_resolve_menu_options(
  p_groups jsonb,
  p_selected jsonb
)
returns table(options jsonb, surcharge numeric)
language plpgsql
stable
set search_path = ''
as $$
declare
  v_groups jsonb := case when jsonb_typeof(p_groups) = 'array' then p_groups else '[]'::jsonb end;
  v_selected jsonb;
  v_pick jsonb;
  v_group jsonb;
  v_keys text[] := '{}';
  v_key text;
  v_count integer;
  v_max integer;
  v_min integer;
  v_options jsonb := '[]'::jsonb;
  v_surcharge numeric := 0;
  v_choice jsonb;
  v_price numeric;
begin
  if p_selected is null or jsonb_typeof(p_selected) = 'null' then
    v_selected := '[]'::jsonb;
  elsif jsonb_typeof(p_selected) <> 'array' or jsonb_array_length(p_selected) > 100 then
    raise exception 'invalid menu option';
  else
    v_selected := p_selected;
  end if;

  -- Every pick must name a real choice of a real group, once.
  for v_pick in select value from jsonb_array_elements(v_selected)
  loop
    if jsonb_typeof(v_pick) <> 'object'
       or coalesce(v_pick->>'group_id', '') = ''
       or coalesce(v_pick->>'choice_id', '') = '' then
      raise exception 'invalid menu option';
    end if;
    v_key := (v_pick->>'group_id') || chr(31) || (v_pick->>'choice_id');
    if v_key = any(v_keys) then
      raise exception 'invalid menu option';
    end if;
    v_keys := v_keys || v_key;
    if not exists (
      select 1
      from jsonb_array_elements(v_groups) g
      cross join lateral jsonb_array_elements(
        case when jsonb_typeof(g.value->'choices') = 'array' then g.value->'choices' else '[]'::jsonb end
      ) c
      where g.value->>'id' = v_pick->>'group_id'
        and c.value->>'id' = v_pick->>'choice_id'
    ) then
      raise exception 'invalid menu option';
    end if;
  end loop;

  -- Group rules, then build the stored selection in menu order.
  for v_group in select value from jsonb_array_elements(v_groups)
  loop
    select count(*) into v_count
    from jsonb_array_elements(v_selected) s
    where s.value->>'group_id' = v_group->>'id';

    v_max := greatest(1, least(20, coalesce(
      case when v_group->>'max_select' ~ '^\s*[0-9]{1,4}(\.[0-9]+)?\s*$' then floor((v_group->>'max_select')::numeric)::integer end,
      1)));
    if v_count > v_max then
      raise exception 'too many menu options selected';
    end if;
    v_min := case when v_group->'required' = 'true'::jsonb then 1 else 0 end;
    if v_group ? 'min_select' then
      if jsonb_typeof(v_group->'min_select') <> 'number'
         or (v_group->>'min_select') !~ '^[0-9]{1,2}$' then
        raise exception 'invalid menu option limits';
      end if;
      v_min := greatest(v_min,(v_group->>'min_select')::integer);
      if v_min > v_max or v_min > jsonb_array_length(
        case when jsonb_typeof(v_group->'choices')='array' then v_group->'choices' else '[]'::jsonb end) then
        raise exception 'invalid menu option limits';
      end if;
    end if;
    if v_count < v_min then raise exception 'required menu option missing'; end if;

    if v_count > 0 then
      for v_choice in
        select c.value
        from jsonb_array_elements(
          case when jsonb_typeof(v_group->'choices') = 'array' then v_group->'choices' else '[]'::jsonb end
        ) c
        where exists (
          select 1 from jsonb_array_elements(v_selected) s
          where s.value->>'group_id' = v_group->>'id'
            and s.value->>'choice_id' = c.value->>'id'
        )
      loop
        v_price := greatest(0, coalesce(
          case when v_choice->>'price' ~ '^\s*[0-9]{1,7}(\.[0-9]+)?\s*$' then (v_choice->>'price')::numeric end,
          0));
        v_surcharge := v_surcharge + v_price;
        v_options := v_options || jsonb_build_array(jsonb_build_object(
          'group_id', v_group->>'id',
          'group_name', v_group->>'name',
          'choice_id', v_choice->>'id',
          'choice_name', v_choice->>'name',
          'price', v_price
        ));
      end loop;
    end if;
  end loop;

  return query select v_options, round(v_surcharge, 2);
end;
$$;

revoke all on function internal.food_resolve_menu_options(jsonb, jsonb) from public, anon, authenticated;
commit;
