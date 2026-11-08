# Porting the Galaxy S9+ iOS port (danstronics/ios-s9plus-exynos) to the Pixel 7

Source being converted: `danstronics/ios-s9plus-exynos` — the Galaxy S9+ (SM-G965F, `star2lte`,
Exynos 9810) integration of the **Scion fork** of HakiOS, published 2026-11-06 and
hardware-verified: iOS 16.5 SpringBoard, touch + buttons, battery/charging indication, Broadcom
Wi-Fi (association/DHCP/DNS/SSH), GLES via Mesa/Panfrost, userland from the owner's own iPhone X
20F66 IPSW, SYSTEM installed on UFS flash, 600 s return-to-recovery timer.

Read with `docs/PORT-PLAN.md` (the original plan against upstream oosexgang) and `docs/HW-GAPS.md`
(the DTB-verified gs201 hardware map). Evidence labels: **[verified]** = from the cloned Scion
repos and our own phone runs; **[ref]** = Scion source reading; **[t-verify]** = to confirm.

## 0. Why this repo changes our plan

1. **Same fork network.** `Scion-Project/scion-kernel` is a fork of `oosexgang/hakios-xnu-kernel`
   and shares GitHub's fork network with our `jiracipika/hakios-xnu-kernel`. Same XNU
   (`xnu-8796.121.2`, Darwin 22.5), same kernel virtual base `0xFFFFFFF004000000`, same Mach-O
   kernel ABI, same boot_args contract, same boot-args registry (588 args). Our m2ld loader's
   kernel contract was written against exactly this ABI, so **our loader can boot a Scion-built
   kernel unchanged**.
2. **Samsung to Samsung.** gs201 (Tensor G2) is Samsung S.LSI silicon. Scion's only booted SoC
   layer is Exynos 9810; the Samsung family drivers (soc/exynos acpm/hsi2c/spi/m3/tee,
   display/dpu, display/panel, storage/ufs, wifi/brcmfmac + exynos_pcie, input, power, audio)
   consume one indirection header (`hakios.exynos_soc.h` picks `HAKIOS_SOC_HEADER` by
   `CONFIG_SOC`), so a port is "a filled socs/<soc>/ include header plus code only where the
   hardware differs".
3. **An in-tree gs201 stub exists** (`socs/gs201`): block matrix + register header whose numbers
   match our DTB-verified panther facts (WDT cl0 0x10060000, UFS HCI 0x14700000, DECON
   0x1C240000, DSIM 0x1C2C0000, Mali 0x28000000, APM mailbox 0x18210000 + SRAM 0x18500000, PMU
   0x18060000, GICD 0x10400000 + GICR 0x10440000). Upstream oosexgang has no gs201 layer at all.
4. **The S9+ build is the only XNU-plus-iOS-on-flash flow in the lineage**: TWRP installer with
   verified write and readback, SYSTEM-on-flash read-only root, RAM /private/var, per-device
   identity (MAC slot) supplied locally, never distributing it. Patterns we can lift for panther.

## 1. Boot-chain conversion

