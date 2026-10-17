"""Extend the existing platform-campaign fixture through real checkout RPCs."""
from concurrent.futures import ThreadPoolExecutor
from decimal import Decimal
from pathlib import Path
import json
import os
import shlex
import signal
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
DB, STORE, OWNER, ADMIN, FIRST = sys.argv[1:]
assert DB.startswith('wyn_platform_campaigns_test_'), 'requires the disposable campaign fixture'
PSQL = shlex.split(os.environ.get('PSQL', 'psql'))
CHECKS = 0
MENU = '10000000-0000-0000-0000-000000000001'
OPTION_MENU = '10000000-0000-0000-0000-000000000002'
OTHER_STORE = '10000000-0000-0000-0000-000000000003'
OTHER_MENU = '10000000-0000-0000-0000-000000000004'
JOINED_STORE = '10000000-0000-0000-0000-000000000005'
JOINED_MENU = '10000000-0000-0000-0000-000000000006'


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def process():
    return subprocess.Popen([*PSQL, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, start_new_session=True)


def stop(child):
    if child.poll() is None:
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    child.communicate(timeout=5)


def sql(statement, check=True):
    child = process()
    try:
        stdout, stderr = child.communicate("set statement_timeout='10s';" + statement, timeout=20)
    except subprocess.TimeoutExpired:
        stop(child)
        raise AssertionError('fixture SQL exceeded 20 seconds') from None
    if check and child.returncode:
        raise AssertionError(stderr)
    return subprocess.CompletedProcess(child.args, child.returncode, stdout.strip(), stderr)


def as_user(buyer, statement, check=True, role='authenticated', extra=''):
    return sql(f"set role {role}; set test.uid={literal(buyer)};" + extra + statement, check)


def equal(actual, expected, label):
    global CHECKS
    assert actual == expected, f'{label}: actual={actual!r}, expected={expected!r}'
    CHECKS += 1
    print('PASS', label, flush=True)


def denied(buyer, statement, message, **kwargs):
    result = as_user(buyer, statement, check=False, **kwargs)
    equal(result.returncode != 0 and message in result.stderr, True, message)


def buyer():
    identity = str(uuid.uuid4())
    sql(f"insert into auth.users values({literal(identity)}); "
        f"insert into public.profiles(id,username) values({literal(identity)},'synthetic_buyer');")
    return identity


def lines(menu=MENU, options=None):
    line = {'menu_item_id': menu, 'quantity': 1}
    if options is not None:
        line['selected_options'] = options
    return literal(json.dumps([line])) + '::jsonb'


def quote_call(items, store=STORE, coupon=None, wrapper=False):
    suffix = f",null,null,{literal(coupon) if coupon else 'null'}" if wrapper else ''
    return f'public.food_quote_order{"_v2" if wrapper else ""}({literal(store)},{items}{suffix})'


def order_call(items, store=STORE, coupon=None, wrapper=False):
    suffix = f",null,null,{literal(coupon) if coupon else 'null'}" if wrapper else ''
    return (f'public.food_create_order{"_v2" if wrapper else ""}({literal(store)},'
            f"'Synthetic buyer','0800000000','Synthetic address',null,{items}{suffix})")


def quote(identity, items=None, **kwargs):
    result = as_user(identity, 'select ' + quote_call(items or lines(), **kwargs) + ';')
    return json.loads(result.stdout, parse_float=Decimal)


def order(identity, items=None, **kwargs):
    return as_user(identity, 'select ' + order_call(items or lines(), **kwargs) + ';').stdout


def totals(order_id):
    return sql("select concat_ws('|',subtotal,delivery_fee,campaign_discount,delivery_discount,total) "
               f"from public.food_orders where id={literal(order_id)};").stdout


def snapshot(order_id):
    # Retained business snapshots, excluding operational release/settlement state.
    return sql("select jsonb_build_object('subtotal',o.subtotal,'delivery_fee',o.delivery_fee,"
               "'discount',o.campaign_discount,'delivery_discount',o.delivery_discount,'total',o.total,"
               "'campaign_id',o.campaign_id,'campaign_name',o.campaign_name,"
               "'funding',(select jsonb_build_object('campaign',c.campaign_id,'platform',c.platform_campaign_id,"
               "'name',c.campaign_name,'type',c.campaign_type,'discount',c.campaign_discount,"
               "'delivery_discount',c.delivery_discount,'platform_funded',c.platform_funded) "
               "from public.food_order_campaigns c where c.order_id=o.id),"
               "'items',(select jsonb_agg(jsonb_build_object('name',i.item_name,'unit_price',i.unit_price,"
               "'quantity',i.quantity,'options',i.selected_options)) from public.food_order_items i where i.order_id=o.id)) "
               f"from public.food_orders o where o.id={literal(order_id)};").stdout


def wait_for(statement, label):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if sql(statement).stdout == 't':
            return
        time.sleep(0.02)
    raise AssertionError('Timed out waiting for ' + label)


sql("""
create function public.is_developer_account() returns boolean language sql stable as $$select false$$;
create function public.food_customer_access_enabled() returns boolean language sql stable as $$
  select auth.uid() is not null and current_setting('test.food_access',true) is distinct from 'off'$$;
create function public.food_public_access_enabled() returns boolean language sql stable as $$select true$$;
create function public.food_is_permanent_account() returns boolean language sql stable as $$select auth.uid() is not null$$;
alter table public.food_stores add column minimum_order numeric(10,2) not null default 0,
  add column delivery_fee numeric(10,2) not null default 20;
alter table public.food_menu_items add column name text, add column price numeric(10,2),
  add column is_available boolean not null default true, add column options jsonb not null default '[]';
alter table public.food_orders alter column id set default gen_random_uuid();
alter table public.food_orders add column created_by uuid, add column source text,
  add column recipient_name text, add column recipient_phone text, add column shipping_address text,
  add column customer_note text, add column created_at timestamptz not null default now();
create table public.food_order_items(order_id uuid references public.food_orders(id),menu_item_id uuid,
  item_name text,unit_price numeric(10,2),quantity integer,selected_options jsonb,item_note text);
create table public.food_order_events(order_id uuid,event_type text,to_status text,note text,actor_id uuid);
create table public.food_customer_addresses(id uuid primary key);
create table public.merchant_activity_log(merchant_account_id uuid,actor_id uuid,actor_username_snapshot text,
  action text,target_type text,target_id uuid,detail jsonb);
""")
# Load authoritative pricing, option resolution, and create routines. Coupon
# wrappers were loaded by the parent fixture before the first-order predicate.
sql((ROOT / 'supabase/migrations_wynos_food_delivery_zone_v1.sql').read_text())
sql((ROOT / 'supabase/migrations_wynos_food_order_options_v1.sql').read_text())
option_groups = [{'id': 'extra', 'name': 'Extra', 'required': False, 'max_select': 1,
                  'choices': [{'id': 'cent', 'name': 'One satang', 'price': 0.01}]}]
sql(f"insert into public.food_stores(id,name,merchant_account_id) select {literal(OTHER_STORE)},'Other store',"
    f"merchant_account_id from public.food_stores where id={literal(STORE)}; "
    f"insert into public.food_stores(id,name,merchant_account_id) select {literal(JOINED_STORE)},'Second joined store',"
    f"merchant_account_id from public.food_stores where id={literal(STORE)}; "
    f"insert into public.food_menu_items(id,store_id,name,price,options) values "
    f"({literal(MENU)},{literal(STORE)},'Threshold item',100,'[]'),"
    f"({literal(OPTION_MENU)},{literal(STORE)},'Option item',99.99,{literal(json.dumps(option_groups))}),"
    f"({literal(OTHER_MENU)},{literal(OTHER_STORE)},'Other item',100,'[]'),"
    f"({literal(JOINED_MENU)},{literal(JOINED_STORE)},'Joined item',100,'[]');")
as_user(ADMIN, 'select public.admin_food_first_order_set_active(true);')
as_user(OWNER, f'select public.merchant_join_platform_campaign({literal(JOINED_STORE)},{literal(FIRST)});')

fresh = buyer()
denied('', 'select ' + quote_call(lines()) + ';', 'food customer access required')
denied('', 'select ' + order_call(lines()) + ';', 'food customer access required')
denied(fresh, 'select ' + quote_call(lines()) + ';', 'permission denied', role='anon')
denied(fresh, 'select ' + order_call(lines()) + ';', 'permission denied', role='anon')
denied(fresh, 'select ' + order_call(lines()) + ';', 'food customer access required',
       extra="set test.food_access='off';")
equal(sql("select has_function_privilege('authenticated',"
          "'internal.food_campaign_candidates(uuid,numeric,numeric,jsonb)','execute');").stdout,
      'f', 'clients cannot directly call the campaign candidate helper')

# The threshold is food subtotal, including server-resolved options, excluding delivery.
low = buyer()
q = quote(low, lines(OPTION_MENU))
equal((q['subtotal'], q['delivery_fee'], q['campaign_discount'], q['total']),
      (Decimal('99.99'), 20, 0, Decimal('119.99')), '99.99 food plus delivery does not qualify')
low_order = order(low, lines(OPTION_MENU))
equal(totals(low_order), '99.99|20.00|0.00|0.00|119.99', 'create agrees at the 99.99 boundary')
equal(sql(f"select count(*) from public.food_order_campaigns where order_id={literal(low_order)};").stdout,
      '0', 'below-threshold checkout creates no campaign snapshot')
equal(quote(low)['campaign_discount'], 0, 'a prior regular Food order also consumes first-order eligibility')

exact = buyer()
q = quote(exact)
equal((q['subtotal'], q['campaign_discount'], q['delivery_discount'], q['total']),
      (100, 40, 0, 80), 'exactly 100.00 food qualifies for exactly 40.00')
exact_order = order(exact)
equal(totals(exact_order), '100.00|20.00|40.00|0.00|80.00', 'create agrees at the 100.00 boundary')
equal(sql("select concat_ws('|',campaign_discount+delivery_discount,platform_funded,"
          "campaign_discount+delivery_discount-platform_funded) from public.food_order_campaigns "
          f"where order_id={literal(exact_order)};").stdout, '40.00|0.00|40.00',
      'first-order discount is entirely merchant funded')
equal(quote(exact)['campaign_discount'], 0, 'pending first checkout reserves the once-per-buyer benefit')
equal(quote(exact, lines(JOINED_MENU), store=JOINED_STORE)['campaign_discount'], 0,
      'first-order consumption applies across joined stores')
equal(totals(order(exact)), '100.00|20.00|0.00|0.00|120.00', 'a second actual checkout receives no second benefit')

option_buyer = buyer()
forged = lines(OPTION_MENU, [{'group_id': 'extra', 'choice_id': 'cent', 'price': 0, 'choice_name': 'Forged'}])
q = quote(option_buyer, forged)
equal((q['subtotal'], q['campaign_discount'], q['total']), (100, 40, 80),
      'a real one-satang option crosses the threshold despite a forged client price')
option_order = order(option_buyer, forged)
equal(totals(option_order), '100.00|20.00|40.00|0.00|80.00', 'create uses the same option-inclusive threshold')
equal(sql("select unit_price||'|'||(selected_options->0->>'choice_name')||'|'||"
          f"(selected_options->0->>'price') from public.food_order_items where order_id={literal(option_order)};").stdout,
      '100.00|One satang|0.01', 'order item options snapshot authoritative names and price')
before = snapshot(option_order)
sql(f"update public.food_menu_items set name='Changed menu',price=500,options='[]' where id={literal(OPTION_MENU)};")
as_user(ADMIN, 'select public.admin_food_first_order_set_active(false);')
equal(snapshot(option_order), before, 'menu and campaign deactivation do not rewrite placed discount, item, or funding snapshots')
as_user(ADMIN, 'select public.admin_food_first_order_set_active(true);')
denied(option_buyer, f"update public.food_order_campaigns set platform_funded=40 where order_id={literal(option_order)};",
       'permission denied')

unjoined_buyer = buyer()
unjoined_order = order(unjoined_buyer, lines(OTHER_MENU), store=OTHER_STORE)
equal(totals(unjoined_order), '100.00|20.00|0.00|0.00|120.00', 'a store must opt in before funding the benefit')
equal(quote(unjoined_buyer)['campaign_discount'], 0, 'a prior order at an unjoined store consumes the global first order')

for payment in ['pending', 'paid', 'submitted', 'refunded']:
    identity = buyer()
    placed = order(identity)
    equal(totals(placed), '100.00|20.00|40.00|0.00|80.00', f'{payment} cancellation starts with a real discounted checkout')
    sql(f"update public.food_orders set status='cancelled',payment_status={literal(payment)} where id={literal(placed)};")
    expected_discount = 40 if payment == 'pending' else 0
    equal(quote(identity)['campaign_discount'], expected_discount, f'{payment} cancellation keeps the documented eligibility policy')
    next_order = order(identity)
    equal(sql(f"select campaign_discount from public.food_orders where id={literal(next_order)};").stdout,
          f'{expected_discount}.00', f'{payment} cancellation policy is enforced again at create')

# Automatic campaigns compete by saving; food and free-delivery policies never stack.
def merchant_campaign(name, kind, amount):
    return as_user(OWNER, f"select public.merchant_upsert_food_campaign({literal(STORE)},{literal(name)},"
                   f"{literal(kind)},'store',{amount});").stdout


fixed = merchant_campaign('Store fixed offer', 'fixed', 30)
delivery = merchant_campaign('Store free delivery', 'free_delivery', 0)
best_buyer = buyer()
q = quote(best_buyer)
equal((q['campaign_discount'], q['delivery_discount'], q['total']), (40, 0, 80),
      'first-order 40 beats fixed 30 and delivery 20 without stacking them')
best_order = order(best_buyer)
equal(sql(f"select count(*) from public.food_order_campaigns where order_id={literal(best_order)};").stdout,
      '1', 'actual checkout stores exactly one winning campaign')
as_user(OWNER, f"select public.merchant_upsert_food_campaign({literal(STORE)},'Store fixed offer','fixed','store',"
        f"50,0,null,now(),null,null,'{{}}'::uuid[],{literal(fixed)});")
better_buyer = buyer()
equal(quote(better_buyer)['campaign_id'], fixed, 'a larger merchant discount wins over the first-order offer')
equal(totals(order(better_buyer)), '100.00|20.00|50.00|0.00|70.00', 'create applies only the winning merchant discount')
as_user(OWNER, f'select public.merchant_set_food_campaign_active({literal(STORE)},{literal(fixed)},false);')
sql(f'update public.food_stores set delivery_fee=60 where id={literal(STORE)};')
delivery_buyer = buyer()
q = quote(delivery_buyer)
equal((q['campaign_id'], q['campaign_discount'], q['delivery_discount'], q['total']), (delivery, 0, 60, 100),
      'delivery saving 60 wins over first-order food saving 40')
equal(totals(order(delivery_buyer)), '100.00|60.00|0.00|60.00|100.00', 'create does not stack first-order food discount onto free delivery')
as_user(OWNER, f'select public.merchant_set_food_campaign_active({literal(STORE)},{literal(delivery)},false);')
sql(f'update public.food_stores set delivery_fee=20 where id={literal(STORE)};')

# A real editable hybrid campaign proves funding snapshots survive changed terms.
hybrid = as_user(ADMIN, "select public.admin_upsert_platform_campaign(null,'Hybrid checkout offer',null,"
                 "'fixed',50,0,null,now(),null,null,50,true,true);").stdout
as_user(OWNER, f'select public.merchant_join_platform_campaign({literal(STORE)},{literal(hybrid)});')
hybrid_order = order(buyer())
equal(sql("select campaign_discount||'|'||platform_funded||'|'||(campaign_discount-platform_funded) "
          f"from public.food_order_campaigns where order_id={literal(hybrid_order)};").stdout,
      '50.00|25.00|25.00', 'actual checkout snapshots the winning hybrid 50/50 funding split')
before = snapshot(hybrid_order)
as_user(ADMIN, f"select public.admin_upsert_platform_campaign({literal(hybrid)},'Changed hybrid offer',null,"
        "'fixed',10,0,null,now(),null,null,100,true,true);")
equal(snapshot(hybrid_order), before, 'later discount and funding-share edits cannot reprice a placed checkout')
as_user(OWNER, f'select public.merchant_leave_platform_campaign({literal(STORE)},{literal(hybrid)});')

# Final v2 wrappers must preserve the automatic quote/create path with no code.
wrapped_buyer = buyer()
equal(quote(wrapped_buyer, wrapper=True)['campaign_discount'], 40, 'final no-code quote wrapper preserves 100/40')
equal(totals(order(wrapped_buyer, wrapper=True)), '100.00|20.00|40.00|0.00|80.00',
      'final no-code create wrapper preserves the same automatic policy')

# A supplied code still competes with the automatic offer; wrapper rejection
# must roll back the base checkout rather than silently create an undiscounted order.
coupon_campaign = as_user(ADMIN, "select public.admin_upsert_platform_campaign(null,'Coupon checkout offer',null,"
                          "'fixed',30,0,null,now(),null,null,100,true,true);").stdout
as_user(ADMIN, f"select public.admin_food_issue_coupon({literal(coupon_campaign)},'CHECKOUT30');")
as_user(OWNER, f'select public.merchant_join_platform_campaign({literal(STORE)},{literal(coupon_campaign)});')
coupon_buyer = buyer()
denied(coupon_buyer, 'select ' + quote_call(lines(), coupon='CHECKOUT30', wrapper=True) + ';',
       'coupon_not_applicable_or_better_automatic_discount')
denied(coupon_buyer, 'select ' + order_call(lines(), coupon='CHECKOUT30', wrapper=True) + ';',
       'coupon_not_applicable_or_better_automatic_discount')
equal(sql(f"select count(*) from public.food_orders where buyer_id={literal(coupon_buyer)};").stdout,
      '0', 'losing coupon rejection rolls back the whole base checkout')
equal(quote(coupon_buyer)['campaign_discount'], 40, 'a rejected coupon does not consume first-order eligibility')
as_user(ADMIN, f"select public.admin_upsert_platform_campaign({literal(coupon_campaign)},'Coupon checkout offer',null,"
        "'fixed',50,0,null,now(),null,null,100,true,true);")
q = quote(coupon_buyer, coupon='CHECKOUT30', wrapper=True)
equal((q['campaign_discount'], q['delivery_discount'], q['total'], q['coupon_applied']), (50, 0, 70, True),
      'the larger coupon wins one single 50 discount over automatic 40')
coupon_order = order(coupon_buyer, coupon='CHECKOUT30', wrapper=True)
equal(totals(coupon_order), '100.00|20.00|50.00|0.00|70.00', 'coupon create does not stack its saving with first-order 40')
equal(sql("select count(*)||'|'||max(platform_funded) from public.food_order_campaigns "
          f"where order_id={literal(coupon_order)};").stdout, '1|50.00',
      'winning coupon writes one campaign snapshot with its actual platform funding')
as_user(OWNER, f'select public.merchant_leave_platform_campaign({literal(STORE)},{literal(coupon_campaign)});')

# Checkouts at two independently enrolled stores reach the same buyer lock
# before release, proving global redemption under real overlap. No interactive
# stdout is used because the maintained CI adapter buffers both streams.
parallel_buyer = buyer()
gate = process()
try:
    lock_key = f"hashtext('food_create_order:'||{literal(parallel_buyer)})"
    gate.stdin.write("set application_name='first_order_checkout_gate'; "
                     f'select pg_advisory_lock({lock_key});\n')
    gate.stdin.flush()
    wait_for("select exists(select 1 from pg_locks l join pg_stat_activity a on a.pid=l.pid "
             "where a.datname=current_database() and a.application_name='first_order_checkout_gate' "
             "and l.locktype='advisory' and l.granted);", 'parallel checkout gate')
    with ThreadPoolExecutor(max_workers=2) as pool:
        requests = [(STORE, MENU), (JOINED_STORE, JOINED_MENU)]
        futures = [pool.submit(as_user, parallel_buyer,
                               'select ' + order_call(lines(menu), store=store) + ';',
                               extra=f"set application_name='first_order_checkout_{index}';")
                   for index, (store, menu) in enumerate(requests)]
        wait_for("select count(*)=2 from pg_stat_activity where datname=current_database() "
                 "and application_name in ('first_order_checkout_0','first_order_checkout_1') "
                 "and wait_event_type='Lock' and wait_event='advisory';", 'both parallel customer requests')
        gate.stdin.write(f'select pg_advisory_unlock({lock_key});\n\\q\n')
        gate.stdin.flush()
        gate.communicate(timeout=5)
        placed_ids = [future.result().stdout for future in futures]
    equal(len(set(placed_ids)), 2, 'simultaneous checkouts at different stores create separate orders')
    equal(sql(f"select count(distinct store_id) from public.food_orders "
              f"where buyer_id={literal(parallel_buyer)};").stdout, '2',
          'parallel checkouts commit at both independently enrolled stores')
    equal(sql(f"select string_agg(campaign_discount::text,',' order by campaign_discount) "
              f"from public.food_orders where buyer_id={literal(parallel_buyer)};").stdout, '0.00,40.00',
          'simultaneous cross-store requests redeem exactly one first-order discount')
    equal(sql("select count(*) from public.food_order_campaigns c join public.food_orders o on o.id=c.order_id "
              f"where o.buyer_id={literal(parallel_buyer)} and c.platform_campaign_id={literal(FIRST)};").stdout,
          '1', 'parallel placement commits one first-order campaign/funding snapshot')
finally:
    stop(gate)

print(f'PASS real Food first-order checkout: {CHECKS} assertions', flush=True)
