# Engine Embedding Guide

This guide explains how to embed the `NVSL` script engine into your Haxe-based game engine.

## The ScriptEngine Façade

The `novel.script.ScriptEngine` class is the primary entry point for all engine operations. It provides a clean API for parsing, checking, compiling, and loading scripts.

### Basic Setup

To use `NVSL`, you first need to load your script sources. You can load from a directory, an array of source strings, or a single source.

```haxe
import novel.script.ScriptEngine;
import novel.script.project.ScriptProject.ScriptSourceInput;

// Load from a directory
var runtime = ScriptEngine.loadDirectory("assets/scripts");

// Or load from specific source inputs
var inputs: Array<ScriptSourceInput> = [
    { sourceName: "main.nvsl", source: "module main; fn hello() { \"world\" }" }
];
var runtime = ScriptEngine.loadSources(inputs);
```

## Execution Backends

`NVSL` provides two execution backends:

1.  **AST Interpreter**: Recommended for development and rapid iteration. It supports rich resumable execution and detailed diagnostics.
2.  **Bytecode VM (`nvslvm`)**: Recommended for production. It executes pre-compiled `NVBC` bytecode, which is faster and more portable.

### Using the AST Interpreter

```haxe
var runtime = ScriptEngine.loadDirectory("scripts");
var result = runtime.call("game.main", "start", []);
```

### Using the Bytecode VM

```haxe
// Compile to bytecode
var program = ScriptEngine.compileDirectory("scripts", ".nvsl", "game.main", "start");

// (Optional) Encode to JSON for storage
var json = ScriptEngine.encodeBytecode(program);

// Load and run from bytecode
var vm = ScriptEngine.loadBytecode(program);
var result = vm.callDefault([]);
```

## Communicating with Scripts

The host engine and scripts communicate primarily through function calls and global variables.

### Calling Script Functions

Use `runtime.call(module, export, args)` to invoke a function exported by a script module. Arguments must be of type `ScriptValue`.

```haxe
import novel.script.runtime.ScriptValue;

var args = [VInt(10), VString("hero")];
var result = runtime.call("game.logic", "calculateScore", args);

// Convert result back to Haxe types
switch result {
    case VInt(val): trace("Score: " + val);
    case VString(val): trace("Message: " + val);
    default: trace("Unexpected result type");
}
```

### ScriptValue Types

The `ScriptValue` enum represents all possible values in NVSL:

- `VVoid`: No value.
- `VInt(Int)`: 64-bit integer.
- `VFloat(Float)`: 64-bit float.
- `VString(String)`: UTF-8 string.
- `VBool(Bool)`: Boolean.
- `VList(Array<ScriptValue>)`: Dynamic list.
- `VRecord(String, StringMap<ScriptValue>)`: Named record (struct).
- `VEnum(String, String)`: Named enum case.
- `VClosure(...)`: A function value (not serializable).
- `VBuiltin(String)`: A builtin function (not serializable).

## Accessing Global State


You can read and update mutable globals from the host engine.

```haxe
var gameState = runtime.getModule("game.state");

// Read a global
var currentScore = gameState.getGlobal("score");

// Update a global (requires the global to be declared with 'let' in NVSL)
gameState.env.assign("score", VInt(100));
```

## Save and Load

`NVSL` supports two models for saving state:

### 1. Project Snapshots (Story State)

This captures all mutable globals across all modules. Use this for traditional "save games" where you want to persist the player's progress but not necessarily their exact position in a running script.

```haxe
// Save
var snapshotJson = runtime.createSnapshot();

// Load
runtime.restoreSnapshot(snapshotJson);
```

### 2. Execution Snapshots (Resumable Scripts)

This captures the entire call stack, local variables, and instruction pointer. Use this for "suspending" a script (e.g., waiting for player input or a long animation) and resuming it later.

```haxe
// Start execution
var execution = runtime.beginExecution("game.main", "orchestrate", []);

// Run until it needs to wait
execution.step(100); 

// Save the in-flight state
var snapshot = execution.createSnapshot();

// ... later, perhaps after a restart ...
var restoredExecution = runtime.restoreExecutionSnapshot(snapshot);
restoredExecution.run();
```

## Error Handling

All `ScriptEngine` operations can throw a `ScriptError`. Use `ScriptEngine.formatError` to get a human-readable diagnostic with source context.

```haxe
try {
    ScriptEngine.loadDirectory("scripts");
} catch (e: ScriptError) {
    var formatted = ScriptEngine.formatError(e, mySourceMap);
    Sys.stderr().writeString(formatted + "\n");
}
```

## Custom Host Functions (Libraries)

NVSL is designed to be extended with engine-specific libraries (e.g., `vn.*`, `ui.*`, `audio.*`).

You can register host functions dynamically using `ScriptHost.register` or `ScriptHost.registerSimple`. This does **not** require modifying the NVSL source code.

### 1. Registering with a simple signature

Use `registerSimple` for functions with a fixed number of arguments and a single return type.

```haxe
import novel.script.runtime.ScriptHost;
import novel.script.semantics.ScriptType;
import novel.script.runtime.ScriptValue;

// Register vn.showBg(String) -> Void
ScriptHost.registerSimple(
    "vn.showBg",
    [TString], // Parameter types
    TVoid,     // Return type
    function(args, span) {
        var bgId = args[0];
        // Your engine code here:
        // MyEngine.displayBackground(bgId);
        return VVoid;
    }
);
```

### 2. Registering with complex type checking

Use `register` if your function is polymorphic (like `std.max` which accepts `Int` or `Float`).

```haxe
ScriptHost.register(
    "math.pow",
    function(argTypes, span) {
        // Validation logic:
        if (argTypes.length != 2) throw new ScriptError("pow expects 2 args", span);
        return TFloat; // Result type
    },
    function(args, span) {
        // Implementation logic:
        return VFloat(Math.pow(args[0].toFloat(), args[1].toFloat()));
    }
);
```

### 3. Using in NVSL

Once registered, scripts can call these functions just like `std.*` functions. No imports are required for builtins, but using a namespace prefix is recommended for clarity.

```txt
module game.scene;

fn start() {
    vn.showBg("bg.forest");
    vn.playMusic("bgm.theme");
}
```

*Note: The `std.*` library is automatically registered into `ScriptHost` on first use.*