| Stage | S9+ (star2lte) | Pixel 7 conversion (ours) |
|---|---|---|
| Bootloader load | Samsung S-Boot reads BOOT (boot.img v1) | Google ABL: `fastboot boot` RAM-only sessions; AVB-shaped 64 MB container; entry at the stock kernel's PE entry point [verified] |
| Stage 2 | BootShim + Silicium Mu-Silicium UEFI (starlte pkg) at EL2 | **None.** No gs201 UEFI exists and none is needed: our gsloader/m2ld PE-entry chainloader (GSPE blob) already covers the BootShim+UEFI+loader role [verified executing] |
| Loader job | xnuloader (UEFI app): parses XNUP payload {loader.efi, kernel, ramdisk, cmdline}, builds Apple DT + boot_args, PSCI_CPU_ON bootcpu=2, UEFI stays resident and serves flash blocks (ufs=2) | m2ld: parses GSPE blob, maps a window, copies segments, builds Apple DT + boot_args (mtkloader port), jumps with x0 = boot_args PA |
| Kernel entry ABI | EL1, x0 = boot_args PA, MMU off at jump (Scion loader.c:583-612 clears M/C/I + `ic iallu`) | same contract; m2ld v16+ (EL1 identity regime fix in) |
| Return path | `loader_return_after` timer, resident UEFI, SWRESET with INFORM3 recovery magic to TWRP | our key-wdt / SMC 0x82000504 reset + ramoops plog; BCB boot-recovery mitigation in progress |
| iOS SYSTEM | SYSTEM partition on UFS, APFS, read-only root; /private/var in RAM | Phase 1: RAM-only (system.apfs as the GSPE `ramdisk` entry, /dev/md0, exactly upstream's `xl ramdisk` + `xl run` flow). Phase 2 (later): SYSTEM on flash via a spare partition, written with the S9+ installer's guard rails |

RAM-only first is deliberate: nothing flashed, Android untouched (dual boot preserved), and the
PE-entry vehicle is our proven silicon asset — adopting Scion's Samsung-only vehicle would discard
it.

## 2. Per-subsystem verdicts

Verdicts: **PORT** = Scion code is the base (numbers + hooks); **PORT-lite** = structure reuse,
gs201 is a different IP generation; **REFERENCE** = concepts only; **KEEP** = our existing asset;
**REJECT** = IP absent or different on gs201.

| Subsystem | Verdict | Scion asset | Conversion for gs201 |
|---|---|---|---|
| Kernel ABI + DT | KEEP (m2ld) | xnuloader devicetree.c, platforms/*.c | m2ld already has the Apple-DT builder; adopt Scion's `/chosen/dram-size` covers-all-RAM fix (PR 251) and arm-io GIC node contract |
| Display DPU | **PORT** (high value) | display/dpu/hakios.exynos_dpu.c (749 ln; DECON/DPP/VGF0 fb_dpp scaling, fb_flip/fb_zc) | gs201 registers: DECON 0x1C240000, DPP 0x1C0B0000 [verified], DSIM 0x1C2C0000. Our parked m2bars probes stalled exactly where this driver answers: TRIG_CON RMW + SHD_REG_UP_REQ shadow-update discipline |
| Display panel | PORT-lite | display/panel/hakios.s6e3ha8.c (S9 panel, command-mode DSI via DSIM0) | gs201 = S6E3FC3-P10, same Samsung command-mode DSI family; brightness recipe already panther-proven by omarchy's gs-dsim-cmd |
| UFS | **PORT** | storage/ufs/hakios.ufshc.c (4.0k ln) + hakios.ufs.c (3.7k ln) | Bases already in Scion's gs201 header (HCI 0x14700000, VS 0x14701100, UNIPRO 0x14780000, PMA 0x14704000, PMU PHY 0x18063EC8); UFS cold re-init required [ref]; S2MPU/DMA caveat (PixOS gs101) [t-verify] |
| WiFi | **PORT staged** | wifi_pcie=1..6 exynos_pcie.c (999 ln) + brcmfmac=1..8 (Linux brcmfmac via lx layer) | panther = BCM4389 over PCIe (DTBO fragment@87) — same two-stage pattern; gs201 PCIe RC numbers from panther DTBO; firmware from the phone's /vendor at run time (their loader pattern) |
| Touch | KEEP upstream | s6sy761 (Samsung I2C) | panther = Synaptics TCM on SPI; upstream redwood_tcm.c speaks TCM (FEATURES.md: TWEAK). Scion's s6sy761 is wrong IP for panther |
| Battery/charging | PORT-lite | max77705 (1.0k ln, charger dump max77705_diag=1 + gauge line) | gs201 charger = MAX77759 (Maxim 777xx family) [t-verify]; after ACPM |
| PMIC | REJECT | s2mps18_rtc | gs201 = S2MPG11 over ACPM — needs ACPM first |
| ACPM | **PORT + adapt** | soc/exynos/acpm.c (616 ln) | gs201 = Google's ACPM variant (initdata 0xA000 [ref]); mailbox/SRAM numbers already in their header |
| CPU bring-up | PORT | smp.c PSCI_CPU_ON (9810: core 1 parked by S-Boot, bootcpu=2) | gs201 PSCI method=smc [verified from DTB]; m2ld is cpus=1 now, add cores with this pattern |
| USI/I2C | PORT | soc/exynos/hsi2c.c (251 ln) | gs201 USI v2 control register at block +0xC0 [ref] |
| MFC video | REFERENCE | exynos_mfc.c (1.3k ln) | gs201 BigOcean/MFC, firmware — later |
| Audio | REJECT (now) | abox (2.2k ln) + cs47l93/max98512 | gs201 ABOX generation differs + CS35L43 amp — later campaign |
| GPU | **REJECT for bring-up order** | mali.c (G72 panfrost path) | **The S9+ GLES/Panfrost path does NOT transfer**: G72 is Bifrost (job-manager, panfrost's model); G710 is CSF (firmware-scheduled, panthor/panvk). GPU = separate later campaign |
| iOS userland | PORT the flow | sysimage/unpack.sh + userland/build.sh (iPhone X 20F66 IPSW to system.apfs) | identical upstream flow; identity per IDENTITY.md (iPhone 13 validation only) |
| Installer | PORT guard rails | TWRP update-binary: verify/readback/restore-on-fail | lift for any future flash step on panther |
| Return timer | KEEP | loader_return.c kernel timer | port into our kernel once it runs past first fault |

## 3. What the gs201 header still needs (the real porting work)

`socs/gs201/include/hakios.gs201_soc.h` has SoC/chipid/PMU, GIC, MCT, WDT cl0, APM, UFS, USB,
DECON/DSIM, Mali, MFC. Missing for the drivers to build (Scion's rule: a block without its
numbers is not built, `tools/soc-check.py`):

- `EXYNOS_UART_PA` 0x10A00000 (earlycon fact [verified]) + peric0 gating, DSIM1?, DPP
  0x1C0B0000 [verified], DPU_DMA/IDMA bases, USI, CMU gate table, GPIO banks, PCIe RC bases,
  keys GPIO, ADC, PWM, poweroff (PS_HOLD 0x18060000+0x3e9c bit8 [verified from our research]).
- Convention proposal: add source tag **O** = silicon-verified on this project's Pixel 7 (DTB
  pulls, register pokes, ramoops readouts); existing tags B (AOSP gs201 dtsi) and L (mainline
  gs101 family) stay.

## 4. Work queue (this campaign)

1. Compile gate — build the Scion tree for gs201 on this host. If green, the base is buildable
   with our host fixes (CPATH/uuid, gawk, python3 shim).
2. Header completion (section 3), then enable drivers one at a time in panther.config — Scion's
   device.conf status discipline: each flip gets a status line + recorded boot-args.
3. m2ld updates: dram-size DT fix, then point the GSPE payload at the Scion-built panther kernel.
4. Phone test via our proven loop; success signal unchanged = XNU's first fault in the URET
   record (the open puzzle is not affected by the base switch).
5. Display unpark: port exynos_dpu.c to gs201 registers — a real driver behind the m2bars probes.
6. WiFi ladder: wifi_pcie 1..6 + brcmfmac 1..8 staging on gs201 PCIe.
7. Battery (Maxim 777xx) after ACPM; GPU = separate campaign; flash-SYSTEM phase last, with the
   installer guard rails, Android untouched.

## 5. Source repo facts

- danstronics/ios-s9plus-exynos: 2 commits, Nov 6 2026; BOOT template + TWRP installer +
  assemble_boot.py; profiles/installed-gles.json carries the full working cmdline
  (`cpus=6 bootcpu=2 mali=9 mali_uv=750000 ufs=2 ufs_write=0 ufs_native_ro=1
  system_apfs=ufs_SYSTEM wifi_pcie=6 brcmfmac=8 fb_dpp=1 ...`).
- Scion-Project org (30 repos): scion-kernel (the fork, hyperactive — ~20 merges on Nov 7-8
  alone, incl. an xnu-12377/iOS-26 experiment base), scion-starlte (booted S9),
  scion-star2lte/crownlte (untested device layers), scion-installer, scion-recovery, plus
  Pixel 10 work (scion-frankel + scion-soc-lga, QEMU-only, "never run on a phone", different
  IP generation — not relevant to gs201).
- Adopted into our fork as branches `scion-main` (pure mirror) and `pixel7-scion` (work), same
  policy as upstream: mirror never force-pushed, port work on the pixel7 branch. Panther device
  repo registered in the manifest (jiracipika/hakios-gs201).
