-- Disable the event writer; retain receipts and already reconciled fee values.
-- Revert the matching webhook handler before a separately approved rollout.
drop function if exists public.food_record_stripe_fee_refund_event(text,text,text,text,bigint,bigint,text,boolean,timestamptz);
notify pgrst, 'reload schema';
