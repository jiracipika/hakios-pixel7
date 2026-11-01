#!/usr/bin/env bash
# pull-panther-fdt.sh — pull the Pixel 7's own device tree once the phone is on USB (USB debugging on).
# Gate 1 of the port plan: tools/new-device.py reads this FDT to fill the gs201 soc.args.
# Rooted phone: tries `su -c` first (works on stock without root for /sys/firmware/fdt? — unverified);
# unrooted: plain adb pull, which usually works for /sys/firmware/fdt on Pixels [to verify].
set -uo pipefail
OUT="${1:-device/panther-fdt.dtb}"
adb wait-for-device
echo "device: $(adb shell getprop ro.product.device) ($(adb shell getprop ro.product.model))"
adb pull /sys/firmware/fdt "$OUT" && file "$OUT" && ls -la "$OUT" || {
  echo "plain pull failed — trying root:"
  adb shell su -c 'cat /sys/firmware/fdt' >"$OUT" && file "$OUT" || { echo "FAILED: no FDT; try factory-image vendor_boot extraction"; exit 1; }
}
echo "next: tools/hakios-device.py new panther ... --fdt $OUT   (or tools/new-device.py against devices/panther)"
