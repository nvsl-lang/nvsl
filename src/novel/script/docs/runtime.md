# Runtime And Save/Resume

For runtime state shape details, see [memory-model.md](./memory-model.md).
For failure modes, see [errors.md](./errors.md).

## Pipeline

The current scripting pipeline is:

1. tokenize
2. parse
3. type check
4. link modules
5. either:
   - load the AST interpreter runtime directly
   - compile to `NVBC` and load `nvslvm`
6. execute

## Project Load

Project load is module-aware.

It handles:

- module declarations
- imports
- cross-file type resolution
- cross-file function access
- deterministic module load order

## Execution Backends

There are currently two execution backends.

### 1. AST Interpreter

This is the richer runtime path today.

It supports:

- direct calls
- resumable execution
- execution snapshots
- project/global snapshots
- closures at runtime

### 2. Bytecode VM

This is the compiled/runtime distribution path.

It supports:

- `NVSL -> NVBC` compilation
- direct bytecode execution
- anonymous lambdas and closure calls
- resumable bytecode execution
- project/global snapshots
- execution snapshots
- deterministic module initialization

## Save Models

There are currently two save models.

### 1. Project State Snapshot

This saves mutable top-level globals across modules.

Saved data includes:

- mutable exported globals
- initialization state for those globals
- serializable values
- project schema/version data

This does not save:

- current instruction position
- active call stack
- local variables inside a running function

Use this when you only want persistent story state.

### 2. Execution Snapshot

This is the resumable model.

Saved data includes:

- project/global state
- active execution frames
- execution op stack
- execution value stack
- local scopes
- local variables in those scopes

This is the model used for:

- pause
- save mid-execution
- restore
- continue from the same logical point

This is available through both the AST interpreter runtime and `nvslvm`.

## Public Runtime API

Interpreter direct call:

```haxe
var runtime = ScriptEngine.loadSources(inputs);
var result = runtime.call("game.state", "heroMood", []);
```

Bytecode compile and load:

```haxe
var program = ScriptEngine.compileSources(inputs, "game.app", "main");
var vm = ScriptEngine.loadBytecode(program);
var result = vm.callDefault([]);
```

Begin resumable execution:

```haxe
var execution = runtime.beginExecution("game.app", "orchestrate", [VInt(3)]);
```

Step:

```haxe
execution.step(1);
```

Run to completion:

```haxe
var result = execution.run();
```

Create execution snapshot:

```haxe
var payload = execution.createSnapshot();
```

Restore execution snapshot:

```haxe
var resumed = restoredRuntime.restoreExecutionSnapshot(payload);
var result = resumed.run();
```

## Serializable Values

Project/global snapshots serialize:

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
- anonymous closures stored in runtime state

That restriction is intentional. It keeps persistent save data deterministic and predictable.

`nvslvm` execution snapshots additionally support builtin values and bytecode closures that are currently in flight inside execution frames, stacks, and captured environments.

## Snapshot Compatibility

Snapshots are versioned and schema-checked.

That means restore fails cleanly if:

- the snapshot format is unknown
- the snapshot version is unsupported
- the current project state shape no longer matches the saved schema

This is safer than silently accepting incompatible saves.

## Optional Host Libraries

The runtime intentionally separates:

- core language behavior
- built-in `std.*`
- optional host-provided modules

Engine-specific APIs should be layered above the language runtime instead of being treated as part of the base spec.

## Current Resume Limit

Resume now works through both runtimes:

- the AST interpreter execution runner
- `nvslvm` bytecode execution snapshots

Both runtimes now support resumable higher-order execution snapshots. Project/global snapshots remain intentionally stricter and only serialize persistent story state.
