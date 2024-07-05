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
You will need the following tools:
- CMake 3.20+
- A C++20 compiler _(Clang is recommended)_
- Ninja _(technically optional)_

First, clone the repo:

```bash
git clone --recurse-submodules -j8 TODO
```

TaMaRa is compiled against a specific version of Yosys, which is linked as a Git submodule in the `lib`
directory. It can only be guaranteed that it will compile against the specific version in the `lib` directory.

When a new version of the Yosys submodule is pushed, use this to update it:

```bash
git submodule update --init --recursive --remote
```

To compile TaMaRa:

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
plugin -i libtamara.so
```

This will then make available the `tmr` and `tmr` commands.

Install TaMaRa:

TODO

## Usage in Yosys
As mentioned above, you first need to use `plugin -i libtamara` to load the TaMaRa plugin.

You can use `help tmr` and `help tmr_finalise` to see more about what the commands do (and check that they
have been installed correctly).

TODO

## Compiling the thesis
This repo also includes my thesis submission, _A triple modular redundancy EDA flow for Yosys_.

The thesis is written in [Typst](https://github.com/typst/typst). In the `thesis` directory, you can run `typst
compile uqthesis.typ` to produce `uqthesis.pdf`.

This uses my [uqthesis_eecs_hons](https://github.com/mattyoung101/uqthesis_eecs_hons) Typst template.

## Licence
TBA, hopefully MPL 2.0
