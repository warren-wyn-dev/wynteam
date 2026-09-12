-- WYN-155 / system audit: harden SECURITY DEFINER RPC exposure.
--
-- PostgreSQL grants EXECUTE on newly-created functions to PUBLIC by default.
-- A large part of WYNOS' older public-schema SECURITY DEFINER surface was
-- created before we standardized the explicit REVOKE pattern used by newer
-- migrations. Because PostgREST exposes public-schema functions, that left
-- anonymous, not-signed-in requests able to invoke many RPCs that are intended
-- for authenticated application users (including admin/moderation RPCs).
--
-- Keep the current authenticated behavior intact while removing both the
-- inherited PUBLIC grant and the explicit `anon` grant from every public
-- SECURITY DEFINER function. Then restore the three deliberately pre-auth
-- endpoints documented by the product flows.
--
-- The dynamic sweep is intentional: it fixes historical functions as a class,
-- including overloaded signatures, and avoids a brittle hand-maintained list
-- that could silently omit an older SECURITY DEFINER function.

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
  loop
    execute format(
      'revoke execute on function %s from public, anon',
      fn.signature
    );

    -- Production already grants authenticated EXECUTE on this historical
    -- surface. Re-assert it here so removing PUBLIC can never turn this
    -- security repair into an application outage on a fresh installation.
    execute format(
      'grant execute on function %s to authenticated',
      fn.signature
    );
  end loop;
end
$$;

-- Deliberate pre-auth exceptions.
-- 1) Welcome/AuthMethod must read the invite-gate toggle before sign-in.
grant execute on function public.is_invite_gate_enabled() to anon, authenticated;

-- 2) Referral-code validation happens before account creation/sign-in.
grant execute on function public.validate_referral_code(text) to anon, authenticated;

-- 3) Club invite links must be previewable from a shared URL before auth.
grant execute on function public.preview_club_invite_link(text) to anon, authenticated;
