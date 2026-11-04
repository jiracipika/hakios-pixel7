# Feature workstreams — Pixel 7 port

Working sections for the features we build **on top of** the boot-chain milestones
(M0–M3 in HW-GAPS.md). One feature is worked at a time; verdicts below decide
**tweak upstream vs rewrite** per item. Driver code lives in the `hakios-gs201`
repo on its `features` branch; this doc tracks intent and evidence.

Hardware evidence source: stock factory image `rango-bp4a.251205.006` (DTB,
dtbo overlays, vendor.img/vendor_dlkm.img strings) — noted inline as (DTB), (dtbo),
(vendor).

---

## 1. Camera (front + rear) — FIRST WORKSTREAM

### Hardware map (dtbo `lwiscamera` fragment + vendor HAL configs, all DTB-verified)

Google drives cameras through **LWIS** (Lightweight I/O Service, `lwis.ko`): every
peripheral (sensor/actuator/OIS/eeprom/flash/ToF) is a plain DT-described device
(`google,lwis-i2c-device` / `-spi-device`), and the HAL (Google **Lyric**) sequences
them. The overlay contains **register-level power sequences per camera module**
(`module_power_seq@0..4`). Board family codenames (rango = gs201 family; our unit
is panther, no tele/ToF populated):

| module | sensor codename | sensor node | i2c | extras on the same bus |
|---|---|---|---|---|
| **Front 10.8MP (3J1)** | `sensor-svarog` | sensor@1 | 0x10, LSIOE cli8 | `eeprom-smaug-svarog` @0x50 |
| **Rear main 50MP GN1-class (OIS)** | `sensor-barghest` | sensor@0 | 0x10, LSIOS cli1 | `act-nessie` @0x24, `ois-nessie` @0x24, `eeprom-nessie` @0x24, `flash-lm3644` @0x63 |
| **Rear UW 12MP** | `sensor-imentet` | sensor@3 | 0x2d, LSIOE cli13 | `eeprom-smaug-imentet-uw` @0x50 |
| (7 Pro only) Tele | `sensor-dokkaebi-tele` | sensor@4 | 0x10, LSIOS cli3 | `ois-humbaba`, `eeprom-humbaba` @0x61 |
| (7 Pro only) ToF | `tof-tarasque` | tof@0 | SPI @20MHz | — |

Vendor proof strings: `rango_rear_barghest_normal.binarypb`,
`rango_frontinner_svarog_normal.binarypb`, `rango_rear_imentet_wide.binarypb`,
`rango_rear_dokkaebi_tele.binarypb`; `3j1`/`gn1` tokens; Lyric HAL
(`vendor/google/services/LyricCameraHAL/...`); ISP pipeline software = catpipe.

Rails: `PP1050_CAM` (fixed regulator on a GPIO, enable-ramp 2000 µs) +
`slg51002@75` camera PMIC (SPI). Front camera needs **no** AF/OIS — simplest module,
so front is the first "proof of life" target, then rear main.

### Verdict: REWRITE (nothing upstream to tweak) — but Google's structure is copyable

No camera code exists in any upstream repo (HW-GAPS #11). However Google's own
kernel-side design is exactly the precedent the rest of the project follows: dumb
DT-described devices + a sequencer. We reimplement LWIS's *shape* (not its code) in
the gs201 device repo: `kernel/` gains a camera subtree driven directly by the facts
the overlay hands us (i2c addresses, rail names, GPIO resets, power-seq steps).

### Plan (front first, then rear; one milestone at a time)

| step | deliverable | needs |
|---|---|---|
| CM0 | pin the active overlay variant (`ro.boot.dtbo_idx` on the phone) → which sensor set panther instantiates | phone on adb |
| CM1 | gs201 I2C controller bring-up (LSIOE/LSIOS `cli*`) + `PP1050_CAM`/SLG51002 rail control | M0/M1 loader running XNU on hardware |
| CM2 | power-seq interpreter: execute `module_power_seq@1` (svarog, front) then `@0`/`@2` (barghest) — the overlay spells out every rail/GPIO/delay step | CM1 |
| CM3 | sensor probe over I2C: read 3J1 + GN1 IDs (front first — fixed focus, no OIS dance) | CM2 |
| CM4 | CSI-2 RX (CD-PHY @0x3c0000/0x3e0000 + CSIS) dump one raw frame from the front sensor to memory, hex/PGM out | CM3 + GIC/SMMU work |
| CM5 | rear main frame (OIS reset needed for lens) → then ispfe/ispbe minimal path or userspace raw | CM4 |

Status: **evidence complete; code scaffold on `features` branch** (`camera/` in
hakios-gs201). Blocked by M0/M1 (needs XNU running on hardware first).

---

## 2. Bluetooth

- Hardware (dtbo fragment@103 + vendor_dlkm): **Broadcom combo BT over UART**,
  Google's `goog,nitrous` driver shape (host/device-wakeup, timesync, shutdown,
  DBO GPIOs); modules `btbcm.ko`, `bluetooth.ko`; firmware = `.hcd` in vendor
  (btbcm loads it over the tty).
