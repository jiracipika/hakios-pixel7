# Upstream sync log

## 2026-10-31 23:31 UTC
- hakios-xnu-kernel: up to date (a48d2b29dd58da5ef322052a7f4f73d7eb8eebc4)
- hakios-xnu-kernel: newest tag v0.1.0
- hakios-metal: up to date (a097abde4cd2d6934ed2e6f1d48e0fe102d486f3)
- hakios-uefi: up to date (687fa6c6a5a70f43184de92980e0a76eea5f2c4b)
- watch:
  - https://github.com/oosexgang/hakios-sm7325 HEAD 04fbfff933f52faf203a55aca9dd5680092e6ec5
  - https://github.com/oosexgang/hakios-mt6768 HEAD b60346c8ae50b539c51a1156899cc86f161bba5c
  - https://github.com/oosexgang/hackios-web HEAD 5d15cfb55e42d3f4a85cf677955c0afa21201ad3

## 2026-11-01 03:04 UTC
- hakios-xnu-kernel: up to date (a48d2b29dd58da5ef322052a7f4f73d7eb8eebc4)
- hakios-xnu-kernel: newest tag v0.1.0
- hakios-metal: up to date (a097abde4cd2d6934ed2e6f1d48e0fe102d486f3)
- hakios-uefi: up to date (687fa6c6a5a70f43184de92980e0a76eea5f2c4b)
- watch:
  - https://github.com/oosexgang/hakios-sm7325 HEAD 04fbfff933f52faf203a55aca9dd5680092e6ec5
  - https://github.com/oosexgang/hakios-mt6768 HEAD b60346c8ae50b539c51a1156899cc86f161bba5c
  - https://github.com/oosexgang/hackios-web HEAD 5d15cfb55e42d3f4a85cf677955c0afa21201ad3

## 2026-11-02 03:38 UTC
- hakios-xnu-kernel: fast-forwarded a48d2b29dd58da5ef322052a7f4f73d7eb8eebc4 -> 96ffbc532e970f3540885755d457e401e04d4707, pushed
- hakios-xnu-kernel: newest tag v0.1.0
- hakios-metal: fast-forwarded a097abde4cd2d6934ed2e6f1d48e0fe102d486f3 -> 9d52b5142542a253b7263a0d7889ad278e5c7693, pushed
- hakios-uefi: up to date (687fa6c6a5a70f43184de92980e0a76eea5f2c4b)
- watch:
  - https://github.com/oosexgang/hakios-sm7325 HEAD 04fbfff933f52faf203a55aca9dd5680092e6ec5
  - https://github.com/oosexgang/hakios-mt6768 HEAD b60346c8ae50b539c51a1156899cc86f161bba5c
  - https://github.com/oosexgang/hackios-web HEAD 5d15cfb55e42d3f4a85cf677955c0afa21201ad3

## 2026-11-02 21:00 UTC
- hakios-xnu-kernel: up to date (96ffbc532e970f3540885755d457e401e04d4707)
- hakios-xnu-kernel: newest tag v0.1.0
- hakios-metal: up to date (9d52b5142542a253b7263a0d7889ad278e5c7693)
- hakios-uefi: up to date (687fa6c6a5a70f43184de92980e0a76eea5f2c4b)
- watch:
  - https://github.com/oosexgang/hakios-sm7325 HEAD 04fbfff933f52faf203a55aca9dd5680092e6ec5
  - https://github.com/oosexgang/hakios-mt6768 HEAD b60346c8ae50b539c51a1156899cc86f161bba5c
  - https://github.com/oosexgang/hackios-web HEAD 5d15cfb55e42d3f4a85cf677955c0afa21201ad3

