# TaMaRa: An automated triple modular redundancy EDA flow for Yosys
By Matt Young <m.young2@student.uq.edu.au>

_BCompSc(Hons) thesis, University of Queensland, 2024-2025_

## Introduction
**tl;dr** TaMaRa is a plugin for Yosys that automatically adds Triple Modular Redundancy (TMR) to any circuit
to improve its reliability in space and other safety-critical applications.

For safety-critical sectors such as aerospace, medicine and defence, silicon ICs and FPGA gateware must be
designed using fault-tolerant methodologies. This is necessary in order to prevent Single Event Upsets (SEUs)
triggered by ionising radiation and other interference. One common fault-tolerant design technique is Triple
Modular Redundancy (TMR), which mitigates SEUs by replicating key parts of the design and using voter circuits
to select a non-corrupted result. Typically, TMR is manually designed at the HDL level, for example by
manually duplicating and linking modules in SystemVerilog. However, this approach is an additional
time-consuming and potentially error-prone step in the already complex design pipeline. Instead, it would be
better if the step of adding TMR could be automatically implemented and verified.

In this thesis, I present TaMaRa: a fully automated triple modular redundancy flow for the open-source Yosys
EDA synthesis tool. TaMaRa operates at the netlist level and can quickly and automatically add TMR voters to
any selectable HDL module.

For more information, please see my thesis: TODO

## Building
**Toolchain and environment**

You will need the following tools:
- CMake 3.20+
- A C++20 compiler _(Clang is recommended)_
- Ninja _(technically optional)_

First, clone the repo:

```bash
git clone --recurse-submodules -j8 git@github.com:mattyoung101/tamara.git
```

TaMaRa is compiled against a specific version of Yosys, which is linked as a Git submodule in the `lib`
directory. It can only be guaranteed that it will compile against the specific version in the `lib` directory.

When a new version of the Yosys submodule is pushed, use this to update it:

```bash
git submodule update --init --recursive --remote
```

**Compiling and running**

Generate the project (assuming you've installed Ninja, otherwise omit `-G Ninja`):

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release # or Debug
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

## Usage in Yosys
TODO

## Testing and verification
**Formal verification**

The formal verification flows are based on Yosys' excellent [eqy](https://github.com/YosysHQ/eqy) and
[mcy](https://github.com/YosysHQ/mcy) tools.

On Arch, you can install them from the AUR using your package manager, something like: `yay -S eqy-nightly
mcy-nightly`. You will also need the nightly version of Yosys, which you can install using `yay -S
yosys-nightly`.

Once you've installed these tools, you will also need an SMT solver backend. I recommend installing z3, yices,
Bitwuzla and Boolector. You can install them using `yay -S z3 bitwuzla-git boolector yices`. Note that there
is currently an [upstream issue](https://github.com/YosysHQ/oss-cad-suite-build/issues/87) (of which I have
made a [pull request](https://github.com/YosysHQ/yosys/pull/4589) to partially fix) that currently prevents
Bitwuzla from working with Yosys, so you'll have to rely on z3, boolector or yices.

Once this is complete, in the `build` directory, use `eqy -f ../tests/formal/equivalence/<test>.eqy` for
equivalence checking.

TODO: mutation coverage

**Fault-injection simulation**

TODO

**Bitstream fault injection using ecp5_shotgun**

TODO

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
Copyright 2024 Matt Young. Available under the **Mozilla Public License v2.0**.

> This Source Code Form is subject to the terms of the Mozilla Public
> License, v. 2.0. If a copy of the MPL was not distributed with this
> file, You can obtain one at https://mozilla.org/MPL/2.0/.

