import { handleLineWebhook } from './handler.mjs';

// Intentionally no database client, token, or side effects in this scaffold.
// LINE's HMAC-SHA256 signature is mandatory on every request.
// In supabase/config.toml only this external webhook has verify_jwt = false.
Deno.serve((request) =>
  handleLineWebhook(request, Deno.env.get('ZOKY_LINE_CHANNEL_SECRET') ?? ''),
);
