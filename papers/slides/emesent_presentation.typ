#import "@preview/touying:0.4.2": *

#let s = themes.metropolis.register(aspect-ratio: "16-9")

#set text(
  font: "Inria Sans",
)

// Global information configuration
#let s = (s.methods.info)(
  self: s,
  title: [*TaMaRa:* An automated triple modular redundancy EDA flow for Yosys \ _With an (attempt at an) introduction to
    computer engineering_],
  author: [Matt Young],
  date: datetime.today().display("[day] [month repr:long] [year]"),
  institution: [University of Queensland \ School of Electrical Engineering and Computer Science \ Supervisor:
    Assoc. Prof. John Williams \ *Prepared for Emesent*],
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

= Prerequisite knowledge
// == Context: How did I get here?
// Worth explaining how I ended up doing a semiconductors thesis when I work at a robotics company! My journey
// goes a bit like this:
//
// - \~2013-2015: Webdev, PHP (sorry)
// - \~2016-2018: Java gamedev, C++ is scary
// - \~2018-2020: Embedded C (ESP32) and C++ (OpenCV) for RoboCup Jr school robotics
// - \~2021-2022: HPC C++! Start to become interested in CPU design after taking CSSE2010
// - \~2022-2023: Learn and practice SystemVerilog, reading up on semiconductors
// - \~2024-2025: We are here! Working on Honours full time, planning PhD :)
// - \~2025-2XXX: PhD probably, ideally involving designing a novel RISC-V CPU

== Terminology
For this entire presentation, assume silicon IC == _digital_ silicon IC == ASIC
- Analogue ICs are very common, but are significantly different - not much here applies
- Caveat: Most designs are _mixed-signal_ (analogue & digital), we consider only the digital part

ASIC = Application Specific Integrated Circuit
- Some examples: NPUs, GPUs, ISPs, display controllers, SuperIO controllers, disk controllers, audio codecs, video
    encoders, .....

If you can see this presentation, you are using many of the above!

== Digital logic
Recall digital logic: fundamentally binary (1/0), using combinatorial logic gates (AND, OR, etc) and
sequential gates (D-flip-flops).

Every ASIC is at its core just these fundamental gates.

#text(size: 12pt)[_(Terms and conditions apply, see:
    mixed signal designs, custom standard cells, optical/MEMS designs, etc.)_]

== Digital logic
Purely combinatorial example: 1-bit full adder

#align(center, [
    #image("diagrams/full_adder.png", width: 70%)

    #text(size: 8pt)[
        Source: https://www.researchgate.net/figure/Full-adder-circuit-diagram-and-truth-table-where-A-B-and-C-in-are-binary-inputs_fig2_349727409
    ]
])

== Digital logic
Sequential example: 4-bit serial in, parallel out (SIPO) shift register

#align(center, [
    #image("diagrams/sipo_shiftreg.svg", width: 80%)

    #text(size: 8pt)[
        Source: https://commons.wikimedia.org/wiki/File:4-Bit_SIPO_Shift_Register.svg
    ]
])


== What even is an integrated circuit???
Digital ICs consist of millions/billions of transistors, etched onto a silicon wafer using _photolithography_.

The photolithography setup forms the _process node_, which in turn forms the transistor size (_gate pitch_).

#pause

This is what people talk about with "4 nm" etc - but this is an *advertising term*!
- *Zero* correlation to physical gate size!

#pause

Photolithography techniques include _deep ultraviolet lithography_ (DUV) ($>=$ 14 nm) and _extreme ultraviolet
lithography_ (EUV) ($<=$ 7 nm and beyond)

#pause

ASML EUV machines cost *$>=$ \$100 million USD* and are considered possibly the most complex machines on
Earth.

== What even is an integrated circuit???
#align(center, [
    #text(size: 10pt)[
    Source: https://electronics.stackexchange.com/questions/518573/can-somebody-identify-this-12-silicon-wafer
    ]

    #image("diagrams/wafer.jpg", width: 65%)
])

