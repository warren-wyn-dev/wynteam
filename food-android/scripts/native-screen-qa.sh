#!/usr/bin/env bash
set -euo pipefail
mkdir -p visual
APK="food-android/app/build/outputs/apk/debug/app-debug.apk"
PACKAGE="online.wynos.food"
unzip -Z1 "$APK" > visual/zoky-apk-file-list.txt
for asset in zoky_hero zoky_service dealpizza_crop dealdrinks_crop; do
  grep -Fqx "assets/$asset.webp.b64" visual/zoky-apk-file-list.txt
done
adb install -r "$APK"
adb shell settings put global private_dns_mode off || true
adb shell settings put global window_animation_scale 0 || true
adb shell settings put global transition_animation_scale 0 || true
adb shell settings put global animator_duration_scale 0 || true

dump_window() {
  local path="$1"
  adb shell uiautomator dump /sdcard/zoky-qa-window.xml >/dev/null
  adb exec-out cat /sdcard/zoky-qa-window.xml > "$path"
  if grep -Eiq 'isn.t responding|not responding|Wait for app|Close app' "$path"; then
    echo "Android/system ANR blocked QA: $path" >&2; return 1
  fi
}
launch_zoky() {
  adb shell am force-stop "$PACKAGE" || true
  adb shell am start -W -n "$PACKAGE/.MainActivity"
  sleep 11
}
tap_accessible() {
  local file="$1" marker="$2"
  local xy
  xy="$(python3 - "$file" "$marker" <<'PY'
import re, sys, xml.etree.ElementTree as ET
path, marker = sys.argv[1:]
root = ET.parse(path).getroot()
for node in root.iter('node'):
    text = node.get('text','') + ' ' + node.get('content-desc','')
    if marker not in text: continue
    bounds = re.findall(r'\[(\d+),(\d+)\]',node.get('bounds',''))
    if len(bounds) == 2:
        x1,y1 = map(int,bounds[0]); x2,y2 = map(int,bounds[1])
        if x2>x1 and y2>y1:
            print((x1+x2)//2,(y1+y2)//2);break
PY
)"
  if [[ -z "$xy" ]]; then echo "Missing accessible control: $marker" >&2;return 1;fi
  adb shell input tap $xy
}

# Native Android widths and app locales. Zoky Home is the entry screen,
# and Food search must remain in the distinct service route.
for width in 320 360 390 430 600 840; do
  adb shell wm size "${width}x844"
  adb shell wm density 160
  for locale in th-TH en-US; do
    adb shell cmd locale set-app-locales "$PACKAGE" --user 0 --locales "$locale" || true
    verified=0
    for attempt in 1 2; do
      launch_zoky
      file="visual/zoky-home-${width}-${locale}-attempt${attempt}.xml"
      adb exec-out screencap -p > "visual/zoky-home-${width}-${locale}-attempt${attempt}.png"
      if ! dump_window "$file"; then continue;fi
      if grep -Fq 'Zoky' "$file" && grep -Fq 'บริการของ Zoky' "$file" &&
         grep -Fq 'สั่งอาหาร' "$file" &&
         ! grep -Fq 'ค้นหาร้านหรือชื่ออาหาร' "$file"; then
        cp "visual/zoky-home-${width}-${locale}-attempt${attempt}.png" "visual/zoky-home-${width}-${locale}.png"
        verified=1; break
      fi
      echo "Home assertions failed: $width $locale attempt=$attempt" >&2
      sleep 3
    done
    if [[ "$verified" != 1 ]]; then echo "FAIL: Zoky Home at $width $locale" >&2;exit 1;fi
  done
done

adb shell wm size 390x844
adb shell wm density 160
adb shell cmd locale set-app-locales "$PACKAGE" --user 0 --locales th-TH || true
launch_zoky
dump_window visual/zoky-food-entry.xml
tap_accessible visual/zoky-food-entry.xml 'สั่งอาหาร ร้านอร่อยใกล้คุณ'
sleep 7
dump_window visual/zoky-food-catalog.xml
adb exec-out screencap -p > visual/zoky-food-catalog-390-th-TH.png
if ! grep -Fq 'ค้นหาร้านหรือชื่ออาหาร' visual/zoky-food-catalog.xml; then
  echo 'Food catalog screen not reachable from Zoky service card.' >&2;exit 1
fi
adb shell input keyevent 4
sleep 3
dump_window visual/zoky-back-home.xml
if ! grep -Fq 'บริการของ Zoky' visual/zoky-back-home.xml; then
  echo 'Back did not return to Zoky Home.' >&2;exit 1
fi
tap_accessible visual/zoky-back-home.xml 'ข้อความ'
sleep 3
dump_window visual/zoky-messages.xml
if ! grep -Fq 'การแจ้งเตือน' visual/zoky-messages.xml ||
   ! grep -Fq 'แชต' visual/zoky-messages.xml; then
  echo 'Notifications first and Chats second tabs not present.' >&2;exit 1
fi
adb exec-out screencap -p > visual/zoky-messages-390-th-TH.png
tap_accessible visual/zoky-messages.xml 'หน้าหลัก'
sleep 2
adb shell input swipe 180 675 180 300 450
sleep 3
adb exec-out screencap -p > visual/zoky-deals-scrolled-390-th-TH.png
dump_window visual/zoky-deals-scrolled.xml
if ! grep -Fq 'ดีลคุ้ม! ดีลแรงวันนี้' visual/zoky-deals-scrolled.xml &&
   ! grep -Fq 'ภาพประกอบเมนู' visual/zoky-deals-scrolled.xml; then
  echo 'Deal card row not reachable by native scroll.' >&2;exit 1
fi
adb logcat -d -v brief -s AndroidRuntime:E System.err:E > visual/zoky-runtime-errors.txt || true
echo 'PASS: Zoky Home native 320/360/390/430/600/840 TH+EN, Food, Messages, Deals.'