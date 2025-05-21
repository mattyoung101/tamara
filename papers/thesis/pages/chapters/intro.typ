#import "../../util/macros.typ": *

= Introduction
For safety-critical sectors such as aerospace, defence, and medicine, both Application Specific Integrated
Circuits (ASICs) and Field Programmable Gate Array (FPGA) gateware must be designed to be fault tolerant to
prevent catastrophic malfunctions. In the context of digital electronics, _fault tolerant_ means that the
design is able to gracefully recover and continue operating in the event of a fault, or upset. A Single Event
Upset (SEU) occurs when ionising radiation strikes a transistor on a digital circuit, causing it to transition
from a 1 to a 0, or vice versa. This type of upset is most common in space, where the Earth's magnetosphere is
not present to dissipate the ionising particles @OBryan2021. On an unprotected system, an unlucky SEU may
corrupt the system's state to such a severe degree that it may cause destruction or loss of life -
particularly important given the safety-critical nature of most space-fairing systems (satellites, crew
capsules, missiles, etc). Thus, fault tolerant computing is widely studied and applied for space-based
computing systems.

One common fault-tolerant design technique is Triple Modular Redundancy (TMR), which mitigates SEUs by
triplicating key parts of the design and using voter circuits to select a non-corrupted result if an SEU
occurs (see @fig:tmrdiagram). Typically, TMR is manually designed at the Hardware Description Language (HDL)
level, for example, by manually instantiating three copies of the target module, designing a voter circuit,
and linking them all together. However, this approach is an additional time-consuming and potentially
error-prone step in the already complex design pipeline.

#figure(
    image("../../diagrams/tmr_diagram.svg"),
    caption: [ Diagram demonstrating how TMR is inserted into an abstract design ]
) <fig:tmrdiagram>

Modern digital ICs and FPGAs are described using Hardware Description Languages (HDLs), such as SystemVerilog
or VHDL. The process of transforming this high level description into a photolithography mask (for ICs) or
bitstream (for FPGAs) is achieved through the use of Electronic Design Automation (EDA) tools. This generally
comprises of the following stages (@fig:synthflow):

#figure(
    image("../../diagrams/synthesis_flow.svg"),
    caption: [ Simplified representation of a typical EDA synthesis flow ]
) <fig:synthflow>

- *Synthesis*: The transformation of a high-level textual HDL description into a lower level synthesisable
    netlist.
    - *Elaboration:* Includes the instantiation of HDL modules, resolution of generic parameters and
        constants. Like compilers, synthesis tools are typically split into frontend/backend, and elaboration
        could be considered a frontend/language parsing task.
    - *Optimisation:* This includes a multitude of tasks, anywhere from small peephole optimisations, to
        completely re-coding FSMs. In commercial tools, this is typically timing driven.
    - *Technology mapping:* This involves mapping the technology-independent netlist to the target platform,
        whether that be FPGA LUTs, or ASIC standard cells.
- *Placement*: The process of optimally placing the netlist onto the target device. For FPGAs, this involves
    choosing which logic elements to use. For digital ICs, this is much more complex and manual - usually done
    by dedicated layout engineers who design a _floorplan_.
- *Routing*: The process of optimally connecting all the placed logic elements (FPGAs) or standard cells
    (ICs).

Due to their enormous complexity and cutting-edge nature, most IC EDA tools are commercial proprietary
software sold by the big three vendors: Synopsys, Cadence and Siemens. These are economically infeasible for
almost all researchers, and even if they could be licenced, would not be possible to extend to implement
custom synthesis passes. The major FPGA vendors, AMD and Intel, also develop their own EDA tools for each of
their own devices, which are often cheaper or free. However, these tools are still proprietary software and
cannot be modified by researchers. Until recently, there was no freely available, research-grade, open-source
EDA tool available for study and improvement. That changed with the introduction of Yosys @Wolf2013. Yosys is
a capable synthesis tool that can emit optimised netlists for various FPGA families as well as a few silicon
process nodes (e.g. Skywater 130nm). When combined with the Nextpnr place and route tool @Shah2019,
Yosys+Nextpnr forms a fully end-to-end FPGA synthesis flow for Lattice iCE40 and ECP5 devices. Importantly,
for this thesis, Yosys can be modified either by changing the source code or by developing modular plugins
that can be dynamically loaded at runtime.

