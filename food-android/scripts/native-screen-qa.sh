#!/usr/bin/env bash
set -euo pipefail
mkdir -p visual
adb install -r food-android/app/build/outputs/apk/debug/app-debug.apk
adb shell settings put global private_dns_mode off || true
adb shell svc wifi enable || true
resolved=0
for attempt in 1 2 3 4; do
  check="$(adb shell ping -c 1 -W 3 kqokpocajhfbidcxpvhh.supabase.co 2>&1 || true)"
  if ! echo "$check" | grep -Eiq "unknown host|bad address|Name or service not known"; then
    resolved=1
    break
  fi
  sleep 6
done
echo "DNS_RESULT=$resolved" | tee visual/android-network.txt
if [ "$resolved" -ne 1 ]; then
  echo "Android emulator cannot resolve Supabase: UI parity NOT certified." >&2
  exit 1
fi

for width in 360 390 430; do
  adb shell wm size "${width}x844"
  adb shell wm density 160
  for locale in th-TH en-US; do
    adb shell cmd locale set-app-locales online.wynos.food --user 0 --locales "$locale" || true
    adb shell am force-stop online.wynos.food || true
    adb shell am start -n online.wynos.food/.MainActivity
    sleep 20
    adb exec-out screencap -p > "visual/android-home-${width}-${locale}.png"
  done
done
adb logcat -d -v brief -s AndroidRuntime:E System.err:E > visual/android-errors.txt || true
