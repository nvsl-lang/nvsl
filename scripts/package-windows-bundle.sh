#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/nvsl-env.sh"
source "$ROOT/scripts/package-bundle-common.sh"

DIST_DIR="${1:-$ROOT/dist}"
BUNDLE_NAME="${2:-nvsl-windows-x64}"
STAGE_DIR="$DIST_DIR/$BUNDLE_NAME"
ARCHIVE_PATH="$DIST_DIR/$BUNDLE_NAME.zip"

RUNTIME_BIN_DIR="${NVSL_RUNTIME_BIN_DIR:-}"
if [[ -z "$RUNTIME_BIN_DIR" ]]; then
  nvsl_require_hl
  RUNTIME_BIN_DIR="$(dirname "$NVSL_HL")"
fi

"$ROOT/scripts/build-tools.sh"
nvsl_stage_bundle_common "$ROOT" "$STAGE_DIR"

cp "$RUNTIME_BIN_DIR/hl.exe" "$STAGE_DIR/bin/hl.exe"
cp "$RUNTIME_BIN_DIR/libhl.dll" "$STAGE_DIR/bin/libhl.dll"

nvsl_archive_zip "$DIST_DIR" "$BUNDLE_NAME" "$ARCHIVE_PATH"

echo "Created Windows bundle:"
echo "  $ARCHIVE_PATH"
