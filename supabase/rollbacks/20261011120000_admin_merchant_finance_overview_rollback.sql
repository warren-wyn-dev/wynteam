-- Rollback for 20261011120000_admin_merchant_finance_overview.sql.
-- Read-only function, nothing else depends on it in the database. The Admin
-- page /merchant/finance shows its error state once this is dropped.
drop function if exists public.admin_merchant_finance_overview(date, date);
