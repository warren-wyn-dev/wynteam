-- WYNOS Merchant payment core: PromptPay QR + slip verification + manual fallback.

alter table public.food_stores
  drop constraint if exists food_stores_promptpay_id_format_check;
alter table public.food_stores
  add constraint food_stores_promptpay_id_format_check
  check (
    promptpay_id is null
    or btrim(promptpay_id) = ''
    or (
      length(regexp_replace(promptpay_id, '[^0-9]', '', 'g')) in (10, 13, 15)
      and (
        length(regexp_replace(promptpay_id, '[^0-9]', '', 'g')) <> 10
        or regexp_replace(promptpay_id, '[^0-9]', '', 'g') like '0%'
      )
    )
  );

alter table public.food_orders
  add column if not exists payment_verification_status text not null default 'not_started',
  add column if not exists payment_provider text,
  add column if not exists payment_provider_code text,
  add column if not exists payment_transaction_ref text,
  add column if not exists payment_verified_at timestamptz,
  add column if not exists payment_verification_note text,
  add column if not exists source_drop_id uuid references public.drops(id) on delete set null;

alter table public.food_orders
  drop constraint if exists food_orders_payment_verification_status_check;
alter table public.food_orders
  add constraint food_orders_payment_verification_status_check
  check (payment_verification_status in (
    'not_started','manual_review','auto_verified','manual_verified','rejected'
  ));

alter table public.food_orders
  drop constraint if exists food_orders_payment_verification_note_length;
alter table public.food_orders
  add constraint food_orders_payment_verification_note_length
  check (payment_verification_note is null or char_length(payment_verification_note) <= 800);

alter table public.food_orders
  drop constraint if exists food_orders_source_check;
alter table public.food_orders
  add constraint food_orders_source_check
  check (source in ('app','manual','social'));

create table if not exists public.food_payment_verifications (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.food_orders(id) on delete cascade,
  store_id uuid not null references public.food_stores(id) on delete cascade,
  buyer_id uuid references public.profiles(id) on delete set null,
  provider text not null,
  status text not null check (status in ('auto_verified','manual_review','rejected')),
  transaction_ref text,
  amount numeric(10,2),
  amount_match boolean,
  receiver_match boolean,
  provider_code text,
  note text,
  created_at timestamptz not null default now(),
  constraint food_payment_verifications_provider_length check (char_length(provider) between 1 and 50),
  constraint food_payment_verifications_transaction_ref_length check (transaction_ref is null or char_length(transaction_ref) <= 200),
  constraint food_payment_verifications_provider_code_length check (provider_code is null or char_length(provider_code) <= 80),
  constraint food_payment_verifications_note_length check (note is null or char_length(note) <= 800)
);

create unique index if not exists food_payment_verifications_provider_transaction_uq
  on public.food_payment_verifications(provider, transaction_ref)
  where transaction_ref is not null;

create index if not exists food_payment_verifications_order_created_idx
  on public.food_payment_verifications(order_id, created_at desc);

alter table public.food_payment_verifications enable row level security;

drop policy if exists "Food payment verification readable by buyer and merchant" on public.food_payment_verifications;
create policy "Food payment verification readable by buyer and merchant"
on public.food_payment_verifications
for select
to authenticated
using (
  (public.food_is_permanent_account() and buyer_id = auth.uid())
  or public.food_has_merchant_access(store_id)
);

revoke all on table public.food_payment_verifications from anon;
revoke insert, update, delete on table public.food_payment_verifications from authenticated;
grant select on table public.food_payment_verifications to authenticated;

