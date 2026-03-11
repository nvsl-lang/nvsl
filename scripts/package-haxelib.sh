#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

package_name="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${repo_root}/haxelib.json" | head -n 1)"
package_version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${repo_root}/haxelib.json" | head -n 1)"

if [[ -z "${package_name}" || -z "${package_version}" ]]; then
	echo "Failed to read name/version from haxelib.json" >&2
	exit 1
fi

stage_dir="$(mktemp -d /tmp/${package_name}-haxelib.XXXXXX)"
tmp_zip="/tmp/${package_name}-${package_version}-haxelib.zip"
output_zip="${repo_root}/dist/${package_name}-${package_version}-haxelib.zip"

cleanup() {
	rm -rf "${stage_dir}"
	rm -f "${tmp_zip}"
}

trap cleanup EXIT

mkdir -p "${repo_root}/dist"

cp -R "${repo_root}/src" "${stage_dir}/src"
cp "${repo_root}/README.md" "${stage_dir}/README.md"
cp "${repo_root}/LICENSE" "${stage_dir}/LICENSE"
cp "${repo_root}/haxelib.json" "${stage_dir}/haxelib.json"
cp "${repo_root}/build.nvslc.hxml" "${stage_dir}/build.nvslc.hxml"
cp "${repo_root}/build.nvslvm.hxml" "${stage_dir}/build.nvslvm.hxml"
cp "${repo_root}/build.nvslbench.hxml" "${stage_dir}/build.nvslbench.hxml"
cp "${repo_root}/build.script.hxml" "${stage_dir}/build.script.hxml"
cp "${repo_root}/INSTALL.md" "${stage_dir}/INSTALL.md"

(
	cd "${stage_dir}"
	zip -qr "${tmp_zip}" \
		src \
		README.md \
		LICENSE \
		haxelib.json \
		build.nvslc.hxml \
		build.nvslvm.hxml \
		build.nvslbench.hxml \
		build.script.hxml \
		INSTALL.md
)

mv -f "${tmp_zip}" "${output_zip}"
echo "Wrote ${output_zip}"
echo "Next: haxelib submit ${output_zip}"
