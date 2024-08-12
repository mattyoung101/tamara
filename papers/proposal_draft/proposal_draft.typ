#import "@preview/cetz:0.2.2": canvas, plot

// Colour links blue like LaTeX
#show cite: set text(fill: blue)
#show link: set text(fill: blue)
#show ref: set text(fill: blue)
#show footnote: set text(fill: blue)

#set list(indent: 12pt)
#set heading(numbering: "1.")
#set math.equation(numbering: "(1)")
#set page(numbering: "1")

#let TODO(msg) = {
  [#text(fill: red, weight: "bold", size: 12pt)[TODO #msg]]
}

#align(center, text(20pt)[
    *An automated triple modular redundancy EDA flow for Yosys*
])

#align(center, text(16pt)[
    _REIT4882 Draft Thesis Project Proposal_
])

#align(center, text(12pt)[
    Matt Young

    m.young2\@student.uq.edu.au

    August 2024
])

#[
#set par(justify: true)
#align(center)[
    *Abstract*

    Safety-critical sectors require Application Specific Integrated Circuit (ASIC) designs and Field
    Programmable Gate Array (FPGA) gateware to be fault-tolerant. In particular, space-fairing computers need
    to mitigate the effects of Single Event Upsets (SEUs) caused by ionising radiation. One common
    fault-tolerant design technique is Triple Modular Redundancy (TMR), which mitigates SEUs by triplicating
    key parts of the design and using voter circuits. Typically, this is manually implemented by designers at
    the Hardware Description Language (HDL) level, but this is error-prone and time-consuming. Leveraging the
    power and flexibility of the open-source Yosys Electronic Design Automation (EDA) tool, in this document I
    will propose TaMaRa: a novel fully automated TMR flow, implemented as a Yosys plugin. I provide a
    comprehensive review of relevant automated TMR literature, and provide a detailed plan of the TaMaRa
    project, including its design and verification.
]
]

// Create a scope for this style: https://typst.app/docs/reference/styling/
#[
    // https://typst.app/docs/reference/model/outline/#definitions-entry
    #show outline.entry.where(
      level: 1
    ): it => {
      v(12pt, weak: true)
      strong(it)
    }

    #outline(
        // https://www.reddit.com/r/typst/comments/1bp8zty/how_to_make_dots_in_outline_spaced_the_same_for/
        fill: box(width: 1fr, repeat(h(5pt) + "." + h(5pt))) + h(8pt),
        indent: auto
    )
]

// #outline(
//     title: [List of Figures],
//     fill: box(width: 1fr, repeat(h(5pt) + "." + h(5pt))) + h(8pt),
//     target: figure,
// )

#pagebreak()

= Background and introduction
For safety-critical sectors such as aerospace and defence, both Application Specific Integrated Circuits
(ASICs) and Field Programmable Gate Array (FPGA) gateware must be designed to be fault tolerant to prevent
catastrophic malfunctions. In the context of digital electronics, _fault tolerant_ means that the design is
able to gracefully recover and continue operating in the event of a fault, or upset. A Single Event Upset
(SEU) occurs when ionising radiation strikes a transistor on a digital circuit, causing it to transition from
a 1 to a 0, or vice versa. This type of upset is most common in space, where the Earth's atmosphere is not
present to dissipate the ionising particles @OBryan2021. On an unprotected system, an unlucky SEU may corrupt
the system's state to such a severe degree that it may cause destruction or loss of life - particularly
important given the safety-critical nature of most space-fairing systems (satellites, crew capsules, missiles,
etc). Thus, fault tolerant computing is widely studied and applied for space-based computing systems.

One common fault-tolerant design technique is Triple Modular Redundancy (TMR), which mitigates SEUs by
triplicating key parts of the design and using voter circuits to select a non-corrupted result if an SEU
occurs. Typically, TMR is manually designed at the Hardware Description Language (HDL) level, for example, by
manually instantiating three copies of the target module, designing a voter circuit, and linking them all
together. However, this approach is an additional time-consuming and potentially error-prone step in the
already complex design pipeline.

#TODO("diagram of TMR")

