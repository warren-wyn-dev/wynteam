#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
merchant_dir="$(dirname "$script_dir")"
web_dir="$(dirname "$merchant_dir")"
flutter_revision=abaf9c523780a608bd46686fd5e53740a07077f8
flutter_sdk_dir="${ZOKY_FLUTTER_SDK:-$web_dir/.vercel/cache/flutter-3.47.7}"
export CI=true FLUTTER_SUPPRESS_ANALYTICS=true

if [ ! -x "$flutter_sdk_dir/bin/flutter" ]; then
  mkdir -p "$(dirname "$flutter_sdk_dir")"
  git clone --depth 1 --branch 3.47.7 https://github.com/flutter/flutter.git "$flutter_sdk_dir"
fi
if [ "$(git -C "$flutter_sdk_dir" rev-parse HEAD)" != "$flutter_revision" ]; then
  printf '%s\n' 'Flutter SDK revision mismatch. Expected Flutter 3.47.7.' >&2
  exit 1
fi
cd "$merchant_dir"
"$flutter_sdk_dir/bin/flutter" pub get --enforce-lockfile
"$flutter_sdk_dir/bin/flutter" analyze --no-pub
"$flutter_sdk_dir/bin/flutter" test --no-pub
# Rebuild generated output so a prior SDK fallback font cannot survive a flag change.
rm -rf -- "$web_dir/public/merchant-flutter"
"$flutter_sdk_dir/bin/flutter" build web --release --no-pub \
  --web-resources-cdn --no-wasm-dry-run --base-href /merchant-flutter/ \
  --output "$web_dir/public/merchant-flutter"
# Renderer stays same-origin. Text fallback is provided by Flutter itself,
# rather than bundling a second branded/text font into the consumer web.
if [ ! -f "$web_dir/public/merchant-flutter/canvaskit/canvaskit.js" ]; then
  cp -R "$flutter_sdk_dir/bin/cache/flutter_web_sdk/canvaskit" "$web_dir/public/merchant-flutter/canvaskit"
fi
node "$web_dir/scripts/check-web-fonts.mjs"
