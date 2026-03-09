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
    powershell.exe -NoLogo -NoProfile -Command "Compress-Archive -Path '$bundle_win\\*' -DestinationPath '$archive_win' -Force" >/dev/null
    return 0
  fi

  (
    cd "$dist_dir"
    zip -qr "$archive_path" "$bundle_name"
  )
}
