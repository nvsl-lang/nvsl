# Language Reference

This file explains what the frozen `NVSL` core contains and how each construct behaves.

For exact syntax shapes, see [grammar.md](./grammar.md).
For the builtin helper module, see [std-library.md](./std-library.md).

## Scope

`NVSL` is intentionally small.

It is designed for:

- strict module-based scripting
- predictable runtime behavior
- static checking before runtime
- safe embedding in larger engines

It is not intended to become a general-purpose language.

## File Structure

Every project file must declare exactly one module:

```txt
module game.state;
```

Imports are project-module imports:

```txt
import common.types;
import common.types as types;
```

Rules:

- module names are dot-qualified
- imports resolve project modules only
- there is no arbitrary import from the host system
- there is no import of OS or standard library packages

## Top-Level Declarations

The frozen top-level declaration set is:

- `let`
- `fn`
- `struct`
- `enum`

Example:

```txt
let score: Int = 0;

fn nextScore(delta: Int) -> Int {
	set score = score + delta;
	score
}

struct Character {
	name: String;
	tags: List<String>;
}

enum Mood {
	Warm;
	Cold;
}
```

## Semicolons

Semicolons are required for statements.

Examples:

```txt
let score: Int = 0;
set score = score + 1;
```

Inside a block, the final expression has no semicolon and becomes the block result:

```txt
fn value() -> Int {
	let x: Int = 2;
	x + 1
}
```

This rule is fixed in the current language:

- statements require `;`
- block tail expressions do not use `;`

## Types

Built-in types:

- `Void`
- `Int`
- `Float`
- `String`
- `Bool`
- `List<T>`

User-defined types:

- `struct` record types
- `enum` types

Function values also exist as typed values:

```txt
fn add(a: Int, b: Int) -> Int {
	a + b
}
```

Current non-features:

- no classes
- no methods
- no inheritance
- no dynamic type
- no dictionary/map type in the core

## Functions

Named functions:

```txt
fn add(a: Int, b: Int) -> Int {
	a + b
}

fn add(a: Int, b: Int) -> Int = a + b;
```

Lambda form:

```txt
fn(value: Int) -> Int => value + 1
```

Rules:

- top-level functions must declare a return type with `->`
- lambda return types may be inferred when omitted
- functions are first-class in the AST interpreter
- the current bytecode compiler is intentionally stricter than the interpreter

## Variables And Assignment

Declaration:

```txt
let score: Int = 0;
```

Assignment:

```txt
set score = score + 1;
```

Current assignment support is intentionally narrow:

- only simple identifier targets
- no field assignment
- no index assignment
- no destructuring assignment

This keeps execution and snapshot behavior simpler.

## Expressions

Supported expression forms:

- literals
- identifier paths
- function calls
- unary operators
- binary operators
- `if / else`
- block expressions
- list literals
- record literals
- record field access
- list indexing
- lambda expressions

### Literals

```txt
1
1.5
"hello"
true
false
["a", "b"]
```

### Paths

```txt
score
types.Mood.Warm
game.state.currentHero
std.repeat
```

Path resolution is intentionally strict:

1. local scope
2. current module exports
3. imported modules
4. fully-qualified project modules
5. built-in `std.*`

### Record Literals

```txt
types.Character {
	name: "Ava",
	tags: ["pilot", "friend"]
}
```

Rules:

- the target type must be a `struct`
- all required fields must be present
- duplicate fields are rejected

### Field Access

```txt
hero.name
state.currentHero().tags
```

Field access is currently supported on records.

### List Indexing

```txt
hero.tags[0]
```

Rules:

- index values must be `Int`
- indexing is currently only supported on lists

## Control Flow

Current control flow is intentionally small.

### `if / else`

```txt
if score > 0 {
	"positive"
} else {
	"zero"
}
```

Rules:

- the condition must be `Bool`
- both branches must resolve to the same type

### Blocks

```txt
{
	let next: Int = score + 1;
	next
}
```

Blocks:

- create a local scope
- can contain `let`, `set`, and expression statements
- return the final expression value or `Void`

### No Loops

There are currently no:

- `for`
- `while`
- `do while`

This is intentional. Higher-level control should come from structured libraries and runtime flow, not raw looping constructs in the core language.

## Operators

Unary:

- `-`
- `!`

Binary:

- `+`
- `-`
- `*`
- `/`
- `%`
- `==`
- `!=`
- `<`
- `<=`
- `>`
- `>=`
- `&&`
- `||`

Operator notes:

- `+` supports matching numeric types or two `String` values
- arithmetic operators require matching numeric types
- logical operators require `Bool`
- there is no implicit numeric conversion
- equality is currently limited to primitive values and enums

## Structs And Enums

### Struct

```txt
struct Character {
	name: String;
	tags: List<String>;
}
```

Structs are used through:

- typed fields
- record literals
- field access

### Enum

```txt
enum Mood {
	Warm;
	Cold;
}
```

Enum values are referenced by path:

```txt
types.Mood.Warm
```

## Builtin Library

`std.*` is the only builtin library guaranteed by the core language.

It is:

- safe
- deterministic
- utility-focused
- free of host access

All builtin helpers are documented in [std-library.md](./std-library.md).

Important list semantics:

- `std.listPush` returns a new list
- `std.listSet` returns a new list
- neither mutates the original list in place

## Optional Host Libraries

The core language does not require a specific engine library namespace.

That means:

- `std.*` is builtin
- engine-facing modules are optional host extensions
- a host may later expose `vn.*`, `ui.*`, `audio.*`, or another safe API surface

Those engine-facing modules belong to host documentation, not the frozen core language reference.
