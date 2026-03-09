# NVSL

`NVSL` is a small, safe game scripting language.

It is not tied to one genre. You can use it anywhere you need strict, sandboxed scripting for game logic, story flow, events, state changes, or host-driven runtime commands.

The toolchain is written in Haxe, so you can embed or build it anywhere Haxe targets run, including HashLink, C++, JS, and other Haxe runtime targets.

This package contains:

- the parser
- the checker
- the project/linker layer
- the AST interpreter
- the bytecode compiler
- the bytecode VM
- docs
- samples

## Quick Start

Build the compiler:

```bash
haxe build.nvslc.hxml
```

Build the VM:

```bash
haxe build.nvslvm.hxml
```

Compile a script project directory into bytecode:

```bash
hl bin/nvslc.hl path/to/scripts bin/game.nvbc --entry game.app.main
```

Run compiled bytecode:

```bash
hl bin/nvslvm.hl bin/game.nvbc
```

Run a specific entrypoint explicitly:

```bash
hl bin/nvslvm.hl bin/game.nvbc game.app.main
```

If `hl` is not on your `PATH`, replace it with the full path to your HashLink binary.

Check the bundled samples:

```bash
./src/novel/script/samples/check-samples.sh
```

## Main Entry Points

- [ScriptEngine.hx](./ScriptEngine.hx)
- [docs/README.md](./docs/README.md)
- [CORE_LANGUAGE.md](./CORE_LANGUAGE.md)

## Docs

Reference docs live in:

- [docs/README.md](./docs/README.md)

## Samples

Runnable samples and edge cases live in:

- [samples/README.md](./samples/README.md)
