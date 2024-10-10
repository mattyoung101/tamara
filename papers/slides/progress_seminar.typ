#import "@preview/touying:0.4.2": *

#let s = themes.metropolis.register(aspect-ratio: "16-9")

#set text(
  font: "Inria Sans",
)

// Set the speaker notes configuration, you can show it by pympress
#let s = (s.methods.show-notes-on-second-screen)(self: s, right)

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
Application Specific Integrated Circuits (ASICs) and Field Programmable Gate Arrays (FPGAs) commonly deployed
in space (and on Earth)...

#grid(
    columns: (auto, auto),
    gutter: 8pt,
    [
        #align(center, [
            #image("diagrams/tinytapeout.jpg", width: 80%)

            #text(size: 11pt)[Source: https://zeptobars.com/en/read/tt04-tinytapeout-silicon-inside-gds-sky130]
        ])
    ],
    [
        #align(center, [
            #image("diagrams/ice40_fpga.png", width: 85%)

            #text(size: 11pt)[Source: Lattice iCE40 UltraPlus Family Data Sheet. #sym.copyright 2021 Lattice Semiconductor
            Corp.]
        ])
    ]
)

#speaker-note[
    - ASICs and FPGAs deployed in space/Earth for high reliability applications
]


== Single Event Upsets
#align(center)[
    #image("diagrams/see_mechan.gif", width: 70%)
    #text(size: 12pt)[
        Source: https://www.cogenda.com/article/SEE
    ]
]

#speaker-note[
    - Suffer from SEUs caused by ionising radiation striking transistors and causing bit flips
    - Particularly common for space-based applications
    - Must be mitigated to prevent catastrophic failures
    - Even terrestrial applications, where the Earth's magnetosphere protects chips from the majority of
        ionising radiation, mitigati0g SEUs still important for high reliability applications
]

== SEU protection
Protection from SEUs remains expensive!

RAD750 CPU @Berger2001 (James Webb Space Telescope, Curiosity rover, + many more) is commonly used, but costs
*>\$200,000 USD* @Hagedoorn2021!

#align(center, [
    #image("diagrams/jimbo_webb.png", width: 38%)

    #text(size: 10pt)[Source: https://commons.wikimedia.org/wiki/File:JWST_spacecraft_model_3.png]
])


== Triple Modular Redundancy
#align(center)[
    #image("diagrams/tmr_diagram.svg", width: 65%)
]

== Triple Modular Redundancy
TMR can be added manually...

but this is *time consuming* and *error prone*.

#[
#set text(size: 24pt)
*Can we automate it?*
]

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
#grid(
    columns: (14em, auto),
    gutter: 1pt,
    [
        TaMaRa is mainly netlist-driven. Voter insertion is inspired by Benites @Benites2018 "logic cones"
        concept, and parts of Johnson @Johnson2010.

        Also propagate a Verilog annotation to select TMR granularity (like
        Kulis @Kulis2017).

        Runs after techmapping (i.e. after `abc` in Yosys)
    ],
    [
        #align(center)[
            #image("diagrams/tamara_synthesis_flow.svg", width: 115%)
        ]
    ]
)

== TaMaRa algorithm: Logic cones
#align(center, [
    #text(size: 12pt)[Source: @Beltrame2015]
    #image("diagrams/logic_cone.png", width: 90%)
])

== TaMaRa algorithm: In depth
#align(center, [
    #image("diagrams/algorithm.svg", width: 75%)
])

#speaker-note[
#set text(size: 18pt)
- Construct TaMaRa logic graph and logic cones
    - Analyse Yosys RTLIL netlist
    - Perform backwards BFS from IOs to FFs (or other IOs) to collect combinatorial RTLIL primitives
    - Convert RTLIL primitives into TaMaRa primitives
    - Bundle into logic cone
- Replicate RTLIL primitives inside logic cones
- Insert voters into logic cones
- Wiring
    - Wire voter up to replicated primitives
    - Wire replicated primitive IOs to the rest of the circuit
    - Factor in feedback loop circuits
- Build successor logic cones
- Repeat until no more successors
]

== Verification
Comprehensive verification procedure using formal methods, simulation and fuzzing.

Driven by SymbiYosys tools _eqy_ and _mcy_
- In turn driven by Satisfiability Modulo Theorem (SMT) solvers (Yices @Dutertre2014, Boolector @Niemetz2014, etc)

#pause

Equivalence checking: Formally verify that the circuit is functionally equivalent before and after the TaMaRa
pass.
- Ensures TaMaRa does not change the underlying behaviour of the circuit.

#pause

Mutation: Formally verify that TaMaRa-processed circuits correct injected faults in a testbench
- Ensures TaMaRa does its job!

== Fuzzing
TaMaRa must work for _all_ input circuits, so we need to test at scale.

#pause

Idea:
1. Use Verismith @Herklotz2020 to generate random Verilog RTL.
2. Run TaMaRa synthesis end-to-end.
3. Use formal equivalence checking to verify the random circuits behave the same before/after TMR.

#pause

Problem: Mutation
- Need valid testbenches for these random circuits
- Requires automatic test pattern generation (ATPG), highly non-trivial
- Future topic of further research

