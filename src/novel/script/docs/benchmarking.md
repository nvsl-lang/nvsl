# Benchmarking

This file documents the built-in `NVSL` benchmark harness.

## Scope

The benchmark is intended for:

- rough local performance comparisons
- checking regressions while changing parser/checker/compiler/runtime code
- comparing the AST runtime and the bytecode VM on the same generated input

It is **not** intended to be a formal cross-machine performance claim.

The generated benchmark project is synthetic and runs entirely in memory. It is useful for repeatable tooling/runtime measurements, but it is not a proxy for every real game project.

## Command

From a source checkout:

```bash
./nvsl bench
```

Direct tool form:

```bash
./nvslbench
```

## Options

```bash
./nvsl bench [--modules N] [--helpers N] [--iterations N] [--run-iterations N] [--warmup N] [--seed N]
```

Arguments:

- `--modules N`: synthetic benchmark module count
- `--helpers N`: helper function count per generated module
- `--iterations N`: iterations for parse/check/link/compile/load phases
- `--run-iterations N`: iterations for runtime call/execution phases
- `--warmup N`: warmup runs before each measured phase
- `--seed N`: integer argument passed into the generated entrypoint

Defaults:

- `--modules 8`
- `--helpers 16`
- `--iterations 20`
- `--run-iterations 200`
- `--warmup 3`
- `--seed 7`

## What It Measures

Current phases:

- `parseSources`
- `checkProject`
- `linkProject`
- `compileProject`
- `encodeBytecode`
- `decodeBytecode`
- `loadSourceRuntime`
- `loadBytecodeRuntime`
- `astCall`
- `astExecutionRun`
- `vmCall`
- `vmExecutionRun`

The harness also validates that the AST runtime and VM produce the same result for the generated entrypoint before timing results are reported.

## Example

```bash
./nvsl bench --modules 12 --helpers 24 --iterations 10 --run-iterations 250
```

Example output shape:

```text
NVSL benchmark

Config:
  modules: 12
  helpers/module: 24
  phase iterations: 10
  runtime iterations: 250
  warmup iterations: 3
  seed: 7

Dataset:
  source files: 13
  source lines: 400
  estimated call depth: 300
  validated result: 123

phase                iter      total ms      avg ms      min ms      max ms
============================================================================
parseSources           10        20.000       2.000       1.900       2.200
...
```

## Notes

- Run benchmarks on an otherwise quiet machine if you want cleaner numbers.
- Compare runs on the same machine and same runtime target when possible.
- Use the benchmark mainly for trends and regressions, not marketing claims.