Modern digital ICs and FPGAs are described using Hardware Description Languages (HDLs), such as SystemVerilog
or VHDL. The process of transforming this high level description into a photolithography mask (for ICs) or
bitstream (for FPGAs) is achieved through the use of Electronic Design Automation (EDA) tools. This generally
comprises of the following stages:

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
process nodes (e.g. Skywater 130nm). Importantly, for this thesis, Yosys can be modified either by changing
the source code or by developing modular plugins that can be dynamically loaded at runtime. Due to specific
advice from the Yosys development team @Engelhardt2024, TaMaRa will be developed as a loadable C++ plugin.

#TODO("diagram of the synthesis flow")

= Literature review
== Introduction, methodology and terminology
The automation of triple modular redundancy, as well as associated topics such as general fault-tolerant
computing methods and the effects of SEUs on digital hardware, have been studied a fair amount in academic
literature. Several authors have invented a number of approaches to automate TMR, at various levels of
granularity, and at various points in the FPGA/ASIC synthesis pipeline. This presents an interesting challenge
to systematically review and categorise. To address this, Williams @Williams2024 proposed the use of a
two-dimensional graph, which I have implemented as follows:

// #let style = (stroke: black, fill: rgb(0, 0, 200, 75))
// #let x_axis = ("Low-level", "High-level")
// #let y_axis = ("Software", "HDL", "Post-synthesis", "Post-techmapping", "Post-implementation", "Multi-FPGA",
//     "Multi-PCB", "Multi-System")
// #canvas(length: 1cm, {
//   plot.plot(size: (12, 6),
//     x-ticks: x_axis.enumerate().map(((i, s)) => (i+1, raw(s))),
//     x-tick-step: none,
//     y-tick-step: none,
//     x-label: "Granularity",
//     {
//       plot.add(
//         style: style,
//         domain: (-calc.pi, calc.pi), calc.sin)
//     })
// })

#TODO("the 2D graph")

== Fault tolerant computing and redundancy
The application of triple modular redundancy to computer systems was first introduced into academia by
Lyons and Vanderkul @Lyons1962 in 1962. Like much of computer science, however, the authors trace the original
concept back to John von Neumann
#footnote("von Neumann was a prolific academic who invented many concepts important in computer science.")
. In addition to introducing the application of TMR to computer systems, the
authors also provide a rigorous Monte-Carlo mathematical analysis of the reliability of TMR. One important
takeaway from this is that the only way to make a system reliably redundant is to split it into multiple
components, each of which is more reliable than the system as a whole. In the modern FPGA concept, this
implies applying TMR at an RTL module level, although as we will soon see, more optimal and finer grained TMR
can be applied. Although their Monte Carlo analysis shows that TMR dramatically improves reliability, they
importantly show that as the number of modules $M$ in the computer system increases, the computer will
eventually become less reliable. This is due to the fact that the voter circuits may not themselves be
perfectly reliable, and is important to note for FPGA and ASIC designs which may instantiate hundreds or
potentially thousands of modules.

However, the hardening of space and safety-critical systems is not just limited to triple modular redundancy.

#TODO("more background literature")

== Single Event Upsets (SEUs)
#TODO("more literature defining probabilities of SEUs on ASICs/FPGAs in space")

#TODO("also consider talking about rad-hardened CMOS processes for ASICs")

== Post-synthesis automated TMR
Recognising that prior literature focused mostly around manual or theoretical TMR, and the limitations of a
manual approach, Johnson and Wirthlin @Johnson2010 introduced four algorithms for the automatic insertion of
TMR voters in a circuit, with a particular focus on timing and area trade-offs. Together with the thesis this
paper was based on @Johnson2010a, these two publications form the seminal works on automated TMR for digital
EDA.
#TODO("")

