#!/usr/bin/env bash
# sync-upstream.sh — the 5-day upstream sync for hakios-pixel7.
#
# For each fork (forks/<name>): fetch oosexgang upstream, fast-forward local main,
# push to origin (our GitHub fork), then pin the submodule SHA in the parent repo.
# Watch-repos are tip-checked and logged. Never force-pushes; diverged mains are
# reported, not repaired. Appends everything to notes/sync-log.md.
#
# Exit: 0 up to date | 1 synced or warnings | 2 needs a human (divergence/failure).

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/notes/sync-log.md"
TS="$(date -u '+%Y-%m-%d %H:%M UTC')"
UPSTREAM_ORG="oosexgang"
ORIGIN_OWNER="jiracipika"
SCION_ORIGIN_URL="https://github.com/${ORIGIN_OWNER}/hakios-xnu-kernel"

# 2026-11-09 repo cleanup: hakios-metal fork dropped (upstream dead — the Metal
# driver moved into the kernel repo), hakios-uefi fork dropped (not in panther's
# boot path: panther boots via ABL, not UEFI). Both archived on GitHub; re-fork
# in one click if ever needed.
# CORRECTION: hakios-gs201 stays — it is the canonical device repo (kernel-repo
# .gitignore /devices/* by upstream design; devices/panther clones it; the
# kernel fork pins its commit via devices/manifest.conf). Active repos: 3.
FORKS=(hakios-xnu-kernel)
WATCH=(
  "https://github.com/${UPSTREAM_ORG}/hakios-sm7325"
  "https://github.com/${UPSTREAM_ORG}/hakios-mt6768"
  "https://github.com/${UPSTREAM_ORG}/hackios-web"
  # Scion lineage (fork of hakios-xnu-kernel; the working Samsung Exynos S9/S9+ iOS port
  # being converted to panther — docs/PORT-FROM-SCION.md)
  "https://github.com/Scion-Project/scion-kernel"
  "https://github.com/Scion-Project/scion-starlte"
  "https://github.com/Scion-Project/scion-star2lte"
  "https://github.com/Scion-Project/scion-soc-lga"
  "https://github.com/danstronics/ios-s9plus-exynos"
)

# Credentials: use GITHUB_TOKEN from the environment or ~/.hermes/.env (never stored on disk).
if [ -z "${GITHUB_TOKEN:-}" ] && [ -f "$HOME/.hermes/.env" ]; then
  set -a; . "$HOME/.hermes/.env" >/dev/null 2>&1; set +a
fi
GIT_USER="${GIT_USER:-x-access-token}"

# Security: https only, host allowlist (no localhost/loopback/private/reserved hosts).
url_ok() {
  case "$1" in
    https://github.com/*|https://api.github.com/*|https://codeload.github.com/*) return 0 ;;
    *) return 1 ;;
  esac
}

say() { printf '%s\n' "$*"; }
log() { printf '%s\n' "$*" >>"$LOG"; }
die2() { log "ERROR: $*"; say "ERROR: $*"; exit 2; }

mkdir -p "$ROOT/notes" "$ROOT/forks"
[ -f "$LOG" ] || printf '# Upstream sync log\n' >"$LOG"
log ""
log "## $TS"

[ -n "${GITHUB_TOKEN:-}" ] || log "WARN: GITHUB_TOKEN not set — pushes will fail if needed."

detect_429() { grep -qi '429\|rate limit' 2>/dev/null; }

RESULT=0
PIN_UPDATED=0

for repo in "${FORKS[@]}"; do
  dir="$ROOT/forks/$repo"
  up="https://github.com/${UPSTREAM_ORG}/${repo}.git"
  origin="https://github.com/${ORIGIN_OWNER}/${repo}.git"
  url_ok "$up" || die2 "refusing non-allowlisted upstream URL: $up"
  if [ ! -d "$dir/.git" ]; then
    log "- $repo: SKIP (no clone at forks/$repo)"
    RESULT=1; continue
  fi

  err="$(git -C "$dir" fetch upstream --prune --tags 2>&1)" || {
    if printf '%s' "$err" | detect_429; then die2 "HTTP 429 rate-limited fetching $repo — stopping per policy."; fi
    log "- $repo: FETCH FAILED: $(printf '%s' "$err" | tail -1)"
    RESULT=2; continue
  }

  local_sha="$(git -C "$dir" rev-parse refs/heads/main 2>/dev/null || true)"
  up_sha="$(git -C "$dir" rev-parse refs/remotes/upstream/main 2>/dev/null || true)"
  if [ -z "$up_sha" ]; then
    log "- $repo: no upstream/main after fetch"; RESULT=2; continue
  fi

  if [ "$local_sha" = "$up_sha" ]; then
    log "- $repo: up to date ($local_sha)"
  elif git -C "$dir" merge-base --is-ancestor "$local_sha" "$up_sha" 2>/dev/null; then
    git -C "$dir" checkout -q main
    if git -C "$dir" merge --ff-only "$up_sha" >/dev/null 2>&1; then
      push_err="$(git -C "$dir" -c credential.helper= \
        -c "credential.helper=!f(){ printf 'username=%s\npassword=%s\n' '$GIT_USER' \"\$GITHUB_TOKEN\"; };f" \
        push "$origin" main 2>&1)" || {
        if printf '%s' "$push_err" | detect_429; then die2 "HTTP 429 rate-limited pushing $repo — stopping per policy."; fi
        log "- $repo: merged locally but PUSH FAILED: $(printf '%s' "$push_err" | tail -1)"
        RESULT=2; continue
      }
      log "- $repo: fast-forwarded $local_sha -> $up_sha, pushed"
      PIN_UPDATED=1
    else
      log "- $repo: FF-MERGE FAILED (unexpected)"; RESULT=2
    fi
  elif git -C "$dir" merge-base --is-ancestor "$up_sha" "$local_sha" 2>/dev/null; then
    log "- $repo: DIVERGED (fork main is AHEAD of upstream — policy violation; move local commits to a pixel7 branch)"
    RESULT=2
  else
    log "- $repo: DIVERGED (both ahead — upstream force-push or stale mirror; needs a human)"
    RESULT=2
  fi

  new_tag="$(git -C "$dir" for-each-ref 'refs/tags/v*' --sort=-creatordate --format='%(refname:short)' | head -1)"
  [ -n "$new_tag" ] && log "- $repo: newest tag $new_tag"
