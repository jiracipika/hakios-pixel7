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
  https://ftp.gnu.org/*|https://github.com/*|https://mirrors.edge.kernel.org/*|https://archive.ubuntu.com/*) return 0 ;;
  *) echo "REJECT $1" >&2; return 1 ;; esac; }

# QEMU 9.2 from Ubuntu debs extracted (no root) into ~/.local/qemu-deb — the Android
# SDK's qemu is an emulator fork without -M virt.
export PATH="$HOME/.local/bin:$HOME/.local/lldenv/bin:$HOME/.local/qemu-deb/root/usr/bin:$PATH"
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
    && ./configure --prefix="$HOME/.local" CFLAGS="-O2 -std=gnu17" CXXFLAGS="-O2 -std=gnu17" >/dev/null \
    && make -j"$(nproc)" >/dev/null \
    && make install >/dev/null ) || { echo "FAILED build $name"; return 1; }
  echo "ok: $name"
}

build m4-1.4.19            https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz        || exit 1
build flex-2.6.4           https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz || exit 1
build bison-3.8.2          https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz   || exit 1
build autoconf-2.71        https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz || exit 1
build automake-1.16.5      https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.xz     || exit 1
build ncurses-6.5          https://ftp.gnu.org/gnu/ncurses/ncurses-6.5.tar.gz          || exit 1
# gawk: XNU's sysent generators emit `\\(` per gawk/BSD-awk rules; mawk (this box's
# default awk) emits it differently, putting literal backslashes in init_sysent.c
build gawk-5.3.1           https://ftp.gnu.org/gnu/gawk/gawk-5.3.1.tar.xz              || exit 1
# libuuid (uuid/uuid.h) for the XNU host-compat shim (hostinc/hostcompat.h)
( cd /tmp/src-e2fsprogs-1.47.2 2>/dev/null && make -j"$(nproc)" >/dev/null 2>&1 && make install >/dev/null 2>&1 ) || {
  rm -rf /tmp/src-e2fsprogs-1.47.2; mkdir -p /tmp/src-e2fsprogs-1.47.2
  curl -fL --max-time 300 https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.2/e2fsprogs-1.47.2.tar.xz -o /tmp/e2fsprogs.tar.xz \
    && tar -xf /tmp/e2fsprogs.tar.xz -C /tmp/src-e2fsprogs-1.47.2 --strip-components=1 \
    && ( cd /tmp/src-e2fsprogs-1.47.2 && ./configure --prefix="$HOME/.local" --disable-nls CFLAGS="-O2 -std=gnu17" >/dev/null \
         && make -C lib/et -j"$(nproc)" >/dev/null && make -C lib/uuid -j"$(nproc)" >/dev/null \
         && make -C lib/et install >/dev/null && make -C lib/uuid install >/dev/null ) \
    || { echo "FAILED libuuid build"; exit 1; }
}
echo "ok: e2fsprogs-1.47.2 (libuuid)"

# lld (lld-link for the UEFI loader) via micromamba/conda-forge, no root
MAMBA="${MAMBA:-$HOME/toolchain-dl/bin/micromamba}"
if [ -x "$MAMBA" ] && [ ! -x "$HOME/.local/lldenv/bin/lld-link" ]; then
  "$MAMBA" create -y -q -p "$HOME/.local/lldenv" -c conda-forge lld && echo "ok: lld"
fi