This thesis will focus on the design and implementation of _TaMaRa_, an automated Triple Modular Redundancy
EDA flow for Yosys. In @chap:lit, I present a comprehensive literature review of prior TMR algorithms by
classifying them into dichotomy of either netlist-level or design-level approaches. I evaluate the strengths
and weakness of each approach, and determine how it will shape the TaMaRa algorithm. In @chap:method, I
introduce the TaMaRa algorithm, and demonstrate how it was implemented as a Yosys plugin. Finally, in
@chap:results, I show the results of the TaMaRa algorithm for a number of real-world circuits and measure its
ability to mitigate SEUs.

== Yosys internals
Yosys supports dynamically loading plugins at runtime. These plugins are compiled against the Yosys codebase,
and are compiled into Unix shared objects (.so files). This allows users to define and register custom passes
and frontends within the main Yosys application, without having to trouble the upstream maintainers with the
maintenance of new code. This is precisely why the Yosys authors advised TaMaRa to be implemented as a Yosys
plugin, rather than as an upstream contribution @Engelhardt2024. This plugin system is a unique and powerful
part of Yosys, and one of the main advantages of the tool being open-source. End users are free to design and
implement their own plugins, under their own choice of licence, to extend Yosys in any way they see fit.
Comparatively, proprietary tools are limited to rather simple Tcl scripting, as further modification is locked
away behind complex intellectual property (IP) rights, including patents, and non-disclosure agreements
(NDAs).

Yosys uses _frontends_ to read various Register Transfer Languages (RTLs), such as Verilog or SystemVerilog.
Using the typical combination of a lexer and parser, Yosys transforms RTL source code into an Abstract Syntax
Tree (AST), and then into an intermediate language called RTL Intermediate Language (RTLIL). RTLIL is, in
essence, a model of a given circuit's netlist at various different levels of abstraction. RTLIL can be used
anywhere from a near direct 1:1 mapping with the original RTL, complete with processes and annotations, all
the way down to very low-level FPGA/ASIC specific primitives. The typical Yosys flow is to use its extensive
set of built-in commands and synthesis scripts to process a circuit from this high-level abstraction, down to
device-specific low-level primitives; for example, ASIC standard cells for a given process node. This is
virtually identical to the flow used by commercial tools such as Synopsys' Design Compiler or Xilinx's Vivado.

TaMaRa operates at the netlist level, which in the context of Yosys means operating on RTLIL circuits.
Internally, RTLIL is implemented as a set of C++ classes that describe the general structure of a netlist as
wires (`RTLIL::Wire`) and cells (`RTLIL::Cell`). Wires may potentially be multi-bit, which introduces a
challenge as TaMaRa voters are single-bit. Groups of wires and cells can be bundled into a module
(`RTLIL::Module`). Modules are arranged in a tree structure, where the root of the tree is known as the top
module. RTLIL is one of the most important and powerful parts of Yosys, because it allows plugins like TaMaRa
to operate on a common intermediate representation of a circuit netlist, irrespective of the user's choice of
input RTL language and/or output type. This means that TaMaRa can operate exactly the same for a user using
VHDL for a Lattice iCE40 FPGA, and a user using Verilog for a Skywater 130 nm ASIC. RTLIL's importance is
further elaborated on by Wolf @Wolf2013 and Shah et al. @Shah2019. In essence, the unique combination of Yosys
being open-source, its runtime plugin system, and its RTL Intermediate Language is what makes Yosys the ideal
platform to develop the TaMaRa algorithm for.
