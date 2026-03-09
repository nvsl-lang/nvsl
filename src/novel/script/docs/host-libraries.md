# Host Library Integration

`NVSL` is designed so the core language stays small and the host engine exposes extra behavior as optional libraries.

## Core Rule

The core language should not know about:

- filesystems
- sockets
- processes
- rendering backends
- audio backends
- engine scene objects

Those belong to the host engine layer.

## Builtin vs Host Libraries

Guaranteed by core:

- `std.*`

Optional host layers:

- `vn.*`
- `ui.*`
- `audio.*`
- `save.*`
- any other safe engine-facing namespace

The exact names are a host choice, not a language rule.

## Design Guidelines

Host libraries should be:

- explicit
- deterministic when possible
- serializable where required
- safe by construction
- narrow in surface area

Bad host API shape:

```txt
os.exec("rm -rf /")
fs.read("/home/user/file")
```

Good host API shape:

```txt
vn.showBg("bg.school")
audio.playMusic("bgm.opening")
ui.openPanel("codex")
```

The script only sees safe ids. The engine resolves those ids to real assets or runtime actions.

## Recommended Boundary

Prefer one of these models:

### 1. Command-like APIs

Good for engine effects:

- scene transitions
- audio control
- UI actions
- save/load requests

### 2. Safe Query APIs

Good for controlled reads:

- current locale
- current platform tag
- registered settings values
- validated asset metadata

## Important Constraint

If a host API makes the script feel like it has general-purpose host access, it is too broad.

That includes:

- arbitrary path access
- arbitrary object creation
- arbitrary reflection
- arbitrary process execution

## Bytecode Compatibility

If a host library is meant to work through both:

- the AST interpreter
- `nvslvm`

then its call behavior should remain stable and serializable enough for the same script semantics to hold across both backends.

## Recommendation For Engine Integrators

If your engine adds `vn.*`, it should be documented as:

- an engine host library
- built on top of `NVSL`
- not part of the core language specification