create or replace function public.food_record_payment_verification(
  p_order_id uuid,
  p_provider text,
  p_result text,
  p_transaction_ref text default null,
  p_amount numeric default null,
  p_amount_match boolean default null,
  p_receiver_match boolean default null,
  p_provider_code text default null,
  p_note text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
  v_result text := p_result;
  v_provider text := left(trim(coalesce(p_provider, '')), 50);
  v_ref text := nullif(left(trim(coalesce(p_transaction_ref, '')), 200), '');
  v_code text := nullif(left(trim(coalesce(p_provider_code, '')), 80), '');
  v_note text := nullif(left(trim(coalesce(p_note, '')), 800), '');
  v_existing public.food_payment_verifications%rowtype;
begin
  if v_provider = '' then raise exception 'payment provider required'; end if;
  if v_result not in ('auto_verified','manual_review','rejected') then
    raise exception 'invalid payment verification result';
  end if;

  select * into v_order
  from public.food_orders
  where id = p_order_id
  for update;

  if not found then raise exception 'order not found'; end if;
  if v_order.status in ('delivered','cancelled') then raise exception 'order is closed'; end if;
  if v_order.payment_slip_path is null then raise exception 'payment slip required'; end if;

  if v_ref is not null then
    select * into v_existing
    from public.food_payment_verifications
    where provider = v_provider and transaction_ref = v_ref
    limit 1;

    if found then
      if v_existing.order_id = p_order_id then
        update public.food_orders
        set payment_status = case
              when v_existing.status = 'auto_verified' then 'paid'
              when v_existing.status = 'rejected' then 'issue'
              else 'submitted'
            end,
            payment_verification_status = v_existing.status,
            payment_provider = v_existing.provider,
            payment_provider_code = v_existing.provider_code,
            payment_transaction_ref = v_existing.transaction_ref,
            payment_verified_at = case
              when v_existing.status in ('auto_verified','rejected') then coalesce(payment_verified_at, now())
              else null
            end,
            payment_verification_note = v_existing.note,
            paid_at = case
              when v_existing.status = 'auto_verified' then coalesce(paid_at, now())
              else paid_at
            end
        where id = v_order.id;
        return v_existing.status;
      end if;
      v_result := 'rejected';
      v_code := 'duplicate_transaction';
      v_note := 'สลิปนี้ถูกใช้กับออเดอร์อื่นแล้ว';
      v_ref := null;
    end if;
  end if;

  if v_result = 'auto_verified' then
    if v_ref is null
       or p_amount is null
       or p_amount_match is distinct from true
       or p_receiver_match is distinct from true
       or round(p_amount::numeric, 2) <> round(v_order.total::numeric, 2) then
      raise exception 'unsafe automatic payment verification';
    end if;
  end if;

  insert into public.food_payment_verifications (
    order_id, store_id, buyer_id, provider, status, transaction_ref,
    amount, amount_match, receiver_match, provider_code, note
  ) values (
    v_order.id, v_order.store_id, v_order.buyer_id, v_provider, v_result, v_ref,
    p_amount, p_amount_match, p_receiver_match, v_code, v_note
  );

  if v_result = 'auto_verified' then
    update public.food_orders
    set payment_status = 'paid',
        payment_verification_status = 'auto_verified',
        payment_provider = v_provider,
        payment_provider_code = v_code,
        payment_transaction_ref = v_ref,
        payment_verified_at = now(),
        payment_verification_note = v_note,
        payment_note = null,
        paid_at = coalesce(paid_at, now())
    where id = v_order.id;
  elsif v_result = 'rejected' then
    update public.food_orders
    set payment_status = 'issue',
        payment_verification_status = 'rejected',
        payment_provider = v_provider,
        payment_provider_code = v_code,
        payment_transaction_ref = coalesce(v_ref, payment_transaction_ref),
        payment_verified_at = now(),
        payment_verification_note = v_note,
        payment_note = coalesce(v_note, 'ตรวจสอบสลิปไม่ผ่าน กรุณาส่งสลิปใหม่')
    where id = v_order.id;
  else
    update public.food_orders
    set payment_status = 'submitted',
        payment_verification_status = 'manual_review',
        payment_provider = v_provider,
        payment_provider_code = v_code,
        payment_transaction_ref = coalesce(v_ref, payment_transaction_ref),
        payment_verified_at = null,
        payment_verification_note = v_note,
        payment_note = null
    where id = v_order.id;
  end if;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (v_order.id,'payment_verification_' || v_result,v_note,null);

  return v_result;
end;
$$;

revoke all on function public.food_record_payment_verification(uuid,text,text,text,numeric,boolean,boolean,text,text) from public, anon, authenticated;
grant execute on function public.food_record_payment_verification(uuid,text,text,text,numeric,boolean,boolean,text,text) to service_role;

create or replace function public.food_submit_payment(p_order_id uuid, p_slip_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
begin
  if not public.food_is_permanent_account() then raise exception 'permanent account required'; end if;

  select * into v_order from public.food_orders where id = p_order_id;
  if not found or v_order.buyer_id <> auth.uid() then raise exception 'order not found'; end if;
  if v_order.status in ('delivered','cancelled') then raise exception 'order is closed'; end if;
  if p_slip_path is null or p_slip_path not like (auth.uid()::text || '/slips/' || p_order_id::text || '/%') then
    raise exception 'invalid slip path';
  end if;

  update public.food_orders
  set payment_status = 'submitted',
      payment_slip_path = p_slip_path,
      payment_note = null,
      payment_verification_status = 'manual_review',
      payment_provider = null,
      payment_provider_code = null,
      payment_transaction_ref = null,
      payment_verified_at = null,
      payment_verification_note = null
  where id = p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_submitted','ลูกค้าแนบหลักฐานการชำระเงิน',auth.uid());
end;
$$;

create or replace function public.food_set_payment_status(
  p_order_id uuid,
  p_status text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.food_orders%rowtype;
  v_note text := nullif(left(trim(coalesce(p_note,'')),800),'');
begin
  select * into v_order from public.food_orders where id=p_order_id;
  if not found or not public.food_has_merchant_access(v_order.store_id) then
    raise exception 'merchant access required';
  end if;
  if p_status not in ('paid','issue','refunded') then raise exception 'invalid payment status'; end if;

  update public.food_orders
  set payment_status=p_status,
      payment_note=v_note,
      payment_verification_status=case
        when p_status='paid' then 'manual_verified'
        when p_status='issue' then 'rejected'
        else payment_verification_status
      end,
      payment_provider=case when p_status in ('paid','issue') then 'merchant_manual' else payment_provider end,
      payment_verified_at=case when p_status in ('paid','issue') then now() else payment_verified_at end,
      payment_verification_note=case when p_status in ('paid','issue') then v_note else payment_verification_note end,
      paid_at=case when p_status='paid' then coalesce(paid_at,now()) else paid_at end
  where id=p_order_id;

  insert into public.food_order_events(order_id,event_type,note,actor_id)
  values (p_order_id,'payment_' || p_status,v_note,auth.uid());
end;
$$;

create or replace function internal.food_order_notify()
returns trigger
language plpgsql
security definer
set search_path = public, internal
as $$
declare
  v_reason text;
begin
  if tg_op = 'INSERT' and new.source in ('app','social') then
    v_reason := 'WYNOS Merchant · ออเดอร์ใหม่ #' || new.order_number || ' · ฿' || trim(to_char(new.total, 'FM999999990.00'));
    insert into public.notifications(recipient_id, actor_id, type, reason)
    select fs.user_id, null, 'system', v_reason
    from public.food_staff fs
    where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
  elsif tg_op = 'UPDATE' and new.payment_status is distinct from old.payment_status then
    if new.payment_status = 'submitted' then
      v_reason := 'WYNOS Merchant · ลูกค้าส่งสลิป #' || new.order_number;
      insert into public.notifications(recipient_id, actor_id, type, reason)
      select fs.user_id, null, 'system', v_reason
      from public.food_staff fs
      where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
    elsif new.payment_status = 'paid' then
      if new.buyer_id is not null then
        insert into public.notifications(recipient_id, actor_id, type, reason)
        values (new.buyer_id, null, 'system', 'ชำระเงินออเดอร์ #' || new.order_number || ' สำเร็จแล้ว');
      end if;
      insert into public.notifications(recipient_id, actor_id, type, reason)
      select fs.user_id, null, 'system', 'WYNOS Merchant · ชำระเงินแล้ว #' || new.order_number
      from public.food_staff fs
      where fs.store_id = new.store_id and fs.active and fs.role in ('owner','staff');
    elsif new.payment_status = 'issue' and new.buyer_id is not null then
      insert into public.notifications(recipient_id, actor_id, type, reason)
      values (
        new.buyer_id, null, 'system',
        coalesce(new.payment_verification_note, new.payment_note, 'สลิปออเดอร์ #' || new.order_number || ' ต้องตรวจสอบอีกครั้ง')
      );
    end if;
  end if;

  return new;
end;
$$;

revoke all on function internal.food_order_notify() from public, anon, authenticated;

drop trigger if exists food_orders_notify_merchant_payment on public.food_orders;
create trigger food_orders_notify_merchant_payment
after insert or update of payment_status on public.food_orders
for each row execute function internal.food_order_notify();
