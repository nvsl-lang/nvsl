# NVSL

`NVSL` is a small, safe game scripting language.

It is designed for strict, sandboxed scripting in games, but it is not tied to one engine or genre. You can use it for story flow, events, state changes, gameplay scripting, or host-driven runtime commands.

The toolchain is written in Haxe, so it can be embedded anywhere Haxe targets run, including HashLink, C++, JS, and other Haxe runtime targets.

## What Is Here

- parser and lexer
- type checker
- project loader and linker
- AST runtime
- bytecode compiler
- bytecode VM
- benchmark harness
- docs
- samples

## Repo Layout

- [src/novel/script](./src/novel/script): core source
- [src/novel/script/docs](./src/novel/script/docs): reference docs
- [src/novel/script/samples](./src/novel/script/samples): runnable samples and edge cases

## Quick Start

See [INSTALL.md](./INSTALL.md) for full install and run instructions across Linux, Windows, and macOS.

From source on Linux:

```bash
./install.sh
```

From a release bundle:

```bash
./nvsl run path/to/scripts --entry game.app.main
```

Current release bundles:

- `nvsl-linux-x64.tar.gz`
- `nvsl-macos-x64.tar.gz`
- `nvsl-windows-x64.zip`

The packaged bundles include the local HashLink runtime, so users do not need to install `hl` separately for the shipped bundles.

Compile and run a source project in one command:

```bash
./nvsl run path/to/scripts --entry game.app.main
```

Compile a source project into bytecode:

```bash
./nvslc path/to/scripts bin/game.nvbc --entry game.app.main
```

Run compiled bytecode:

```bash
./nvslvm bin/game.nvbc
```

Run a specific entrypoint:

```bash
./nvslvm bin/game.nvbc game.app.main
```

The wrapper scripts auto-build `nvslc` and `nvslvm` if the local `bin/` outputs are missing or stale.

If you want the raw underlying commands, they are still:

```bash
haxe build.nvslc.hxml
haxe build.nvslvm.hxml
hl bin/nvslc.hl path/to/scripts bin/game.nvbc --entry game.app.main
hl bin/nvslvm.hl bin/game.nvbc
```

Run the bundled samples:

```bash
./nvsl samples
```

Run the built-in benchmark from a source checkout:

```bash
./nvsl bench
```

## Add To PATH

From the repo root, add the local command wrappers to your shell `PATH`:

```bash
export PATH="/absolute/path/to/nvsl:$PATH"
```

Example:

```bash
export PATH="$HOME/Desktop/nvsl:$PATH"
```

Then you can run:

```bash
nvsl run path/to/scripts --entry game.app.main
nvslc path/to/scripts bin/game.nvbc --entry game.app.main
nvslvm bin/game.nvbc
```

If you want this permanently, add the `export PATH=...` line to your shell profile such as `~/.bashrc` or `~/.zshrc`.

## Cross-Platform Status

The language core is cross-platform.

- `NVSL`, `nvslc`, and `nvslvm` are written in Haxe
- the compiler/runtime can be built anywhere the Haxe target and host runtime are supported
- the repo-level source convenience scripts are still Linux/Bash-first
- packaged release bundles are prepared for Linux, Windows, and macOS

So the honest answer is:

- language/toolchain architecture: cross-platform
- source install helpers: primarily Linux-oriented
- packaged bundles: cross-platform for the supported release targets

If you already have Haxe and HashLink on another platform, the raw build/run commands still work:

```bash
haxe build.nvslc.hxml
haxe build.nvslvm.hxml
hl bin/nvslc.hl path/to/scripts bin/game.nvbc --entry game.app.main
hl bin/nvslvm.hl bin/game.nvbc
```

## Automation

This repo includes GitHub Actions for:

- CI builds on pushes and pull requests
- sample-suite validation
- tagged releases that attach `nvslc.hl` and `nvslvm.hl` build artifacts

The workflows install Haxe and HashLink on Linux before running the build and sample checks.

## Main Commands

- [install.sh](./install.sh): install Linux dependencies and build the tools
- [nvsl](./nvsl): convenience wrapper for build, run, check, and sample validation
- [nvsl.cmd](./nvsl.cmd): Windows command launcher for `nvsl`
- [nvslc](./nvslc): wrapper for the bytecode compiler
- [nvslc.cmd](./nvslc.cmd): Windows command launcher for `nvslc`
- [nvslvm](./nvslvm): wrapper for the bytecode VM
- [nvslvm.cmd](./nvslvm.cmd): Windows command launcher for `nvslvm`
- [nvslbench](./nvslbench): wrapper for the built-in benchmark harness
- [nvslbench.cmd](./nvslbench.cmd): Windows command launcher for `nvslbench`
- [scripts/build-hashlink-runtime.sh](./scripts/build-hashlink-runtime.sh): build the core HashLink runtime for bundle packaging
- [scripts/package-linux-bundle.sh](./scripts/package-linux-bundle.sh): build a self-contained Linux release bundle
- [scripts/package-macos-bundle.sh](./scripts/package-macos-bundle.sh): build a self-contained macOS release bundle
- [scripts/package-windows-bundle.sh](./scripts/package-windows-bundle.sh): build a self-contained Windows release bundle
- [INSTALL.md](./INSTALL.md): install and run guide

## Main Entry Points

- [ScriptEngine.hx](./src/novel/script/ScriptEngine.hx)
- [docs/README.md](./src/novel/script/docs/README.md)
- [CORE_LANGUAGE.md](./src/novel/script/CORE_LANGUAGE.md)
- [INSTALL.md](./INSTALL.md)
- [src/novel/script/docs/benchmarking.md](./src/novel/script/docs/benchmarking.md)
- [CONTRIBUTING.md](./CONTRIBUTING.md)

## License

MIT. See [LICENSE](./LICENSE).
