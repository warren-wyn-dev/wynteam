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

# A successful screencap does NOT prove the app rendered. A previous run
# uploaded Android screenshots obscured by a "Pixel Launcher isn't responding"
# system modal and incorrectly appeared green. Verify the focused window.
capture_native_screen() {
  local output="$1"
  local width="$2"
  local locale="$3"
  local focus=""
  local hierarchy=""
  for attempt in 1 2 3; do
    adb shell am force-stop online.wynos.food || true
    adb shell am start -W -n online.wynos.food/.MainActivity
    sleep 18
    focus="$(adb shell dumpsys window 2>/dev/null | grep -E 'mCurrentFocus|mFocusedApp' || true)"
    # UI hierarchy distinguishes a native system ANR from a screenshot of Food.
    adb shell uiautomator dump /sdcard/wynos-food-screen.xml >/dev/null 2>&1 || true
    hierarchy="$(adb shell cat /sdcard/wynos-food-screen.xml 2>/dev/null || true)"
    if printf '%s' "$hierarchy" | grep -Eiq "(isn.t responding|not responding|ไม่ตอบสนอง)"; then
      echo "System ANR dialog obscures native UI at ${width}px ${locale}; attempt ${attempt}" >&2
      adb shell input keyevent 4 || true
      sleep 3
      continue
    fi
    if ! printf '%s' "$focus" | grep -Fq 'online.wynos.food'; then
      echo "Food is not the focused Android window at ${width}px ${locale} (attempt ${attempt}): $focus" >&2
      adb shell input keyevent 4 || true
      sleep 3
      continue
    fi
    adb exec-out screencap -p > "$output"
    if [ -s "$output" ]; then
      echo "Verified focused Food UI: $output"
      return 0
    fi
  done
  echo "Failed to capture verified native Food UI at ${width}px ${locale}" >&2
  return 1
}

qa_failed=0
for width in 360 390 430; do
  adb shell wm size "${width}x844"
  adb shell wm density 160
  for locale in th-TH en-US; do
    adb shell cmd locale set-app-locales online.wynos.food --user 0 --locales "$locale" || true
    capture_native_screen "visual/android-home-${width}-${locale}.png" "$width" "$locale" || qa_failed=1
  done
done
adb logcat -d -v brief -s AndroidRuntime:E System.err:E > visual/android-errors.txt || true
if [ "$qa_failed" -ne 0 ]; then
  echo "Native screenshot verification FAILED; do not certify UI parity." >&2
  exit 1
fi
