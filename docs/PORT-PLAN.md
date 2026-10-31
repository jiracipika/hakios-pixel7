# Pixel 7 (panther) port of HakiOS — plan

Target: Google Pixel 7, codename **panther**, SoC **Tensor G2 (`gs201`)**.
Goal: HakiOS (Apple's open-source XNU, `xnu-8796.121.2`) booting on the phone with the same
session-in-RAM model upstream uses, then drivers one at a time, then Metal on the GPU.

Evidence labels: **[upstream]** = read from upstream source/docs on 2026-10-31;
**[ref]** = reference device facts from `hakios-sm7325` / `hakios-mt6768`;
**[t-verify]** = from general knowledge, must be confirmed against the phone / factory image before building on it.

## 0. What upstream is, as of 2026-10-31 [upstream]

| Repo | What | State |
|---|---|---|
| `oosexgang/hakios-xnu-kernel` | common tree: XNU port, drivers, loader (`xl/`), userland, tools, QEMU device | v0.1.0 (2026-10-22), pushed daily, 2030★ |
| `oosexgang/hakios-sm7325` | reference device repo: POCO X5 Pro 5G (`redwood`), SoC layer `sc7280` (Qualcomm) | the fully working device; UEFI path |
| `oosexgang/hakios-mt6768` | Infinix Hot 20 (`x6826b`), MediaTek MT6768, **Mali-G52 works: kernel mali driver + Mesa panfrost + Metal driver, CoreAnimation draws through Metal** | the non-Qualcomm, non-UEFI precedent; `mtk` branch in the common tree |
| `oosexgang/hakios-uefi` | Mu-Silicium (Project Silicium) + HakiOS boot path + HakiOS U-Boot | Qualcomm-only platforms |
| `oosexgang/hakios-metal` | Metal command model on **Adreno** (7c+ Gen 3, `0x06030500`): Mesa a6xx registers, PM4, ir3, msm DRM, turnip-derived render path | Adreno-only by construction |
| `hackios-web` | the guide ("Adapt it to your device", QEMU, Metal) | site: hackios-web.vercel.app/en/guide |

Boot model [upstream]: the loader goes into RAM via `fastboot boot`; the system lives in RAM for a
session; a reboot returns the phone to Android. The only default write is a few KB of loader log to
`logdump`; `ufs_write=1` allows writes to a user-created `darwin` partition only.

Official porting procedure [upstream]: `docs/porting/index.md` in the kernel tree — scaffold with
`tools/hakios-device.py new <name> --soc <soc> --fdt <dtb>`, first boot with no phone drivers, then
drivers in this order: CPUFREQ/THERMAL/SOCINFO → BUTTONS → touch → UFS → GPU → ADSP/audio/battery →
WIFI → haptic/camera/torch/modem/BT. Each step has a "done when" gate. Status recorded in
`device.conf` (`works`/`partial`/`missing`), then published by PR to `devices/manifest.conf`.

## 1. Target hardware facts

| Part | Pixel 7 (panther) | Notes |
|---|---|---|
| SoC | Tensor G2, `gs201` [t-verify] | Samsung Exynos-derived; 2×X1 + 2×A78 + 4×A55, GICv3 [t-verify] |
| GPU | **Mali-G710 MP7, Valhall v10 (CSF command stream)** [t-verify] | NOT Adreno — the central conversion problem; Mesa `panvk`/`panfrost` v10 is the equivalent codebase to upstream's a6xx/ir3 stack [t-verify] |
| Storage | UFS 3.1 [t-verify] | controller is the Exynos/Tensor one, not Qualcomm's — the sm7325 UFS driver will not fit as-is |
| Wi-Fi/BT | Broadcom BCM4389 (Cypress fw) [t-verify] | upstream uses `ath11k` for WCN6750 [ref] — different driver family |
| Modem | Exynos 5300 [t-verify] | upstream's cellular is Qualcomm IPA/QMI [ref] — rewrite, deprioritize |
| Display | 6.3" OLED, 90 Hz [t-verify] | Tensor DPU/DSI, not Qualcomm MDSS |
| Bootloader | unlockable (`fastboot flashing unlock`), `fastboot boot` supported [t-verify] | same RAM-session flow upstream relies on [upstream] |
| Kernel in Android | 5.10 GKI [t-verify] | DTB in `vendor_boot`/`dtbo` of factory image [t-verify] |

## 2. Conversion surface, layer by layer

### 2.1 Common kernel (`forks/hakios-xnu-kernel`)
Mostly stays. We add, on a `pixel7` branch:
- `socs/gs201/` — new SoC layer (upstream knows `sc7280`; `--soc gs201` scaffolds a blank one [upstream]).
  Must answer: CPU bringup (8 cores, bootcpu, cpufreq), interrupt controller, timer, memory map from
  the panther DTB, storage hooks, the `soc_*` args the common tree reads. Note: the tool's `soc.args`
  keys are Qualcomm-shaped (modem blocks, IPA, mailboxes) [upstream] — gs201 fills what applies and
  leaves the rest empty, like mt6768 did [ref].
- Nothing in the XNU core itself is expected to change; mt6768 proved the common tree carries a
  non-Qualcomm SoC without core edits [ref].

### 2.2 Device repo (`hakios-gs201`, later published)
Follow the `hakios-sm7325` layout [ref]: `device.conf`, `configs/panther_defconfig` +
`configs/panther.config`, `prebuilt/` (device-tree.dtb, BootShim/loader payload, mkbootimg),
`pull-firmware.sh` (GPU/wifi/touch firmware from the phone), `tools/` probes, `docs/` run notes.

### 2.3 Boot path — decision needed, options in order of preference
- **B (recommended for v1): chainloader in `boot.img`, mt6768-style.** `mtkloader` sits in the boot
  image in front of Android's kernel and starts XNU once [ref]. On Pixel 7: `fastboot boot` a
  panther boot image carrying our loader (no flashing at all in the first phase). We write a
  `gsloader` modeled on `mtk/loader/` (common tree, branch `mtk`) [upstream][ref].
- A: UEFI. Project Silicium is Qualcomm-only; no Tensor platform exists. From-scratch platform +
  proprietary driver binaries (display/UFS). High cost; revisit after B boots, possibly via the
  HakiOS U-Boot in `hakios-uefi/u-boot/` [upstream].
- The loader's job list for gs201: MMU/memory map, UFS (or ramdisk-only first boot), build XNU's
  device tree and boot args, framebuffer if cheap, log capture.

### 2.4 GPU — the big one
- Kernel side [ref]: mt6768 has `hakios.mali.c`/`hakios.mali.cpp` bringing up Mali-G52. G710 is
  Valhall v10 with CSF — the kernel driver's submission model must move to CSF queues; expect a
  substantive rewrite, not a port, but the G52 driver defines the interfaces (how the kernel driver
  answers the common tree's GPU requests, how firmware loads).
- Mesa side [t-verify]: panvk v10 (G610-class) is the nearest upstream-Mesa relative; panfrost v10
  support is the one mt6768 uses at G52 (Bifrost).
- Metal side: `hakios-metal` is deliberately a6xx/PM4/ir3 [upstream]. The mt6768 Metal driver shows
  the org's pattern for Mali [ref]. Conversion = reimplement the command model on CSF/Mali
  descriptors, keep the Metal-facing C API (`hakios_metal.h`) unchanged so userland does not change.
- GPU firmware: Mali needs no userspace-signed firmware blob like Adreno (CSF firmware `mali_csffw`
  is shipped in the Android image) [t-verify] — pull via `pull-firmware.sh`.

### 2.5 Driver order for panther (adapted from the upstream table [upstream])
| Upstream order | panther equivalent | Expectation |
|---|---|---|
| CPUFREQ, THERMAL, SOCINFO | gs201 cpufreq (CPULIB?/ACPM), thermal (TMU), SOCINFO | SoC-layer work [t-verify] |
| BUTTONS | power/vol via PMIC | straightforward |
| touch | Pixel 7 touch controller (Google touch / ftm?) [t-verify] | needs controller ID from phone |
| UFS | Tensor UFS (Exynos controller) | new driver work; v1 can stay ramdisk-only |
| GPU (ADRENO→**MALI**) | G710 CSF bring-up | section 2.4 |
| ADSP, battery, sound, mic | Tensor AOC (audio offload DSP) [t-verify] | nontrivial |
| WIFI | BCM4389/brcmfmac family [t-verify] | new driver family vs upstream's ath11k |
| modem/BT/camera/haptic | later | cellular is a rewrite; last |

## 3. Sequencing with done-gates

0. **Baseline sanity** — build the common kernel from our fork; `make qemu-open` boots. Done when:
   QEMU session reaches launchd [upstream quick start].
1. **Facts** — extract panther DTB from a factory image (`vendor_boot`/`dtbo`), pull the stock boot
   image, record hardware IDs (touch controller, UFS host controller, panel) from Android via adb
   (root not strictly needed for `/sys/firmware/fdt`? confirm) [t-verify].
2. **Device repo scaffold** — `tools/hakios-device.py new panther --soc gs201 --title "Pixel 7"
   --vendor Google --maintainer <us> --repo --fdt device-tree.dtb`. Done when:
   `tools/hakios-device.py check panther` passes [upstream].
3. **First boot, nothing of the phone's** — `gsloader` v0 (or reuse `mtk/loader` structure), kernel
   with only SoC-fragment + QEMU drivers. Done when: logs show loader banner, `kernel.ver=`,
   `hakios-kernel: N drivers built in`, launchd, and the phone returns to Android [upstream gate].
4. **Drivers one at a time** per §2.5, each with its device.conf status line written honestly.
5. **GPU** — kernel mali driver v10/CSF, then Mesa, then the Metal retarget, probes first
   (`gpu-probe` pattern from mt6768 [ref]).
6. **Publish** — split `hakios-gs201` into its own repo, PR the block into upstream's
   `devices/manifest.conf` [upstream].

## 4. Risks (ruthless list)

1. **Mali-G710 CSF** is a generation newer than anything upstream has working (G52 is Bifrost).
   The kernel-side driver is a rewrite; timeline risk is the project's single biggest unknown.
2. **No Tensor UEFI** — mitigated by the chainload path (§2.3 B); do not sink time into Silicium
   for Tensor.
3. **Broadcom Wi-Fi** is a whole different driver family than what upstream ships.
4. **Upstream moves fast** (kernel pushed the day we started; daily commits). Mitigated by the
   5-day sync (`docs/UPSTREAM-SYNC.md`) and by keeping fork `main` a pure upstream mirror.
5. **The official tooling assumes Qualcomm** (`soc.args` keys, docs wording) [upstream] — small
   tool patches may be needed; upstream them as PRs where they are generic.
6. **GKI/DTB extraction details** on Pixels are [t-verify] until §3.1 is done.

## 5. Repository and sync policy

- Forks (`jiracipika/hakios-{xnu-kernel,metal,uefi}`) are submodules here.
- Fork `main` = pure upstream mirror (fast-forward only, enforced by `scripts/sync-upstream.sh`).
  **All port work happens on `pixel7` branches** — never commit to fork `main`.
- Sync cadence: every 5 days, automated (plus on-demand: `scripts/sync-upstream.sh`). See
  `docs/UPSTREAM-SYNC.md`.
- Upstream device-repo revisions are pinned like upstream pins its manifest: `revision` lines in the
  sync log.
