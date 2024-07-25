// Colour links blue like LaTeX
#show cite: set text(fill: blue)
#show link: set text(fill: blue)
#show ref: set text(fill: blue)
#show footnote: set text(fill: blue)

#set list(indent: 12pt)
#set heading(numbering: "1.")
#set math.equation(numbering: "(1)")
#set page(numbering: "1")

#align(center, text(20pt)[
    *An automated triple modular redundancy EDA flow for Yosys*
])

#align(center, text(16pt)[
    _REIT4882 Thesis Draft Project Proposal_
])

#align(center, text(12pt)[
    Matt Young

    46972495

    m.young2\@student.uq.edu.au

    August 2024
])


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
//#pagebreak()

= Introduction and background
For safety-critical sectors such as aerospace and defence, silicon ICs and FPGA gateware must be designed to
be fault tolerant. In the context of digital electronics, _fault tolerant_ means that the design is able to
gracefully recover and continue operating in the event of a fault, or upset. A Single Event Upset (SEU) occurs
when ionising radiation strikes a transistor on a digital circuit, causing it to transition from a 1 to a 0,
or vice versa. This type of upset is most common in space, where the Earth's atmosphere is not present to
dissipate the ionising particles. On an unprotected system, an unlucky SEU may corrupt the system's state to
such a severe degree that it may cause destruction or loss of life - particularly important given the
safety-critical nature of most space-fairing systems (satellites, crew capsules, missiles, etc).

One common fault-tolerant design technique is Triple Modular Redundancy (TMR), which mitigates SEUs by
triplicating key parts of the design and using voter circuits to select a non-corrupted result if an SEU
occurs. Typically, TMR is manually designed at the Hardware Description Language (HDL) level, for example, by
manually instantiating three copies of the target module, designing a voter circuit, and linking them all
together. However, this approach is an additional time-consuming and potentially error-prone step in the
already complex design pipeline.

// TODO: diagram of TMR

To address these issues, I propose TaMaRa: a novel fully automated TMR flow for the open source Yosys EDA tool
@Shah2019.

Modern digital ICs and FPGAs are described using Hardware Description Languages (HDLs), such as SystemVerilog
or VHDL. The process of transforming this high level description into a photolithography mask (for ICs) or
bitstream (for FPGAs) is achieved through the use of Electronic Design Automation (EDA) tools. This generally
comprises of the following stages:

- *Synthesis*: The transformation of a high-level textual HDL description into a lower level synthesisable
    netlist.
    - Elaboration
    - Optimisation
    - Technology mapping
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
EDA tool available for study and improvement. That changed with the introduction of Yosys and Nextpnr
@Shah2019. Yosys is a capable synthesis tool that can emit optimised netlists for various FPGA families as
well as a few silicon process nodes (e.g. Skywater 130nm). Nextpnr is a place and route tool that targets
various FPGA families. Together, they provide a fully open-source, end-to-end EDA toolchain. Importantly, for
this thesis, Yosys can be modified either by changing the source code or by developing modular plugins that
can be dynamically loaded at runtime. Due to specific advice from the Yosys development team @Engelhardt2024,
TaMaRa will be developed as a loadable C++ plugin.

// TODO diagram of the synthesis flow

= Aims
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

- Research the applications of graph theory to

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
    [ Tamara SHALL be implemented as a C++ pass for the Yosys synthesis tool ],
    [ Yosys is certainly going to be the synthesis tool used, and the C++ plugin API is the most stable. ],

    [ Tamara SHALL process the design in such a way that triple modular redundancy (TMR) is applied to the
    selected HDL module(s), protecting it from SEUs ],
    [ This is the overarching goal of the thesis. ],

    [ Tamara MAY operate at any desired level of granularity - anywhere from RTL code level, to elaboration,
    to techmapping - but it SHALL operate on at least one level of granularity ],
    [ As long as the TMR is implemented correctly, it doesn't matter what level of granularity the algorithm
    uses. Each level of granularity has different tradeoffs which still require research at this stage. ],

    [ Tamara SHOULD be capable of handling large designs, up to and including picorv32, in reasonable amounts
    of time and memory ],
    [ Also supports the overarching goal of the thesis, but left as a SHOULD in case of major unforeseen
    implementation issues with the performance. ],

    [ Tamara MAY handle FPGA primitives like SRAMs and DSP slices ],
    [ Most likely will not handle these primitives as there's no reliable way to replicate them across all
    FPGA vendors supported by Yosys. ],

    [ Tamara MAY make the voters themselves redundant ],
    [ Could be added for extra assurance, but not typically considered necessary in industry. ],

    [ Tamara SHOULD NOT be timing driven ],
    [ Timing is best left up to the P&R tool (Nextpnr). Although some EDA synthesis tools are timing driven,
    Yosys currently is not. ],

    [ Tamara SHOULD have a clean codebase through the use of tools like clang-tidy ],
    [ Easy to implement and highly desirable but not strictly necessary for correct functioning. ]
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

    [ Verification MAY involve a physical, real-life radiation test whereby an FPGA with a Tamara bitstream
    on it is exposed to radiation ],
    [ It's not known at the time of writing whether UQ has the facilities to perform this test, or whether
    the risks caused by radiation exposure are worth the investigation. ]
)

= Literature review

= Milestones

#bibliography("proposal.bib", title: "References", style: "institute-of-electrical-and-electronics-engineers")
