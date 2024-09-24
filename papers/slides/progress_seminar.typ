#import "@preview/touying:0.4.2": *

#let s = themes.metropolis.register(aspect-ratio: "16-9")

#set text(
  font: "Inria Sans",
)

// Global information configuration
#let s = (s.methods.info)(
  self: s,
  title: [*Progress Seminar* \ An automated triple modular redundancy EDA flow for Yosys],
  author: [Matt Young],
  date: datetime.today().display("[day] [month repr:long] [year]"),
  institution: [University of Queensland \ School of Electrical Engineering and Computer Science \ Supervisor:
    Assoc. Prof. John Williams],
)

#set list(indent: 12pt)
#set enum(indent: 12pt)
// Colour links blue like LaTeX
#show cite: set text(fill: blue)
#show link: set text(fill: blue)
#show ref: set text(fill: blue)
#show footnote: set text(fill: blue)

// Extract methods
#(s.enable-styled-warning = false)
#let (init, slides, touying-outline, alert, speaker-note) = utils.methods(s)
#show: init

// Extract slide functions
#let (slide, empty-slide, focus-slide) = utils.slides(s)
#show: slides

= Background
== Motivation
Fault tolerant computing is important for safety critical sectors (aerospace, defence, medicine, etc.)

#pause
For space-based applications, Single Event Upsets (SEUs) are very common
- Must be mitigated to prevent catastrophic failure
- Caused by ionising radiation //striking transistors on a digital circuit

Even in terrestrial applications, SEUs can still occur
- Must be mitigated for high reliability applications

#pause
Application Specific Integrated Circuits (ASICs) and Field Programmable Gate Arrays (FPGAs) commonly deployed
in space (and on Earth)...
#pause
but protection from SEUs remains expensive!

RAD750 CPU @Berger2001 (James Webb Space Telescope, Curiosity rover, + many more) is commonly used, but costs
*>\$200,000 USD* @Hagedoorn2021!

== Triple Modular Redundancy
#align(center)[
    #image("diagrams/tmr_diagram.svg", width: 65%)
]

== Triple Modular Redundancy
TMR can be added manually...

but this is *time consuming* and *error prone*.

Can we automate it?

= TaMaRa
== Concept
Implement TMR as a pass in an EDA synthesis tool.
- Integrated with the rest of the flow
- Easy to use
- Fully automated

#pause

*Goal*: Pick any design, of any complexity, "press a button" and have it be rad-hardened.

#pause

Yosys @Wolf2013 is the best (and the only) open-source, research grade EDA synthesis tool.
#pause
- Proprietary vendor tools (Synopsys, Cadence, Xilinx, etc) immediately discarded
- Can't be extended to add custom passes

== Existing works
Two main paradigms:

- *Design-level approaches* ("thinking in terms of HDL")
    - Kulis @Kulis2017, Lee @Lee2017
- *Netlist-level approaches* ("thinking in terms of circuits")
    - Johnson @Johnson2010, Benites @Benites2018, Skouson @Skouson2020

== The TaMaRa algorithm

TaMaRa is mainly netlist-driven. Voter insertion is inspired by Benites @Benites2018 "logic cones"
concept, and parts of Johnson @Johnson2010.

Also aim to propagate a `(* triplicate *)` HDL annotation to select TMR granularity (similar to Kulis
@Kulis2017).

Runs after techmapping (i.e. after `abc` in Yosys)

#align(center)[
    #image("diagrams/tamara_synthesis_flow.svg", width: 55%)
]

== The TaMaRa algorithm

Why netlist driven with the `(* triplicate *)` annotation?

#pause

- Removes the possibility of Yosys optimisation eliminating redundant TMR logic
- Removes the necessity of complex blackboxing logic and trickery to bypass the normal design flow
- Cell type shouldn't matter, TaMaRa targets FPGAs and ASICs
- Still allows selecting TMR granularity - *best of both worlds*

== Verification
Comprehensive verification procedure using formal methods, simulation and fuzzing.

Driven by SymbiYosys tools _eqy_ and _mcy_
- In turn driven by Satisfiability Modulo Theorem (SMT) solvers (Yices @Dutertre2014, Boolector @Niemetz2014, etc)

== Formal verification
Equivalence checking: Formally verify that the circuit is functionally equivalent before and after the TaMaRa
pass.
#pause
- Ensures TaMaRa does not change the underlying behaviour of the circuit.

#pause

Mutation: Formally verify that TaMaRa-processed circuits correct SEUs (single bit only)
#pause
- Ensures TaMaRa does its job!

#pause

Also considering Beltrame's verification tool @Beltrame2015, and other literature on TMR formal
verification.

== Fuzzing
TaMaRa must work for _all_ input circuits, so we need to test at scale.

#pause

Idea:

1. Use Verismith @Herklotz2020 to generate random Verilog RTL.
2. Run TaMaRa synthesis end-to-end.
3. Use formal equivalence checking to verify the random circuits behave the same before/after TMR.

#pause

Problem: Mutation

#pause

- We need valid testbenches for these random circuits, how would we generate that?
- Under active research in academia (may not be possible at the moment)

== Simulation
We want to simulate an SEU environment.
- UQ doesn't have the capability to expose FPGAs to real radiation
- Physical verification is challenging (how do you measure it?)

#pause

Use one of Verilator or Yosys' own cxxrtl to simulate a full design.
- Each simulator has different trade-offs
- Currently considering picorv32 or Hazard3 RISC-V CPUs as the Device Under Test (DUT)

#pause

Concept:
- Iterate over the netlist, randomly consider flipping a bit every cycle
- Write a self-checking testbench and ensure that the DUT responds correctly (e.g. RISC-V CoreMark)

== Technical implementation
Implemented in C++20, using CMake.

