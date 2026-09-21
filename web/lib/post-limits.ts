/**
 * WYN-185 item 12: single source of truth for the max images per post.
 * Previously `9` was duplicated as a magic number across the composer
 * (button-disable checks, the file-picker's own truncation, the "x/9"
 * counter) and the publish helper, with no shared constant tying them
 * together -- server-side enforcement (drop_images_position_max_9 /
 * club_posts_image_urls_length, both applied to production 2026-09-03,
 * plus the atomic-publish RPC's own `v_image_count > 9` check) already
 * agreed on 9, this only fixes the client having no single place that
 * says so.
 */
export const MAX_POST_IMAGES = 9;
