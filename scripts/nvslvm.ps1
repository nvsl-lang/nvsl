Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "nvsl-common.ps1")

$nvslRoot = Get-NvslRoot $PSScriptRoot
Ensure-NvslTool $nvslRoot "nvslvm"
$hlPath = Get-NvslHlPath $nvslRoot
$toolPath = Join-Path $nvslRoot "bin\nvslvm.hl"

& $hlPath $toolPath @args
exit $LASTEXITCODE
