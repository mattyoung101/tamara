# TaMaRa: An automated triple modular redundancy EDA flow for Yosys
By Matt Young <m.young2@student.uq.edu.au>

_BCompSc(Hons) thesis, University of Queensland, 2024-2025_

<!-- mtoc-start -->

* [Introduction](#introduction)
* [Building](#building)
  * [Setup](#setup)
  * [Compile and run](#compile-and-run)
  * [Usage in Yosys](#usage-in-yosys)
* [Testing and verification](#testing-and-verification)
  * [Formal verification](#formal-verification)
  * [Fault-injection simulation](#fault-injection-simulation)
  * [Bitstream fault injection using ecp5_shotgun](#bitstream-fault-injection-using-ecp5_shotgun)
  * [Fuzzing and regression pipe](#fuzzing-and-regression-pipe)
* [Compiling papers](#compiling-papers)
* [Licence](#licence)

<!-- mtoc-end -->

## Introduction
TaMaRa is a plugin for Yosys that automatically adds Triple Modular Redundancy (TMR) to any circuit
to improve its reliability in space and other safety-critical applications.

TODO: thesis abstract here

For more information, please see my thesis: TODO

## Building
### Setup
You will need the following tools:
- CMake 3.20+
- A C++20 compiler _(Clang 16 or newer is recommended)_
- Ninja _(optional, recommended)_
- The same dependencies Yosys requires to build, see [Yosys README](https://github.com/yosyshq/yosys?tab=readme-ov-file#building-from-source) for more info

First, clone the repo:

```bash
git clone --recurse-submodules -j8 git@github.com:mattyoung101/tamara.git
```

TaMaRa is compiled against a specific version of Yosys, which is linked as a Git submodule in the `lib`
directory. It can only be guaranteed that it will compile against the specific version in the `lib` directory.

TODO: tie it to an upstream Yosys release version, not the lib dir?

When a new version of the Yosys submodule is pushed, use this to update it:

```bash
git submodule update --init --recursive --remote
```

### Compile and run

Generate the project (assuming you've installed Ninja, otherwise omit `-G Ninja`):

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release  # or Debug
```

Build (in `build` directory):

```bash
ninja
```

This will generate the main artefact, `libtamara.so`. You can load this in Yosys as follows:

```bash
$ yosys
yosys> plugin -i libtamara.so
```

This will then make available the `tamara_propagate` and `tamara_tmr` commands (with their help as well, which
you should look at!)

For a quick build and run cycle, you can compile and load TaMaRa at the same time:

```bash
ninja && yosys -m libtamara.so
```

If you have Yosys installed on your system, you can run `ninja install` to install TaMaRa as a global plugin.
(TODO this is not yet true)

### Usage in Yosys
TODO

## Testing and verification
### Formal verification
The formal verification flows are based on Yosys' excellent [eqy](https://github.com/YosysHQ/eqy) and
[mcy](https://github.com/YosysHQ/mcy) tools.

On Arch, you can install them from the AUR using your package manager, something like: `yay -S eqy-nightly
mcy-nightly`. You will also need the nightly version of Yosys, which you can install using `yay -S
yosys-nightly`.

Once you've installed these tools, you will also need an SMT solver backend. I recommend installing yices,
Bitwuzla and Boolector. You can install them using `yay -S bitwuzla-git boolector yices`. Note that there
is currently an [upstream issue](https://github.com/YosysHQ/oss-cad-suite-build/issues/87) (of which I have
made a [pull request](https://github.com/YosysHQ/yosys/pull/4589) to partially fix) that currently prevents
Bitwuzla from working with Yosys, and there are notable performance issues. Your best bet at the moment is
probably Yices.

Once this is complete, in the `build` directory, use `eqy -f ../tests/formal/equivalence/<test>.eqy` for
equivalence checking.

TODO: mutation coverage

### Fault-injection simulation

TODO

### Bitstream fault injection using ecp5_shotgun

TODO

### Fuzzing and regression pipe
TaMaRa includes a regression pipeline based on Verilog fuzzing techniques to try and identify crashes and
other problematic behaviour in the tool.

You will need GNU Parallel and [Verismith](https://github.com/ymherklotz/verismith). Verismith is very
challenging to build, but I was able to get it to work on Arch as follows:

1. [Install ghcup](https://www.haskell.org/ghcup/install/) to setup the GHC toolchain.
2. Setup cabal 3.12.1.0 and GHC 9.6.4.
3. Build verismith using cabal.

```
ghcup install ghc --set 9.6.4
ghcup install cabal --set 3.12.1.0
cabal update
cabal build
```

Now, you need to symlink the location of the `verismith` binary to `<TAMARA>/build/verismith`. The command
`cabal list-bin verismith` will tell you where the binary is located.

Finally, to run the pipeline, just go to the build directory and run `../tests/fuzz/verismith.sh`.

## Compiling papers
This repo also includes various papers including the proposal draft, presentation slides, and the actual
thesis itself. The papers are all written in [Typst](https://github.com/typst/typst).

To compile the papers, you will need:
- Typst >= 0.11
- [MermaidJS CLI](https://github.com/mermaid-js/mermaid-cli)
- [dvisvgm](https://github.com/mgieseki/dvisvgm)
    - mupdf
    - mupdf-tools
- [Just](https://github.com/casey/just)

Next, in the papers directory, use `typst watch <file>` to edit and live reload. Or `typst compile` to just
compile it once.

For the proposal and proposal draft, build the Gantt charts by running `just`.

The thesis uses [uqthesis_eecs_hons](https://github.com/mattyoung101/uqthesis_eecs_hons) Typst template.

## Licence
Copyright (c) 2024 Matt Young.

Code and tests are available under the **Mozilla Public License v2.0**, see the file LICENSE.code.

Papers and slides (in the `papers` directory) are available under **CC Attribution 4.0 International**,
see the file LICENSE.papers.

Many files in the `tests/verilog` directory have been pulled in from other projects. These are all under
compatible open-source licences, and have their copyright included at the top of the file if applicable.
As these are external projects, the TaMaRa MPL 2.0 licence does _not_ apply to these files.

