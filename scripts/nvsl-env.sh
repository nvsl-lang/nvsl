#!/usr/bin/env bash

if [[ -n "${NVSL_ENV_LOADED:-}" ]]; then
  return 0
fi
NVSL_ENV_LOADED=1

NVSL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NVSL_ROOT

nvsl_require_haxe() {
  if command -v haxe >/dev/null 2>&1; then
    return 0
  fi

  echo "Missing Haxe. Install it first or run ./install.sh on Linux." >&2
  exit 1
}

nvsl_require_hl() {
  if [[ -n "${NVSL_HL:-}" && -x "${NVSL_HL}" ]]; then
    export NVSL_HL
    return 0
  fi

  if [[ -n "${HL:-}" && -x "${HL}" ]]; then
    NVSL_HL="${HL}"
    export NVSL_HL
    return 0
  fi

  if command -v hl >/dev/null 2>&1; then
    NVSL_HL="$(command -v hl)"
    export NVSL_HL
    return 0
  fi

  if [[ -x "$NVSL_ROOT/.deps/hashlink/hl" ]]; then
    NVSL_HL="$NVSL_ROOT/.deps/hashlink/hl"
    export NVSL_HL
    return 0
  fi

  echo "Missing HashLink runtime. Install HashLink first or run ./install.sh on Linux." >&2
  exit 1
}

nvsl_build_file_for() {
  case "$1" in
    nvslc)
      printf '%s\n' "$NVSL_ROOT/build.nvslc.hxml"
      ;;
    nvslvm)
      printf '%s\n' "$NVSL_ROOT/build.nvslvm.hxml"
      ;;
    *)
      echo "Unknown NVSL tool '$1'." >&2
      exit 1
      ;;
  esac
}

nvsl_output_for() {
  case "$1" in
    nvslc)
      printf '%s\n' "$NVSL_ROOT/bin/nvslc.hl"
      ;;
    nvslvm)
      printf '%s\n' "$NVSL_ROOT/bin/nvslvm.hl"
      ;;
    *)
      echo "Unknown NVSL tool '$1'." >&2
      exit 1
      ;;
  esac
}

nvsl_tool_needs_rebuild() {
  local tool="$1"
  local output
  output="$(nvsl_output_for "$tool")"
  local build_file
  build_file="$(nvsl_build_file_for "$tool")"

  if [[ "${NVSL_FORCE_REBUILD:-0}" == "1" ]]; then
    return 0
  fi

  if [[ ! -f "$output" ]]; then
    return 0
  fi

  if [[ "$build_file" -nt "$output" ]]; then
    return 0
  fi

  if [[ -d "$NVSL_ROOT/src" ]] && find "$NVSL_ROOT/src" -type f -newer "$output" -print -quit | grep -q .; then
    return 0
  fi

  return 1
}

nvsl_build_tool() {
  local tool="$1"
  local build_file
  build_file="$(nvsl_build_file_for "$tool")"

  nvsl_require_haxe
  mkdir -p "$NVSL_ROOT/bin"
  (
    cd "$NVSL_ROOT"
    haxe "$build_file"
  )
}

nvsl_ensure_tool() {
  local tool="$1"
  local output
  output="$(nvsl_output_for "$tool")"

  nvsl_require_hl

  if nvsl_tool_needs_rebuild "$tool"; then
    echo "[build] $tool"
    nvsl_build_tool "$tool"
  fi

  if [[ ! -f "$output" ]]; then
    echo "Expected built tool at $output but it was not produced." >&2
    exit 1
  fi
}
