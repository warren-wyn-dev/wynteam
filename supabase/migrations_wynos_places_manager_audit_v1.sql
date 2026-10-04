-- Allow dedicated WYNOS Places Admin audit events.
alter table public.audit_log
  drop constraint if exists audit_log_event_type_check;

alter table public.audit_log
  add constraint audit_log_event_type_check check (
    event_type = any (array[
      'account_deleted',
      'admin_ad_account_status',
      'admin_ad_settings_updated',
      'admin_ad_topup_reviewed',
      'admin_announcement_sent',
      'admin_content_removed',
      'admin_content_restored',
      'admin_food_order_viewed',
      'admin_food_staff_updated',
      'admin_food_store_suspended',
      'admin_food_store_unsuspended',
      'admin_inactive_reminder_sent',
      'admin_merchant_application_approved',
      'admin_merchant_application_rejected',
      'admin_platform_campaign_saved',
      'admin_platform_campaign_settled',
      'admin_user_action_applied',
      'admin_user_unbanned',
      'admin_wynos_place_saved',
      'admin_wynos_place_enabled',
      'admin_wynos_place_disabled',
      'admin_wynos_places_imported',
      'appeal_decided',
      'data_exported',
      'moderation_action_applied',
      'system_notification_sent'
    ]::text[])
  );
