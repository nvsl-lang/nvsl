#!/usr/bin/env bash
set -euo pipefail

nvsl_stage_bundle_common() {
  local root="$1"
  local stage_dir="$2"

  rm -rf "$stage_dir"
  mkdir -p "$stage_dir/bin" "$stage_dir/scripts"

  cp "$root/README.md" "$stage_dir/"
  cp "$root/INSTALL.md" "$stage_dir/"
  cp "$root/LICENSE" "$stage_dir/"
  cp "$root/nvsl" "$stage_dir/"
  cp "$root/nvslc" "$stage_dir/"
  cp "$root/nvslvm" "$stage_dir/"
  cp "$root/scripts/nvsl-env.sh" "$stage_dir/scripts/"
  cp "$root/bin/nvslc.hl" "$stage_dir/bin/"
  cp "$root/bin/nvslvm.hl" "$stage_dir/bin/"

  for file in nvsl.cmd nvslc.cmd nvslvm.cmd; do
    if [[ -f "$root/$file" ]]; then
      cp "$root/$file" "$stage_dir/"
    fi
  done

  for file in nvsl-common.ps1 nvsl.ps1 nvslc.ps1 nvslvm.ps1; do
    if [[ -f "$root/scripts/$file" ]]; then
      cp "$root/scripts/$file" "$stage_dir/scripts/"
    fi
  done

  chmod +x \
    "$stage_dir/nvsl" \
    "$stage_dir/nvslc" \
    "$stage_dir/nvslvm" \
    "$stage_dir/scripts/nvsl-env.sh"
}

nvsl_copy_matching_runtime_files() {
  local src_dir="$1"
  local name_pattern="$2"
  local dest_dir="$3"
  local nullglob_was_set=0
  local path
  local copied=1

  if shopt -q nullglob; then
    nullglob_was_set=1
  fi
  shopt -s nullglob

  for path in "$src_dir"/$name_pattern; do
    cp -a "$path" "$dest_dir/"
    copied=0
  done

  if [[ $nullglob_was_set -eq 0 ]]; then
    shopt -u nullglob
  fi

  return "$copied"
}

nvsl_first_staged_runtime_file() {
  local stage_dir="$1"
  local name_pattern="$2"
  local nullglob_was_set=0
  local path

  if shopt -q nullglob; then
    nullglob_was_set=1
  fi
  shopt -s nullglob

  for path in "$stage_dir"/$name_pattern; do
    printf '%s\n' "$path"
    break
  done

  if [[ $nullglob_was_set -eq 0 ]]; then
    shopt -u nullglob
  fi
}

nvsl_ensure_runtime_alias() {
  local stage_dir="$1"
  local required_name="$2"
  local fallback_pattern="$3"

  if [[ -z "$required_name" || -e "$stage_dir/$required_name" ]]; then
    return 0
  fi

  local fallback
  fallback="$(nvsl_first_staged_runtime_file "$stage_dir" "$fallback_pattern")"
  if [[ -z "$fallback" ]]; then
    return 1
  fi

  ln -s "$(basename "$fallback")" "$stage_dir/$required_name"
}

nvsl_linux_needed_libhl_name() {
  local hl_path="$1"

  if ! command -v readelf >/dev/null 2>&1; then
    return 0
  fi

  readelf -d "$hl_path" 2>/dev/null | awk -F'[][]' '/NEEDED/ && $2 ~ /^libhl\.so(\..*)?$/ { print $2; exit }'
}

nvsl_linux_resolved_libhl_path() {
  local hl_path="$1"
  local needed_name="${2:-}"

  if ! command -v ldd >/dev/null 2>&1; then
    return 0
  fi

  ldd "$hl_path" 2>/dev/null | awk -v needed_name="$needed_name" '
    needed_name != "" && $1 == needed_name && $3 ~ /^\// { print $3; exit }
    $1 ~ /^libhl\.so(\..*)?$/ && $3 ~ /^\// { print $3; exit }
  '
}

nvsl_macos_needed_libhl_name() {
  local hl_path="$1"

  if ! command -v otool >/dev/null 2>&1; then
    return 0
  fi

  otool -L "$hl_path" 2>/dev/null | awk '
    NR > 1 && $1 ~ /libhl[^[:space:]]*\.dylib$/ {
      n = split($1, parts, "/")
      print parts[n]
      exit
    }
  '
}

