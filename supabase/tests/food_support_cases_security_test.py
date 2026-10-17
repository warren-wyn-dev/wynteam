# Isolated real-role/concurrency/rollback regression; uses only synthetic fixtures.
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import hashlib
import os
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PSQL = os.environ.get('PSQL', 'psql')
DB = f'food_support_security_{os.getpid()}'
A = '00000000-0000-0000-0000-000000000001'
B = '00000000-0000-0000-0000-000000000002'
VIEW = '00000000-0000-0000-0000-000000000003'
EDIT = '00000000-0000-0000-0000-000000000004'
OUTSIDER = '00000000-0000-0000-0000-000000000007'
ORDER = '20000000-0000-0000-0000-000000000001'
CHECKS = 0


def sql(statement, database=DB, check=True):
    result = subprocess.run([PSQL, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', database],
                            input=statement, text=True, capture_output=True)
    if check and result.returncode:
        raise AssertionError(result.stderr)
    return result


def role_sql(statement, actor=None, role='authenticated', check=True):
    uid = f"set test.uid='{actor}';" if actor else "set test.uid='';"
    return sql(uid + f'set role {role};' + statement, check=check)


def equal(actual, expected, label):
    global CHECKS
    assert actual == expected, f'{label}: actual={actual!r} expected={expected!r}'
    CHECKS += 1
    print('PASS', label)


def denied(statement, actor, message, role='authenticated'):
    result = role_sql(statement, actor, role, check=False)
    assert result.returncode and message in result.stderr, result.stderr
    global CHECKS
    CHECKS += 1
    print('PASS', message)


migration = (ROOT / 'supabase/migrations/20261014072555_food_support_cases.sql').read_text()
test = (ROOT / 'supabase/tests/food_support_cases_test.sh').read_text()
setup = test.split("run >/dev/null <<'SQL'\n", 1)[1].split('\nSQL\n', 1)[0]
print('Migration SHA256', hashlib.sha256(migration.encode()).hexdigest())
sql('create database ' + DB, database='postgres')
try:
    sql(setup)
    sql("""
      create table auth.users(id uuid primary key);
      insert into auth.users select id from public.profiles;
      alter table public.profiles add foreign key(id) references auth.users(id) on delete cascade;
      alter table public.food_orders add foreign key(buyer_id) references public.profiles(id) on delete set null;
      grant usage on schema auth to anon,authenticated;
    """)
    sql(migration)
    sql(migration)
    denied('select public.food_support_cases();', None, 'permission denied', 'anon')
    denied('select public.admin_food_support_cases();', OUTSIDER, 'Not authorized')
    denied('select * from public.food_support_cases;', A, 'permission denied')
    create = f"select public.food_create_support_case('{ORDER}','order','Missing item','Synthetic missing item report')->>'id';"
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: role_sql(create, A, check=False), range(2)))
    equal(sum(result.returncode == 0 for result in results), 1, 'simultaneous duplicate case creates one row')
    equal(sql('select count(*) from public.food_support_cases;').stdout.strip(), '1', 'duplicate intake preserves count')
    case = sql('select id from public.food_support_cases;').stdout.strip()
    equal(role_sql('select jsonb_array_length(public.admin_food_support_cases());', VIEW).stdout.strip(), '1', 'actual view-role queue read')
    denied(f"select public.food_support_case_detail('{case}');", B, 'Not authorized')
    denied(f"select public.admin_update_food_support_case('{case}',1,'in_progress','','Synthetic review reason',true);", VIEW, 'Not authorized')
    update = f"select public.admin_update_food_support_case('{case}',1,'in_progress','','Synthetic review reason',true)->>'version';"
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: role_sql(update, EDIT, check=False), range(2)))
    equal(sum(result.returncode == 0 for result in results), 1, 'simultaneous expected-version update has one winner')
    equal(sql('select version from public.food_support_cases;').stdout.strip(), '2', 'exactly one version increment')
    equal(sql('select count(*) from public.food_support_events;').stdout.strip(), '2', 'exactly one audit per committed operation')
    snapshot = sql("select jsonb_build_array((select count(*) from public.food_support_cases),(select count(*) from public.food_support_messages),(select count(*) from public.food_support_events))::text;").stdout.strip()
    sql((ROOT / 'supabase/rollbacks/20261014072555_food_support_cases_rollback.sql').read_text())
    denied('select public.food_support_cases();', A, 'permission denied')
    equal(sql("select jsonb_build_array((select count(*) from public.food_support_cases),(select count(*) from public.food_support_messages),(select count(*) from public.food_support_events))::text;").stdout.strip(), snapshot, 'rollback preserves case conversation and audit')
    sql(migration)
    equal(role_sql(f"select public.food_support_case_detail('{case}')->>'status';", A).stdout.strip(), 'in_progress', 'reapply restores preserved case access')
    sql(f"delete from auth.users where id in ('{A}','{EDIT}');")
    equal(sql('select count(*) from public.profiles where id in (\'' + A + "','" + EDIT + "');").stdout.strip(), '0', 'auth-user deletion cascades profiles without support FK block')
    equal(sql('select (buyer_id is null and assigned_to is null)::text from public.food_support_cases;').stdout.strip(), 'true', 'deleted buyer and assigned agent anonymized')
    equal(sql('select count(*) from public.food_support_events where actor_id is not null;').stdout.strip(), '0', 'deleted actors removed from preserved audit')
    equal(sql('select count(*) from public.food_support_messages where actor_id is not null;').stdout.strip(), '0', 'deleted actors removed from preserved messages')
    equal(sql('select count(*) from public.food_support_events;').stdout.strip(), '2', 'audit still present after auth/profile deletion')
    denied(f"select public.food_support_case_detail('{case}');", B, 'Not authorized')
    print(f'PASS independent support security/concurrency/rollback: {CHECKS} assertions')
finally:
    sql('drop database ' + DB, database='postgres')