== Simulation
I want to simulate an SEU environment.
- UQ doesn't have the capability to expose FPGAs to real radiation
- Physical verification is challenging (particularly measurement)

#pause

Use one of Verilator or Yosys' own cxxrtl to simulate a full design.
- Each simulator has different trade-offs
- Currently considering picorv32 RISC-V CPU as the Device Under Test (DUT)
- Simpler DUTs will be tested as well

#pause

Concept:
- Iterate over the netlist, randomly consider flipping a bit every cycle
    - May be non-trivial depending on simulator
- Self-checking testbench that ensures the DUT responds correctly (e.g. RISC-V CoreMark)

= Current status & future
== Current status
Algorithm design and planning essentially complete. Yosys internals (particularly RTLIL) understood to a
satisfactory level (still learning as I go).

#pause

C++ development well under way, approaching 1000 lines across 8 files. Using C++20.

#pause

Designed majority voters and other simple circuits in Logisim and translated to SystemVerilog HDL.

#pause

Started on formal equivalence checking for TaMaRa voters and simple manually-designed combinatorial circuits.

#pause

Programming hopefully finished _around_ February 2025, verification by April 2025.

// TODO make this based on not_tmr.ys instead (it's currently based on not_triplicate.ys)
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
After `tamara_debug replicateNot`:

#align(center, [
    #image("diagrams/triplicate_graph.svg", width: 60%)
])

== Progress: Equivalence checking
Voter circuit:

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
    #image("diagrams/logisim.png", width: 65%)
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

== Progress: Equivalence checking (Voter insertion)
Original, very simple circuit:

#align(center, [
    #image("diagrams/not_circuit.svg", width: 60%)
])

== Progress: Equivalence checking (Voter insertion)
After manual voter insertion (using SystemVerilog):

#align(center, [
    #image("diagrams/not_circuit_voter.svg", width: 105%)
])

== Progress: Equivalence checking (Voter insertion)
Are they equivalent? Yes! (Thankfully)

#align(center, [
    #image("diagrams/not_voter_eqy.png", width: 75%)
])

#pause

*Caveat:* Still need to verify circuits with more complex logic (i.e. DFFs).

== Current problem: Duplicate DFFs
#place(
    bottom + right,
    dy: -4.5em,
    dx: -0em,
    rect(
        stroke: 2pt + red,
        width: 60%
    )
)

#grid(
    columns: (16em, auto),
    gutter: 0pt,
    [
        #image("diagrams/duplicate_dffs.svg")
    ],
    [
        #set text(size: 14pt)
        ```
        7.2. Computing logic graph
        Module has 1 output ports, 2 selected cells

        Searching from output port o
        Starting search for cone 0
            ... [snip] ...
        Search complete for cone 0, have 3 items

        Replicating 3 collected items for logic cone 0
            Replicating ElementCellNode $logic_not$../tests/verilog/not_triplicate.sv:16$2
            Replicating ElementWireNode ff
            Replicating FFNode $procdff$3
        Checking terminals
        Input node $procdff$3 is not IONode, replicating it
            Replicating FFNode $procdff$3
        Warning: When replicating FFNode $procdff$3 in cone 0: Already replicated in logic cone 0
        Input node o is IONode, it will NOT be replicated

        Inserting voter into logic cone 0

        ... [snip] ...
        ```
    ]
)
== The future
Tasks that remain (more or less):

- Fixing duplicate logic elements when replicating RTLIL primitives
- Wiring voter to logic elements, and wiring replicated logic elements to the rest of the circuit
- Considering wiring for feedback circuits _(expected to be complex/massive time sink!)_
- Global routing of error signal to a net
- Processing complex circuits like picorv32
- Writing a cycle-accurate fault-injection simulator, and associated testbenches
- Formal equivalence checking for complex circuits
- Formal mutation coverage
- Fuzzing _(if time permits)_

== The future
I'm aiming to produce at least one academic publication from this thesis.
- If TaMaRa works, its hybrid algorithm addresses a number of limitations in previous literature
- May be useful for research labs (CubeSats) and industry

#pause

TaMaRa plugin code and tests will be released open-source under the MPL 2.0 (used by Firefox, Eigen, etc).
Papers will hopefully be available under CC-BY.

TaMaRa will be freely available for anyone to use and build on. Combination of academic publication + open
source for widest possible reach.

#pause

I have also spoken with the team at YosysHQ GmbH and Sandia National Laboratories, who are very interested in
the results of this project and its applications.

= Conclusion
== Summary
- TaMaRa: Automated triple modular redundancy EDA flow for Yosys
- Fully integrated into Yosys suite
- Takes any circuit, helps to prevent it from experiencing SEUs by adding TMR
- Synthesises netlist-driven approaches @Beltrame2015 @Johnson2010 with design-level approaches @Kulis2017
- *Key goal:* "Click a button" and have any circuit run in space/in high reliability environments!

_I'd like to extend my gratitude to N. Engelhardt of YosysHQ, the team at Sandia National Laboratories, and my
supervisor Assoc. Prof. John Williams for their support and interest during this thesis so far._

== References
#slide[
#set text(size: 10pt)
#bibliography("slides.bib", style: "institute-of-electrical-and-electronics-engineers", title: none)
]

#focus-slide[Thank you! Any questions?]
