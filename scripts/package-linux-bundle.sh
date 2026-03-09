#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/nvsl-env.sh"

DIST_DIR="${1:-$ROOT/dist}"
BUNDLE_NAME="${2:-nvsl-linux-x64}"
STAGE_DIR="$DIST_DIR/$BUNDLE_NAME"
ARCHIVE_PATH="$DIST_DIR/$BUNDLE_NAME.tar.gz"

nvsl_require_hl
nvsl_ensure_tool nvslc
nvsl_ensure_tool nvslvm

HL_DIR="$(dirname "$NVSL_HL")"
LIBHL_PATH=""

if [[ -f "$HL_DIR/libhl.so" ]]; then
  LIBHL_PATH="$HL_DIR/libhl.so"
else
  LIBHL_PATH="$(ldd "$NVSL_HL" 2>/dev/null | awk '/libhl\.so/ {print $3; exit}')"
fi

rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/bin" "$STAGE_DIR/scripts"

cp "$ROOT/README.md" "$STAGE_DIR/"
cp "$ROOT/LICENSE" "$STAGE_DIR/"
cp "$ROOT/nvsl" "$STAGE_DIR/"
cp "$ROOT/nvslc" "$STAGE_DIR/"
cp "$ROOT/nvslvm" "$STAGE_DIR/"
cp "$ROOT/scripts/nvsl-env.sh" "$STAGE_DIR/scripts/"
cp "$ROOT/bin/nvslc.hl" "$STAGE_DIR/bin/"
cp "$ROOT/bin/nvslvm.hl" "$STAGE_DIR/bin/"
cp "$NVSL_HL" "$STAGE_DIR/bin/hl"

if [[ -n "$LIBHL_PATH" && -f "$LIBHL_PATH" ]]; then
  cp "$LIBHL_PATH" "$STAGE_DIR/bin/libhl.so"
fi

chmod +x \
  "$STAGE_DIR/nvsl" \
  "$STAGE_DIR/nvslc" \
  "$STAGE_DIR/nvslvm" \
  "$STAGE_DIR/scripts/nvsl-env.sh" \
  "$STAGE_DIR/bin/hl"

tar -czf "$ARCHIVE_PATH" -C "$DIST_DIR" "$BUNDLE_NAME"

echo "Created Linux bundle:"
echo "  $ARCHIVE_PATH"
