# Memory Model

`NVSL` does not expose a manual memory model like C or C++.

At runtime it uses a small managed state model built on top of Haxe objects and the target runtime garbage collector.

## Short Version

Think about runtime memory in four layers:

1. module globals
2. local scope cells
3. transient execution values
4. captured environments for closures

The important rule is:

- `set` mutates a binding cell
- it does not mutate lists or records in place

## 1. Module Globals

Top-level `let` declarations become module-level cells.

Example:

```txt
let score: Int = 0;
```

Runtime behavior:

- the module owns a cell named `score`
- the cell stores:
  - name
  - type
  - mutability
  - initialization state
  - current value

These cells are the main persistent state for save/load.

## 2. Local Scope Cells

Each block creates a new local environment layer.

Example:

```txt
{
	let next: Int = score + 1;
	next
}
```

That `let next` is stored in a local cell inside the block scope.

Rules:

- inner scopes can shadow outer names
- lookup walks outward through parent scopes
- `set name = expr` updates the nearest matching cell

## 3. Transient Execution Values

Expression evaluation also uses transient values.

Examples:

- operands of `a + b`
- function call arguments
- list literal elements while building a list
- temporary results inside nested expressions

In the AST interpreter these live in the explicit execution/value stacks used by resumable execution.

In `nvslvm` these live on the bytecode VM stack.

They are short-lived unless stored into:

- a global cell
- a local cell
- a closure capture

## 4. Closures And Captured Environments

The AST interpreter supports closures.

Example:

```txt
let inc = fn(value: Int) -> Int => value + 1;
```

A closure stores:

- parameter names
- parameter types
- return type
- function body
- a reference to the environment it captured

Important consequence:

- closures capture environment cells, not copies of every variable value

So if a closure sees a mutable captured cell, later reads observe the updated cell contents.

## Mutation Model

This is the most important design point.

### `set` mutates bindings

```txt
set score = score + 1;
```

This changes the contents of the `score` cell.

### Lists Are Persistent-Style Values

`std.listPush` and `std.listSet` return new lists:

```txt
let nextTags = std.listPush(tags, "ally");
```

This means:

- the original list value is not mutated in place
- a new list value is allocated
- if you want to keep it, store it back into a binding

Example:

```txt
set tags = std.listPush(tags, "ally");
```

### Records Are Value Containers

Records are constructed as values and then stored in cells or passed around.

There is currently:

- no field assignment
- no in-place record mutation syntax

So record updates must currently happen by building a new value rather than editing one field in place.

## Interpreter vs Bytecode VM

### AST Interpreter

The AST interpreter keeps:

- module environments
- nested local environments
- execution frames
- execution op stacks
- execution value stacks

That is why it can support resumable execution snapshots.

### `nvslvm`

The bytecode VM keeps:

- module environments
- local scope environments
- a bytecode value stack
- an instruction pointer during execution

Those live VM structures can now be snapshotted and restored through `nvslvm` execution snapshots.

## Serialization Model

Only serializable values can be saved.

Serializable:

- `Void`
- `Int`
- `Float`
- `String`
- `Bool`
- `List`
- `Record`
- `Enum`

Project/global snapshots still reject:

- builtin function values
- captured closures in persistent global state

VM execution snapshots additionally support builtin values and bytecode closures that are currently in flight.

## Ownership In Practice

If you want the practical rule of thumb:

- globals own long-lived story state
- locals own short-lived scoped state
- stacks own temporary expression values
- closures keep references to captured scope cells
- list helpers return new values instead of mutating old ones

## What This Means For Users

For script authors:

- treat globals as persistent state
- treat locals as temporary scoped state
- treat lists as persistent-style values
- do not assume in-place mutation except through `set`

For engine authors:

- host libraries should prefer deterministic value-returning APIs
- save/load should only depend on serializable cells and values
- keeping the core away from direct host object references is the right design