== What even is an integrated circuit???
#grid(
    columns: (20em, auto),
    gutter: 1em,
    [
        Modern ICs are built using complementary metal oxide semiconductor (CMOS) transistors.

        Combination of NMOS and PMOS transistors.

        Significantly better static power (leakage current) NMOS/PMOS, and faster switching times, at the cost
        of higher area.
    ],
    [
        #align(right)[
            #image("diagrams/CMOS_NAND.svg", height: 90%)
            #text(size: 10pt)[
                Source: https://en.wikipedia.org/wiki/File:CMOS_NAND.svg
            ]
        ]
    ]
)

// == Die shot break time!
// Too much info... die shot break time!
//
// A _die_ is a production-ready block of a silicon wafer ready to packaged into a chip.
//
// You can't see them with the naked eye (too small, need a good microscope/electron microscope)
//
// I love die shots. Most of these come from the amazing: https://zeptobars.com/en
//
// == Die shot break time!
// #align(center, [
//     #image("diagrams/Ti-CD4011BE-HD.jpg", width: 60%)
//
//     #text(size: 11pt)[
//         TI TTL logic chip: 4x 2-input NAND gates. Simple as it gets.
//
//         Source: https://zeptobars.com/en/read/Ti-CD4011BE-quad-2-NAND-gate-CMOS
//     ]
// ])

== What even is an FPGA???
Manufacturing silicon ICs is _extraordinarily_ expensive, and totally uneconomic for low-volume runs.

But people still need digital circuits in many low-volume industries!

Field Programmable Gate Arrays (FPGAs) allow for many of the benefits of silicon ICs at a fraction of the
cost.

#pause

But to understand what an FPGA is, we first need to talk about PALs...

== PALs
#grid(
    columns: (15em, auto),
    gutter: 1em,
    [
        Programmable Array Logic: The precursor to FPGAs (c. 1978).

        Designer implements Boolean logic manually using sum of products on a programmable AND/OR plane.

        Recall _sum of products_: canonical representation of Boolean truth table (e.g. $A.B + overline(B) . C
    + ...$)
    ],
    [
        #align(center)[
            #image("diagrams/pal.svg", height: 90%)
            #text(size: 10pt)[
                Source: https://commons.wikimedia.org/wiki/File:Programmable_Logic_Device.svg
            ]
        ]
    ]
)

== FPGAs
Eventually PALs turned into CPLDs, and finally CPLDs turned into... FPGAs!

Now we have 100,000+ _logic cells_ (terminology depends on vendor), that can be chained together to implement
any digital logic. Super flexible!

#pause

Configuration (_bitstream_) is written to FPGA SRAM on boot, so cheap & easy to flash.

#pause

Hardened functional blocks for better performance/power (typically multipliers, RAM, IO, etc, nowadays even
CPUs, NPUs).

Tricky mixed signal components also hardened (PLLs, SERDES, etc).

#pause

Still: Worse power, performance and area (PPA) than an actual silicon ASIC (hence why ASICs are still designed!)

== FPGAs
#text(size: 12pt)[Source: Lattice iCE40 UltraPlus Family Data Sheet. #sym.copyright 2021 Lattice Semiconductor
Corp.]

#align(center, [
    #image("diagrams/ice40_fpga.png", width: 65%)
])

== FPGAs
#text(size: 12pt)[Source: Lattice iCE40 UltraPlus Family Data Sheet. #sym.copyright 2021 Lattice Semiconductor
Corp.]

#align(center, [
    #image("diagrams/ice40_cell.png", width: 60%)
])

== FPGA use cases
FPGAs are used in everything, everywhere. Anywhere you need fast, low-power, application specific processing.

Big sectors include aerospace/space, defence, science, high frequency trading, DSP, RF, machine learning, video
processing.

*LiDARS!* Every LiDAR Emesent uses has _at least_ one FPGA.
- "Vendor A": 1x Altera Cyclone V (ancient).
- "Vendor B": 2x Xilinx Artix-7
- "Vendor C": They actually use a custom ASIC (!), but also likely $>=$ 1 FPGA.

Rule of thumb: You'll be surprised how often an FPGA shows up when you pull apart something.

== Case study: Saleae Logic 8 logic analyser
#align(center, [
    #text(size: 12pt)[Source: https://twitter.com/timonsku/status/1497725434888437762]

    #image("diagrams/saleae.jpg", width: 52%)
])

== Electronic Design Automation (EDA)
In ye olden days, circuits were _manually_ designed using pencil and paper (including first Intel CPUs!)

