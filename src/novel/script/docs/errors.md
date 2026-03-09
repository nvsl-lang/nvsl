# Errors And Diagnostics

This file documents the main error layers in `NVSL`.

## Error Stages

Errors can happen in five main stages:

1. lexing/parsing
2. semantic checking
3. linking and project loading
4. bytecode compilation
5. runtime execution

## 1. Parse Errors

These happen when source text does not match the grammar.

Common examples:

- missing `;`
- missing `}`
- malformed parameter list
- invalid record literal syntax

Example message:

```txt
Expected ';' after binding.
```

Typical source:

```txt
let score: Int = 0
```

## 2. Semantic Check Errors

These happen after parsing, when the checker validates meaning and types.

Common examples:

- unknown import
- unknown type
- duplicate export
- invalid builtin usage
- mismatched branch types
- mixed list element types
- unsupported empty list literal

Example messages:

```txt
Unknown imported module 'missing.module'.
Operator '+' requires matching numeric types or two Strings.
Empty list literals are not supported without a typed constructor.
```

## 3. Link/Project Errors

These happen when resolving a project as a set of modules.

Common examples:

- duplicate module names
- missing entry module
- missing entry export
- entry exists but is not callable

Example messages:

```txt
Unknown entry module 'game.app'.
Module 'game.app' does not export 'main'.
Entrypoint 'game.app.main' is not callable; found Int.
```

## 4. Bytecode Tool Errors

These happen in `nvslc`, `nvslvm`, or while loading `NVBC`.

The bytecode path now supports the frozen language core, including anonymous lambdas and function-value calls.

Common bytecode-specific failures are:

- unsupported `NVBC` version or format
- missing default entrypoint metadata
- invalid or corrupted bytecode control-flow data

Example messages:

```txt
Unsupported NVBC version '1'.
NVBC program does not define a default entrypoint.
Invalid jump target 99 in 'game.app.main'.
```

## 5. Runtime Errors

These happen when valid code executes invalid runtime behavior.

Common examples:

- list index out of bounds
- division by zero
- modulo by zero
- snapshot schema mismatch
- non-serializable saved value

Example messages:

```txt
List index 5 is out of bounds.
Division by zero.
Snapshot schema does not match the current project state.
```

## Diagnostic Formatting

Structured error messages can be formatted against a source map with:

```haxe
var formatted = ScriptEngine.formatError(error, sourceMap);
```

That formatted output includes:

- source file name
- line/column
- source excerpt
- underline/caret marker

This is the main user-facing diagnostics path for editors, tools, and command-line wrappers.

## Suggested Handling

### For Tools

- parse/check/compile failures should stop immediately
- display formatted source diagnostics when available
- do not hide the exact message text

### For Runtime

- surface the exact runtime error
- show the current script entry if possible
- treat snapshot mismatch as a hard failure, not a warning

## Good Error Boundaries

The current error model is intentionally strict:

- syntax errors fail before checking
- type errors fail before execution
- unsupported compiler features fail before bytecode emission
- invalid runtime behavior fails loudly instead of silently coercing

That strictness is a feature. It makes the language safer and easier to debug.
