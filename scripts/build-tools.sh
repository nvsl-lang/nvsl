#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/nvsl-env.sh"

if [[ ! -f "$ROOT/build.nvslc.hxml" || ! -f "$ROOT/build.nvslvm.hxml" ]]; then
  if [[ -f "$ROOT/bin/nvslc.hl" && -f "$ROOT/bin/nvslvm.hl" ]]; then
    echo "Using bundled NVSL tools in $ROOT/bin"
    exit 0
  fi

  echo "Missing build.nvslc.hxml/build.nvslvm.hxml. This checkout cannot rebuild the tools." >&2
  exit 1
fi

nvsl_build_tool nvslc
nvsl_build_tool nvslvm

echo "Built:"
echo "  $ROOT/bin/nvslc.hl"
echo "  $ROOT/bin/nvslvm.hl"
