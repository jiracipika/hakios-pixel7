# hakios-pixel7

Porting [HakiOS](https://github.com/oosexgang/hakios-xnu-kernel) — Apple's open-source XNU kernel
(`xnu-8796.121.2`) running Android phones — to the **Google Pixel 7 (`panther`, Tensor G2 / `gs201`)**.

This is a fork-supervisor monorepo: the three upstream codebases live here as **git submodules pointing
at our forks**, plus the port plan, the sync tooling, and (later) the device repo work.

## Layout

| Path | What |
|---|---|
| `forks/hakios-xnu-kernel` | common tree (XNU port, drivers, loader, userland, QEMU device) — submodule of our fork |
| `forks/hakios-metal` | Metal command model on the GPU — submodule of our fork |
| `forks/hakios-uefi` | UEFI/U-Boot firmware — submodule of our fork |
| `docs/PORT-PLAN.md` | the Pixel 7 conversion plan: hardware facts, layer-by-layer conversion surface, sequencing, risks |
| `docs/UPSTREAM-SYNC.md` | branch policy + the 5-day sync procedure |
| `scripts/sync-upstream.sh` | the sync implementation (ff-only, never force-pushes, logs to `notes/sync-log.md`) |
| `notes/sync-log.md` | history of upstream drift and sync runs |
| `notes/hakios-sm7325`, `notes/hakios-mt6768` | read-only reference clones of upstream device repos (not tracked; gitignored) |

## Branch policy

Fork `main` is a **pure upstream mirror** (fast-forward only). All Pixel 7 work happens on `pixel7`
branches in the forks; rebase onto `main` after every sync.

## Quick start

```sh
scripts/sync-upstream.sh                 # bring forks up to upstream (every 5 days, automated)
cd forks/hakios-xnu-kernel
make doctor                              # what this machine lacks
make qemu-open                           # the open kernel in QEMU — baseline sanity gate
```

## Why Pixel 7 is a real port, not a config change

Upstream runs on Qualcomm (Adreno GPU, Silicium UEFI, ath11k Wi-Fi). Pixel 7 is Tensor G2:
**Mali-G710 (Valhall v10/CSF)** instead of Adreno, no existing UEFI platform, Broadcom Wi-Fi, Exynos
modem. The `hakios-mt6768` device (MediaTek + Mali-G52) is the closest precedent — it already runs
Metal-on-Mali through Mesa's panfrost. Details: `docs/PORT-PLAN.md`.

## Sync cadence

Upstream pushes near-daily; we sync **every 5 days** (automated) and before starting any port
session. Upstream: `oosexgang/hakios-{xnu-kernel,metal,uefi}`; watch-list also includes
`hakios-sm7325`, `hakios-mt6768`, `hackios-web` and `devices/manifest.conf`.
