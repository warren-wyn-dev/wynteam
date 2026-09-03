import 'package:supabase_flutter/supabase_flutter.dart';

/// Upload options for a file whose storage path is unique per upload and
/// therefore never changes content: Drop/Club-post/chat images, Pop
/// videos and thumbnails, appeal evidence. Every one of those paths
/// carries a timestamp (and an index, where there can be several), so a
/// given URL always resolves to the same bytes forever.
///
/// Supabase Storage's default is `cache-control: max-age=3600`, so the
/// CDN and every viewer's browser re-fetched each feed image once an
/// hour even though it could not possibly have changed -- the single
/// cheapest bandwidth and repeat-visit-latency win available, and it
/// costs nothing but this header.
///
/// Deliberately NOT used for the avatar upload: that one writes to a
/// stable path (`{userId}/avatar.{ext}`) with `upsert: true`, so its
/// bytes really do change. (Its public URL carries a `?v=` cache-buster
/// for exactly that reason -- but a long max-age there would still be
/// betting the whole cache lifetime on every reader having the current
/// query string, which is not a bet worth making for one small file.)
const immutableUploadFileOptions = FileOptions(
  // One year, the conventional maximum. `immutable` tells a client it
  // need not revalidate at all.
  cacheControl: '31536000, immutable',
);
