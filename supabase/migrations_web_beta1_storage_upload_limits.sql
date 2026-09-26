-- =====================================================================
-- Web Beta1 QA — WEB-B1-QA-03: server-side upload type/size limits
--
-- Founder runs this via the Supabase Dashboard SQL editor; no AI applies
-- production SQL (AGENTS.md Change Control). Idempotent: safe to re-run.
--
-- Storage RLS already scopes every path to its owner / conversation /
-- club, but nothing server-side limited WHAT could be uploaded. A client
-- calling the Storage API directly could put text/html or image/svg+xml
-- (script-capable) or arbitrarily large files into the public avatars /
-- drop-images buckets. Client-side checks are bypassable (AGENTS.md:
-- "ห้ามเชื่อ extension หรือ client MIME เพียงอย่างเดียว").
--
-- Allowed: raster image types that web (<input accept="image/*">, HEIC
-- from iPhone) and the Flutter app (mime type guessed from the file
-- extension) actually send. application/octet-stream stays allowed
-- because Flutter falls back to it for unknown extensions; browsers
-- download it instead of rendering it, so it cannot execute script.
-- NOT allowed: image/svg+xml, text/html and everything else.
--
-- Sizes: avatars/covers are cropped/compressed client-side (10 MB);
-- post, chat and club images keep headroom for full-resolution phone
-- photos (20 MB). pop-videos and appeal-evidence are not touched.
-- =====================================================================

update storage.buckets
set
  allowed_mime_types = array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'image/heic', 'image/heif', 'image/avif',
    'application/octet-stream'
  ],
  file_size_limit = case id when 'avatars' then 10485760 else 20971520 end
where id in ('avatars', 'drop-images', 'chat-media', 'club-media');
