-- Catalog-only verification of the exact reviewed fulfillment functions. No order/customer rows.
with expected(signature,definition_md5) as (values
('internal.food_fulfillment_notify()','d9c69a23efdb8b00ea94856422d8c79d'),
  ('internal.food_fulfillment_now()','1d1a0db3cdc1142561a28df5bbeeb01a'),
  ('internal.food_fulfillment_order_guard()','51e5b9209b539c991e56aee1861d5a65'),
  ('internal.food_fulfillment_store_guard()','bf740a3690fc8b702ea8af71ea420682'),
  ('internal.food_order_status_notify()','2dce4e02de8dbad42b34da106e23f467'),
  ('internal.food_orders_gp_snapshot()','bde76e67cd70d9f4458a3497de3d78d5'),
  ('internal.food_pickup_slots(uuid,timestamp with time zone)','804bac8b2377702cad17406120ce79f3'),
  ('internal.food_refund_storage_access(text,boolean)','a646ad9afe96eb40846b3f7e468065fe'),
  ('internal.food_set_scheduled_order(uuid,timestamp with time zone)','59e9ad51d56cd594950897c44e605800'),
  ('internal.food_validate_fulfillment(uuid,text,text,timestamp with time zone,boolean)','29a29852fdffea014730ebf32ad8187f'),
  ('public.admin_food_fulfillment_summary(date,date)','098a0fe5c86adc6abec756b9dc1b02f3'),
  ('public.admin_food_orders_v2(uuid,text,text,integer,text,text)','cafd6e59b653fba96f5500338be23968'),
  ('public.food_cancel_order(uuid,text)','4569bb76954130beef7253dd93308822'),
  ('public.food_complete_delivery(uuid,text,text,text)','78de2a06e938710a3b37f36c37d9e856'),
  ('public.food_create_order(uuid,text,text,text,text,jsonb,double precision,double precision)','d3403f9032876a7154a8afb14656e574'),
  ('public.food_create_order_v3(uuid,text,text,text,text,jsonb,double precision,double precision,text,text,timestamp with time zone,text)','e3dcc87e05585cd71ff5b7d26d8db50e'),
  ('public.food_public_catalog()','e7c6f76929dcf64e784c5d1670e57256'),
  ('public.food_quote_order(uuid,jsonb,double precision,double precision)','3a5b74285594596c5553cb02ca3568b6'),
  ('public.food_quote_order_v3(uuid,jsonb,double precision,double precision,text,text)','3d8276399e97e175ca0ecbd0479687cb'),
  ('public.food_request_cancel(uuid,text)','6c8f08f371a7af1ebd9c7938ed101ba5'),
  ('public.food_resolve_cancel_request(uuid,boolean,boolean,text)','70797b0ac04de13fc0213000c221dba9'),
  ('public.food_set_payment_status(uuid,text,text)','74906d14b64428288110be255dc1cdd0'),
  ('public.food_store_cancel_order(uuid,boolean,text)','f31a4fb6f738697e732035207fe2b8b8'),
  ('public.food_store_directory_v2(text)','6e80152edf6f5be0f0249785cf6f34dc'),
  ('public.food_store_mark_refunded(uuid,text,text)','17553b2c6e4d528344a34852bccf17cd'),
  ('public.food_store_set_fulfillment(uuid,boolean,boolean,boolean,integer)','ab9bb8992a6e81a0d3d054abf37ac219'),
  ('public.food_submit_payment(uuid,text)','e39046a865eb1379b7b70b7c264f723e'),
  ('public.food_submit_store_review(uuid,integer,text,text[],boolean)','da95a24b20ca843ecbff0f673761dc90'),
  ('public.food_timeout_cancel(uuid,text)','f9f4c20c368c76b6afb65f19187b4e57'),
  ('public.food_transition_order(uuid,text,integer,text)','22670c7fa436703fbe32ab5ffbec202b'),
  ('public.merchant_sales_report(uuid)','4445a74f0282b946d24198b212c97c7e'),
  ('public.merchant_set_refund_status(uuid,text,text)','a61e78c65bc2bf2f65d3f1f66eefcda3')
)
select not exists(select 1 from expected where to_regprocedure(signature) is null or md5(pg_get_functiondef(to_regprocedure(signature))) is distinct from definition_md5)
  and (select count(*)=13 from information_schema.columns where table_schema='public' and ((table_name='food_stores' and column_name in ('pickup_enabled','delivery_enabled','cod_enabled','prep_minutes')) or (table_name='food_orders' and column_name in ('fulfillment_type','payment_method','pickup_at','pickup_code','picked_up_at','cancel_requested_at','cancel_request_note','refund_slip_path','refunded_by_store_at'))))
  and (select count(*)=6 from pg_policies where schemaname='storage' and tablename='objects' and policyname like 'Refund slips %')
  and (select count(*)=3 from pg_trigger where tgname in ('food_fulfillment_order_guard','food_fulfillment_store_guard','food_fulfillment_notify') and not tgisinternal and tgenabled='O')
  and not exists(select 1 from expected where signature ~ '^public\.(food_(quote_order_v3|create_order_v3|request_cancel|store_cancel_order|resolve_cancel_request|store_mark_refunded|store_set_fulfillment|store_directory_v2)|admin_food_(orders_v2|fulfillment_summary))\(' and has_function_privilege('anon',to_regprocedure(signature),'EXECUTE'))
  as schema_ok;