# QEMU (the Android SDK's qemu is an emulator fork without -M virt) + AAVMF firmware,
# from Ubuntu pool debs extracted into ~/.local — no root needed
DEB="$HOME/.local/qemu-deb"
if [ ! -x "$DEB/root/usr/bin/qemu-system-aarch64" ]; then
  mkdir -p "$DEB" && cd "$DEB"
  UB="https://archive.ubuntu.com/ubuntu/pool/main"
  for spec in \
    "q/qemu qemu-system-arm_9.2.1+ds-1ubuntu5.2_amd64.deb" \
    "q/qemu qemu-system-data_10.2.1+ds-1ubuntu3.3_all.deb" \
    "i/ipxe ipxe-qemu_1.21.1+git-20250829.969ce2c55+dfsg-3ubuntu2_all.deb" \
    "l/libaio libaio1t64_0.3.113-9_amd64.deb" \
    "d/device-tree-compiler libfdt1_1.7.2-2ubuntu1_amd64.deb" \
    "f/fuse3 libfuse3-3_3.14.0-5build1_amd64.deb" \
    "p/pmdk libpmem1_1.8-1ubuntu1_amd64.deb" \
    "r/rdma-core librdmacm1_39.0-1_amd64.deb" \
    "r/rdma-core libibverbs1_64.0-1ubuntu1_amd64.deb" \
    "libs/libslirp libslirp0_4.9.3-1ubuntu1_amd64.deb"; do
    d="${spec%% *}"; f="${spec#* }"
    url_ok "$UB/$d/$f" || exit 1
    [ -f "$f" ] || curl -fsSL --max-time 300 "$UB/$d/$f" -o "$f" || { echo "FAILED $f"; exit 1; }
    dpkg-deb -x "$f" root
    echo "ok: $f"
  done
  cd - >/dev/null
fi
if [ ! -f "$HOME/.local/aavmf/usr/share/AAVMF/AAVMF_CODE.no-secboot.fd" ]; then
  mkdir -p "$HOME/.local/aavmf" && cd "$HOME/.local/aavmf"
  f="qemu-efi-aarch64_2026.05-2ubuntu3_all.deb"
  url_ok "https://archive.ubuntu.com/ubuntu/pool/main/e/edk2/$f" || exit 1
  curl -fsSL --max-time 180 "https://archive.ubuntu.com/ubuntu/pool/main/e/edk2/$f" -o "$f" \
    && dpkg-deb -x "$f" root && echo "ok: AAVMF"
  cd - >/dev/null
fi
# tcsh (built by xnu-deps/setup.sh) needs tgetent(); hand it the ~/.local ncurses
export CPPFLAGS="-I$HOME/.local/include"
export LDFLAGS="-L$HOME/.local/lib"
# XNU's make ignores CPPFLAGS/LDFLAGS; clang/gcc honor these env include/lib paths
export CPATH="$HOME/.local/include"
export LIBRARY_PATH="$HOME/.local/lib"
# only the widec variant got built; tcsh's tgetent probe never tries -lncursesw
export LIBS="-lncursesw"
# XNU build host tools: xnu-build.sh passes HOST_CC="$HOSTCC" from env — theos clang
# accepts the Apple flags (-mmacosx-version-min, -isysroot) that gcc rejects.
export HOSTCC="$HOME/theos/toolchain/linux/iphone/bin/clang"

echo "== installed: $(command -v flex bison m4 autoreconf automake clang 2>/dev/null | tr '\n' ' ') =="

cd "$KERNEL" || exit 1
echo "== xnu-deps/setup.sh =="
xnu-deps/setup.sh || { echo "BASELINE-FAIL: xnu-deps"; exit 1; }

echo "== make kernel =="
# some sub-make environments lose ~/.local/bin from PATH; pass the tools explicitly
THEOSBIN="$HOME/theos/toolchain/linux/iphone/bin"
make -j"$(nproc)" kernel SHELL=/bin/bash DSYMUTIL="$THEOSBIN/dsymutil" NMEDIT="$THEOSBIN/nmedit" || { echo "BASELINE-FAIL: make kernel"; exit 1; }

echo "== qemu boot =="
# AAVMF firmware extracted from Ubuntu's qemu-efi-aarch64 deb into ~/.local/aavmf
export QEMU_SHARE_DIR="$HOME/.local/qemu-deb/root/usr/share/qemu"
export QEMU_EFI="$HOME/.local/aavmf/root/usr/share/AAVMF/AAVMF_CODE.no-secboot.fd"
export QEMU_VARS="$HOME/.local/aavmf/root/usr/share/AAVMF/AAVMF_VARS.fd"
# qemu's extracted deb libraries (libfuse3 landed under /lib, the rest under /usr/lib)
export LD_LIBRARY_PATH="$HOME/.local/qemu-deb/root/usr/lib/x86_64-linux-gnu:$HOME/.local/qemu-deb/root/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
make qemu-open SECS=45 SHELL=/bin/bash || { echo "BASELINE-FAIL: qemu"; exit 1; }
echo "BASELINE-DONE"
