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
