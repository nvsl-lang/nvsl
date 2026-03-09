Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "nvsl-common.ps1")

$nvslRoot = Get-NvslRoot $PSScriptRoot
Ensure-NvslTool $nvslRoot "nvslc"
$hlPath = Get-NvslHlPath $nvslRoot
$toolPath = Join-Path $nvslRoot "bin\nvslc.hl"

& $hlPath $toolPath @args
exit $LASTEXITCODE
