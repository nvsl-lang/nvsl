#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/nvsl-env.sh"
source "$ROOT/scripts/package-bundle-common.sh"

DIST_DIR="${1:-$ROOT/dist}"
BUNDLE_NAME="${2:-nvsl-linux-x64}"
STAGE_DIR="$DIST_DIR/$BUNDLE_NAME"
ARCHIVE_PATH="$DIST_DIR/$BUNDLE_NAME.tar.gz"

RUNTIME_BIN_DIR="${NVSL_RUNTIME_BIN_DIR:-}"
if [[ -z "$RUNTIME_BIN_DIR" ]]; then
  nvsl_require_hl
  RUNTIME_BIN_DIR="$(dirname "$NVSL_HL")"
fi

"$ROOT/scripts/build-tools.sh"
nvsl_stage_bundle_common "$ROOT" "$STAGE_DIR"

cp "$RUNTIME_BIN_DIR/hl" "$STAGE_DIR/bin/hl"
nvsl_stage_linux_runtime_libs "$RUNTIME_BIN_DIR" "$STAGE_DIR/bin"

chmod +x "$STAGE_DIR/bin/hl"

nvsl_archive_tar_gz "$DIST_DIR" "$BUNDLE_NAME" "$ARCHIVE_PATH"

echo "Created Linux bundle:"
echo "  $ARCHIVE_PATH"