Whilst they provide an excellent design of TMR insertion algorithms, and a very thorough analysis of their
area and timing trade-offs, Johnson and Wirthlin do not have a rigorous analysis of the
correctness of these algorithms. They produce experimental results demonstrating the timing and area
trade-offs of the TMR algorithms on a real Xilinx Virtix 1000 FPGA, up to the point of P&R, but do not run it
on a real device. More importantly, they also do not have any formal verification or simulated SEU scenarios
to prove that the algorithms both work as intended, and keep the underlying behaviour of the circuit the same.
Finally, in his thesis @Johnson2010a, Johnson states that the benchmark designs were synthesised using a
combination of the commercial Synopsys Synplify tool, and the _BYU-LANL Triple Modular Redundancy (BL-TMR)
Tool_. This Java-based set of tools ingest EDIF-format netlists, perform TMR on them, and write the
processed result to a new EDIF netlist, which can be re-ingested by the synthesis program for place and route.
This is quite a complex process, and was also designed before Yosys was introduced in 2013. It would be very
better if the TMR pass was instead integrated directly into the synthesis tool - which is only possible
for Yosys, as Synplify is commercial proprietary software. This is especially important for industry users who
often have long and complicated synthesis flows.

Later, Skouson et al. @Skouson2020 (from the same lab as above) introduced SpyDrNet, a
Python-based netlist transformation tool that also implements TMR using the same algorithm as above. SpyDrNet
is a great general purpose transformation tool for research purposes, but again is a separate tool that is not
integrated _directly_ into the synthesis process. I instead aim to make a _production_ ready tool, with a
focus on ease-of-use, correctness and performance.

Using a similar approach, Benites and Kastensmidt @Benites2018, and Benites' thesis @Benites2018a, introduce an
automated TMR approach implemented as a Tcl script for use in Cadence tools. They distinguish between "coarse
grained TMR" (which they call "CGTMR"), applied at the RTL module level, and "fine grained TMR" (which they
call "FGTMR"), applied at the sub-module (i.e. net) level. Building on that, they develop an approach that
replicates both combinatorial and sequential circuits, which they call "fine grain distributed TMR" or
"FGDTMR". They split their TMR pipeline into three stages: implementation ("TMRi"), optimisation ("TMRo"), and
verification ("TMRv"). The implementation stage works by creating a new design to house the TMR design (which
I'll call the "container design"), and instantiating copies of the original circuit in the container design.
Depending on which mode the user selects, the authors state that either each "sequential gate" will be
replaced by three copies and a voter, or "triplicated voters" will be inserted. What happens in the
optimisation stage is not clear as Benites does not elaborate at all, but he does state it's only relevant
for ASICs and involves "gate sizing". For verification, Benites uses a combination of fault-injection
simulation (where SEUs are intentionally injected into the simulation), and formal verification through
equivalence checking. Equivalence checking involves the use of Boolean satisfiability solvers ("SAT solvers")
to mathematically prove one circuit is equivalent to another. Benites' key verification contribution is
identifying a more optimal way to use equivalence checking to verify fine-grained TMR. He identified that each
combinatorial logic path will be composed of a path identical to the original logic, plus one or more voters.
This way, he only has to prove that each "logic cone" as he describes it is equivalent to the original
circuit. Later on, he also uses a more broad-phase equivalence checking system to prove that the circuits
pre and post-TMR have the same behaviours.

One of the most important takeaways from these works are related to clock synchronisation. Benites
interestingly chooses to not replicate clocks or asynchronous reset lines, which he states is due to clock
skew and challenges with multiple clock domains created by the redundancy. Due to the clear challenges
involved, ignoring clocks and asynchronous resets is a reasonable limitation introduced by the authors, and
potentially reasonable for us to introduce as well. Nonetheless, it is a limitation I would like to address in
TaMaRa if possible, since leaving these elements unprotected creates a serious hole that would likely preclude
its real-world usage
#footnote([My view is essentially that an unprotected circuit remains unprotected, regardless of how difficult
    it is to correct clock skewing. In other words, simply saying that the clock skew exists doesn't magically
    resolve the issue. In Honours, we are severely time limited, but it's still my goal to address this
    limitation if possible.]).
Arguably, the most important takeaway from Benites' work is the use of equivalence
checking in the TMR verification stage. This is especially important since Johnson @Johnson2010 did not
formally verify his approach. Benites' usage of formal verification, in particular, equivalence checking, is
an excellent starting point to design the verification methodology for TaMaRa.

