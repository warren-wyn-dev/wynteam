-- Native Android Food: authenticated, server-atomic order-attempt identity.
--
-- NOT APPLIED TO PRODUCTION BY THIS PR. Run against a disposable full-parity
-- Food staging database before considering any production rollout.
--
-- This is order creation only. PaymentIntent / Stripe webhook reconciliation
-- is separate. The legacy food_create_order RPC remains for current web flows.

create table if not exists internal.food_mobile_order_attempts (
    buyer_id uuid not null references auth.users(id) on delete cascade,
    attempt_id uuid not null,
    request_digest text not null,
    order_id uuid not null references public.food_orders(id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (buyer_id, attempt_id),
    constraint food_mobile_order_attempt_digest_shape check (length(request_digest) = 32)
);

-- This record contains a buyer linkage but no recipient address, phone,
-- payment secrets or copies of the item payload.
alter table internal.food_mobile_order_attempts enable row level security;
revoke all on table internal.food_mobile_order_attempts from public, anon, authenticated;

create index if not exists food_mobile_order_attempts_order_id_idx
    on internal.food_mobile_order_attempts (order_id);

create or replace function public.food_create_order_idempotent(
    p_attempt_id uuid,
    p_store_id uuid,
    p_recipient_name text,
    p_recipient_phone text,
    p_shipping_address text,
    p_customer_note text,
    p_items jsonb,
    p_latitude double precision,
    p_longitude double precision
)
returns uuid
language plpgsql
security definer
set search_path to ''
as $function$
declare
    v_buyer uuid := auth.uid();
    v_digest text;
    v_existing_digest text;
    v_existing_order_id uuid;
    v_order_id uuid;
begin
    -- SECURITY DEFINER is used only for the internal attempt table.
    -- Authorization, public rollout eligibility, restaurant availability,
    -- promotions, item prices and delivery range are still enforced by
    -- public.food_create_order as for the existing web checkout.
    if v_buyer is null or not public.food_customer_access_enabled() then
        raise exception 'food customer access required' using errcode = '42501';
    end if;

    if p_attempt_id is null or p_store_id is null or p_items is null then
        raise exception 'invalid mobile checkout attempt' using errcode = '22023';
    end if;

    if jsonb_typeof(p_items) is distinct from 'array'
       or octet_length(p_items::text) > 100000 then
        raise exception 'invalid mobile order items' using errcode = '22023';
    end if;

    -- Equality fingerprint is only to reject a reused attempt ID for another
    -- payload. It does not authorize the user or determine prices.
    v_digest := pg_catalog.md5(
        jsonb_build_object(
            'store', p_store_id,
            'recipient', p_recipient_name,
            'phone', p_recipient_phone,
            'address', p_shipping_address,
            'note', p_customer_note,
            'items', p_items,
            'latitude', p_latitude,
            'longitude', p_longitude
        )::text
    );

    -- Serialize the same buyer + attempt ID across simultaneous requests,
    -- then query the durable result. Hash collisions serialize only; they
    -- cannot cause one attempt to return another attempt's order.
    perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_buyer::text || ':' || p_attempt_id::text, 0)
    );

    select request_digest, order_id
      into v_existing_digest, v_existing_order_id
      from internal.food_mobile_order_attempts
     where buyer_id = v_buyer and attempt_id = p_attempt_id
     for update;
    if found then
        if v_existing_digest is distinct from v_digest then
            raise exception 'mobile order attempt payload changed' using errcode = '22023';
        end if;
        return v_existing_order_id;
    end if;

    -- Creating the order and recording the attempt occur in ONE transaction.
    -- If this function fails, neither write is committed.
    v_order_id := public.food_create_order(
        p_store_id => p_store_id,
        p_recipient_name => p_recipient_name,
        p_recipient_phone => p_recipient_phone,
        p_shipping_address => p_shipping_address,
        p_customer_note => p_customer_note,
        p_items => p_items,
        p_latitude => p_latitude,
        p_longitude => p_longitude
    );

    insert into internal.food_mobile_order_attempts (
        buyer_id, attempt_id, request_digest, order_id
    ) values (v_buyer, p_attempt_id, v_digest, v_order_id);

    return v_order_id;
end;
$function$;

-- Restrict direct access to the trusted authenticated customer RPC.
revoke all on function public.food_create_order_idempotent(
    uuid,uuid,text,text,text,text,jsonb,double precision,double precision
) from public, anon;
grant execute on function public.food_create_order_idempotent(
    uuid,uuid,text,text,text,text,jsonb,double precision,double precision
) to authenticated;

comment on function public.food_create_order_idempotent(
    uuid,uuid,text,text,text,text,jsonb,double precision,double precision
) is 'Idempotent customer order creation for Native Food, payment separate; deploy only after staging QA.';
