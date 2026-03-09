# NVSL Sample Projects

This folder contains runnable sample projects and edge cases for `nvslc` and `nvslvm`.

## Layout

- `ok/`: projects that should compile and run successfully
- `edge/`: projects that should fail in a specific phase

## Quick Check

Use the checker script in this folder:

```bash
./samples/check-samples.sh
```

Or from the current monorepo root:

```bash
./src/novel/script/samples/check-samples.sh
```

That script:

- builds `nvslc`
- builds `nvslvm`
- compiles and runs the positive samples
- checks compile-time edge cases
- checks runtime edge cases

It auto-detects the repo root by walking upward until it finds the build files.

## Folder Conventions

Successful sample folders contain:

- `.nvsl` source files
- `entry.txt`
- `expected.txt`

Edge-case folders contain:

- `.nvsl` source files
- `phase.txt`
- `expected-error.txt`
- optional `entry.txt` for runtime-failure cases
