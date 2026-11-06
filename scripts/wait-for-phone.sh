#!/usr/bin/env bash
# wait-for-phone.sh — poll adb; when a real panther appears (not the emulator), run the
# FULL read-only backup to the HDD and pull the device tree, then exit.
# Authorized by the user (2026-11-02): "do a full backup ... use the hdd".
# READ-ONLY: nothing is written to or deleted from the phone.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTROOT="/mnt/hdd2/pixel7-backup-$(date +%Y%m%d-%H%M%S)"
FDT="${FDT:-$ROOT/device/panther-fdt.dtb}"
mkdir -p "$ROOT/device"
echo "[wait-for-phone] polling adb every 10s for panther; backup will go to $OUTROOT"
while true; do
  SER="$(adb devices | awk 'NR>1 && $2=="device" && $1 !~ /^emulator-|^127\.0\.0\.1/ {print $1; exit}')"
  if [ -n "${SER:-}" ]; then
    DEV="$(adb -s "$SER" shell getprop ro.product.device 2>/dev/null | tr -d '\r')"
    if [ "$DEV" = "panther" ]; then
      echo "[wait-for-phone] panther detected as $SER — starting FULL backup"
      # backup-pixel7-full.sh takes SERIAL OUTDIR (serial-strict after the two-device
      # incident); OUTDIR alone was read as the serial and the backup silently never ran
      if ! bash "$ROOT/scripts/backup-pixel7-full.sh" "$SER" "$OUTROOT"; then
        echo "[wait-for-phone] BACKUP FAILED — FDT pull skipped; fix before any fastboot work" >&2
        exit 1
      fi
      echo "[wait-for-phone] pulling device tree"
      adb -s "$SER" pull /sys/firmware/fdt "$FDT" && file "$FDT" \
        || echo "[wait-for-phone] WARN: FDT pull failed (some ROMs restrict it; factory image is the fallback)"
      echo "[wait-for-phone] DONE: backup at $OUTROOT, FDT at $FDT"
      exit 0
    fi
  fi
  sleep 10
done
