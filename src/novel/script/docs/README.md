# NVSL Docs

This folder documents the `NVSL` scripting language.

The language is intentionally small. It is not meant to become a general-purpose programming language. Its job is to provide:

- strict syntax
- strict typing
- safe execution
- multi-file story projects
- save/load support
- resumable execution support
- a bytecode pipeline for shipping/runtime targets
- a clean foundation for safe host library modules

## Goals

- Keep authoring simple for VN content.
- Keep runtime behavior predictable and serializable.
- Prevent unsafe host access by construction.
- Make static checking happen before runtime.

## Current Layout

- [language-reference.md](./language-reference.md): syntax, types, declarations, expressions, semantics
- [grammar.md](./grammar.md): concrete grammar and lexical structure
- [std-library.md](./std-library.md): every `std.*` builtin with signatures and behavior
- [memory-model.md](./memory-model.md): cells, scopes, closures, stack/state behavior
- [errors.md](./errors.md): parse/check/compile/runtime error categories and diagnostics
- [host-libraries.md](./host-libraries.md): how engine-specific safe modules should layer on top
- [tooling.md](./tooling.md): `nvslc`, `nvslvm`, build files, bytecode flow
- [runtime.md](./runtime.md): parse/check/link/load flow, save/load, resume, interpreter/runtime model
- [bytecode.md](./bytecode.md): `NVSL`, `nvslc`, `NVBC`, `nvslvm`
- [authoring-guide.md](./authoring-guide.md): how to write scripts, what to avoid, current constraints

## Short Example

```txt
module game.sample;

import common.types as types;

let score: Int = 0;

fn labelFor(scoreValue: Int) -> String {
	if scoreValue > 0 { "positive" } else { "zero" }
}

fn nextTagline() -> String {
	std.repeat("go", 2)
}
```

## Core Position

The base language is frozen on purpose.

That means future feature growth should usually happen in:

- `std.*` for safe utility helpers
- optional host libraries for engine-specific behavior

It should not happen by turning the base language into a bigger programming language.

## Library Model

`NVSL` itself only guarantees the core language and `std.*`.

Engine-specific modules should stay optional. One engine may expose `vn.*`, another may expose `quest.*` or `ui.*`, but those are host-layer choices, not language rules.

## Runtime Split

There are now two ways to execute the language:

- the direct AST interpreter, which is the richer dev/runtime path today
- the bytecode path:
  - `NVSL` source
  - `nvslc` compiler
  - `NVBC` bytecode
  - `nvslvm` bytecode VM

That bytecode path is the long-term shipping/runtime direction because it gives the project one portable execution format without writing many host-language backends.
