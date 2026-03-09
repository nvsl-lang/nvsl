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

Install the Linux toolchain and build the local tools:

```bash
./install.sh
```

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

## Main Entry Points

- [ScriptEngine.hx](./src/novel/script/ScriptEngine.hx)
- [docs/README.md](./src/novel/script/docs/README.md)
- [CORE_LANGUAGE.md](./src/novel/script/CORE_LANGUAGE.md)

## License

MIT. See [LICENSE](./LICENSE).
