# Install And Run

This file explains the current supported ways to install and run `NVSL`.

## What You Need

There are four practical paths today:

- Linux source checkout
- Linux release bundle
- Windows release bundle
- macOS release bundle

The language core is cross-platform. The easiest source-install flow is still Linux-first, while the packaged runtime story now covers Linux, Windows, and macOS bundles.

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

## Option 3: Windows Release Bundle

Download the Windows release archive from GitHub Releases and extract it:

```text
nvsl-windows-x64.zip
```

The Windows bundle includes:

- `nvsl.cmd`
- `nvslc.cmd`
- `nvslvm.cmd`
- `bin\hl.exe`
- `bin\libhl.dll`
- `bin\nvslc.hl`
- `bin\nvslvm.hl`

So Windows users do not need a separate HashLink install for the packaged release.

Run a source project:

```text
nvsl run path\to\scripts --entry game.app.main
```

Compile to bytecode:

```text
nvslc path\to\scripts bin\game.nvbc --entry game.app.main
```

Run bytecode:

```text
nvslvm bin\game.nvbc
```

## Option 4: macOS Release Bundle

Download the macOS release archive from GitHub Releases and extract it:

```bash
tar -xzf nvsl-macos-x64.tar.gz
cd nvsl-macos-x64
```

The macOS bundle includes:

- `nvsl`
- `nvslc`
- `nvslvm`
- `bin/hl`
- `bin/libhl.dylib`
- `bin/nvslc.hl`
- `bin/nvslvm.hl`

So macOS users do not need a separate HashLink install for the packaged release.

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

On Windows, add the extracted bundle directory to `PATH` through the system environment settings or use the local `nvsl.cmd`, `nvslc.cmd`, and `nvslvm.cmd` launchers directly from the extracted folder.

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
- Windows self-contained bundle: supported
- macOS self-contained bundle: supported

The toolchain itself is portable because it is written in Haxe. The easiest source-install flow is still Linux-first, but packaged release bundles now cover the main desktop targets.
