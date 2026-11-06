#!/usr/bin/env bash
# dump-bl-log.sh — ABL's own boot log, from a recovery ROOT shell.
#
# gs201 (gs201-rmem.dtsi): bl_log @0xfd800000 (512K, current boot) and
# bl_old_log @0xfd880000 (512K, PREVIOUS boot — this is where a failed
# fastboot-boot attempt's ABL log ends up after the watchdog reset).
# Also reads the ramoops console zone (our gsloader plog channel) via pstore.
#
# Needs: custom recovery with root adb (TWRP-class). /dev/mem read via dd
# (4096-byte blocks: skip = phys/4096).
# usage: dump-bl-log.sh SERIAL [outdir]
set -uo pipefail
SER="${1:?usage: dump-bl-log.sh SERIAL [outdir]}"
OUT="${2:-/tmp/bl-log}"
mkdir -p "$OUT"

adb -s "$SER" root >/dev/null 2>&1 || true
sleep 2
echo "== whoami: $(adb -s "$SER" shell id 2>&1 | head -1)"

for reg in "bl_old_log:0xfd880000" "bl_log:0xfd800000"; do
  name="${reg%%:*}"; pa="${reg##*:}"
  pg=$(( 0x$pa / 4096 ))
  adb -s "$SER" shell "dd if=/dev/mem bs=4096 skip=$pg count=128 2>/dev/null" > "$OUT/$name.bin" 2>/dev/null
  echo "== $name @ $pa ($(wc -c < "$OUT/$name.bin") bytes) — last 50 lines =="
  strings -n 6 "$OUT/$name.bin" | tail -50
done

echo "== pstore =="
adb -s "$SER" shell "ls /sys/fs/pstore/ 2>/dev/null; head -c 4096 /sys/fs/pstore/console-ramoops-0 2>/dev/null; head -c 4096 /sys/fs/pstore/console-ramoops 2>/dev/null"
echo "== plog (v9 channel) tail =="
adb -s "$SER" shell "head -c 4096 /sys/fs/pstore/console-ramoops-0 2>/dev/null" | tail -20
