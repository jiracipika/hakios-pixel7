# Pixel 7 hardware gaps vs upstream's implementation

Analysis 2026-11-04. Hardware facts are **DTB-verified** against the stock kernel
device tree we extracted (`forks/.../devices/panther/dtb/panther-lga-base.dtb`,
decompiled; 605 top-level nodes). Upstream facts verified from `hakios-mt6768` @
b60346c and `hakios-sm7325` @ af52dfb trees + their docs. Items marked *(inferred)*
come from public gs201 documentation and still need the phone or kernel sources to
confirm.

## How upstream supports a device (the model to follow)

- **Qualcomm path (redwood/SM7325)**: no kernel device drivers in the device repo at
  all — Silicium UEFI brings up hardware; XNU rides on it. Not available to us
  (no Tensor UEFI exists).
- **Non-Qualcomm path (x6826b/MT6768 — the precedent for us)**: real XNU drivers
  written in the device repo under `kernel/bsd/dev/` + `kernel/iokit/Kernel/`
  (`redwood_connsys.c` WiFi/BT, `redwood_emmc.c` storage, `redwood_mali.c` +
  `RedwoodMali.cpp` GPU, `redwood_tcm.c` touch, `redwood_scp.c` coprocessor,
  `redwood_mtkkeys.c` keys), enabled by config symbols from the SoC fragment
  (`CONFIG_MALI`, `CONFIG_HAKIOS_TCM`, `CONFIG_SCP_STEP`…), loaded by their own
  boot-image chainloader (`mtkloader` ≈ our `gsloader`). Device defconfig =
  `common_defconfig` + `mt6768.config` (SoC) + `x6826b.config` (device).
- **The common kernel already defines the upper halves**: a framebuffer/display
  path (fb_* config symbols), a radio stack with a clean driver contract, a network
  frame layer, Metal's Metal-on-X stack. A new device writes the *lower halves*.

### The radio contract (from `docs/wifi-x6826b.md`, translated)

The common kernel ships: `redwood_apple80211.c` (Apple80211 service: scan/networks/
connect), `redwood_sta.c` (one serialized worker thread + scan cache + join-at-boot),
`redwood_net.h` (XNU network interface frames), `wifi/lx/src/lx_wpa.c` (WPA2
handshake, desktop-tested). A new radio only implements:

```c
struct redwood_sta_ops {
    int  (*power)(bool on);
    int  (*scan)(const struct redwood_sta_scan *what);
    void (*heard)(void (*each)(const struct redwood_sta_bss *, void *), void *);
    int  (*join)(const struct redwood_sta_join *what);   /* open or WPA2-PSK */
    int  (*leave)(void);
    void (*state)(struct redwood_sta_state *state);      /* callable asleep */
};
redwood_sta_attach(&ops); redwood_sta_lost(err);
struct redwood_net_link { bool (*transmit)(mbuf_t, size_t); unsigned (*poll)(void); ... };
redwood_net_attach(&link); redwood_net_input(frame, len); redwood_net_link_state(up);
```

The Qualcomm lower half (ath11k over FreeBSD LinuxKPI) **does not transfer** — wrong
radio, as upstream themselves note. MediaTek gen4m also doesn't. Ours is Broadcom.

## Per-subsystem gap table (Pixel 7 / gs201)

