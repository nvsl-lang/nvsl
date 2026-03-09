#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLATFORM="${NVSL_BUNDLE_PLATFORM:-${1:-linux}}"
ARCH="${NVSL_BUNDLE_ARCH:-${2:-x64}}"
HASHLINK_REPO="${HASHLINK_REPO:-https://github.com/HaxeFoundation/hashlink.git}"
HASHLINK_REF="${HASHLINK_REF:-latest}"
HASHLINK_SRC_DIR="${HASHLINK_SRC_DIR:-$ROOT/.deps/hashlink-src}"
HASHLINK_BUILD_DIR="${HASHLINK_BUILD_DIR:-$ROOT/.deps/hashlink-build/$PLATFORM-$ARCH}"

if [[ ! -d "$HASHLINK_SRC_DIR/.git" ]]; then
  git clone --depth 1 --branch "$HASHLINK_REF" "$HASHLINK_REPO" "$HASHLINK_SRC_DIR"
fi

case "$PLATFORM" in
  linux)
    cmake -S "$HASHLINK_SRC_DIR" -B "$HASHLINK_BUILD_DIR" -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DWITH_SYSTEM_PCRE2=OFF
    cmake --build "$HASHLINK_BUILD_DIR" --config Release --target hl libhl
    HL_PATH="$HASHLINK_BUILD_DIR/bin/hl"
    ;;
  macos)
    MACOS_ARCH="$ARCH"
    if [[ "$MACOS_ARCH" == "x64" ]]; then
      MACOS_ARCH="x86_64"
      MACOS_DEPLOYMENT_TARGET="10.13"
    else
      MACOS_DEPLOYMENT_TARGET="11.0"
    fi

    cmake -S "$HASHLINK_SRC_DIR" -B "$HASHLINK_BUILD_DIR" -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DWITH_SYSTEM_PCRE2=OFF \
      -DCMAKE_OSX_ARCHITECTURES="$MACOS_ARCH" \
      -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET"
    cmake --build "$HASHLINK_BUILD_DIR" --config Release --target hl libhl
    HL_PATH="$HASHLINK_BUILD_DIR/bin/hl"
    ;;
  windows)
    WINDOWS_ARCH="$ARCH"
    if [[ "$WINDOWS_ARCH" == "x64" ]]; then
      WINDOWS_ARCH="x64"
    fi

    cmake -S "$HASHLINK_SRC_DIR" -B "$HASHLINK_BUILD_DIR" \
      -G "Visual Studio 17 2022" \
      -A "$WINDOWS_ARCH" \
      -DCMAKE_BUILD_TYPE=Release \
      -DFLAT_INSTALL_TREE=ON \
      -DWITH_SYSTEM_PCRE2=OFF
    cmake --build "$HASHLINK_BUILD_DIR" --config Release --target hl libhl
    HL_PATH="$HASHLINK_BUILD_DIR/bin/hl.exe"
    ;;
  *)
    echo "Unsupported NVSL bundle platform '$PLATFORM'." >&2
    exit 1
    ;;
esac

RUNTIME_BIN_DIR="$HASHLINK_BUILD_DIR/bin"
echo "Built HashLink runtime:"
echo "  $RUNTIME_BIN_DIR"

if [[ -n "${NVSL_OUTPUT_ENV:-}" ]]; then
  {
    printf 'NVSL_RUNTIME_BIN_DIR=%s\n' "$RUNTIME_BIN_DIR"
    printf 'HL=%s\n' "$HL_PATH"
  } >>"$NVSL_OUTPUT_ENV"
fi