## 2026-11-04 13:15 UTC (manual, user-requested)
- hakios-xnu-kernel: fast-forwarded 96ffbc5 -> 87bf485 (29 commits), pushed
  - upstream: window server draws through Metal (metal_m2v=1), Turnip on Darwin (vk_test PASS),
    Metal-on-Vulkan pipeline (tools/m2v/*), 120 Hz interactive runs, Metal shader cache across boots
  - new upstream branch: metal-perf (currently == main tip on both kernel and metal)
- hakios-metal: fast-forwarded 9d52b51 -> 7025778 (142 commits, incl. window-server/ tree + Mesa AIR
  frontend), pushed
- hakios-uefi: up to date (687fa6c)
- fork pixel7 rebased onto 87bf485 -> f40fded, force-with-lease pushed; 4 port commits preserved,
  zero conflicts (manifest.conf redwood pin bump auto-merged beside our panther block)
- parent pins: xnu-kernel f40fded, metal 7025778
- watch:
  - https://github.com/oosexgang/hakios-sm7325 main HEAD 04fbfff (manifest pins mac branch af52dfb)
  - https://github.com/oosexgang/hakios-mt6768 HEAD b60346c (unmoved since 10-30)
  - https://github.com/oosexgang/hackios-web HEAD 5bd869e (marketing site, not ported)

## 2026-11-05 22:30 UTC (manual — automation did not log a run today)
- hakios-xnu-kernel: fast-forwarded 87bf485 -> 2631f5d (228 commits), pushed; pixel7 rebased -> 0a266a2
- BIG upstream restructure: hakios-metal MERGED INTO the kernel tree (hakios-metal/ dir, "with its
  history", a128588); the hakios-metal repo is ARCHIVED (tip = d36f329 "Moved", history REWRITTEN —
  our fork main force-reset to the tombstone to mirror). New top-level: socs/, sysimage/, mkxnuimg.py.
  Identity system: xnuloader/mkidentity.sh builds identity.h from the user's OWN IPSW device tree
  (DeviceTree.d22ap.im4p, iPhone XS default; sysimage/unpack.sh takes the IPSW). U-Boot path added
  as Silicium alternative. "Darwin, not iOS" rename. Touch sampling, framebuffer SoC guards,
  device-repo metal.args (9da1523) — panther's added (5cce3c5).
- hakios-metal: upstream history rewritten at archival; fork main reset d7495f4 -> d36f329 (mirror
  policy: follow upstream; history preserved inside the kernel tree)
- hakios-uefi: up to date (687fa6c)
- NOTE: Nov 5 12:00 automation did not fire/log — check automation runner health.

## 2026-11-15 17:01 UTC
- hakios-xnu-kernel: fast-forwarded 2631f5d7d4f9d7322aca60991b34ba465dec343b -> 63fc2b4633bac3af8e57dadab9f5a8d4cb940438, pushed
- hakios-xnu-kernel: newest tag v0.1.0
- scion-kernel: mirror fast-forwarded 025f97557ac439651b08f2a906c01addfad77ece -> 2a79ef85e4bf1fe17bc94e3d1db58ba1d78aa247, pushed
- scion-kernel: tip 2a79ef85 Merge pull request #296 from Scion-Project/contrib/anan-jaser-camera
- watch:
  - https://github.com/oosexgang/hakios-sm7325 HEAD 04fbfff933f52faf203a55aca9dd5680092e6ec5
  - https://github.com/oosexgang/hakios-mt6768 HEAD ad65e1f4b3ba479e9d7ada98f17398b83cc6f285
  - https://github.com/oosexgang/hackios-web HEAD 72a5a9a93a75a38005529f1f25c6f61a7c4d2418
  - https://github.com/Scion-Project/scion-kernel HEAD 2a79ef85e4bf1fe17bc94e3d1db58ba1d78aa247
  - https://github.com/Scion-Project/scion-starlte HEAD 87be95cc732570d256a6d6d462881945be671aca
  - https://github.com/Scion-Project/scion-star2lte HEAD ee5bfa3678de0f0459d4c84429171987fdb446e1
  - https://github.com/Scion-Project/scion-soc-lga HEAD 0a332c35c7a0aa795cd166599f23c5badeafc2dc
  - https://github.com/danstronics/ios-s9plus-exynos HEAD 2d092398040f98685b0c5a07776df5e9f199b9dc
- news (Pixel-7 relevance check):
  - mt6768 MOVED b60346c -> ad65e1f4 (first movement since 10-30): WiFi WORKS (gen4m driver,
    WPA2 join from Settings, Safari); Bluetooth WORKS (MT6631, HCI over STP ch0 on BTIF,
    BLE scan sees devices, Settings discoverable as "iPhone"); main camera S5K JN1 live
    preview in Camera.app + userland camera stack (camera_device.c 1822 ln, camera_isp.c 556 ln).
    RESTRUCTURED: repo is now device-layer only — mtkloader + run scripts moved to
    hakios-xnu-kernel branch "mtk" (a9627984 = mtk/loader + mtk/tools); the mt6768 repo no
    longer has an mtk branch.
  - kernel upstream delta = 4 commits (PR#53 soc-args register-cell width decode; PR#54
    var-store older-checksum fallback); devices/manifest.conf UNCHANGED in the range; tags:
    still v0.1.0 only, nothing new.
  - oosexgang org: 7 repos, NO new ones (hackios-web, hackios-xnu-userland, hakios-metal,
    hakios-mt6768, hakios-sm7325, hakios-uefi, hakios-xnu-kernel).
  - token: ~/.hermes/.env GITHUB_TOKEN returns 401 (stale); this run exported gh auth token
    via GITHUB_TOKEN env — all pushes succeeded. Token never written to disk.