Lithography masks were manually drawn by hand, hence the term "tape out".

Nowadays, ICs consist of billions of transistors. Manual design has not been an option since the late 80s.

Instead, Electronic Design Automation (EDA) tools are used.

== Electronic Design Automation (EDA)
Verilog/SystemVerilog/VHDL: Hardware description languages (HDLs), the "source code" of FPGAs and ICs.

In the semiconductor industry, we call this code Register Transfer Language (RTL).

#pause

Used for both synthesis (what is on the actual chip) and simulation. _(Which is totally not confusing and has
never caused any bugs ever...)_

#pause

Describe circuits and simulation testbenches using "simple" text-based constructs.

Similar to software code... _but be careful_! Hardware and software are _very_ different. HDLs are _not_ the
same as code!

== Electronic Design Automation (EDA)
EDA tools: the "compilers" of the semiconductor industry.

Take HDL code and produce a bitstream (for FPGAs), or a photolithography mask (for ASICs).

#pause

A bitstream/photolith mask is a bit like machine code/object files in the software world.

Again, be warned: These are similar in principle, but _very very_ different from compilers.

Yes, they have a frontend that lexes/parses Verilog, but the backend consists of _multiple_ NP-complete
placing/routing problems. Large ASICs can take weeks to "compile".

== SystemVerilog HDL example
(Yoinked from thesis, you'll see this slide again later)

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

== EDA pipeline
#align(center, [
    #image("diagrams/synthesis_flow.svg", width: 100%)
])

== Yosys
If EDA tools are the "compilers" of the semiconductor industry, then *Yosys* @Wolf2013 is GCC/Clang.

#pause

Context: Semiconductor industry is very privatised and _very_ expensive. Until last decade, open-source did
not exist. Everything is IP'd/patented to hell and back. FPGA vendors very hostile to open-source.

So not only are ASICs expensive to manufacture, but just the tools to design them can set you back $>=$ *\$1
million*.

This sucks unless you're Intel/AMD/whoever. Good luck if you're a researcher/startup.

== Yosys+nextpnr
*Yosys* is a free, open-source EDA synthesis tool, with an accompanying PnR tool nextpnr @Shah2019 that is
high quality, research grade and production ready. Managed by YosysHQ GmbH.

Yosys+nextpnr support various FPGAs: Lattice iCE40/ECP5, Gowin, and a few others. Built using very complex
bitstream reverse engineering.

#pause

Also supports interesting _formal verification_ flows like equivalence checking and mutation coverage.

#pause

The holy grail of open-source EDA. (Wouldn't be possible without Berkeley's abc @Brayton2010 tool!)

#pause

State of the art: We can actually design 130 nm ASICs end-to-end (Verilog to GDSII mask) using fully open-source
tools, thanks to the efforts of OpenLane @Shalan2020, OpenSTA, Skywater Technologies @skywater, Google and
Yosys. _Wow!_

== Further reading
*S. Harris, D. Harris, _Digital Design and Computer Architecture, RISC-V Edition._ Morgan Kaufmann, 2021.*

Probably the only textbook in the world actually worth buying :)

A large majority of this info I learned from this book.

= Thesis background
== Single Event Upsets
#grid(
    columns: (17em, auto),
    gutter: 1pt,
    [
        Fault tolerant computing is important for safety critical sectors (aerospace, defence, medicine, etc.)

        For space-based applications, Single Event Upsets (SEUs) are very common
        - Bit flips caused by ionising radiation
        - Must be mitigated to prevent catastrophic failures

        Even in terrestrial applications, SEUs can still occur
        - Must be mitigated for high reliability applications
    ],
    [
        #align(center)[
            #image("diagrams/see_mechan.gif")
            #text(size: 12pt)[
                Source: https://www.cogenda.com/article/SEE
            ]
        ]
    ]
)

== Motivation
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

// TODO describe the algorithm in more details (replace usage overview with this description)

// == The TaMaRa algorithm
//
// Why netlist driven with the `(* triplicate *)` annotation?
//
// #pause
//
// - Removes the possibility of Yosys optimisation eliminating redundant TMR logic
// - Removes the necessity of complex blackboxing logic and trickery to bypass the normal design flow
// - Cell type shouldn't matter, TaMaRa targets FPGAs and ASICs
// - Still allows selecting TMR granularity - *best of both worlds*

