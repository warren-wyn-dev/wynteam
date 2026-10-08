-- Sandbox QA reporting-only indexes. No DML and no changes to payment path.
-- Target Supabase QA pcatuxtenluqzjzzwsvl; never Production.
create index if not exists food_finance_qa_report_all_projections_idx
 on public.food_finance_order_projections_qa(created_at desc,order_id desc);
create index if not exists food_finance_qa_report_store_refunds_idx
 on public.food_finance_refund_adjustments_qa(store_id,created_at desc,id desc);
create index if not exists food_finance_qa_report_all_refunds_idx
 on public.food_finance_refund_adjustments_qa(created_at desc,id desc);
