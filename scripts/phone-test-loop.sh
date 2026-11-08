#!/usr/bin/env bash
# phone-test-loop.sh — the fully headless M0 heartbeat test (no phone-side interaction).
#
# Loop: Android (adb) -> reboot bootloader -> fastboot preflight -> fastboot boot IMG
#       -> the gsloader heartbeat should SYSTEM_RESET the phone within seconds
#       -> phone lands back in Android -> adb sees it again. Total time is the signal.
#
# If the phone does NOT come back within REBOOT_TIMEOUT_S, it parked (double-fault in
# the loader — no transport reaches it): long-press power is the only way out. That
# is the single intervention this script can ever need.
#
# usage: phone-test-loop.sh SERIAL [boot.img]     (default: gsloader/panther-boot.img)
#        REBOOT_TIMEOUT_S=90 PHONE_WAIT_S=600 phone-test-loop.sh ...   (env overrides)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SER="${1:?usage: phone-test-loop.sh SERIAL [boot.img]}"
IMG="${2:-$ROOT/forks/hakios-xnu-kernel/devices/panther/gsloader/panther-boot.img}"
REBOOT_TIMEOUT_S="${REBOOT_TIMEOUT_S:-90}"     # heartbeat window after fastboot boot
PHONE_WAIT_S="${PHONE_WAIT_S:-600}"            # max wait for Android to reappear
FASTBOOT_WAIT_S="${FASTBOOT_WAIT_S:-60}"

adb_err() { echo "[phone-test] ERROR: $*" >&2; exit 1; }

[ -f "$IMG" ] || adb_err "boot image not found: $IMG"
command -v adb >/dev/null && command -v fastboot >/dev/null || adb_err "adb/fastboot missing"

say() { echo "[phone-test $(date +%H:%M:%S)] $*"; }

# 1. phone must be in Android on adb
DEV="$(adb -s "$SER" shell getprop ro.product.device 2>/dev/null | tr -d '\r')"
[ "$DEV" = "panther" ] || adb_err "device on adb is '${DEV:-none}', expected panther (serial $SER)"
say "panther on adb ($SER); bootloader state: $(adb -s "$SER" shell getprop ro.boot.flash.locked | tr -d '\r') (0 = unlocked; authoritative check is fastboot below)"

# 2. into the bootloader, headlessly
say "rebooting to bootloader..."
adb -s "$SER" reboot bootloader || adb_err "adb reboot bootloader failed"

# 3. wait for fastboot to enumerate
FB=""
t0=$SECONDS
while [ -z "$FB" ]; do
  FB="$(fastboot devices | awk -v s="$SER" '$1==s {print $1; exit}')"
  [ -n "$FB" ] && break
  [ $((SECONDS - t0)) -ge "$FASTBOOT_WAIT_S" ] && adb_err "fastboot never enumerated ($FASTBOOT_WAIT_S s)"
  sleep 2
done
say "fastboot up: $FB"

# 4. preflight: unlocked + slot
UNLOCKED="$(fastboot -s "$SER" getvar unlocked 2>&1 | awk -F': ' '/unlocked/ {print $2; exit}' | tr -d '[:space:]')"
SLOT="$(fastboot -s "$SER" getvar current-slot 2>&1 | awk -F': ' '/current-slot/ {print $2; exit}' | tr -d '[:space:]')"
say "preflight: unlocked=$UNLOCKED slot=$SLOT img=$(basename "$IMG") ($(wc -c < "$IMG") bytes)"
[ "$UNLOCKED" = "yes" ] || adb_err "bootloader reports locked — stop (user decision required)"

# 5. THE TEST: fastboot boot (RAM session; nothing is flashed)
say "fastboot boot $(basename "$IMG") — heartbeat should reset the phone within seconds"
fastboot -s "$SER" boot "$IMG" > /tmp/ptl-fastboot.log 2>&1
FBRC=$?
say "fastboot rc=$FBRC: $(tail -1 /tmp/ptl-fastboot.log)"

# 6. wait for the phone to come back on adb (self-reboot = heartbeat heard)
say "waiting up to ${REBOOT_TIMEOUT_S}s for the self-reboot..."
BOOT_T0=$SECONDS
FOUND=""
while [ $((SECONDS - BOOT_T0)) -lt "$REBOOT_TIMEOUT_S" ]; do
  STATE="$(adb -s "$SER" get-state 2>/dev/null || true)"
  if [ "$STATE" = "device" ]; then FOUND=1; break; fi
  sleep 2
done

if [ -z "$FOUND" ]; then
  # one more chance: it may be sitting in fastboot (ABL refused the image — our old puzzle)
  IF_FB="$(fastboot devices | awk -v s="$SER" '$1==s {print; exit}')"
  if [ -n "$IF_FB" ]; then
    say "RESULT: NO-JUMP — phone idle in fastboot (ABL refused the image; no code ran). fastboot reboot to recover"
    fastboot -s "$SER" reboot || true
    exit 2
  fi
  echo "[phone-test] RESULT: PARKED — no adb, no fastboot for ${REBOOT_TIMEOUT_S}s." >&2
  echo "[phone-test] The ONE finger-case: long-press power (~10s), then rerun this script." >&2
  exit 3
fi

# 7. phone is back: report the round trip
DT=$((SECONDS - BOOT_T0))
BOOTED_DEV="$(adb -s "$SER" shell getprop ro.product.device 2>/dev/null | tr -d '\r')"
BR="$(adb -s "$SER" shell getprop ro.boot.bootreason 2>/dev/null | tr -d '\r')"
say "bootreason after comeback: ${BR:-unknown} (watchdog,* = wdt reset heard us)"
say "RESULT: HEARTBEAT — phone self-rebooted to Android in ~${DT}s (device=${BOOTED_DEV:-settling})"
say "gsloader ran under ABL: the fastboot-boot contract holds. M0 = GREEN"
exit 0
