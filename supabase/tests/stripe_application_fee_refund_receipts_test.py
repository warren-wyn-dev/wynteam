"""Actual PostgreSQL roles, pinned payment checks, concurrency and rollback."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import os
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
PSQL = os.environ.get('PSQL', 'psql')
DB = f'stripe_fee_refund_test_{os.getpid()}'
MIGRATION = ROOT / 'supabase/migrations/20261014074213_stripe_application_fee_refund_receipts.sql'
ROLLBACK = ROOT / 'supabase/rollbacks/20261014074213_stripe_application_fee_refund_receipts_rollback.sql'
CHECKS = 0


def psql_process(database=DB):
    return subprocess.Popen([PSQL, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', database],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, start_new_session=True)


def stop_process(process):
    if process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    process.communicate(timeout=5)


def sql(statement, database=DB, check=True):
    process = psql_process(database)
    try:
        stdout, stderr = process.communicate(statement, timeout=20)
    except subprocess.TimeoutExpired:
        stop_process(process)
        raise AssertionError('psql command exceeded 20 seconds') from None
    result = subprocess.CompletedProcess(process.args, process.returncode, stdout, stderr)
    if check and result.returncode:
        raise AssertionError(result.stderr)
    return result


def query(statement, role='service_role', check=True):
    return sql(f'set role {role};' + statement, check=check)


def equal(actual, expected, label):
    global CHECKS
    assert actual == expected, f'{label}: actual={actual!r} expected={expected!r}'
    CHECKS += 1
    print('PASS', label)


def denied(statement, text, role='service_role'):
    result = query(statement, role, check=False)
    assert result.returncode and text in result.stderr, result.stderr
    global CHECKS
    CHECKS += 1
    print('PASS', text)


def call(event='evt_full', account='acct_original', intent='pi_pinned', fee=100, refunded=100,
         currency='thb', live='false', at='2026-10-12T12:00:00Z', fee_id='fee_pinned'):
    return ("select public.food_record_stripe_fee_refund_event("
            f"'{event}','{account}','{intent}','{fee_id}',{fee},{refunded},'{currency}',{live},'{at}')")


def amount():
    return sql("select application_fee_refunded_satang::text from public.food_stripe_payments where payment_intent_id='pi_pinned';").stdout.strip()


def timestamp():
    return sql("select extract(epoch from application_fee_refunded_at)::bigint::text from public.food_stripe_payments where payment_intent_id='pi_pinned';").stdout.strip()


def wait_for_database(statement, label):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if sql(statement).stdout.strip() == 't':
            return
        time.sleep(0.02)
    raise AssertionError(f'Timed out waiting for {label}')


def wait_for_lock(application_name, wait_event=None):
    event_filter = f" and wait_event='{wait_event}'" if wait_event else ''
    wait_for_database("select exists(select 1 from pg_stat_activity where datname=current_database() "
                      f"and application_name='{application_name}' and wait_event_type='Lock'{event_filter});",
                      f'{application_name} lock wait')


def concurrent_legacy_refund():
    # Import the actual existing webhook RPC. Its order FOR UPDATE precedes its
    # payment upsert; the webhook receipt's order FK also participates in locks.
    legacy = (ROOT / 'supabase/migrations_wynos_stripe_payment_core_v1.sql').read_text()
    start = legacy.index('create or replace function public.food_apply_stripe_event(')
    end = legacy.index('-- A buyer must explicitly expire', start)
    sql(legacy[start:end])
    sql("""
      create function public.pause_legacy_payment() returns trigger language plpgsql as $$
      begin
        if current_setting('application_name')='fee_receipt_legacy' then
          perform pg_advisory_xact_lock(1143, 74213);
        end if;
        return new;
      end $$;
      create trigger pause_legacy_payment before insert on public.food_stripe_payments
        for each row execute function public.pause_legacy_payment();
    """)
    gate = psql_process()
    try:
        gate.stdin.write("set application_name='fee_receipt_gate'; select pg_advisory_lock(1143,74213);\n")
        gate.stdin.flush()
        # CI's psql wrapper buffers stdout until exit. Observe the real lock
        # from another connection; interactive output is never a ready signal.
        wait_for_database("select exists(select 1 from pg_locks l join pg_stat_activity a on a.pid=l.pid "
                          "where a.datname=current_database() and a.application_name='fee_receipt_gate' "
                          "and l.locktype='advisory' and l.classid=1143 and l.objid=74213 and l.granted);",
                          'legacy payment gate')
        legacy_call = """select public.food_apply_stripe_event(
          'evt_legacy_refund','charge.refunded','00000000-0000-0000-0000-000000000002',
          'acct_atomic','ch_atomic',null,'pi_atomic',5000,'thb','refunded',null,null,'re_atomic');"""
        fee_call = call(event='evt_parallel_fee', account='acct_atomic', intent='pi_atomic', fee=50, refunded=50)

        def session(name, statement):
            return sql("set statement_timeout='10s'; set deadlock_timeout='100ms'; "
                       f"set application_name='{name}'; set role service_role;" + statement, check=False)

        with ThreadPoolExecutor(max_workers=2) as pool:
            legacy_result = pool.submit(session, 'fee_receipt_legacy', legacy_call)
            wait_for_lock('fee_receipt_legacy', 'advisory')
            fee_result = pool.submit(session, 'fee_receipt_parallel', fee_call + "->>'recorded';")
            wait_for_lock('fee_receipt_parallel')
            # The legacy call already holds the parent order and pauses just
            # before its payment upsert. The fee writer must wait on that parent
            # without first locking the payment, or releasing this gate deadlocks.
            gate.stdin.write('select pg_advisory_unlock(1143,74213);\n\\q\n')
            gate.stdin.flush()
            gate.communicate(timeout=5)
            results = [legacy_result.result(), fee_result.result()]
        errors = '\n'.join(result.stderr for result in results if result.returncode)
        equal([result.returncode for result in results], [0, 0],
              'legacy refund and fee event complete together without a deadlock or retry'
              + (f': {errors}' if errors else ''))
        equal(sql("select count(*) from public.food_stripe_webhook_events where event_id in "
                  "('evt_legacy_refund','evt_parallel_fee');").stdout.strip(), '2',
              'both concurrent provider receipts commit')
        equal(sql("select status||':'||application_fee_refunded_satang from public.food_stripe_payments "
                  "where payment_intent_id='pi_atomic';").stdout.strip(), 'refunded:50',
              'concurrent legacy payment state and confirmed fee projection are preserved')
    finally:
        stop_process(gate)
        sql('drop trigger pause_legacy_payment on public.food_stripe_payments;')


def mapping_change_while_waiting():
    gate = psql_process()
    try:
        gate.stdin.write("set application_name='fee_receipt_mapping_gate'; begin; "
                         "select 1 from public.food_orders where "
                         "id='00000000-0000-0000-0000-000000000002' for update;\n")
        gate.stdin.flush()
        wait_for_database("select exists(select 1 from pg_stat_activity where datname=current_database() "
                          "and application_name='fee_receipt_mapping_gate' and state='idle in transaction' "
                          "and query like '%for update%');", 'mapping change gate')
        statement = call(event='evt_stale_mapping', account='acct_atomic', intent='pi_atomic', fee=50, refunded=50)
        with ThreadPoolExecutor(max_workers=1) as pool:
            result = pool.submit(sql, "set statement_timeout='10s'; set application_name='fee_receipt_mapping'; "
                                 "set role service_role;" + statement + "->>'reason';")
            wait_for_lock('fee_receipt_mapping')
            gate.stdin.write("update public.food_stripe_payments set payment_intent_id='pi_reassigned' "
                             "where payment_intent_id='pi_atomic'; commit;\n\\q\n")
            gate.stdin.flush()
            gate.communicate(timeout=5)
            equal(result.result().stdout.strip(), 'unmapped',
                  'payment mapping is rechecked after waiting for the order lock')
        equal(sql("select count(*) from public.food_stripe_webhook_events where event_id='evt_stale_mapping';").stdout.strip(),
              '0', 'a changed PaymentIntent mapping cannot claim a fee receipt')
    finally:
        stop_process(gate)
        sql("update public.food_stripe_payments set payment_intent_id='pi_atomic' where payment_intent_id='pi_reassigned';")


sql('create database ' + DB, database='postgres')
try:
    sql("""
      do $$ begin create role anon; exception when duplicate_object then null; end $$;
      do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
      do $$ begin create role service_role; exception when duplicate_object then null; end $$;
      create table public.food_orders(id uuid primary key,status text,payment_status text,
        store_id uuid,buyer_id uuid,total numeric,refund_status text,stripe_refund_id text,
        refunded_at timestamptz,payment_provider_code text,payment_note text);
      create table public.food_stripe_accounts(store_id uuid primary key,stripe_account_id text);
      create table public.food_stripe_payments(
        order_id uuid primary key references public.food_orders(id),
        stripe_account_id text not null,payment_intent_id text unique,livemode boolean not null default false,
        amount_satang bigint not null,currency text not null,application_fee_satang bigint not null default 0,
        application_fee_refunded_satang bigint not null default 0,application_fee_refunded_at timestamptz,
        store_id uuid,buyer_id uuid,checkout_session_id text,status text,payment_method text,
        paid_at timestamptz,refunded_at timestamptz,last_error text,updated_at timestamptz,
        check(application_fee_satang between 0 and amount_satang),
        check(application_fee_refunded_satang between 0 and application_fee_satang)
      );
      create table public.food_stripe_webhook_events(event_id text primary key,event_type text not null,
        stripe_account_id text,order_id uuid references public.food_orders(id),object_id text,
        received_at timestamptz not null default now());
      insert into public.food_orders(id,status,payment_status) values
        ('00000000-0000-0000-0000-000000000001','cancelled','refunded'),
        ('00000000-0000-0000-0000-000000000002','cancelled','refunded');
      insert into public.food_stripe_payments(order_id,stripe_account_id,payment_intent_id,livemode,
        amount_satang,currency,application_fee_satang) values
        ('00000000-0000-0000-0000-000000000001','acct_original','pi_pinned',false,10000,'thb',100),
        ('00000000-0000-0000-0000-000000000002','acct_atomic','pi_atomic',false,5000,'thb',50);
      update public.food_orders set store_id='00000000-0000-0000-0000-000000000003',total=50
        where id='00000000-0000-0000-0000-000000000002';
      insert into public.food_stripe_accounts values
        ('00000000-0000-0000-0000-000000000003','acct_atomic');
      alter table public.food_stripe_payments enable row level security;
      alter table public.food_stripe_webhook_events enable row level security;
      revoke all on public.food_stripe_payments,public.food_stripe_webhook_events from public,anon,authenticated,service_role;
      grant usage on schema public to anon,authenticated,service_role;
    """)
    sql(MIGRATION.read_text())
    sql(MIGRATION.read_text())
    for role in ['anon', 'authenticated']:
        denied(call() + ';', 'permission denied', role)
    denied('select * from public.food_stripe_payments;', 'permission denied', 'authenticated')
    equal(query(call(refunded=40, event='evt_partial') + "->>'reason';").stdout.strip(),
          'partial_fee_reconciliation_required', 'partial return retains receipt without a GP reversal')
    equal(amount(), '0', 'partial fee does not fabricate a full return')
    equal(sql("select count(*) from public.food_stripe_webhook_events where event_id='evt_partial';").stdout.strip(), '1', 'partial receipt is retained')
    for args in [dict(account='acct_reconnected'), dict(live='true'), dict(currency='usd'), dict(fee=99, refunded=99)]:
        denied(call(event='evt_mismatch', **args) + ';', 'mismatch' if args.get('currency') != 'usd' else 'Invalid')
    for args in [dict(fee=0, refunded=0), dict(refunded=-1), dict(refunded=101),
                 dict(fee=9007199254740992, refunded=100), dict(at='infinity'), dict(live='null')]:
        denied(call(event='evt_invalid', **args) + ';', 'Invalid')
    equal(sql('select count(*) from public.food_stripe_webhook_events;').stdout.strip(), '1', 'rejected events leave no durable receipt')
    equal(query(call(event='evt_unmapped', intent='pi_unmapped') + "->>'reason';").stdout.strip(), 'unmapped', 'unknown payment cannot be attributed through metadata')
    equal(sql("select count(*) from public.food_stripe_webhook_events where event_id='evt_unmapped';").stdout.strip(), '0', 'unmapped event leaves no receipt so a later mapping can recover on retry')
    sql("update public.food_stripe_payments set payment_intent_id='pi_unmapped' where payment_intent_id='pi_pinned';")
    equal(query(call(event='evt_unmapped', intent='pi_unmapped') + "->>'recorded';").stdout.strip(), 'true', 'same event recovers after delayed payment mapping appears')
    equal(sql("select count(*) from public.food_stripe_webhook_events where event_id='evt_unmapped';").stdout.strip(), '1', 'recovered event receives exactly one durable receipt')
    sql("update public.food_stripe_payments set payment_intent_id='pi_pinned' where payment_intent_id='pi_unmapped';")
    equal(query(call() + "->>'recorded';").stdout.strip(), 'true', 'full fee is authoritatively reconciled')
    equal(amount(), '100', 'full fee return projected once')
    first = timestamp()
    equal(query(call() + "->>'reason';").stdout.strip(), 'duplicate', 'same event id replays without a second update')
    equal(query(call(event='evt_full_later', at='2026-10-13T12:00:00Z') + "->>'recorded';").stdout.strip(), 'true', 'later distinct full receipt accepted')
    equal(timestamp(), first, 'later receipt preserves original full-return date')
    equal(query(call(event='evt_full_earlier', at='2026-10-11T12:00:00Z') + "->>'recorded';").stdout.strip(), 'true', 'out-of-order earlier full event accepted')
    earlier = timestamp()
    equal(int(earlier) < int(first), True, 'earliest known full-return event determines date')
    query(call(event='evt_partial_late', refunded=40, at='2026-10-10T12:00:00Z') + ';')
    equal(amount(), '100', 'late partial snapshot never regresses full returned amount')
    equal(timestamp(), earlier, 'partial snapshot never rewrites full-return date')
    # An update failure must roll back its receipt; a retry can then recover.
    sql("""create function public.reject_fee_write() returns trigger language plpgsql as $$
      begin raise exception 'synthetic projection failure'; end $$;
      create trigger reject_fee_write before update on public.food_stripe_payments
      for each row execute function public.reject_fee_write();""")
    atomic = call(event='evt_atomic', account='acct_atomic', intent='pi_atomic', fee=50, refunded=50)
    denied(atomic + ';', 'synthetic projection failure')
    equal(sql("select count(*) from public.food_stripe_webhook_events where event_id='evt_atomic';").stdout.strip(), '0', 'failed projection rolls back event receipt atomically')
    sql('drop trigger reject_fee_write on public.food_stripe_payments;')
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: query(atomic + "->>'recorded';").stdout.strip(), range(2)))
    equal(sorted(results), ['false', 'true'], 'simultaneous retries have exactly one financial winner')
    equal(sql("select application_fee_refunded_satang from public.food_stripe_payments where payment_intent_id='pi_atomic';").stdout.strip(), '50', 'retry after rollback recovers fee projection')
    equal(sql("select count(*) from public.food_stripe_webhook_events where event_id='evt_atomic';").stdout.strip(), '1', 'one receipt for simultaneous retry')
    equal(sql("select count(*) from public.food_orders where status='cancelled' and payment_status='refunded';").stdout.strip(), '2', 'fee reconciliation never mutates customer payment/order states')
    concurrent_legacy_refund()
    mapping_change_while_waiting()
    snapshot = sql('select jsonb_agg(to_jsonb(p) order by order_id)::text from public.food_stripe_payments p;').stdout.strip()
    receipts = sql('select count(*) from public.food_stripe_webhook_events;').stdout.strip()
    sql(ROLLBACK.read_text())
    equal(sql("select to_regprocedure('public.food_record_stripe_fee_refund_event(text,text,text,text,bigint,bigint,text,boolean,timestamptz)') is null;").stdout.strip(), 't', 'rollback disables writer')
    equal(sql('select jsonb_agg(to_jsonb(p) order by order_id)::text from public.food_stripe_payments p;').stdout.strip(), snapshot, 'rollback preserves reconciled fee values')
    equal(sql('select count(*) from public.food_stripe_webhook_events;').stdout.strip(), receipts, 'rollback preserves audit receipts')
    sql(MIGRATION.read_text())
    equal(query(call() + "->>'reason';").stdout.strip(), 'duplicate', 'reapply preserves replay protection')
    print(f'PASS Stripe application fee PostgreSQL: {CHECKS} assertions')
finally:
    sql('drop database ' + DB + ' with (force)', database='postgres')
