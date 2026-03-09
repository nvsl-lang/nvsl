# Authoring Guide

## What This Language Is For

Use this language for:

- story state
- condition logic
- safe helper expressions
- safe orchestration through optional host libraries

Do not treat it like a replacement for Haxe.

## Recommended Style

### Keep Functions Small

Good:

```txt
fn moodLabel(mood: Mood) -> String {
	if mood == Mood.Warm { "warm" } else { "cold" }
}
```

Avoid large, deeply nested functions. This language should stay readable for writers and tool authors.

### Prefer Explicit Types At Module Boundaries

Top-level bindings already require explicit types.

Keep function signatures explicit too:

```txt
fn nextScore(delta: Int) -> Int {
	set score = score + delta;
	score
}
```

### Treat Lists As Persistent Values

Use:

- `std.listPush`
- `std.listSet`

These return new lists.

Example:

```txt
fn withExtraTag(tags: List<String>) -> List<String> {
	std.listPush(tags, "friend")
}
```

Do not expect in-place mutation.

### Prefer Blocks Only When They Help Clarity

Good:

```txt
fn next() -> Int {
	let result: Int = score + 1;
	result
}
```

Avoid block-heavy code that starts looking like a general programming language.

## What To Avoid

- building complex generic utility logic
- simulating loops with recursion unless absolutely necessary
- storing closures inside persistent story state
- designing scripts as if they were engine code

## Current Constraints To Remember

- semicolons are required
- no loops
- no classes
- no field assignment
- no index assignment
- no empty list literals
- no unsafe host access
- closures and function values are not serializable save data

## How To Think About Libraries

### `std`

Use `std.*` for:

- math
- string helpers
- list helpers
- conversions

### Optional Host Libraries

Use optional host libraries for:

- scene changes
- characters
- dialogue
- choices
- jumps
- waits
- presentation and engine-side effects

That separation is important:

- `std` should stay safe and utility-focused
- host libraries should carry engine-facing behavior

## Rule Of Thumb

If a requested feature makes the language feel more like a normal programming language than a VN scripting language, it should probably not be added to the core.
