# Stock boot path decode — Pixel 7 (rango BP4A.251205.006)

Decoded 2026-11-04 from the factory image (SHA-256
`e042c4f0…d8a95`, 9.29 GB, downloaded from `dl.google.com` once the hash-qualified
URL was known — the developers.google.com table was rendered via browser automation).
Factory zip → `image-rango-*.zip` → `boot.img` / `vendor_boot.img` /
`vendor_kernel_boot.img` / `dtbo.img` / `vbmeta.img` + the ABL itself
(`bootloader-rango-deepspace-16.4-14373…` — FBPK container, holds only ABL's own
`google,acfw` firmware tree, NOT the kernel DTB).

## The three reasons our first `fastboot boot` attempt was refused

1. **Wrong v4 header size.** Stock uses header v4 with `header_size=1584`
   (v3's 1580 + trailing `recovery_ds_size`), we wrote 1580.
2. **Wrong kernel compression.** Stock kernel blob is an **lz4 LEGACY stream**
   (magic `0x184c2102`, 8MB-block default). We sent raw and gzip.
3. **Bare image vs partition image.** What `fastboot boot` carries is shaped like the
   full 64MB boot partition image (header page + kernel + AVB0 vbmeta + AVBf footer).
   ABL has always been fed Magisk-style patched *partition images* on Pixels.

## Fix: three variants built (gsloader repo, `gsloader/`)

| file | shape |
|---|--- lz4 |
| `panther-boot.img` | v4/1584 + lz4-legacy gsloader (primary) |
| `panther-boot-raw-v4.img` | v4/1584 + raw gsloader (bisect: compression variable) |
| `panther-boot-avb.img` | real stock 64MB image, header+kernel region patched to gsloader, stock vbmeta+footer kept (Magisk shape) |

All three carry the QEMU-proven gsloader v0 (SMC heartbeat reset). Any of them running
on the phone = the phone **reboots itself within seconds** (PSCI SYSTEM_RESET with our
progress code — ABL ran our loader). Phone not attached at build time; test on next
plug-in.

## M0 RESULT (2026-11-06, 02:00 — phone 36071FDH20009D, slot b, unlocked): **GREEN**

Ran all three variants via `scripts/phone-test-loop.sh` (headless loop; each run
self-recovered the phone):

| variant | result |
|---|---|
| `panther-boot.img` (v4/1584 + lz4-legacy, bare) | **NO-JUMP** — ABL refuses a bare header+kernel |
| `panther-boot-raw-v4.img` (v4 + raw kernel, bare) | **NO-JUMP** — compression is not the discriminator |
| `panther-boot-avb.img` (full 64MB stock image, kernel region patched, stock vbmeta+footer kept) | **HEARTBEAT** — phone self-rebooted to Android (~104 s round trip incl. full boot); uptime after = fresh |

**Conclusion: `fastboot boot` on Pixel demands the complete partition-image shape —
header + kernel + AVB0 vbmeta + AVBf footer at stock offsets (the Magisk-patch shape).
Header version and kernel compression were never the blocker.** The AVB variant is now
the primary M1 vehicle (`mkboot-gs201.sh <stock boot.img>` builds it).

Live-tree facts captured the same session (CM0 for the camera workstream): **3 sensors
instantiated (`sensor@0/1/2` = front/main/UW; numbering pinned empirically at CM3 via
i2c addr)**, `dtbo_idx=22`, hw rev MP1.0, sku GVU6C, **4 memory banks live:
0x80000000, 0x880000000, 0x900000000, 0x980000000** (gsloader's parser consumes these
directly). Wireless adb backup link enabled: 10.0.0.22:5555 alongside USB.

## Where the real kernel DTB lives (bonus find)

`vendor_kernel_boot` (Tensor-specific partition, dtb_loadaddr 0x11f00000) — two
concatenated DTBs, extracted to
`forks/hakios-xnu-kernel/devices/panther/dtb/` (FACTS.md there has the full fact
table: psci **smc**, GIC v3 @ 0x5880000, kernel_la 0x10007200-style facts...).
The ABL's own tree is `google,acfw` firewall config — not what the kernel gets.
Live-tree nodes (`mali@28000000`, `memory@ 0x880000000`) come from dtbo overlays +
ABL runtime fixups.

## Rebuild commands (from gsloader dir)

```bash
./build.sh                                    # gsloader.bin (theos clang, aarch64-none-elf)
./mkboot-gs201.sh /mnt/hdd2/stock/extract/rango-bp4a.251205.006/boot.img
```

A working lz4 CLI (legacy format) lives at `~/.local/bin/lz4` (built v1.10.0 from
source — system liblz4 is present but its frame API is broken via ctypes).
