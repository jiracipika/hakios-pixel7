# Upstream sync policy and procedure

Why: upstream (oosexgang) pushes near-daily; our forks must track it so our `pixel7` branches keep
rebasing cleanly. Cadence: **every 5 days**, automated, plus any time before starting port work.

## Branch policy (enforced by the script)

- Each fork's `main` is a **pure mirror of `oosexgang/<repo>` `main`**: fast-forward only.
- Port work lives on `pixel7` branches in each fork; rebase those onto `main` after each sync.
- The parent repo (`hakios-pixel7`) pins the submodule SHAs; after a sync the script commits and
  pushes the new pins.
- If a fork `main` has local commits (policy violation) or diverged (upstream force-pushed), the
  script **reports and skips** — it never force-pushes or rewrites `main`.

## Manual run

```sh
scripts/sync-upstream.sh          # fetch, ff-merge, push, log to notes/sync-log.md
```

Exit codes: `0` all up to date; `1` something synced (or a minor warning); `2` a fork needs a human
(diverged) or a network/auth failure. Watch-repos (sm7325, mt6768, hackios-web, manifest) are
tip-checked with `git ls-remote` and logged so we see upstream drift beyond our three forks.

## Automated run

A scheduled automation fires every 5 days at 12:00 local (chosen to sit outside the
14:00–18:00 UTC+8 no-heavy-work window). It runs the script, reads the log delta, checks the
upstream org for anything new that matters (device repos, `mtk` branch progress, `manifest.conf`
and guide changes), commits the log, pushes, and reports a summary.

Standing constraints baked into the automation prompt:
- **Never touch the `automated-newsletter` project** — explicit exclusion in every generated prompt.
- Stop immediately on HTTP 429 (rate limit).
- One network operation at a time (zai/GLM concurrency ~2; 1 child is safe).

## Release watch

The kernel has tags/releases (`v0.1.0` "source drop", 2026-10-22); metal/uefi have none yet. The
sync fetches `--tags`, and the log notes any tag that appeared, since releases are the user-visible
milestones we should rebase major work onto.
