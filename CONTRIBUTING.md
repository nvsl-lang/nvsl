# Contributing

## Scope

`NVSL` is intentionally small. Contributions should preserve that.

Good contribution areas:

- parser, checker, compiler, VM correctness
- diagnostics and error reporting
- docs and examples
- tooling quality
- performance work
- portability improvements

Changes that should be treated carefully:

- new core language syntax
- features that push `NVSL` toward general-purpose programming
- unsafe host access
- platform-specific assumptions in the core runtime

Read [src/novel/script/CORE_LANGUAGE.md](./src/novel/script/CORE_LANGUAGE.md) before proposing core-language changes.

## Development Setup

On Linux:

```bash
./install.sh
```

If you already have Haxe and HashLink:

```bash
./scripts/build-tools.sh
```

## Common Commands

Build the tools:

```bash
./scripts/build-tools.sh
```

Run the sample suite:

```bash
./nvsl samples
```

Run a source project:

```bash
./nvsl run path/to/scripts --entry game.app.main
```

Compile manually:

```bash
./nvslc path/to/scripts bin/game.nvbc --entry game.app.main
./nvslvm bin/game.nvbc
```

Run the direct smoke test:

```bash
haxe build.script.hxml
```

## PATH Setup

If you want the local wrappers available globally from this checkout:

```bash
export PATH="/absolute/path/to/nvsl:$PATH"
```

Example:

```bash
export PATH="$HOME/Desktop/nvsl:$PATH"
```

Add that line to `~/.bashrc` or `~/.zshrc` if you want it to persist.

## Repo Conventions

- keep the language core small
- prefer docs and tests with behavior changes
- keep user-facing commands simple
- do not commit generated `bin/` release artifacts as source changes

## Pull Requests

Before opening a PR, run:

```bash
haxe build.script.hxml
./nvsl samples
```

If your change affects docs, update the relevant files under [src/novel/script/docs](./src/novel/script/docs).

If your change affects user workflows, update [README.md](./README.md).