Although the most commonly cited literature implements automated TMR post-synthesis on the netlist, other
authors over time have explored other stages of the ASIC/FPGA synthesis pipeline to insert TMR, both lower
level and higher level.

== Low-level TMR approaches
On the lower level side, Hindman et al. @Hindman2011 introduce an ASIC standard-cell
based automated TMR approach. When digital circuits are synthesised into ASICs, they are technology mapped
onto standard cells provided by the foundry as part of their Process Design Kit (PDK). For example, SkyWater
Technology provides an open-source 130 nm ASIC PDK, which contains standard cells for NAND gates, muxes and
more @skywater. The authors design a TMR flip-flop cell, known as a "Triple Redundant Self Correcting
Master-Slave Flip-Flop" (TRSCMSFF), that mitigates SEUs at the implementation level. Since this is so low
level and operates below the entire synthesis/place and route pipeline, their approach has the advantage that
_any_ design - including proprietary encrypted IP cores that are (unfortunately) common in industry - can be
made redundant. Very importantly, the original design need not be aware of the TMR implementation, so this
approach fulfills my goal of making TMR available seamlessly to designers. The authors demonstrate that the
TRSCMSFF cell adds minimal overhead to logic speed and power consumption, and even perform a real-life
radiation test under a high energy ion beam. Overall, this is an excellent approach for ASICs. However, this
approach, being standard-cell specific, cannot be applied to FPGA designs. Rather, the FPGA manufacturers
themselves would need to apply this method to make a series of specially rad-hardened devices (note that an
FPGA is itself an ASIC
#footnote([This terminology may be confusing, so, to clarifty: ASICs encompass the majority of silicon
    ICs with an application-specific purpose. This includes devices like GPUs, NPUs as well as more
    domain-specific chips such as video transcoders or RF transceivers. An FPGA is a specific type of ASIC
    that implements an array of LUTs that can be programmed by SRAM.])).
It would also appear that designers
would have to port the TRSCMSFF cell to each fab and process node they intend to target. While TaMaRa will
have worse power, performance and area (PPA) trade-offs on ASICs than this method, it is also more general in
that it can target FPGAs _and_ ASICs due to being integrated directly into Yosys. Nevertheless, it would
appear that for the specific case of targeting the best PPA trade-offs for TMR on ASICs, the approach
described in @Hindman2011 is the most optimal one available.

// future research topic! design a rad hardened FPGA using this approach!

== High-level TMR approaches
Several authors have investigated applying TMR directly to the HDL source code - a much higher level approach
than either netlist or gate level. One of the most notable examples was introduced by Kulis @Kulis2017,
through a tool he calls "TMRG". TMRG operates on Verilog RTL by implementing the majority of a Verilog parser
and elaborator from scratch. It takes as input Verilog RTL, as well as a selection of Verilog source comments
that act as annotations to guide the tool on its behaviour. In turn, the tool modifies the design code and
outputs processed Verilog RTL that implements TMR, as well as Synopsys Design Compiler design constraints.
Like the goal of TaMaRa, the TMRG approach is designed to target both FPGAs and ASICs, and for FPGAs, Kulis
correctly identifies the issue that not all FPGA blocks can be replicated. For example, a design that
instantiates a PLL clock divider on an FPGA that only contains one PLL could not be replicated. Kulis also
correctly identifies that optimisation-driven synthesis tools such as Yosys and Synopsys DC will eliminate TMR
logic as part of the synthesis pipeline, as the redundancy is, by nature, redundant and subject to removal. In
Yosys, this occurs specifically in the `opt_share` and `opt_clean` passes according to specific advice from
the development team @Engelhardt2024. However, unlike Synopsys DC, Yosys is not constraint driven, which means
that Kulis' constraint-based approach to preserving TMR logic through optimisation would not work in this
case.  Finally, since TMRG re-implements the majority of a synthesis tool's frontend (including the parser and
elaborator), it is limited to only supporting Verilog. Yosys natively supports Verilog and some SystemVerilog,
with plugins @synlig providing more complete SV and VHDL support. Since TaMaRa uses Yosys' existing frontend,
it should be more reliable and useable with many more HDLs.

