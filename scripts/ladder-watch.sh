#!/usr/bin/env bash
# ladder-watch.sh — fires the v8/v9/v10 gsloader ladder automatically the moment
# the phone becomes reachable again (RSA approved, or back on Android).
#
# State machine, one pass every 15s:
#   - authorized ROOT adb (custom recovery): dump ABL logs + pstore once
#   - authorized Android (ro.product.device=panther): run the ladder in order,
#     one image per pass, marking each done in /tmp
# usage: ladder-watch.sh SERIAL
set -uo pipefail
SER="${1:?usage: ladder-watch.sh SERIAL}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GS="$ROOT/forks/hakios-xnu-kernel/devices/panther/gsloader"
LOG=/tmp/ladder-watch.log
say() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

say "watching $SER (ladder: v8 -> v9 -> v10)"
while true; do
  ID="$(adb -s "$SER" shell id -u 2>/dev/null | tr -d '\r')"
  DEV="$(adb -s "$SER" shell getprop ro.product.device 2>/dev/null | tr -d '\r')"

  if [ "$ID" = "0" ] && [ ! -f /tmp/bldump-done ]; then
    say "root adb detected — dumping ABL logs + pstore"
    bash "$ROOT/scripts/dump-bl-log.sh" "$SER" /tmp/bl-log >> "$LOG" 2>&1
    touch /tmp/bldump-done
  fi

  if [ "$DEV" = "panther" ]; then
    if [ ! -f /tmp/ladder-v8-done ]; then
      say "=== LADDER v8 (key-protocol wdt) ==="
      REBOOT_TIMEOUT_S=240 bash "$ROOT/scripts/phone-test-loop.sh" "$SER" \
        "$GS/panther-boot-avb-v8.img" >> "$LOG" 2>&1
      say "v8 rc=$?"
      touch /tmp/ladder-v8-done
    elif [ ! -f /tmp/ladder-v9-done ]; then
      say "=== LADDER v9 (v8 + ramoops plog) ==="
      REBOOT_TIMEOUT_S=240 bash "$ROOT/scripts/phone-test-loop.sh" "$SER" \
        "$GS/panther-boot-avb-v9.img" >> "$LOG" 2>&1
      say "v9 rc=$?"
      touch /tmp/ladder-v9-done
    elif [ ! -f /tmp/ladder-v10-done ]; then
      say "=== LADDER v10 (v9 + EL2 normalization) ==="
      REBOOT_TIMEOUT_S=240 bash "$ROOT/scripts/phone-test-loop.sh" "$SER" \
        "$GS/panther-boot-avb-v10.img" >> "$LOG" 2>&1
      say "v10 rc=$?"
      touch /tmp/ladder-v10-done
    elif [ ! -f /tmp/ladder-finish-done ]; then
      say "ladder complete — tail of watch log follows:"
      grep -E "RESULT|bootreason|rc=" "$LOG" | tail -12
      touch /tmp/ladder-finish-done
    fi
  fi
  sleep 15
done
