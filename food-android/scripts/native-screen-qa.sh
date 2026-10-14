#!/usr/bin/env bash
set -euo pipefail

mkdir -p visual
adb install -r food-android/app/build/outputs/apk/debug/app-debug.apk
adb shell settings put global private_dns_mode off || true
adb shell svc wifi enable || true
adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true

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

# Android Emulator can show system ANR dialogs ABOVE a correctly rendered app.
# Such screenshots are not visual evidence, even when the screenshot command succeeds.
assert_native_window() {
  local width="$1" locale="$2" attempt="$3"
  local dump="visual/android-window-${width}-${locale}-attempt${attempt}.xml"
  adb shell uiautomator dump /sdcard/wynos-food-window.xml >/dev/null
  adb exec-out cat /sdcard/wynos-food-window.xml > "$dump"

  if grep -Eiq "(isn't responding|is not responding|isn.t responding|is not responding|isn’t responding|Wait for app|Close app|System UI.*responding|Pixel Launcher.*responding|not responding)" "$dump"; then
    echo "System/app not-responding dialog detected: ${width}px / ${locale} (attempt ${attempt})" >&2
    return 1
  fi

  # Positive assertions: it is not enough to have a screenshot or a working DNS.
  # The actual WYNOS Food guest header AND localized home content must be visible.
  if ! grep -Fq 'WYNOS' "$dump" || ! grep -Fq 'Food' "$dump"; then
    echo "WYNOS Food header not visible in Android accessibility window." >&2
    return 1
  fi
  if [[ "$locale" == th-TH ]]; then
    if ! grep -Fq 'เลือกอาหารที่อยากกินได้เลย' "$dump"; then
      echo "Thai native guest-home content missing: ${width}px." >&2
      return 1
    fi
  else
    if ! grep -Fq 'Find something delicious' "$dump"; then
      echo "English native guest-home content missing: ${width}px." >&2
      return 1
    fi
  fi
}

for width in 360 390 430; do
  adb shell wm size "${width}x844"
  adb shell wm density 160
  for locale in th-TH en-US; do
    adb shell cmd locale set-app-locales online.wynos.food --user 0 --locales "$locale" || true
    verified=0
    for attempt in 1 2; do
      adb shell am force-stop online.wynos.food || true
      adb shell am start -W -n online.wynos.food/.MainActivity
      sleep 18
      adb exec-out screencap -p > "visual/android-home-${width}-${locale}-attempt${attempt}.png"
      if assert_native_window "$width" "$locale" "$attempt"; then
        cp "visual/android-home-${width}-${locale}-attempt${attempt}.png" "visual/android-home-${width}-${locale}.png"
        verified=1
        break
      fi
      # Best-effort recovery for a launcher/system ANR, not an assertion bypass.
      adb shell input keyevent 4 || true
      adb shell am force-stop com.google.android.apps.nexuslauncher || true
      adb shell am force-stop com.android.launcher3 || true
      sleep 5
    done
    if [ "$verified" -ne 1 ]; then
      echo "FAILED: Android visual QA not certified at ${width}px ${locale}" >&2
      adb shell dumpsys window | tail -65 > "visual/android-window-failure-${width}-${locale}.txt" || true
      exit 1
    fi
  done
done
adb logcat -d -v brief -s AndroidRuntime:E System.err:E > visual/android-errors.txt || true
