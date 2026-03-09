# Benchmark

`NVSL` includes a built-in synthetic benchmark harness.

Quick run:

```bash
./nvsl bench
```

Custom run:

```bash
./nvsl bench --modules 12 --helpers 24 --iterations 10 --run-iterations 250
```

What it measures:

- parse
- check
- link
- compile
- bytecode encode/decode
- source runtime load
- bytecode runtime load
- AST call/execution
- VM call/execution

Important:

- this is mainly for regression tracking and local comparison
- it is not meant to be a formal cross-machine benchmark
- the workload is synthetic and generated in memory

Detailed benchmark docs:

- [src/novel/script/docs/benchmarking.md](./src/novel/script/docs/benchmarking.md)
