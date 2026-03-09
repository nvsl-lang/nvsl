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
- docs
- samples

## Repo Layout

- [src/novel/script](./src/novel/script): core source
- [src/novel/script/docs](./src/novel/script/docs): reference docs
- [src/novel/script/samples](./src/novel/script/samples): runnable samples and edge cases

## Quick Start

See [INSTALL.md](./INSTALL.md) for full install and run instructions.

From source on Linux:

```bash
./install.sh
```

From a Linux release bundle:

```bash
./nvsl run path/to/scripts --entry game.app.main
```

The Linux release bundle includes `bin/hl`, `bin/libhl.so`, `nvslc.hl`, and `nvslvm.hl`, so users do not need to install HashLink separately.

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
- the current convenience scripts and self-contained release bundle are Linux/Bash-first

So the honest answer is:

- language/toolchain architecture: cross-platform
- repo install helpers and packaged no-`hl` runtime right now: primarily Linux-oriented

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
- [nvslc](./nvslc): wrapper for the bytecode compiler
- [nvslvm](./nvslvm): wrapper for the bytecode VM
- [scripts/package-linux-bundle.sh](./scripts/package-linux-bundle.sh): build a self-contained Linux release bundle
- [INSTALL.md](./INSTALL.md): install and run guide

## Main Entry Points

- [ScriptEngine.hx](./src/novel/script/ScriptEngine.hx)
- [docs/README.md](./src/novel/script/docs/README.md)
- [CORE_LANGUAGE.md](./src/novel/script/CORE_LANGUAGE.md)
- [INSTALL.md](./INSTALL.md)
- [CONTRIBUTING.md](./CONTRIBUTING.md)

## License

MIT. See [LICENSE](./LICENSE).
