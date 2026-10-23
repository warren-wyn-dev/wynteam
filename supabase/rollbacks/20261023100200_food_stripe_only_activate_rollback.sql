-- Rollback for 20261023100200_food_stripe_only_activate.sql (Founder approval
-- required). Back to legacy payment behaviour: stores without Stripe take
-- orders again and slips are accepted. Automatic refunds keep running.
update public.food_payment_policy set stripe_only_from = null, updated_at = now() where id;
