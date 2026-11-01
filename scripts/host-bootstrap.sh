#!/usr/bin/env bash
# host-bootstrap.sh — one-time host prep for the hakios-pixel7 baseline build, without root.
# Installs the five GNU autotools into ~/.local, then runs the common tree's own
# xnu-deps/setup.sh (which fetches Apple's open sources and the kernel SDK),
# builds the kernel, and boots the open kernel in QEMU for a first sanity gate.
#
# Security: https-only downloads from an explicit allowlist (gnu.org, github.com).
# Usage: scripts/host-bootstrap.sh            (long; log at /tmp/hakios-baseline.log)
set -uo pipefail

LOG="${LOG:-/tmp/hakios-baseline.log}"
KERNEL="${ROOT_KERNEL:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/forks/hakios-xnu-kernel}"
QEMU_SDK=/home/rs/Android/Sdk/emulator/qemu/linux-x86_64

# https-only, host allowlist
url_ok() { case "$1" in
  https://ftp.gnu.org/*|https://github.com/*) return 0 ;;
  *) echo "REJECT $1" >&2; return 1 ;; esac; }

export PATH="$HOME/.local/bin:$QEMU_SDK:$PATH"
mkdir -p "$HOME/.local/bin"
# Host clang wrappers: theos's clang is iOS-targeted and cannot build host binaries;
# xnu-deps/setup.sh only needs a clang-named host compiler (kernel itself uses xnu-clang,
# linked from theos by setup.sh, not from PATH).
[ -e "$HOME/.local/bin/clang" ] || printf '#!/bin/sh\nexec gcc "$@"\n' >"$HOME/.local/bin/clang"
[ -e "$HOME/.local/bin/clang++" ] || printf '#!/bin/sh\nexec g++ "$@"\n' >"$HOME/.local/bin/clang++"
chmod +x "$HOME/.local/bin/clang" "$HOME/.local/bin/clang++"

echo "== host-bootstrap start $(date -u) =="

build() {
  local name="$1" url="$2" d
  url_ok "$url" || { echo "REJECTED $url"; return 1; }
  echo "== building $name =="
  rm -rf "/tmp/src-$name"; mkdir -p "/tmp/src-$name"
  curl -fL --max-time 300 "$url" -o "/tmp/$name.tar" || { echo "FAILED download $name"; return 1; }
  tar -xf "/tmp/$name.tar" -C "/tmp/src-$name" --strip-components=1 || { echo "FAILED untar $name"; return 1; }
  ( cd "/tmp/src-$name" \
    && ./configure --prefix="$HOME/.local" >/dev/null \
    && make -j"$(nproc)" >/dev/null \
    && make install >/dev/null ) || { echo "FAILED build $name"; return 1; }
  echo "ok: $name"
}

build m4-1.4.19            https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz        || exit 1
build flex-2.6.4           https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz || exit 1
build bison-3.8.2          https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz   || exit 1
build autoconf-2.71        https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz || exit 1
build automake-1.16.5      https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.xz     || exit 1

echo "== installed: $(command -v flex bison m4 autoreconf automake clang 2>/dev/null | tr '\n' ' ') =="

cd "$KERNEL" || exit 1
echo "== xnu-deps/setup.sh =="
xnu-deps/setup.sh || { echo "BASELINE-FAIL: xnu-deps"; exit 1; }

echo "== make kernel =="
make -j"$(nproc)" kernel || { echo "BASELINE-FAIL: make kernel"; exit 1; }

echo "== qemu boot =="
make qemu-open SECS=45 || { echo "BASELINE-FAIL: qemu"; exit 1; }
echo "BASELINE-DONE"
