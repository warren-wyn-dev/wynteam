create index if not exists followed_post_digest_latest_drop_idx
  on public.followed_post_digest_deliveries(latest_drop_id)
  where latest_drop_id is not null;

create index if not exists followed_post_digest_latest_author_idx
  on public.followed_post_digest_deliveries(latest_author_id)
  where latest_author_id is not null;
