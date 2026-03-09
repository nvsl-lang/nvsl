#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${NVSL_REPO_ROOT:-}"
if [[ -z "$ROOT" ]]; then
  probe="$SCRIPT_DIR"
  while [[ "$probe" != "/" ]]; do
    if [[ -f "$probe/build.nvslc.hxml" && -f "$probe/build.nvslvm.hxml" ]]; then
      ROOT="$probe"
      break
    fi
    probe="$(dirname "$probe")"
  done
fi

if [[ -z "$ROOT" ]]; then
  echo "Could not locate repo root. Set NVSL_REPO_ROOT to a directory containing build.nvslc.hxml and build.nvslvm.hxml." >&2
  exit 1
fi

HL="${HL:-}"
if [[ -z "$HL" ]]; then
  if command -v hl >/dev/null 2>&1; then
    HL="$(command -v hl)"
  else
    HL="$ROOT/.deps/hashlink/hl"
  fi
fi
NVSLC_BIN="${NVSLC_BIN:-$ROOT/bin/nvslc.hl}"
NVSLVM_BIN="${NVSLVM_BIN:-$ROOT/bin/nvslvm.hl}"
SAMPLES_ROOT="$SCRIPT_DIR"
TMP_DIR="$(mktemp -d /tmp/nvsl-samples.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! -x "$HL" ]]; then
  echo "Missing HashLink runtime at $HL" >&2
  exit 1
fi

echo "[build] nvslc"
haxe "$ROOT/build.nvslc.hxml"
echo "[build] nvslvm"
haxe "$ROOT/build.nvslvm.hxml"

run_ok_case() {
  local case_dir="$1"
  local case_name
  case_name="$(basename "$case_dir")"
  local entry
  local expected
  local output_path="$TMP_DIR/${case_name}.nvbc"
  local actual

  entry="$(<"$case_dir/entry.txt")"
  expected="$(<"$case_dir/expected.txt")"

  echo "[ok] compile $case_name"
  "$HL" "$NVSLC_BIN" "$case_dir" "$output_path" --entry "$entry" >/dev/null

  echo "[ok] run $case_name"
  actual="$("$HL" "$NVSLVM_BIN" "$output_path")"

  if [[ "$actual" != "$expected" ]]; then
    echo "Expected '$expected' but got '$actual' for $case_name" >&2
    exit 1
  fi
}

run_edge_case() {
  local case_dir="$1"
  local case_name
  case_name="$(basename "$case_dir")"
  local phase
  local expected_error
  local output_path="$TMP_DIR/${case_name}.nvbc"
  local output

  phase="$(<"$case_dir/phase.txt")"
  expected_error="$(<"$case_dir/expected-error.txt")"

  if [[ "$phase" == "compile" ]]; then
    echo "[edge:compile] $case_name"
    if output="$("$HL" "$NVSLC_BIN" "$case_dir" "$output_path" 2>&1)"; then
      echo "Expected compile failure for $case_name" >&2
      exit 1
    fi
  elif [[ "$phase" == "runtime" ]]; then
    local entry
    entry="$(<"$case_dir/entry.txt")"

    echo "[edge:runtime] compile $case_name"
    "$HL" "$NVSLC_BIN" "$case_dir" "$output_path" --entry "$entry" >/dev/null

    echo "[edge:runtime] run $case_name"
    if output="$("$HL" "$NVSLVM_BIN" "$output_path" 2>&1)"; then
      echo "Expected runtime failure for $case_name" >&2
      exit 1
    fi
  else
    echo "Unknown edge phase '$phase' for $case_name" >&2
    exit 1
  fi

  if [[ "$output" != *"$expected_error"* ]]; then
    echo "Expected error containing '$expected_error' for $case_name" >&2
    echo "Actual output:" >&2
    echo "$output" >&2
    exit 1
  fi
}

while IFS= read -r -d '' case_dir; do
  run_ok_case "$case_dir"
done < <(find "$SAMPLES_ROOT/ok" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

while IFS= read -r -d '' case_dir; do
  run_edge_case "$case_dir"
done < <(find "$SAMPLES_ROOT/edge" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

echo "[done] all NVSL sample checks passed"
