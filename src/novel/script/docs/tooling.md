# Tooling

This file documents the current `NVSL` tooling surface.

## Main Pieces

- `NVSL`: source files, usually `.nvsl`
- `nvslc`: source-to-bytecode compiler
- `NVBC`: bytecode format
- `nvslvm`: bytecode runtime
- `./nvsl`: convenience wrapper for build, run, check, and sample validation

## Build Files

Current Haxe build files:

- [build.script.hxml](../../../../build.script.hxml)
- [build.nvslc.hxml](../../../../build.nvslc.hxml)
- [build.nvslvm.hxml](../../../../build.nvslvm.hxml)

## Simple Wrapper Commands

Repo-root helper scripts:

- [../../../../install.sh](../../../../install.sh): Linux toolchain install plus local build
- [../../../../nvsl](../../../../nvsl): convenience command
- [../../../../nvslc](../../../../nvslc): wrapper for the compiler
- [../../../../nvslvm](../../../../nvslvm): wrapper for the VM
- [../../../../scripts/build-tools.sh](../../../../scripts/build-tools.sh): build local `.hl` tools

Recommended source checkout flow:

```bash
./install.sh
./nvsl run path/to/scripts --entry game.app.main
```

If you already have Haxe and HashLink:

```bash
./scripts/build-tools.sh
./nvslc path/to/scripts bin/game.nvbc --entry game.app.main
./nvslvm bin/game.nvbc
```

The wrapper scripts auto-build `bin/nvslc.hl` and `bin/nvslvm.hl` when needed.

## `./nvsl`

Purpose:

- compile and run source projects with one command
- validate source projects without keeping output
- forward to the VM path for existing `.nvbc` files
- run the bundled sample suite

Usage:

```bash
./nvsl build <source-path> <output.nvbc> [--entry module.export] [--extension .nvsl]
./nvsl run <source-path|program.nvbc> [--entry module.export] [--extension .nvsl] [--out output.nvbc]
./nvsl check <source-path> [--entry module.export] [--extension .nvsl]
./nvsl vm <program.nvbc> [module.export]
./nvsl samples
```

Notes:

- `<source-path>` may be a directory or a single `.nvsl` file
- `./nvsl run` compiles to a temporary `.nvbc` unless `--out` is provided
- source runs usually need `--entry` unless the project already stores a default entrypoint

## `nvslc`

Source:

- [NvslcMain.hx](../tools/NvslcMain.hx)

Purpose:

- load a directory of `.nvsl` modules
- parse and type-check them
- optionally validate a default entrypoint
- compile them to `NVBC`
- write one `.nvbc` output file

Usage:

```bash
hl bin/nvslc.hl <source-dir> <output.nvbc> [--entry module.export] [--extension .nvsl]
```

Arguments:

- `<source-dir>`: root directory to scan recursively for source files
- `<output.nvbc>`: output path for encoded bytecode
- `--entry module.export`: optional default entrypoint stored in the bytecode
- `--extension .nvsl`: optional file extension override

Example:

```bash
./nvslc game/scripts bin/game.nvbc --entry game.app.main
```

## `nvslvm`

Source:

- [NvslVmMain.hx](../tools/NvslVmMain.hx)

Purpose:

- load a compiled `.nvbc` file
- execute either:
  - the explicit entry passed on the command line
  - the default entry stored in the bytecode

Usage:

```bash
hl bin/nvslvm.hl <program.nvbc> [module.export]
```

Arguments:

- `<program.nvbc>`: encoded bytecode file
- `[module.export]`: optional explicit entrypoint to call with zero arguments

Example:

```bash
./nvslvm bin/game.nvbc game.app.main
```

If `hl` is not on your `PATH`, the wrappers also respect `HL=/path/to/hl`.

If the second argument is omitted, `nvslvm` uses the program default entrypoint.

## Engine API

Public entrypoints are exposed from:

- [ScriptEngine.hx](../ScriptEngine.hx)

Important methods:

- `parse`
- `parseSources`
- `parseDirectory`
- `check`
- `checkProject`
- `linkProject`
- `linkSources`
- `linkDirectory`
- `compileProject`
- `compileSources`
- `compileDirectory`
- `encodeBytecode`
- `decodeBytecode`
- `loadProject`
- `loadSources`
- `loadDirectory`
- `loadBytecode`
- `loadBytecodeJson`

## Recommended Workflow

### Dev / editor path

Use the AST interpreter:

1. load source files
2. type-check
3. run directly
4. use execution snapshots when needed

### Shipping path

Use the bytecode path:

1. compile source with `nvslc`
2. ship `.nvbc`
3. run it with `nvslvm` or the embedded VM API

## Sample Projects

Runnable sample projects and edge cases live in:

- [../samples/README.md](../samples/README.md)

Quick checker:

```bash
./nvsl samples
```

## Current Limits

The compiler/VM path now supports the frozen NVSL core, including:

- anonymous lambdas
- named function values
- builtin function values
- higher-order closure calls
- resumable execution snapshots in `nvslvm`