| # | Subsystem | DTB-verified hardware | Upstream precedent | Gap | Priority |
|---|---|---|---|---|---|
| 0 | Chainloader | boot.img v4/1584 + lz4-legacy + 64MB AVB-shaped image (decoded, see STOCK-BOOT.md); DTB from `vendor_kernel_boot` @ 0x11f00000 | mtkloader (their chainloader, same idea) | small — gsloader v0 done, header mirror built, phone test pending | **P0 — heartbeat first** |
| 1 | Display | `sswrp_dpu@ec00000` (Exynos DPU, 21 SMMU layers), 2× `verisilicon,dc9x00-mipi-dsi2h` DSI hosts + Synopsys `dw-mipi-cdphy` @0x3c0000/0x3e0000, `google,panel-gs-simple` nodes, panel driver via dtbo overlay *(inferred: Samsung S6E3HC3-class LTPO panel)* | common fb path + mt6768's DSI/panel bring-up; MiniIOMobileFramebuffer on redwood | **gs201 DPU driver** (Exynos register family + panel init sequences from overlay) — big but self-contained; alternative early trick: leave ABL scanout untouched and paint into its framebuffer *(inferred, verify on phone)* | **P1 — first visible milestone** |
| 2 | GPU | Mali-G710 (live tree `mali@28000000`; node added by dtbo overlay) — Valhall v10, **CSF** (command-stream frontend), 7 MP | hakios-metal = Adreno a6xx/PM4/ir3 only; Mesa AIR frontend compiles to ir3 (Adreno). mt6768's G52 is Bifrost (job-manager) — closest code but older interface | **Valhall CSF driver**: kernel queue/KCMS work + shader path. Mesa has panfrost Valhall (v9/v10 partial) as the NIR compiler source. Largest single work item; Metal-on-Mali G710 is the project's endgame | **P2 — after display** |
| 3 | WiFi | **BCM4389** (Wi-Fi 6e, full-MAC firmware), on PCIe: `pcie@3c500000` (max-link-speed 4, MSI) — *(inferred: pcie1 0x3c500000 carries WLAN; pcie0 0xc500000 for other EP)*; AOC wake lines `wlan2aoc_*` | radio contract above (upper half works for any radio); Qualcomm lower half unusable | `gs201 sta` driver: PCIe EP bring-up (google,lga-pcie registers documented in DTB) + Broadcom DHD-protocol channel to full-MAC firmware + `redwood_sta_ops` impl. Firmware lives in vendor_dlkm (`fw_bcm4389*` *(inferred)*). No GPL code copied — reimplement the protocol like upstream's clean-room approach | **P3 — first "phone-like" capability** |
| 4 | Bluetooth | BCM4389 combo BT5.2 on **UART** (pins `aoc_ap2bt_uart_fc/sda`) + AOC sideband | none upstream (connsys doc covers MTK) | H4/BSCP UART driver + BCM firmware loader (`.hcd` from vendor_dlkm *(inferred)*) — small, standard | P3.5 |
| 5 | Storage | UFS: `ufs@3c400000` compatible `google,ufshc` | mt6768 wrote eMMC (simpler); redwood storage via UEFI BlockIO | **gs201 UFSHCI driver** (UFS 3.1) in XNU (and later in gsloader for ramdisk alternatives). Start ramdisk-only: no storage needed for heartbeat/payload boots | P3 (real root FS) |
| 6 | USB | `google,dwc3-lga` + standard `snps,dwc3@c400000`, HSIO PHYs | none needed on their devices (UEFI/mikloader console) | DWC3 is the best-documented IP on the board; host/device mode for a console or future ADB-ish link | P4 |
| 7 | Touch | not in base tree — dtbo overlay adds it *(inferred: Goodix GTI over SPI, Pixel 7 family)* | `redwood_tcm.c` (their TCM-over-SPI driver) — pattern + structure reusable, protocol different | overlay driver: SPI + GTI protocol, feed common input path | P4 (fastboot-only sessions don't need it) |
| 8 | Buttons/power | not in base tree (overlay) | `redwood_mtkkeys.c` pattern | tiny GPIO-key driver | P4 |
| 9 | Sensors | AOC-connected sensor hub *(inferred; upstream did SCP sensors on mt6768 — see their sensors doc)* | `redwood_scp.c` + sensors doc pattern | AOC mailbox + sensor protocol | P5 |
| 10 | Audio | AOC DSP (`aoc@9000000`, `aoc@8d200000`), Cirrus `cs35l41` speaker amps, `sound-aoc` dai graph | none | AOC audio path — large; skip until everything else works | P6 |
| 11 | Camera | ISP DVFS domains `ispfe`/`ispbe`, Synopsys MIPI CD-PHY camera instances, GMS10-class ISP *(inferred)*; sensors power rails in DTB | **none anywhere upstream** (no camera driver in any repo) | full stack: ISP driver + sensor drivers + userspace HAL — biggest possible item, no precedent to build on | **P7 — last, possibly never** |
| 12 | Modem | Exynos S5400 (`XGDMC_UART_MODEM` pins, mfw/sswrp firewall nodes) | none (redwood has cellular_probe tools only) | never planned | skip |
| 13 | Security | Titan M2 (GSC) (`XGDMC_UART_GSC`) | none | skip | skip |

## Cross-cutting risk: power/clock domains

Every gs201 driver above sits behind Google's ACPM/CMGP clock-power machinery (DTB is
full of `*_freq` DVFS nodes with `dvfs-helper-domain-name`; regulators and power
domains interconnect everything). mt6768's notes make the same point for MTK
("higher GPU clock raises VGPU further: not without the owner's yes"). Mitigation:
the live DTB + ABL fixups give us boot-time-correct clock states — first bring-up
should keep clocks where ABL left them and *never* gate anything (same approach
mtkloader used), adding ACPM calls only when a driver needs a rate change.

## Recommended order (maps to milestones)

1. **M0 (now)**: gsloader heartbeat on the phone (images built and verified against
   stock shape; needs the phone plugged in).
2. **M1**: gsloader hands XNU the real DTB from x0 with payload behind loader → XNU
   registers drivers, panics at initproc as designed (headless proof on hardware).
3. **M2**: display — DPU driver (or ABL-scanout reuse trick) → first visible output.
4. **M3**: UART0 console (0x10A00000, exynos4210-compatible) for debug; USB DWC3 for
   a proper link.
5. **M4**: UFS driver → real root; storage-backed sessions instead of RAM-only.
6. **M5**: WiFi over the radio contract → first connected HakiOS phone on Tensor.
7. **M6+**: touch, BT, sensors, audio. Camera remains a research item.

## What this means in repo terms

- `hakios-gs201` gains `kernel/` (gs201 bsd/dev + iokit drivers), `soc/gs201.config`
  (SoC fragment with config symbols), `configs/panther.config` (device fragment),
  following the mt6768 layout exactly.
- The common kernel needs a `gs201.config` fragment only if gs201-specific symbols
  live there (mirror of upstream's `mt/mt6768/configs/mt6768.config`) — decide when
  the first driver symbol exists.
- gsloader already parses the DTB (memory, /psci) — it will be extended for the
  display-handoff experiment in M2 and storage in M4 if needed.
