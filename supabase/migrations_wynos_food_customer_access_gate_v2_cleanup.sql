-- Cleanup temporary QA-only helper after customer access gate v2.
drop function if exists public.food_require_developer_preview_access();