Lee et al. @Lee2017 present "TLegUp", an extension to the prior "LegUp" High Level Synthesis (HLS) tool. As
stated earlier in this document, modern FPGAs and ASICs are typically designed using Hardware Description
Languages (HDLs). HLS is an alternative approach that aims to synthesise FPGA/ASIC designs from high-level
software source code, typically the C or C++ programming languages. On the background of TMR in FPGAs in
general, the authors identify the necessity of "configuration scrubbing", that is, the FPGA reconfiguring
itself when one of the TMR voters detects a fault. Neither their TLegUp nor our TaMaRa will address this
directly, instead, it's usually best left up to the FPGA vendors themselves (additionally, TaMaRa targets
ASICs which cannot be runtime reconfigured). Using voter insertion algorithms inspired by Johnson
@Johnson2010, the authors operate on LLVM Intermediate Representation (IR) code generated by the Clang
compiler. By inserting voters before both the HLS and RTL synthesis processes have been run, cleverly the
LegUp HLS system will account for the critical path delays introduced by the TMR process. This means that, in
addition to performance benefits, pipelined TMR voters can be inserted. The authors also identify four major
locations to insert voters: feedback paths from the datapath, FSMs, memory output signals and output ports on
the top module. Although TaMaRa isn't HLS-based, Yosys does have the ability to detect abstract features like
FSMs, so we could potentially follow this methodology as well. The authors also perform functional simulation
using Xilinx ISE, and a real-world simulation by using a Microblaze soft core to inject faults into various
designs. They state TLegUp reduces the error rate by 9x, which could be further improved by using better
placement algorithms. Despite the productivity gains, and in this case the benefits of pipelined voters, HLS
does not come without its own issues. Lahti et al. @Lahti2019 note that the quality of HLS results continues
to be worse than those designed with RTL, and HLS generally does not see widespread industry usage in
production designs. One other key limitation that Lee et al. do not fully address is the synthesis
optimisation process incorrectly removing the redundant TMR logic. Their workaround is to disable "resource
sharing options in Xilinx ISE to prevent sub-expression elimination", but ideally we would not have to disable
such a critical optimisation step just to implement TMR. TaMaRa aims to address this limitation by working
with Yosys directly.

Khatri et al. @Khatri2018 propose a similar, albeit much less sophisticated approach. They develop a Matlab
script that ingests a Verilog RTL module, instantiates it three times (to replicate it), and wraps it in a new
top-level module. They also propose a new majority voter using a 2:1 multiplexer, which they claim has 50%
better Fault Mask Ratio (FMR) than the traditional AND-gate based approach. The authors test only one single
circuit, described as a "simple benchmark design", in a fault-injection RTL simulation. They do not use any
systematic verification methodology that other authors use, only injecting a limited number of faults into one
single design. Khatri et al. also make no mention of the limitations that other authors identify for this
high-level TMR approach. This includes the PPA trade-offs that Benites @Benites2018 and Johnson @Johnson2010
identify, as well as the logic optimisation and resource utilisation issues that Kulis @Kulis2017 correctly
pointed out. The decision to develop the tool as a GUI application is highly questionable as it significantly
interrupts the typical command-line based synthesis flow. This is especially true for ASICs, which have very
long synthesis pipelines that are typically Tcl scripted. Whilst this approach is not exactly very thorough or
high quality, the higher reliability voter circuit may possibly be worth investigating.

== TMR verification
While Benites @Benites2018 @Benites2018a discusses verification of the automated TMR process, and other
authors @Lee2017 @Khatri2018 @Hindman2011 also use various different verification/testing methodologies, there
is also some literature that exclusively focuses on the verification aspect. Verification is one of the most
important parts of this process due to the safety-critical nature of the devices TMR is typically deployed to.
Additionally, there are different interesting trade-offs between different verification processes.

#TODO("")

= Project plan
== Aims of the project
#TODO("this needs an overhaul based on our latest meetings with John and Janet")

This thesis is governed by two overarching aims:

