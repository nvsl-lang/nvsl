# Bytecode Pipeline

## Names

- `NVSL`: source language
- `nvslc`: compiler from `.nvsl` source to bytecode
- `NVBC`: bytecode format
- `nvslvm`: bytecode virtual machine

## Why This Exists

The goal is not to transpile `NVSL` into many host languages.

The intended pipeline is:

1. author `.nvsl`
2. parse and type-check
3. compile to `NVBC`
4. ship `NVBC`
5. run `NVBC` through `nvslvm`

Because the compiler and VM are written in Haxe, the engine can still be built to HashLink, C++, JS, and other Haxe targets without maintaining separate script-language backends for each one.

## Current Status

Implemented now:

- `NVBC` program model
- `NVBC` JSON codec
- `nvslc` directory compiler CLI
- `nvslvm` bytecode loader/runtime CLI
- bytecode roundtrip tests
- bytecode runtime global snapshot/restore
- bytecode execution snapshot/restore
- direct and higher-order function calls
- anonymous lambdas and nested closure capture

The bytecode compiler/runtime now cover the frozen NVSL core, including resumable execution snapshots.

## CLI

Compile a directory:

```bash
haxe build.nvslc.hxml
hl bin/nvslc.hl game/scripts bin/game.nvbc --entry game.app.main
```

Run a compiled program:

```bash
haxe build.nvslvm.hxml
hl bin/nvslvm.hl bin/game.nvbc game.app.main
```

If `hl` is not on your `PATH`, replace it with the full path to your HashLink binary.

If no explicit entry is passed to `nvslvm`, it uses the default entry stored in the `NVBC` program.

## Engine API

Compile:

```haxe
var program = ScriptEngine.compileSources(inputs, "game.app", "main");
```

Encode:

```haxe
var encoded = ScriptEngine.encodeBytecode(program);
```

Load in the VM:

```haxe
var runtime = ScriptEngine.loadBytecode(program);
var result = runtime.callDefault([]);
```

## Snapshots

The bytecode VM supports project/global snapshots:

- mutable top-level globals
- initialization state
- serializable values
- schema/version checks

It also supports execution snapshots for live bytecode runs:

- active VM frames
- instruction pointers
- local scope environments
- value stacks
- builtin function values in flight
- bytecode closures and captured environments in flight

## Libraries

`NVBC` does not bake in a special engine namespace.

Right now the guaranteed builtin surface is `std.*`. Engine-facing modules should remain optional host libraries layered above the same bytecode/runtime system.
