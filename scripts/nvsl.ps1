Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "nvsl-common.ps1")

$nvslRoot = Get-NvslRoot $PSScriptRoot

function Show-Usage {
  @"
usage:
  nvsl build <source-path> <output.nvbc> [--entry module.export] [--extension .nvsl]
  nvsl run <source-path|program.nvbc> [--entry module.export] [--extension .nvsl] [--out output.nvbc]
  nvsl check <source-path> [--entry module.export] [--extension .nvsl]
  nvsl vm <program.nvbc> [module.export]
  nvsl samples
"@ | Write-Host
}

function Invoke-Nvslc {
  param([string[]]$Arguments)
  & (Join-Path $PSScriptRoot "nvslc.ps1") @Arguments
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

function Invoke-Nvslvm {
  param([string[]]$Arguments)
  & (Join-Path $PSScriptRoot "nvslvm.ps1") @Arguments
  exit $LASTEXITCODE
}

if ($args.Count -eq 0) {
  Show-Usage
  exit 0
}

$commandName = $args[0]
$remaining = @()
if ($args.Count -gt 1) {
  $remaining = @($args[1..($args.Count - 1)])
}

switch ($commandName) {
  { $_ -in @("build", "compile") } {
    if ($remaining.Count -lt 2) {
      Show-Usage
      exit 1
    }

    $sourceDir = Resolve-NvslSourceDir $remaining[0]
    $forwardArgs = @($sourceDir) + @($remaining[1..($remaining.Count - 1)])
    Invoke-Nvslc $forwardArgs
  }

  "run" {
    if ($remaining.Count -lt 1) {
      Show-Usage
      exit 1
    }

    $inputPath = $remaining[0]
    $extraArgs = @()
    if ($remaining.Count -gt 1) {
      $extraArgs = @($remaining[1..($remaining.Count - 1)])
    }

    $entry = $null
    $extension = ".nvsl"
    $outputPath = $null

    for ($i = 0; $i -lt $extraArgs.Count; $i++) {
      switch ($extraArgs[$i]) {
        "--entry" {
          if ($i + 1 -ge $extraArgs.Count) { throw "Missing value after --entry." }
          $entry = $extraArgs[$i + 1]
          $i++
        }
        "--extension" {
          if ($i + 1 -ge $extraArgs.Count) { throw "Missing value after --extension." }
          $extension = $extraArgs[$i + 1]
          $i++
        }
        "--out" {
          if ($i + 1 -ge $extraArgs.Count) { throw "Missing value after --out." }
          $outputPath = $extraArgs[$i + 1]
          $i++
        }
        default {
          throw "Unknown option '$($extraArgs[$i])' for nvsl run."
        }
      }
    }

    if ((Test-Path $inputPath -PathType Leaf) -and $inputPath.ToLowerInvariant().EndsWith(".nvbc")) {
      if ($extension -ne ".nvsl" -or $outputPath) {
        throw "Do not pass --extension or --out when running an existing .nvbc file."
      }

      if ($entry) {
        Invoke-Nvslvm @($inputPath, $entry)
      } else {
        Invoke-Nvslvm @($inputPath)
      }
    }

    $sourceDir = Resolve-NvslSourceDir $inputPath
    $cleanupPath = $null

    if (-not $outputPath) {
      $cleanupPath = Join-Path $env:TEMP ("nvsl-run-" + [System.Guid]::NewGuid().ToString("N"))
      New-Item -ItemType Directory -Path $cleanupPath | Out-Null
      $outputPath = Join-Path $cleanupPath "program.nvbc"
    }

    try {
      $compileArgs = @($sourceDir, $outputPath)
      if ($entry) {
        $compileArgs += @("--entry", $entry)
      }
      if ($extension -ne ".nvsl") {
        $compileArgs += @("--extension", $extension)
      }

      Invoke-Nvslc $compileArgs

      if ($entry) {
        Invoke-Nvslvm @($outputPath, $entry)
      } else {
        Invoke-Nvslvm @($outputPath)
      }
    } finally {
      if ($cleanupPath -and (Test-Path $cleanupPath)) {
        Remove-Item -Recurse -Force $cleanupPath
      }
    }
  }

  "check" {
    if ($remaining.Count -lt 1) {
      Show-Usage
      exit 1
    }

    $inputPath = $remaining[0]
    $extraArgs = @()
    if ($remaining.Count -gt 1) {
      $extraArgs = @($remaining[1..($remaining.Count - 1)])
    }

    $entry = $null
    $extension = ".nvsl"

    for ($i = 0; $i -lt $extraArgs.Count; $i++) {
      switch ($extraArgs[$i]) {
        "--entry" {
          if ($i + 1 -ge $extraArgs.Count) { throw "Missing value after --entry." }
          $entry = $extraArgs[$i + 1]
          $i++
        }
        "--extension" {
          if ($i + 1 -ge $extraArgs.Count) { throw "Missing value after --extension." }
          $extension = $extraArgs[$i + 1]
          $i++
        }
        default {
          throw "Unknown option '$($extraArgs[$i])' for nvsl check."
        }
      }
    }

    $sourceDir = Resolve-NvslSourceDir $inputPath
    $tmpDir = Join-Path $env:TEMP ("nvsl-check-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    $outputPath = Join-Path $tmpDir "program.nvbc"

    try {
      $compileArgs = @($sourceDir, $outputPath)
      if ($entry) {
        $compileArgs += @("--entry", $entry)
      }
      if ($extension -ne ".nvsl") {
        $compileArgs += @("--extension", $extension)
      }

      Invoke-Nvslc $compileArgs
      Write-Host "NVSL check passed for $sourceDir"
    } finally {
      if (Test-Path $tmpDir) {
        Remove-Item -Recurse -Force $tmpDir
      }
    }

    exit 0
  }

  "vm" {
    if ($remaining.Count -lt 1) {
      Show-Usage
      exit 1
    }

    Invoke-Nvslvm $remaining
  }

  "samples" {
    $sampleScript = Join-Path $nvslRoot "src\novel\script\samples\check-samples.sh"
    if (-not (Test-Path $sampleScript)) {
      throw "Sample validation is only available in a source checkout."
    }

    $bash = Get-Command "bash.exe" -ErrorAction SilentlyContinue
    if (-not $bash) {
      $bash = Get-Command "bash" -ErrorAction SilentlyContinue
    }
    if (-not $bash) {
      throw "Sample validation on Windows requires bash to run the sample checker."
    }

    & $bash.Source $sampleScript
    exit $LASTEXITCODE
  }

  default {
    throw "Unknown command '$commandName'."
  }
}