- Upstream: **none** (mt6768 doc covers only connsys/MediaTek). Verdict: REWRITE —
  but it's a small, standard H4/BSCP UART driver + a firmware blob loader.
- Approach: gs201 UART controller driver first (shared with console work, M3), then
  nitrous-style GPIO sequencing, then BCM init over H4.
- Status: blocked by UART (M3). After WiFi it becomes the quick win.

## 3. Touch

- Hardware (dtbo fragments@243/244): two variants exist per board — `st,fst2`
  and **`synaptics,tcm-spi`** (TouchComm over SPI). Which one panther instantiates
  is overlay-variant-dependent → resolve at CM0.
- Upstream: **`redwood_tcm.c` + `tcm.h` in hakios-mt6768 speak Synaptics TCM over
  SPI already** (their touch screen is a TCM device). Verdict: **TWEAK** — the TCM
  protocol layer should port nearly as-is if panther's touch is the synaptics
  variant; only the gs201 SPI controller + pinmux underneath differ. The `st,fst2`
  variant would be a rewrite of the protocol half.
- Status: resolve variant first; if TCM → port of upstream's driver is the
  cheapest win of this whole list.

## 4. Sensors (accel/gyro/etc.)

- Hardware: AOC (Always-On DSP) hosts the sensor hub; sensors hang off AOC
  mailboxes (upstream mt6768 did the same pattern via their SCP:
  `redwood_scp.c`, `docs/sensors-x6826b.md`, `CONFIG_SCP_STEP`).
- Upstream: SCP sensor pattern **transfers structurally** (mailbox + step machine),
  protocol differs. Verdict: TWEAK-the-architecture, REWRITE-the-protocol.
- Status: after storage (M4) — sensors are polish, not capability.

## 5. Audio

- Hardware: AOC DSP (`aoc@9000000` + `aoc@8d200000`), Cirrus **cs35l43** smart
  amps ×2, cs40l27b haptics, `sound-aoc` DAI graph (dtbo fragments@256/100).
- Upstream: none. Verdict: REWRITE, large (DSP firmware handoff + DAI graph).
  Deliberately last capability-class item; even then start with speaker playback
  only (no capture, no voice path).
- Status: not started.

## 6. USB

- Hardware (DTB): `google,dwc3-lga` glue + **standard `snps,dwc3`** @0xc400000,
  HSIO PHYs, role switch (`google,usb-role-sw`). The most standard IP on the board.
- Upstream: no host/device stack on their phones (they run fastboot/mtkloader
  consoles). XNU has no DWC3 driver. Verdict: REWRITE (port of a known-simple
  design; DWC3 docs/compat are excellent).
- Approach: device-mode first (gadget console = debuggable path before WiFi),
  host later for hubs/storage. Shared with M3.
- Status: planned M3.

## 7. Storage (UFS)

- Hardware (DTB): `ufs@3c400000`, `compatible = "google,ufshc"` (UFS 3.1, with
  UFS-HPB-style extensions implied by vendor modules).
- Upstream: mt6768 wrote **eMMC** (`redwood_emmc.c` — much simpler protocol);
  redwood storage comes free from UEFI BlockIO. Verdict: REWRITE (UFSHCI/UFShcd
  driver) — no transferable code, but the driver shape (transfer requests, doorbell
  rings, descriptors) is textbook.
- Approach: bootconfig/ramdisk sessions don't need it; becomes M4 (real root).
- Status: planned M4.

---

## Working rules for this branch

- One workstream at a time; camera is open now.
- Every driver file carries its DTB evidence in a header comment (node, i2c, rails)
  so nothing is guessed.
- No GPL code is copied from vendor kernels or Android — facts (addresses,
  sequences) from DTBO/vendor are fine; code is ours.
- Milestones land in `hakios-gs201` `features` branch; merged to its `main` only
  when they boot through the M0/M1 loader.
