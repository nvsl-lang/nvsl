# std Library

`std.*` is the only built-in library guaranteed by the core `NVSL` spec.

It is intentionally:

- safe
- pure in behavior
- deterministic
- small
- free of host access

`std.*` is for helper logic, not engine behavior.

## Rules

- no filesystem access
- no OS access
- no network access
- no rendering/audio access
- no hidden mutation of engine state

## Functions

### `std.max(a, b) -> Int | Float`

Returns the larger of two numbers.

Requirements:

- both arguments must be numeric
- both arguments must have the same type

Examples:

```txt
std.max(3, 8)
std.max(1.5, 2.0)
```

### `std.min(a, b) -> Int | Float`

Returns the smaller of two numbers.

Requirements:

- both arguments must be numeric
- both arguments must have the same type

Examples:

```txt
std.min(3, 8)
std.min(1.5, 2.0)
```

### `std.abs(value) -> Int | Float`

Returns the absolute value.

Requirements:

- argument must be `Int` or `Float`

Examples:

```txt
std.abs(-3)
std.abs(-2.5)
```

### `std.clamp(value, min, max) -> Int | Float`

Clamps a numeric value into a range.

Requirements:

- all arguments must be numeric
- all arguments must have the same type

Examples:

```txt
std.clamp(score, 0, 100)
std.clamp(volume, 0.0, 1.0)
```

### `std.len(value) -> Int`

Returns length.

Accepted input:

- `String`
- `List<T>`

Examples:

```txt
std.len("hello")
std.len(tags)
```

### `std.concat(left, right) -> String`

Concatenates two strings.

Requirements:

- both arguments must be `String`

Example:

```txt
std.concat("hello", " world")
```

### `std.substr(text, start, length) -> String`

Returns a substring.

Requirements:

- `text` must be `String`
- `start` must be `Int`
- `length` must be `Int`
- `start` and `length` must be non-negative at runtime

Example:

```txt
std.substr("chapter01", 0, 7)
```

### `std.toString(value) -> String`

Formats a serializable value as text.

Accepted input:

- `Void`
- `Int`
- `Float`
- `String`
- `Bool`
- `List`
- `Record`
- `Enum`

Example:

```txt
std.toString(score)
```

### `std.repeat(text, count) -> String`

Repeats a string.

Requirements:

- `text` must be `String`
- `count` must be `Int`
- `count` must be non-negative at runtime

Example:

```txt
std.repeat("ha", 3)
```

### `std.join(items, separator) -> String`

Joins a list of strings.

Requirements:

- `items` must be `List<String>`
- `separator` must be `String`

Example:

```txt
std.join(tags, ", ")
```

### `std.listPush(items, value) -> List<T>`

Returns a new list with `value` appended.

Requirements:

- first argument must be `List<T>`
- second argument must be assignable to `T`

Important:

- this does not mutate the original list

Example:

```txt
std.listPush(tags, "ally")
```

### `std.listSet(items, index, value) -> List<T>`

Returns a new list with one element replaced.

Requirements:

- first argument must be `List<T>`
- `index` must be `Int`
- `value` must be assignable to `T`
- index must be in bounds at runtime

Important:

- this does not mutate the original list

Example:

```txt
std.listSet(tags, 1, "ally")
```

### `std.random(min, max) -> Int`

Returns a random integer between `min` and `max` (inclusive).

Requirements:

- `min` must be `Int`
- `max` must be `Int`
- `max >= min` at runtime

### `std.randomFloat() -> Float`

Returns a random float between `0.0` (inclusive) and `1.0` (exclusive).

### `std.listContains(items, value) -> Bool`

Checks if a list contains a specific value.

Requirements:

- `items` must be `List<T>`
- `value` must be assignable to `T`

Example:

```txt
std.listContains(inventory, "key")
```

### `std.listRemove(items, value) -> List<T>`

Returns a new list with the first occurrence of `value` removed.

Requirements:

- `items` must be `List<T>`
- `value` must be assignable to `T`

Important:

- this does not mutate the original list

### `std.listClear(items) -> List<T>`

Returns an empty list of the same type.

Example:

```txt
std.listClear(inventory)
```

### `std.contains(text, search) -> Bool`

Checks if a string contains a substring.

Requirements:

- `text` must be `String`
- `search` must be `String`

### `std.trim(text) -> String`

Removes leading and trailing whitespace from a string.

### `std.split(text, delimiter) -> List<String>`

Splits a string into a list of strings.

Requirements:

- `text` must be `String`
- `delimiter` must be `String`

### `std.round(value) -> Int`

Rounds a float to the nearest integer.

### `std.floor(value) -> Int`

Rounds a float down to the nearest integer.

### `std.ceil(value) -> Int`

Rounds a float up to the nearest integer.

## Purity Notes

All current `std.*` functions behave like pure helpers.

That means:

- they return values
- they do not directly mutate runtime globals
- they do not touch the host system

This is important for:

- predictability
- save/load
- bytecode portability
- safe opensource embedding