Load into Yosys: `plugin -i libtamara.so`

TMR is implemented as two separate commands: `tamara_propagate` and `tamara_tmr`

#pause

Run `tamara_propagate` after `read_verilog` to propagate the `(* tamara_triplicate *)` annotations.

#pause

Run `tamara_tmr` after techmapping to perform triplication and voter insertion (add TMR).

= Current status & future
== Current status
Algorithm design and planning essentially complete. Yosys internals (particularly RTLIL) understood to a
satisfactory level (still learning as I go).

#pause

C++ development well under way, have 700 lines and growing. Using modern C++20 features like `shared_ptr` and
`std::variant` meta-programming.

#pause

Designed majority voters and other simple circuits in Logisim and translated to SystemVerilog HDL.

#pause

Started on formal equivalence checking. Proved that TaMaRa generated voter is equivalent to manual SV design,
and that a simple circuit is identical after manual voter insertion.

#pause

Programming hopefully finished _around_ February 2025, verification by April 2025.

== Progress: Automatically triplicating a NOT gate and inserting a voter
Original circuit:

#align(center, [
])

#grid(
    columns: (auto, auto),
    gutter: 8pt,
    [
        #image("diagrams/triplicate_before_graph.svg")
    ],
    [
        #set text(size: 16pt)
        ```systemverilog
        (* tamara_triplicate *)
        module not_triplicate(
            input logic a,
            input logic clk,
            output logic o
        );

        logic ff;

        always_ff @(posedge clk) begin
            ff <= a;
        end

        assign o = !ff;

        endmodule
        ```
    ]
)

== Progress: Automatically triplicating a NOT gate and inserting a voter
After `tamara_debug notTriplicate`:

#align(center, [
    #image("diagrams/triplicate_graph.svg", width: 60%)
])

== Progress: Automatically triplicating a NOT gate and inserting a voter
Results:
- NOT circuit identified in `tamara::LogicGraph`
- RTLIL primitives replicated correctly
- Voter inserted using `tamara::VoterBuilder`
- Voter _not_ yet wired up to main design
- Replicated components _not_ yet re-wired

== Progress: Equivalence checking
#grid(
    columns: (auto, auto),
    gutter: 24pt,
    [
        #table(
            columns: (auto, auto, auto, auto, auto),
            inset: 10pt,
            align: horizon,
            table.header(
                [*a*], [*b*], [*c*], [*out*], [*err*]
            ),
            [0], [0], [0], /* */ [0], [0], // 0
            [0], [0], [1], /* */ [0], [1], // 1
            [0], [1], [0], /* */ [0], [1], // 2
            [0], [1], [1], /* */ [1], [1], // 3
            [1], [0], [0], /* */ [0], [1], // 4
            [1], [0], [1], /* */ [1], [1], // 5
            [1], [1], [0], /* */ [1], [1], // 6
            [1], [1], [1], /* */ [1], [0], // 7
        )
    ],
    [
        ```systemverilog
        module voter(
            input logic a,
            input logic b,
            input logic c,
            output logic out,
            output logic err
        );
            assign out = (a && b) || (b && c) || (a && c);
            assign err = (!a && c) || (a && !b) || (b && !c);
        endmodule
        ```
    ]
)

== Progress: Equivalence checking
Manual design in Logisim:

#align(center, [
    #image("diagrams/logisim.png", width: 80%)
])

== Progress: Equivalence checking
#grid(
    columns: (14em, auto),
    gutter: 8pt,
    [
    #set text(size: 14pt)
        ```cpp
            Voter tamara::VoterBuilder::build(RTLIL::Module *module) {
                // NOT
                // a -> not0 -> and2
                WIRE(not0, and2);
                NOT(0, a, not0_and2_wire);
                ...

                // AND
                // b, c -> and0 -> or0
                WIRE(and0, or0);
                AND(0, b, c, and0_or0_wire);
                ...

                // OR
                // and0, and1 -> or0 -> or2
                WIRE(or0, or2);
                OR(0, and0_or0_wire, and1_or0_wire, or0_or2_wire);
                ...

                return ...;
            }
        ```
    ],
    [
        #image("diagrams/voter.svg", width: 100%)
    ]
)

== Progress: Equivalence checking
Marked equivalent by eqy in conjunction with Yices!

#align(center, [
    #image("diagrams/eqy_voter.png", width: 75%)
])

== The future
I'm aiming to produce at least one academic publication from TaMaRa research.

#pause

TaMaRa plugin code and tests will be released open-source under the Mozilla Public Licence 2.0 (used by
Firefox, Eigen, etc).

Papers, including thesis and hopefully any future academic publications, will be available under CC-BY.

In short, TaMaRa will be freely available for anyone to use and build on.

#pause

I have also spoken with the team at YosysHQ GmbH and Sandia National Laboratories, who are very interested in
the results of this project and its applications.

// TODO what remains to be done

= Conclusion
== Summary
- TaMaRa: Automated triple modular redundancy EDA flow for Yosys
- Fully integrated into Yosys suite
- Takes any circuit, helps to prevent it from experiencing SEUs by adding TMR
- Netlist-driven algorithm based on Johnson's work @Johnson2010 (TODO NOT TRUE)
- *Key goal:* "Click a button" and have any circuit run in space/in high reliability environments!

_I'd like to extend my gratitude to N. Engelhardt of YosysHQ, the team at Sandia National Laboratories, and my
supervisor Assoc. Prof. John Williams for their support and interest during this thesis so far._

== References
#slide[
#set text(size: 10pt)
#bibliography("slides.bib", style: "institute-of-electrical-and-electronics-engineers", title: none)
]

// == Thank you!
// *Any questions?*

#focus-slide[Thank you! Any questions?]
