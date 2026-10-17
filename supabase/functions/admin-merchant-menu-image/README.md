# Admin merchant menu images

This function authenticates the existing user JWT with Auth, checks the live
`merchant:edit` permission through the caller's RPC, and publishes only normalized
images to the reserved `food-public/admin-menu/<store>/<uuid>.webp` prefix.
Restrictive Storage INSERT, UPDATE and DELETE policies protect that prefix from
browser-user writes even when an older permissive policy also matches. Existing
read policies and grants remain unchanged; rollback retains prefix protection.

Before checking, testing, serving or bundling Edge Functions, run from the repository
root:

```sh
python3 tools/prepare_admin_menu_image_vendor.py
deno check supabase/functions/admin-merchant-menu-image/index.ts
deno test --allow-read supabase/functions/admin-merchant-menu-image/
```

The preparation script downloads the exact `@imagemagick/magick-wasm@0.0.44` npm
archive with a pinned SHA-512 integrity check, verifies each selected file's SHA-256,
and copies JavaScript, TypeScript declarations, the single x86 WASM and license
notices into the ignored `_vendor/` directory. It does not execute npm scripts.
Cached assets are verified before reuse. Do not commit generated assets.

Use a Docker-backed CLI bundle with the `static_files` entries in
`supabase/config.toml`; the API/Dashboard 5 MB bundle limit is too small. Importing
the npm package directly also bundles an unused x64 WASM and exceeds the 20 MB
local-bundle limit. Deployment still requires the repository's release gates.

To reproduce the deployment-entry bundle check without deploying or contacting a
Supabase project, use a clean temporary directory containing only this function
and its prepared decoder. The Docker step runs with networking disabled:

```sh
python3 tools/prepare_admin_menu_image_vendor.py
menu_image_build_dir="$(mktemp -d)"
cp supabase/functions/admin-merchant-menu-image/{index.ts,_lib.ts,_image.ts} "$menu_image_build_dir/"
cp -R supabase/functions/admin-merchant-menu-image/_vendor "$menu_image_build_dir/_vendor"
docker run --rm --network none \
  --mount "type=bind,src=$menu_image_build_dir,dst=/function" \
  public.ecr.aws/supabase/edge-runtime@sha256:ad45164b7548bf5820ed7be714789c17ac2865edce79a09cfb4c3756c3d365a8 \
  bundle --entrypoint /function/index.ts \
  --static /function/_vendor/magick.wasm \
  --static /function/_vendor/LICENSE \
  --static /function/_vendor/NOTICE \
  --output /function/admin-menu-image.eszip
wc -c "$menu_image_build_dir/admin-menu-image.eszip"
```

Do not build inside an unrelated npm workspace: Edge Runtime packages its npm
dependencies, including installed development tools. Hosted deployment must use
the approved project's Docker-backed Supabase CLI and these prepared assets;
omit `--use-api`. No deploy command is executed by the preparation script or CI.

The normalizer accepts only actual JPEG, PNG and WebP matching the declared MIME,
at most 4 MiB, 2048 pixels per dimension and 4,000,000 pixels total. It rejects
animation, invalid containers and compressed decoding errors/warnings. It applies
EXIF orientation, limits the longest side to 1024 pixels, strips metadata and
reencodes WebP. Decode/encode work has a 1.4 second cooperative deadline; hosted
Edge Functions also impose their independent 2 second CPU and 256 MB memory limits.
ImageMagick cache allocation is capped at 64 MiB, disk spill is denied, individual
memory requests are capped at 32 MiB and profiles at 256 KiB. WASM initializes only
after the first valid, authorized image reaches the normalizer.

Local verification on 2026-10-17 used Deno 2.9.6 and the official Edge Runtime
1.77.4 image. The complete deployment-entry ESZIP (`index.ts`, `_lib.ts`, `_image.ts`
and the single prepared decoder) was **16,140,015 bytes**, below the 20 MiB local
bundle limit. Its SHA-256 was
`66be127ec800f97e4f690e929cac096269a52aab3f32b9bad9e8f8dcdc6a348e`.
The isolated normalizer-only ESZIP was 16,116,554 bytes. With networking disabled
and only the ESZIP, test harness and synthetic inputs mounted, a user worker capped at
256 MB and 2,000 ms CPU decoded and reencoded noisy 2,000 × 2,000 JPEG and WebP
inputs. First-call timings including WASM initialization were 796 ms and 1,023 ms;
outputs were 476,788 and 476,326 bytes. The entire test container, including its
separate main worker, used 233.1–239 MiB after each request. These are local fixture
measurements, not hosted production latency guarantees. The seven image tests
also passed 29 subcases covering MIME spoofing, animation, corruption, metadata,
orientation, bounds and concurrent calls.

A separate 11-case offline probe used one fresh 256 MB / 2,000 ms user worker per
fixture. PNG `zTXt`, compressed `iTXt` and `iCCP` carried synthetic metadata that
expanded to 1, 16 or 64 MiB; JPEG and WebP carried 3 MiB ICC profiles. Every case
was either rejected with a controlled `corrupt_image` response or reencoded to a
148-byte WebP without ICC, EXIF or XMP chunks. Cold normalization took 102–135 ms
and the entire container used 189.6–222.9 MiB after each request. These are bounded
local fixture measurements, not a concurrency or hosted load guarantee. No
provider or database was contacted.
