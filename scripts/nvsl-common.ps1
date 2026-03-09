Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-NvslRoot {
  param([string]$ScriptRoot)
  return (Resolve-Path (Join-Path $ScriptRoot "..")).Path
}

function Set-NvslRuntimePath {
  param([string]$NvslRoot)

  $binDir = Join-Path $NvslRoot "bin"
  if (Test-Path (Join-Path $binDir "libhl.dll")) {
    $env:PATH = "$binDir;$env:PATH"
  }
}

function Get-NvslHlPath {
  param([string]$NvslRoot)

  if ($env:NVSL_HL -and (Test-Path $env:NVSL_HL)) {
    return (Resolve-Path $env:NVSL_HL).Path
  }

  if ($env:HL -and (Test-Path $env:HL)) {
    return (Resolve-Path $env:HL).Path
  }

  $bundleHl = Join-Path $NvslRoot "bin\hl.exe"
  if (Test-Path $bundleHl) {
    Set-NvslRuntimePath $NvslRoot
    return $bundleHl
  }

  $pathHl = Get-Command "hl.exe" -ErrorAction SilentlyContinue
  if ($pathHl) {
    return $pathHl.Source
  }

  $depsHl = Join-Path $NvslRoot ".deps\hashlink\hl.exe"
  if (Test-Path $depsHl) {
    return $depsHl
  }

  throw "Missing HashLink runtime. Install HashLink first or use a Windows release bundle that includes bin\hl.exe."
}

function Get-NvslBuildFile {
  param(
    [string]$NvslRoot,
    [ValidateSet("nvslc", "nvslvm")][string]$Tool
  )

  switch ($Tool) {
    "nvslc" { return (Join-Path $NvslRoot "build.nvslc.hxml") }
    "nvslvm" { return (Join-Path $NvslRoot "build.nvslvm.hxml") }
  }
}

function Get-NvslToolOutput {
  param(
    [string]$NvslRoot,
    [ValidateSet("nvslc", "nvslvm")][string]$Tool
  )

  switch ($Tool) {
    "nvslc" { return (Join-Path $NvslRoot "bin\nvslc.hl") }
    "nvslvm" { return (Join-Path $NvslRoot "bin\nvslvm.hl") }
  }
}

function Test-NvslToolNeedsRebuild {
  param(
    [string]$NvslRoot,
    [ValidateSet("nvslc", "nvslvm")][string]$Tool
  )

  if ($env:NVSL_FORCE_REBUILD -eq "1") {
    return $true
  }

  $output = Get-NvslToolOutput $NvslRoot $Tool
  if (-not (Test-Path $output)) {
    return $true
  }

  $outputTime = (Get-Item $output).LastWriteTimeUtc
  $buildFile = Get-NvslBuildFile $NvslRoot $Tool
  if ((Test-Path $buildFile) -and ((Get-Item $buildFile).LastWriteTimeUtc -gt $outputTime)) {
    return $true
  }

  $srcDir = Join-Path $NvslRoot "src"
  if (Test-Path $srcDir) {
    $newerSource = Get-ChildItem -Path $srcDir -Recurse -File | Where-Object { $_.LastWriteTimeUtc -gt $outputTime } | Select-Object -First 1
    if ($newerSource) {
      return $true
    }
  }

  return $false
}

function Ensure-NvslHaxe {
  if (-not (Get-Command "haxe" -ErrorAction SilentlyContinue)) {
    throw "Missing Haxe. Install it first to build NVSL tools from source."
  }
}

function Build-NvslTool {
  param(
    [string]$NvslRoot,
    [ValidateSet("nvslc", "nvslvm")][string]$Tool
  )

  Ensure-NvslHaxe
  $buildFile = Get-NvslBuildFile $NvslRoot $Tool
  $binDir = Join-Path $NvslRoot "bin"
  if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir | Out-Null
  }

  Push-Location $NvslRoot
  try {
    & haxe $buildFile
    if ($LASTEXITCODE -ne 0) {
      throw "haxe failed while building $Tool."
    }
  } finally {
    Pop-Location
  }
}

function Ensure-NvslTool {
  param(
    [string]$NvslRoot,
    [ValidateSet("nvslc", "nvslvm")][string]$Tool
  )

  [void](Get-NvslHlPath $NvslRoot)

  if (Test-NvslToolNeedsRebuild $NvslRoot $Tool) {
    Write-Host "[build] $Tool"
    Build-NvslTool $NvslRoot $Tool
  }

  $output = Get-NvslToolOutput $NvslRoot $Tool
  if (-not (Test-Path $output)) {
    throw "Expected built tool at $output but it was not produced."
  }
}

function Resolve-NvslSourceDir {
  param([string]$InputPath)

  if (Test-Path $InputPath -PathType Container) {
    return (Resolve-Path $InputPath).Path
  }

  if (Test-Path $InputPath -PathType Leaf) {
    return (Resolve-Path (Split-Path -Parent $InputPath)).Path
  }

  throw "Source path '$InputPath' does not exist."
}