- To design a C++ plugin for the Yosys synthesis tool that, when presented with any Yosys-compatible
    HDL input, will apply an algorithm to turn the selected HDL module(s) into a triply modular redundant design,
    suitable for space.
- To design and a implement a comprehensive verification process for the above pass, including the use of formal
    methods, HDL simulation, fuzzing and potential real-life radiation exposure.

Much like designing a pass for a compiler, designing a pass for an EDA tool is no light undertaking. It needs
to handle all possible designs the user may provide as input, and provide a high degree of assurance of
correctness. This is particularly important given the safety-critical nature of the designs users may provide
to TaMaRa. I do not undertake this lightly, and the rigorous verification methodology is a necessity to
produce a pass worth using.

These two major aims can be broken down into smaller aims. Under the design pipeline:

#TODO("continue")

== Engineering requirements
Due to the large and complex nature of the TaMaRa development process, I decided it beneficial to apply the
MoSCoW engineering requirements system. I present the requirements and their justifications. The capitalised
keywords are to be interpreted according to RFC 2119 @Bradner1997.

*TMR pass requirements*

#table(
    columns: (auto, auto),
    inset: 5pt,
    align: horizon,
    table.header(
    [*Requirement*], [*Justification*],
    ),
    [ TaMaRa SHALL be implemented as a C++ pass for the Yosys synthesis tool ],
    [ Yosys is certainly going to be the synthesis tool used, and the C++ plugin API is the most stable. ],

    [ TaMaRa SHALL process the design in such a way that triple modular redundancy (TMR) is applied to the
    selected HDL module(s), protecting it from SEUs ],
    [ This is the overarching goal of the thesis. ],

    [ TaMaRa MAY operate at any desired level of granularity - anywhere from RTL code level, to elaboration,
    to techmapping - but it SHALL operate on at least one level of granularity ],
    [ As long as the TMR is implemented correctly, it doesn't matter what level of granularity the algorithm
    uses. Each level of granularity has different trade-offs which still require research at this stage. ],

    [ TaMaRa SHOULD compare coarse and fine grained TMR ],
    [ It would be interesting to see the area and reliability effects of applying TMR in at least two
    different ways. This is left as a SHOULD in case of serious time constraints. ],

    [ TaMaRa SHOULD be capable of handling large designs, up to and including picorv32, in reasonable amounts
    of time and memory ],
    [ Also supports the overarching goal of the thesis, but left as a SHOULD in case of major unforeseen
    implementation issues with the performance. ],

    [ TaMaRa MAY handle FPGA primitives like SRAMs and DSP slices ],
    [ Most likely will not handle these primitives as there's no reliable way to replicate them across all
    FPGA vendors supported by Yosys. ],

    [ TaMaRa MAY make the voters themselves redundant ],
    [ Could be added for extra assurance, but not typically considered necessary in industry. ],

    [ TaMaRa SHOULD NOT be timing driven ],
    [ Timing is best left up to the P&R tool (Nextpnr). Although some EDA synthesis tools are timing driven,
    Yosys currently is not. ],

    [ TaMaRa SHOULD have a clean codebase through the use of tools like clang-tidy ],
    [ Easy to implement and highly desirable but not strictly necessary for correct functioning. ],

    [ TaMaRa SHALL NOT consider multi-bit upsets ],
    [ Although multi-bit upsets may occur in practice, this work focuses on SEUs in particular. MBUs are much
    less likely (#TODO("citation?")) and require significant area increases due to extra voters
    (#TODO("citation?") ],
)

*Verification requirements*

#table(
    columns: (auto, auto),
    inset: 5pt,
    align: horizon,
    table.header(
    [*Requirement*], [*Justification*],
    ),
    [ Verification simulation SHALL be performed using one or more of: Verilator, Icarus Verilog, cxxrtl ],
    [ These are the best open-source simulation tools, and each have different trade-offs (e.g. Verilator is
    fast, but not sub-cycle accurate). ],

    [ Verification SHOULD involve a complex design (e.g. picorv32 CPU) in a simulated SEU environment ],
    [ This is an important final test, but is left as a SHOULD requirement in case of major unforeseen
    issues applying TMR to large designs. ],

    [ Verification SHALL involve equivalence checking (formally proving that a design acts the same before
    and after TMR) using _SymbiYosys_ and _eqy_ ],
    [ Equivalence checking is necessary to formally prove that the TMR pass does not modify the behaviour of
    the design, only that it adds TMR. ],

    [ Verification MAY involve fuzzing equivalence checking (generating random RTL modules, applying TMR,
    and checking they're identical) ],
    [ It's not clear at the time of writing whether a fully end-to-end, automated fuzzing approach for
    equivalence checking is possible. ],

    [ Verification SHALL involve mutation coverage (injecting faults into the design and formally proving
    that TaMaRa mitigates them) using _mcy_ ],
    [ Mutation coverage is necessary to formally prove that the TMR pass correctly mitigates SEUs. ],

    [ Verification MAY involve fuzzing mutation coverage, if such a thing is possible ],
    [ Early research indicates that the generation of random RTL _as well as_ random testbenches is still
    under active research in academia. ],

    [ Verification SHOULD NOT involve a physical, real-life radiation test whereby an FPGA with a TaMaRa bitstream
    on it is exposed to radiation ],
    [ UQ does not have the facilities to expose a real-life FPGA to radiation. Even if it did, the risks and
    challenges created by this verification approach would not be worth its utilisation. ]
)

== Implementation plan
#TODO("")

== Milestones and timeline
To design the timeline of the TaMaRa project, I use a Gantt chart, shown below.

#image("gantt_mermaid.svg", width: 100%)

// #box(
//     image("gantt_mermaid.svg", width: 100%),
//     inset: 10%,
//     clip: true
// )

== Risk assessment
Before it was known that UQ does not have the facilities to expose an FPGA to real-life radiation, it was
considered a possibility that TaMaRa would be tested on a real-life device under intense radiation conditions.
This would have created a number of risks and challenges. However, now that this verification approach has
been discarded, TaMaRa is a pure software/gateware project, and thus carries no significant health and safety
risks.

Nonetheless, TaMaRa is not completely risk-free. Due to the fact that it may be deployed on safety-critical
systems, its correct functioning is important. Hence, a simple risk assessment has been prepared.

// TODO table background colours
#table(
    columns: (auto, auto, auto, auto),
    inset: 5pt,
    align: horizon,
    table.header(
    [*Risk*], [*Potential damage*], [*Rating*], [*Mitigation strategy*],
    [ TaMaRa implementation is not able to be completed in time ],
    [ Thesis result is much worse. Unable to verify results. ],
    [ Medium ],
    [ Proper project planning including formulation of engineering requirements and research questions.
    Regular meetings with supervisor. Contact with YosysHQ dev team. ],

    [ TaMaRa verification is not able to be completed successfully ],
    [ Thesis result is worse, not able to prove the TMR algorithm works. ],
    [ Medium ],
    [ Research into formal verification and basing work on prior papers. Contact with YosysHQ dev team. ],

    [ TaMaRa introduces subtle differences in behaviour in the output circuit ],
    [ Safety-critical systems that TaMaRa is used to design may have unexpected behaviour, potentially
    leading to severe loss of life or property. ],
    [ High ],
    [ Rigorous verification including formal verification and fault-injection simulation. ],

    [ TaMaRa does not implement TMR correctly ],
    [ Safety-critical systems that TaMaRa is used to design may fail due to SEUs, causing severe loss of
    life or property. ],
    [ High ],
    [ Rigorous verification including formal verification and fault-injection simulation. ]
    ),
)

== Ethics
As mentioned in the risk assessment, since TaMaRa may be used to design safety-critical systems, its correct
functioning is considered very important. In addition to being a risk, a subtle failure that accidentally
produces a non-redundant system could be considered an ethical issue, especially if it does result in
destruction or loss of life. This will (hopefully) be mitigated by a rigorous verification methodology.

TaMaRa may be used to design defence systems. This is not considered a significant ethical issue.

= Conclusion
#TODO("")

#pagebreak()
= References
#bibliography("proposal.bib", title: none, style: "institute-of-electrical-and-electronics-engineers")
