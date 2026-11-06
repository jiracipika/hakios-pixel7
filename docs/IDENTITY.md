# iPhone identity for the Pixel 7 — how it works, and the iPhone 13 plan

2026-11-05. Upstream (kernel 2631f5d) ships a complete identity system; this doc
maps it to the user's idea: "use an iPhone 13 to spoof details — not the IMEI,
just device model and iOS version like we spoof on Android."

## How upstream does identity (verified from the tree)

- **`xnuloader/mkidentity.sh [DeviceTree.<board>.im4p | your.ipsw]`** builds
  `xnuloader/identity.h` — the identity table the kernel/loader presents to Darwin
  userland. Source: the **device tree from the user's own IPSW**
  (`Firmware/all_flash/DeviceTree.d22ap.im4p` — iPhone X, matching their 16.5
  userland). `--placeholder` builds an Apple-free identity for QEMU.
- `xnuloader/mkidentity.py` emits exactly what MobileGestalt reads: root node
  `model` + `compatible`, `/product` (screen class, artwork scale, product name),
  `/product/haptics`, `/product/camera`. **iBoot's syscfg values (serial number,
  etc.) stay placeholders** — no real device's identifiers are used. There is no
  IMEI anywhere in a device tree (IMEI lives in baseband NVRAM) — this system
  cannot and does not touch it.
- The userland itself comes from `sysimage/unpack.sh`, hard-pinned to the iPhone X
  16.5 (20F66) IPSW (`select-system.py` is made for that one build). We do NOT
  swap that — their tested userland stays.

## The iPhone 13 plan (user owns an iPhone 13)

**Identity overlay, same-Darwin:** iPhone 13 = `iPhone14,5`, board `d17ap`, and
iOS **16.5 build 20F66** exists for it — the exact build of upstream's userland.
So: extract `DeviceTree.d17ap.im4p` from the iPhone 13 IPSW (public Apple CDN,
6.73 GB, sha256 `6415b86f…05c8f`, downloaded to `/mnt/hdd2/stock/`), then:

```bash
python3 sysimage/ipsw-member.py  /mnt/hdd2/stock/iPhone14,5_16.5_20F66_Restore.ipsw \
       Firmware/all_flash/DeviceTree.d17ap.im4p  sysimage/DeviceTree.d17ap.im4p
xnuloader/mkidentity.sh sysimage/DeviceTree.d17ap.im4p     # -> xnuloader/identity.h
```

After that the Pixel 7 presents: model `iPhone14,5`, compatible `apple,d17ap` /
`iPhone14,5`, A15 chip class, iPhone 13 screen class/artwork scale, haptics and
camera descriptors — with serial/EID/ECID fields as placeholders, exactly as
upstream keeps them.

### Why iPhone 13 is a better mask than the default iPhone X for us

| aspect | iPhone X (upstream default) | iPhone 13 | Pixel 7 |
|---|---|---|---|
| screen | 1125×2436 @3x (375×812pt) | 1170×2532 @3x (390×844pt) | 1080×2400, 20:9 |
| chip class | A12 (2018) | A15 (2021) | Tensor G2 (2021) |
| iOS 16.5 | ✓ (userland source) | ✓ same build 20F66 | — |
| haptics/camera nodes | X-class | dual-cam + newer haptics | (our camera workstream) |

Geometry mismatch is handled separately and independently:
`MiniIOMobileFramebuffer` boot-args (`fbwidth/fbheight/fbscale`, `fbsubtype=N`
since upstream 09cf881) let the kernel report the panel it actually drives while
identity.h carries the iPhone-13 class. Identity and framebuffer are decoupled by
design.

### What the physical iPhone 13 is for

Validation only, of the values the IPSW tree already gives us — Settings →
General → About on the phone (Model `iPhone14,5`, iOS version) and, if wanted, a
Finder backup's `SystemVersion.plist`. **Never** the IMEI, serial, MEID, or any
radio identifier — those don't exist in the device tree and stay placeholders.

## Rules (matching upstream's legal posture)

- We download Apple's public IPSW ourselves to our own disk; upstream's scripts
  download nothing, ours only fetch Apple's CDN file directly.
- No Apple file is committed to any repo. `identity.h` is generated at build time;
  the repo keeps nothing of Apple's (our repos record only the facts above).
- The IPSW's device tree is data we read; all code is ours/upstream's.

## Status

- [x] IPSW 16.5 20F66 for iPhone14,5 downloaded + sha256-verified
      (`/mnt/hdd2/stock/iPhone14,5_16.5_20F66_Restore.ipsw`, 6 729 344 333 B,
      `6415b86f…05c8f`)
- [x] `DeviceTree.d17ap.im4p` extracted (49 135 B, kept at `/mnt/hdd2/stock/` for
      instant regeneration)
- [x] **identity.h generated from the iPhone 13 tree** (2026-11-05): decoded tree
      239 436 B; root now carries `model=iPhone14,5`, `compatible=D17AP/iPhone14,5`,
      `target-sub-type=D17AP`, `device_type=bootrom`; product/haptics/camera tables
      built (74 root properties; pearl-camera, camera-hdr-version present).
      IMEI/serial: zero fields — syscfg stays placeholder as upstream designed.
      lzfse (BSD) auto-built into `xnu-deps/host/bin` by mkidentity.sh.
- [x] identity.h confirmed gitignored (upstream contract: generated, never committed;
      no Apple data can enter any repo)
- [ ] Boot with iPhone 13 identity once M1 (XNU on hardware) is live — MobileGestalt
      queries answered as iPhone14,5 in the boot log
- [ ] Optional: field-table diff vs the iPhone X identity (d22ap) for the docs