done

# Scion mirror: track the Scion-Project kernel fork's main in the kernel submodule
# (branch scion-main = pure mirror, ff-only, same policy as upstream main; port work
# lives on pixel7-scion).
SCION_KERNEL="$ROOT/forks/hakios-xnu-kernel"
if [ -d "$SCION_KERNEL/.git" ]; then
  if git -C "$SCION_KERNEL" remote get-url scion >/dev/null 2>&1; then
    scion_err="$(git -C "$SCION_KERNEL" fetch scion main 2>&1)" || {
      if printf '%s' "$scion_err" | detect_429; then die2 "HTTP 429 rate-limited fetching scion-kernel — stopping per policy."; fi
      log "- scion-kernel: FETCH FAILED: $(printf '%s' "$scion_err" | tail -1)"; RESULT=2
    }
    scion_sha="$(git -C "$SCION_KERNEL" rev-parse refs/remotes/scion/main 2>/dev/null || true)"
    if [ -n "$scion_sha" ]; then
      cur="$(git -C "$SCION_KERNEL" rev-parse refs/heads/scion-main 2>/dev/null || true)"
      if [ "$cur" = "$scion_sha" ]; then
        log "- scion-kernel: mirror up to date ($scion_sha)"
      elif git -C "$SCION_KERNEL" merge-base --is-ancestor "$cur" "$scion_sha" 2>/dev/null; then
        git -C "$SCION_KERNEL" update-ref refs/heads/scion-main "$scion_sha" "$cur" \
          && push_err="$(git -C "$SCION_KERNEL" -c credential.helper= \
             -c "credential.helper=!f(){ printf 'username=%s\npassword=%s\n' '$GIT_USER' \"\$GITHUB_TOKEN\"; };f" \
             push "$SCION_ORIGIN_URL" scion-main 2>&1)" || true
        if [ -n "${push_err:-}" ] && printf '%s' "$push_err" | grep -qi 'error\|failed'; then
          if printf '%s' "$push_err" | detect_429; then die2 "HTTP 429 rate-limited pushing scion-main — stopping per policy."; fi
          log "- scion-kernel: mirror moved $cur -> $scion_sha but PUSH FAILED: $(printf '%s' "$push_err" | tail -1)"; RESULT=2
        else
          log "- scion-kernel: mirror fast-forwarded $cur -> $scion_sha, pushed"
        fi
      else
        log "- scion-kernel: MIRROR DIVERGED (upstream force-push? needs a human)"; RESULT=2
      fi
      log "- scion-kernel: tip $(git -C "$SCION_KERNEL" log -1 --format='%h %s' "$scion_sha" 2>/dev/null | cut -c1-100)"
    fi
  else
    log "- scion-kernel: no scion remote in forks/hakios-xnu-kernel (one-time setup needed)"
    RESULT=1
  fi
fi

log "- watch:"
for w in "${WATCH[@]}"; do
  url_ok "$w" || { log "  - REJECT non-allowlisted watch URL: $w"; continue; }
  tip="$(git ls-remote "$w" HEAD 2>/dev/null | cut -f1)"
  if [ -z "$tip" ]; then
    log "  - $w: ls-remote failed"
  else
    log "  - $w HEAD $tip"
  fi
done

if [ "$PIN_UPDATED" = 1 ]; then
  git -C "$ROOT" add forks/ 2>/dev/null
  if ! git -C "$ROOT" diff --cached --quiet; then
    git -C "$ROOT" commit -q -m "sync: pin forks to upstream ($TS)" || true
    push_err="$(git -C "$ROOT" -c credential.helper= \
      -c "credential.helper=!f(){ printf 'username=%s\npassword=%s\n' '$GIT_USER' \"\$GITHUB_TOKEN\"; };f" \
      push origin main 2>&1)" || {
      if printf '%s' "$push_err" | detect_429; then die2 "HTTP 429 rate-limited pushing parent repo — stopping per policy."; fi
      log "WARN: parent-repo push failed: $(printf '%s' "$push_err" | tail -1)"
      RESULT=2
    }
  fi
fi

case "$RESULT" in
  0) say "sync: all forks up to date. Log: $LOG" ;;
  1) say "sync: done with warnings. Log: $LOG" ;;
  2) say "sync: NEEDS A HUMAN — see $LOG" ;;
esac
exit "$RESULT"