nvsl_macos_resolved_libhl_path() {
  local hl_path="$1"
  local needed_name="${2:-}"

  if ! command -v otool >/dev/null 2>&1; then
    return 0
  fi

  otool -L "$hl_path" 2>/dev/null | awk -v needed_name="$needed_name" '
    NR <= 1 {
      next
    }
    $1 ~ /libhl[^[:space:]]*\.dylib$/ {
      n = split($1, parts, "/")
      base = parts[n]
      if (needed_name == "" || base == needed_name) {
        if ($1 ~ /^\//) {
          print $1
          exit
        }
      }
    }
  '
}

nvsl_stage_linux_runtime_libs() {
  local runtime_bin_dir="$1"
  local stage_bin_dir="$2"
  local hl_path="$runtime_bin_dir/hl"

  nvsl_copy_matching_runtime_files "$runtime_bin_dir" 'libhl.so*' "$stage_bin_dir" || true

  local needed_name
  needed_name="$(nvsl_linux_needed_libhl_name "$hl_path")"

  if [[ -z "$(nvsl_first_staged_runtime_file "$stage_bin_dir" 'libhl.so*')" ]]; then
    local resolved_path
    resolved_path="$(nvsl_linux_resolved_libhl_path "$hl_path" "$needed_name")"
    if [[ -n "$resolved_path" && -f "$resolved_path" ]]; then
      cp "$resolved_path" "$stage_bin_dir/$(basename "$resolved_path")"
    fi
  fi

  if [[ -z "$(nvsl_first_staged_runtime_file "$stage_bin_dir" 'libhl.so*')" ]]; then
    echo "Missing staged Linux HashLink runtime library for $hl_path." >&2
    exit 1
  fi

  if ! nvsl_ensure_runtime_alias "$stage_bin_dir" "$needed_name" 'libhl.so*'; then
    echo "Missing staged Linux HashLink runtime library for $hl_path." >&2
    exit 1
  fi

  if [[ -n "$needed_name" && ! -e "$stage_bin_dir/$needed_name" ]]; then
    echo "Linux bundle is missing required HashLink library '$needed_name'." >&2
    exit 1
  fi
}

nvsl_stage_macos_runtime_libs() {
  local runtime_bin_dir="$1"
  local stage_bin_dir="$2"
  local hl_path="$runtime_bin_dir/hl"

  nvsl_copy_matching_runtime_files "$runtime_bin_dir" 'libhl*.dylib' "$stage_bin_dir" || true

  local needed_name
  needed_name="$(nvsl_macos_needed_libhl_name "$hl_path")"

  if [[ -z "$(nvsl_first_staged_runtime_file "$stage_bin_dir" 'libhl*.dylib')" ]]; then
    local resolved_path
    resolved_path="$(nvsl_macos_resolved_libhl_path "$hl_path" "$needed_name")"
    if [[ -n "$resolved_path" && -f "$resolved_path" ]]; then
      cp "$resolved_path" "$stage_bin_dir/$(basename "$resolved_path")"
    fi
  fi

  if [[ -z "$(nvsl_first_staged_runtime_file "$stage_bin_dir" 'libhl*.dylib')" ]]; then
    echo "Missing staged macOS HashLink runtime library for $hl_path." >&2
    exit 1
  fi

  if ! nvsl_ensure_runtime_alias "$stage_bin_dir" "$needed_name" 'libhl*.dylib'; then
    echo "Missing staged macOS HashLink runtime library for $hl_path." >&2
    exit 1
  fi

  if [[ -n "$needed_name" && ! -e "$stage_bin_dir/$needed_name" ]]; then
    echo "macOS bundle is missing required HashLink library '$needed_name'." >&2
    exit 1
  fi
}

nvsl_archive_tar_gz() {
  local dist_dir="$1"
  local bundle_name="$2"
  local archive_path="$3"

  tar -czf "$archive_path" -C "$dist_dir" "$bundle_name"
}

nvsl_archive_zip() {
  local dist_dir="$1"
  local bundle_name="$2"
  local archive_path="$3"

  rm -f "$archive_path"

  if command -v powershell.exe >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
    local bundle_win
    local archive_win
    bundle_win="$(cygpath -w "$dist_dir/$bundle_name")"
    archive_win="$(cygpath -w "$archive_path")"
    powershell.exe -NoLogo -NoProfile -Command "Compress-Archive -Path '$bundle_win' -DestinationPath '$archive_win' -Force" >/dev/null
    return 0
  fi

  (
    cd "$dist_dir"
    zip -qr "$archive_path" "$bundle_name"
  )
}
