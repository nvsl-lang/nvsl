Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "nvsl-common.ps1")

$nvslRoot = Get-NvslRoot $PSScriptRoot
$buildFile = Join-Path $nvslRoot "build.nvslbench.hxml"
if (-not (Test-Path $buildFile)) {
  throw "Benchmarking is only available in a source checkout."
}

Ensure-NvslTool $nvslRoot "nvslbench"
$hlPath = Get-NvslHlPath $nvslRoot
$toolPath = Join-Path $nvslRoot "bin\nvslbench.hl"

& $hlPath $toolPath @args
exit $LASTEXITCODE
