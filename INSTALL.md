# Install And Run

This file explains the current supported ways to install and run `NVSL`.

## What You Need

There are two practical paths today:

- Linux source checkout
- Linux release bundle

The language core is cross-platform, but the convenience scripts and packaged no-`hl` runtime are currently Linux-first.

## Option 1: Linux Source Checkout

Clone the repo:

```bash
git clone https://github.com/nvsl-lang/nvsl.git
cd nvsl
```

Install the Linux toolchain and build the local tools:

```bash
./install.sh
```

That sets up Haxe, HashLink, and builds:

- `bin/nvslc.hl`
- `bin/nvslvm.hl`

Run a source project:

```bash
./nvsl run path/to/scripts --entry game.app.main
```

Compile to bytecode:

```bash
./nvslc path/to/scripts bin/game.nvbc --entry game.app.main
```

Run bytecode:

```bash
./nvslvm bin/game.nvbc
```

Run the bundled samples:

```bash
./nvsl samples
```

## Option 2: Linux Release Bundle

Download the Linux release archive from GitHub Releases and extract it:

```bash
tar -xzf nvsl-linux-x64.tar.gz
cd nvsl-linux-x64
```

The release bundle includes:

- `nvsl`
- `nvslc`
- `nvslvm`
- `bin/hl`
- `bin/libhl.so`
- `bin/nvslc.hl`
- `bin/nvslvm.hl`

So Linux users do not need to install HashLink separately for the bundled release.

Run a source project:

```bash
./nvsl run path/to/scripts --entry game.app.main
```

Compile to bytecode:

```bash
./nvslc path/to/scripts bin/game.nvbc --entry game.app.main
```

Run bytecode:

```bash
./nvslvm bin/game.nvbc
```

## Add To PATH

If you want the local wrappers available globally from a checkout or extracted bundle:

```bash
export PATH="/absolute/path/to/nvsl:$PATH"
```

Example:

```bash
export PATH="$HOME/Desktop/nvsl:$PATH"
```

Then you can run:

```bash
nvsl run path/to/scripts --entry game.app.main
nvslc path/to/scripts bin/game.nvbc --entry game.app.main
nvslvm bin/game.nvbc
```

To make that permanent, add the `export PATH=...` line to `~/.bashrc` or `~/.zshrc`.

## Raw Commands

If you already have Haxe and HashLink installed, the direct commands are:

```bash
haxe build.nvslc.hxml
haxe build.nvslvm.hxml
hl bin/nvslc.hl path/to/scripts bin/game.nvbc --entry game.app.main
hl bin/nvslvm.hl bin/game.nvbc
```

## Current Platform Status

- Linux source checkout: supported
- Linux self-contained bundle: supported
- Windows: manual setup only for now
- macOS: manual setup only for now

The toolchain itself is portable because it is written in Haxe. The repo-level install and bundled runtime story still needs more work for Windows and macOS.
