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

Build the compiler:

```bash
haxe build.nvslc.hxml
```

Build the VM:

```bash
haxe build.nvslvm.hxml
```

Compile a script directory into bytecode:

```bash
hl bin/nvslc.hl path/to/scripts bin/game.nvbc --entry game.app.main
```

Run compiled bytecode:

```bash
hl bin/nvslvm.hl bin/game.nvbc
```

Run a specific entrypoint:

```bash
hl bin/nvslvm.hl bin/game.nvbc game.app.main
```

If `hl` is not on your `PATH`, replace it with the full path to your HashLink binary.

Run the bundled samples:

```bash
./src/novel/script/samples/check-samples.sh
```

## Automation

This repo includes GitHub Actions for:

- CI builds on pushes and pull requests
- sample-suite validation
- tagged releases that attach `nvslc.hl` and `nvslvm.hl` build artifacts

The workflows install Haxe and HashLink on Linux before running the build and sample checks.

## Main Entry Points

- [ScriptEngine.hx](./src/novel/script/ScriptEngine.hx)
- [docs/README.md](./src/novel/script/docs/README.md)
- [CORE_LANGUAGE.md](./src/novel/script/CORE_LANGUAGE.md)

## License

MIT. See [LICENSE](./LICENSE).
