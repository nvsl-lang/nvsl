## NVSL Core Freeze

The core language is frozen at this stage.

This means the parser, checker, project loader, runtime, and resumable execution model are now the stable base for higher-level libraries.

Future work should prefer adding functionality in:
- `std.*`
- optional host libraries

Future work should avoid expanding the core syntax unless a scripting-specific requirement cannot be expressed safely through those libraries.

### Frozen Syntax

- `module foo.bar;`
- `import foo.bar;`
- `import foo.bar as alias;`
- `let name: Type = expr;`
- `set name = expr;`
- `fn name(args...) -> Type { ... }`
- `fn name(args...) -> Type = expr;`
- `fn(args...) -> Type => expr`
- `if condition { ... } else { ... }`
- block expressions with semicolons required
- list literals: `[a, b, c]`
- record literals: `TypeName { field: value }`
- field access: `value.field`
- list indexing: `value[index]`
- structs
- enums

### Frozen Type Set

- `Void`
- `Int`
- `Float`
- `String`
- `Bool`
- `List<T>`
- struct record types
- enum types
- function types

### Frozen Runtime Model

- multi-file project loading
- module import/linking
- type checking before runtime
- deterministic top-level state snapshots
- resumable execution snapshots across both runtimes
- bytecode compilation/runtime for the frozen core

### Non-Goals For Core

- loops
- classes
- methods
- inheritance
- dynamic typing
- reflection
- arbitrary host access
- file IO
- network access
- OS process access
- metaprogramming
- general-purpose language growth

### Extension Policy

New behavior should be added in libraries, not in the base language:

- pure helpers go in `std.*`
- engine-specific behavior goes in optional host libraries

If a future feature request makes the language feel more like a general programming language than a compact safe scripting language, it should be rejected by default.