== Verification
Comprehensive verification procedure using formal methods, simulation and fuzzing.

Driven by SymbiYosys tools _eqy_ and _mcy_
- In turn driven by Satisfiability Modulo Theorem (SMT) solvers (Yices @Dutertre2014, Boolector @Niemetz2014, etc)

== Formal verification
Equivalence checking: Formally verify that the circuit is functionally equivalent before and after the TaMaRa
pass.
- Ensures TaMaRa does not change the underlying behaviour of the circuit.

#pause

Mutation: Formally verify that TaMaRa-processed circuits correct SEUs (single bit only)
- Ensures TaMaRa does its job!

#pause

Beltrame's verification tool @Beltrame2015 was considered, but is not complete and does not compile under
modern Clang/GCC.

== Fuzzing
TaMaRa must work for _all_ input circuits, so we need to test at scale.

#pause

Idea:
1. Use Verismith @Herklotz2020 to generate random Verilog RTL.
2. Run TaMaRa synthesis end-to-end.
3. Use formal equivalence checking to verify the random circuits behave the same before/after TMR.

#pause

Problem: Mutation
- We need valid testbenches for these random circuits
- Requires automatic test pattern generation (ATPG), highly non-trivial
- Future topic of further research

== Simulation
We want to simulate an SEU environment.
- UQ doesn't have the capability to expose FPGAs to real radiation
- Physical verification is challenging (particularly measurement)

#pause

Use one of Verilator or Yosys' own cxxrtl to simulate a full design.
- Each simulator has different trade-offs
- Currently considering picorv32 or Hazard3 RISC-V CPUs as the Device Under Test (DUT)

#pause

Concept:
- Iterate over the netlist, randomly consider flipping a bit every cycle
    - May be non-trivial depending on simulator
- Write a self-checking testbench and ensure that the DUT responds correctly (e.g. RISC-V CoreMark)

= Current status & future
// == Usage overview
// Implemented as a C++20 Yosys plugin, using CMake.
//
// Load TaMaRa plugin into Yosys: `plugin -i libtamara.so`
//
// TMR is implemented as two separate commands: `tamara_propagate` and `tamara_tmr`
//
// #pause
//
// Run `tamara_propagate` after `read_verilog` to propagate the `(* tamara_triplicate *)` annotations.
//
// #pause
//
// Run `tamara_tmr` after techmapping to perform triplication and voter insertion (add TMR).

== Current status
Algorithm design and planning essentially complete. Yosys internals (particularly RTLIL) understood to a
satisfactory level (still learning as I go).

#pause

C++ development well under way, approaching 1000 lines across 8 files. Using modern C++20 features like
`shared_ptr` and `std::variant` meta-programming.

#pause

Designed majority voters and other simple circuits in Logisim and translated to SystemVerilog HDL.

#pause

Started on formal equivalence checking for TaMaRa voters and simple manually-designed combinatorial circuits.

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
After `tamara_debug replicateNot`:

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

== Progress: Equivalence checking (Voter insertion)
Original, very simple circuit:

#align(center, [
    #image("diagrams/not_circuit.svg", width: 60%)
])

== Progress: Equivalence checking (Voter insertion)
After manual voter insertion (using SystemVerilog):

#align(center, [
    #image("diagrams/not_circuit_voter.svg", width: 100%)
])

== Progress: Equivalence checking (Voter insertion)
Are they equivalent? Yes! (Thankfully)

#align(center, [
    #image("diagrams/not_voter_eqy.png", width: 75%)
])

#pause

*Caveat:* Still need to verify circuits with more complex logic (i.e. DFFs).

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
I'm aiming to produce at least one proper academic publication from this thesis, about TaMaRa.

#pause

TaMaRa plugin code and tests will be released open-source under the Mozilla Public Licence 2.0 (used by
Firefox, Eigen, etc).

Papers, including thesis and hopefully any future academic publications, will be available under CC-BY.

In short, TaMaRa will be freely available for anyone to use and build on.

#pause

I have also spoken with the team at YosysHQ GmbH and Sandia National Laboratories, who are very interested in
the results of this project and its applications.

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
