# TaMaRa: An automated Triple Modular Redundancy EDA flow for Yosys
By Matt Young <matt@mlyoung.cool>

_BCompSc(Hons) thesis, University of Queensland (Australia), 2024-2025_

<!-- mtoc-start -->

* [Introduction](#introduction)
* [Building](#building)
  * [Setup](#setup)
  * [Compile and run](#compile-and-run)
* [Usage in Yosys](#usage-in-yosys)
  * [Limitations](#limitations)
  * [Circuit preparation](#circuit-preparation)
  * [Synthesis preparation](#synthesis-preparation)
* [Testing and verification](#testing-and-verification)
  * [Formal verification](#formal-verification)
  * [Fault-injection simulation](#fault-injection-simulation)
  * [Fuzzing and regression pipe](#fuzzing-and-regression-pipe)
  * [Debugging](#debugging)
* [Compiling papers](#compiling-papers)
* [Licence](#licence)

<!-- mtoc-end -->

## Introduction
TaMaRa is a plugin for Yosys that automatically adds Triple Modular Redundancy (TMR) to any circuit to improve
its reliability in space and other harsh environments, particularly for safety critical applications like
aerospace, medicine and defence.

> Safety-critical sectors require Application Specific Integrated Circuit (ASIC) designs
and Field Programmable Gate Array (FPGA) gateware to be fault-tolerant. In particular, high-reliability
computer systems used in spaceflight computing need to mitigate the effects of Single Event Upsets (SEUs)
caused by ionising radiation. One common fault- tolerant design technique is Triple Modular Redundancy (TMR),
which mitigates SEUs by triplicating key parts of the design and using voter circuits. Typically, this is
manually implemented by designers at the Hardware Description Language (HDL) level, but this is error-prone
and time-consuming. Leveraging the power and flexibility of the open- source Yosys Electronic Design
Automation (EDA) tool, in this thesis, I present TaMaRa: a novel fully automated TMR flow, implemented as a
Yosys plugin. I describe the design and implementation of the TaMaRa tool, and present extensive test results
using a combination of manual tests, formal verification and RTL fuzzing techniques.

TaMaRa was developed for my Bachelor of Computer Science (Honours) thesis at the University of Queensland,
Australia, during 2024 and 2025. For more information, please see my thesis:
[./papers/thesis/uqthesis.pdf](./papers/thesis/uqthesis.pdf)

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

When a new version of the Yosys submodule is pushed, use this to update it:

```bash
git submodule update --init --recursive --remote
```

### Compile and run
Generate the project (assuming you've installed Ninja, otherwise omit `-G Ninja`):

```bash
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release  # or Debug
```

Build:

```bash
cd build
ninja
```

This will generate the main artefact, `libtamara.so`. You can load this in Yosys as follows (from the build
dir):

```bash
$ yosys
yosys> plugin -i libtamara.so
```

This will then make available the `tamara_tmr` command (with help as well, which you should look at!)

For a quick build and run cycle, you can compile and load TaMaRa at the same time:

```bash
ninja && yosys -m libtamara.so
```

<!-- If you have Yosys installed on your system, you can run `ninja install` to install TaMaRa as a global plugin. -->

## Usage in Yosys
### Limitations
> [!CAUTION]
> **TaMaRa is not suitable for production use, and can only handle a very limited number of simple circuits.**

Unfortunately, the Honours timeframe is very limited, and I more or less ran out of time to complete the
algorithm.

There are also a number of [bugs](https://github.com/mattyoung101/tamara/issues) in more complex circuits,
including circuits with multiple logic cones (basically every serious circuit) and circuits that use memories.

### Circuit preparation
Designs that are being processed with TaMaRa should declare exactly one 1-bit signal as the voter error sink
using the `(* tamara_error_sink *)` Verilog annotation. For example:

```verilog
module my_module(
    input a,
    input b,
    (* tamara_error_sink *)
    input err
);
endmodule
```

Make sure that you do _not_ connect the error signal yourself; TaMaRa will handle that, so just leave it
unconnected. The error sink can be omitted, but TaMaRa will produce a warning.

This signal will be set to '1' when any voter in the circuit detects an error, and is '0' otherwise. This can
be used to trigger a reconfiguration or reset when an error is detected on FPGAs, or to take other corrective
action on an ASIC. TaMaRa intentionally leaves this up to the end user, and does not perform any scrubbing or
reconfiguration itself.

### Synthesis preparation
Although the circuit does not need to be substantially modified, the synthesis script does need to be.

Unlike in normal Yosys synthesis scripts, the design can't be lowered directly to FPGA/ASIC primitives (LUTs,
standard cells, etc). It first needs to be lowered to abstract logic primitives (AND gates, NOT gates, etc)
that TaMaRa can process. Then, TaMaRa can be run, after which the design can be lowered to FPGA primitives.

TaMaRa currently also requires you to run the `splitcells` and `splitnets` command before it is invoked.

TaMaRa is run through the `tamara_tmr`, which first needs to be loaded using `plugin -i libtamara.so`.

Factoring in all the above, an example synthesis script that processes `design.v` for the Lattice ECP5 might
look like this:

```bash
# Read design
read_verilog design.v
hierarchy -top top

# Lower to abstract AND gates etc
prep
splitcells
splitnets

# Run TaMaRa
plugin -i libtamara.so
tamara_tmr
opt_clean

# Lower to ECP5
synth_ecp5 -json netlist.json
```

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

### Fault-injection simulation
Fault-injection tests can be performed using the Python scripts `./tools/fault_injection_sweep.py` and
`./tools/multi_graph.py`. All these scripts need to be run from the `build` directory.

Make sure you have all the dependencies installed listed in `requirements.txt`.

The `fault_injection_sweep.py` is the main script, and should be pretty self explanatory:

```bash
$ python ./tools/fault_injection_sweep.py --help
usage: fault_injection_sweep.py [-h] --faults FAULTS --verilog VERILOG --top TOP --samples SAMPLES --type TYPE [--debug] [--nowrite] [--executor EXECUTOR] [--multi]

options:
  -h, --help           show this help message and exit
  --faults FAULTS      Inject up to this many faults
  --verilog VERILOG    Verilog file to test
  --top TOP            Top file in Verilog
  --samples SAMPLES    Number of simulations to run
  --type TYPE          'protected', 'unprotected', 'unmitigated', 'err_protected', or 'err_unprotected'
  --debug              Prints failure reason in run_eqy
  --nowrite            Do not write output files
  --executor EXECUTOR  Use Yosys SAT or eqy? (ys/eqy)
  --multi              Perform TMR twice?
```

Example usage:
```bash
../tools/fault_injection_sweep.py --faults 10 --verilog ../tests/verilog/crc_min.sv --top crc_const_variant4 --samples 100 --type unprotected
```

### Fuzzing and regression pipe
TaMaRa includes a regression pipeline based on Verilog fuzzing techniques to try and identify crashes and
other problematic behaviour in the tool.

You will need GNU Parallel and [Verismith](https://github.com/ymherklotz/verismith). Verismith is very
challenging to build, but I was able to get it to work on Arch as follows:

1. [Install ghcup](https://www.haskell.org/ghcup/install/) to setup the GHC toolchain.
2. Setup cabal 3.12.1.0 and GHC 9.6.4.
3. Build verismith using cabal.

```bash
ghcup install ghc --set 9.6.4
ghcup install cabal --set 3.12.1.0
cabal update
cabal build
```

Now, you need to symlink the location of the `verismith` binary to `<TAMARA>/build/verismith`. The command
`cabal list-bin verismith` will tell you where the binary is located.

Finally, to run the fuzzing suite, just go to the build directory and run `../tests/fuzz/verismith.sh`.

To run the regression test suite, you will need the Python `pyyaml`, `colorama` and `yaspin` packages. Then,
from the build directory, invoke `../tests/regress.py`. The specific tests to run are defined in
`tests/regress.yaml`.

### Debugging
When TaMaRa is compiled in debug mode (`-DCMAKE_BUILD_TYPE=Debug`), there are some environment variables you
can set to enable debugging functionality at runtime. The value of the environment variables doesn't matter,
just that they are set.

- `TAMARA_DEBUG_DUMP_ASYNC`: TaMaRa will verbosely dump timestamped PNG files of the netlist throughout the
algorithm in the current directory, without blocking the main algorithm. Files will be named like:
`dump_1740721386986_\cones_min_@_voter_builder.cpp:208.png`. This is invoked by the `DUMPASYNC` macro in the
code.
- `TAMARA_DEBUG_BYPASS_VOTER`: TaMaRa will bypass voter generation and instead generate a custom `$VOTER`
cell type with 3 inputs and 2 outputs, as a blackboxed cell. This can be used to debug voter wiring.
- `TAMARA_DEBUG_DUMP_BLOCK`: TaMaRa can pause execution at points where the `DUMP` macro is set and display the
netlist as a graph. This enables that functionality.
- `TAMARA_DEBUG_DUMP_RTLIL`: TaMaRa will dump the RTLIL text representation to the console at various points
where the `DUMP_RTLIL` macro is called. This will not block the main algorithm.
- `TAMARA_DEBUG_AGGRESSIVE_CLEAN`: Runs the `opt_clean` command inside `ElementWireNode::replicate` to quickly
  cleanup unused wires and make visual debugging less cluttered. **Can cause significant problems (i.e. break)
  certain circuits**
- `TAMARA_DISABLE_CONE_COLOURS`: Disables the colouring of cones in debug output, which can sometimes be
annoying

## Compiling papers
This repo also includes various papers including the proposal draft, presentation slides, and the actual
thesis itself. The papers are all written in [Typst](https://github.com/typst/typst).

To compile the papers, you will need:
- Typst == 0.13
- [MermaidJS CLI](https://github.com/mermaid-js/mermaid-cli)
- [dvisvgm](https://github.com/mgieseki/dvisvgm)
    - mupdf
    - mupdf-tools
- pdf2svg
- [Just](https://github.com/casey/just)

Next, in the papers directory, use `typst watch <file>` to edit and live reload. Or `typst compile` to just
compile it once.

For the proposal and proposal draft, build the Gantt charts by running `just`.

The thesis uses [uqthesis_eecs_hons](https://github.com/mattyoung101/uqthesis_eecs_hons) Typst template.

If you're using my [dotfiles](https://github.com/mattyoung101/dotfiles) (for some reason), you need to invoke
`:PinThesisMain` in Neovim in order to have the Tinymist LSP handle cross-file references correctly.

## Licence
Copyright (c) 2024-2025 Matt Young.

Code and tests are available under the **Mozilla Public License v2.0**, see the file LICENSE.code.

Papers and slides (in the `papers` directory) are available under **CC Attribution 4.0 International**,
see the file LICENSE.papers.

Many files in the `tests/verilog` directory have been pulled in from other projects. These are all under
compatible open-source licences, and have their copyright included at the top of the file if applicable.
As these are external projects, the TaMaRa MPL 2.0 licence does _not_ apply to these files.

