#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$ROOT/scripts/install-linux-toolchain.sh"

if [[ -f "$ROOT/build.nvslc.hxml" && -f "$ROOT/build.nvslvm.hxml" ]]; then
  "$ROOT/scripts/build-tools.sh"
fi

cat <<'EOF'
NVSL is ready.

Try:
  ./nvsl run ./src/novel/script/samples/ok/basic --entry game.app.main
EOF
