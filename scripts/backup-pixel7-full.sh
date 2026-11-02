#!/usr/bin/env bash
# backup-pixel7-full.sh — FULL unrooted backup of a Pixel 7 to the HDD.
# READ-ONLY: touches nothing on the phone. Captures everything stock adb allows:
#   /sdcard (all user files), user APKs, contacts, SMS/call-log attempts, getprop,
#   package list, bugreport, file manifest, fingerprint -> factory image link.
# NOT possible unrooted (also written to RESTORE-NOTES.txt):
#   app-internal databases (chat apps etc.), Wi-Fi passwords, partition images.
# Going back to stock later = flashing Google's factory image (URL printed at the end).
# Usage: backup-pixel7-full.sh [SERIAL] [OUTDIR]
#   SERIAL required when more than one adb device is attached (e.g. the emulator).
set -uo pipefail
SERIAL="${1:-}"
if [ -z "$SERIAL" ]; then
  mapfile -t DEVS < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
  [ "${#DEVS[@]}" -eq 1 ] && SERIAL="${DEVS[0]}"
fi
[ -n "$SERIAL" ] || { echo "usage: backup-pixel7-full.sh <serial> [outdir] (multiple devices attached)"; exit 1; }
A=(adb -s "$SERIAL")
DEV="$("${A[@]}" shell getprop ro.product.device | tr -d '\r')"
[ "$DEV" = "panther" ] || { echo "refusing: device '$SERIAL' is '$DEV', expected 'panther'"; exit 1; }
OUT="${2:-/mnt/hdd2/pixel7-backup-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"
echo "== pixel7 full backup ($SERIAL) -> $OUT =="

"${A[@]}" shell getprop                  > "$OUT/getprop.txt"
"${A[@]}" shell pm list packages         > "$OUT/packages-all.txt"
"${A[@]}" shell pm list packages -3      > "$OUT/packages-user.txt"
FP="$(grep -oP '^\[ro.build.fingerprint\]: \[\K[^\]]+' "$OUT/getprop.txt" || echo unknown)"
echo "fingerprint: $FP" | tee "$OUT/fingerprint.txt"

echo "== 1/6 /sdcard (all user files) =="
"${A[@]}" pull /sdcard "$OUT/sdcard" || echo "WARN: sdcard pull incomplete"

echo "== 2/6 user APKs =="
mkdir -p "$OUT/apks"
"${A[@]}" shell pm list packages -3 -f | tr -d '\r' | sed 's/^package://;s/=.*//' | sort -u | while read -r apk; do
  [ -n "$apk" ] || continue
  "${A[@]}" pull "$apk" "$OUT/apks/$(basename "$apk")" >/dev/null 2>&1 || echo "  skip: $apk"
done
ls "$OUT/apks" | wc -l | xargs echo "  APKs pulled:"

echo "== 3/6 contacts / SMS / call log (shell may be denied on stock) =="
"${A[@]}" shell content query --uri content://com.android.contacts/contacts > "$OUT/contacts.txt" 2>&1 || echo "  contacts: denied"
"${A[@]}" shell content query --uri content://sms                           > "$OUT/sms.txt" 2>&1 || echo "  sms: denied"
"${A[@]}" shell content query --uri content://call_log/calls                > "$OUT/calllog.txt" 2>&1 || echo "  call_log: denied"

echo "== 4/6 bugreport =="
"${A[@]}" bugreport "$OUT" >/dev/null 2>&1 || echo "  bugreport failed (non-fatal)"

echo "== 5/6 manifest =="
( cd "$OUT" && find . -type f -not -name MANIFEST.txt -printf '%s\t%p\n' | sort -k2 > MANIFEST.txt ) \
  && du -sh "$OUT" | tee -a MANIFEST.txt

echo "== 6/6 restore notes =="
cat > "$OUT/RESTORE-NOTES.txt" <<EOF
Pixel 7 backup $(date -u) — fingerprint: $FP
Back to stock:   flash the factory image for this exact build:
                 https://developers.google.com/android/images (panther)
                 unzip, ./flash-all.sh (this preserves nothing — it is the wipe-recovery path)
Dual boot future: HakiOS chainloader boots from boot.img; Android stays installed.
NOT in this backup (unrooted): app-internal data (chats etc.) — ensure Settings > Google > Backup is ON
                 and run a Google One backup BEFORE unlocking; Wi-Fi passwords (re-enter).
APKs in apks/ reinstall with: adb install apks/<name>.apk
/sdcard restored with: adb push sdcard/ /sdcard/
EOF
echo "== DONE: $OUT =="
