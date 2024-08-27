#import "@preview/touying:0.4.2": *

#let s = themes.metropolis.register(aspect-ratio: "16-9")

#set text(
  font: "Inria Sans",
)

// Global information configuration
#let s = (s.methods.info)(
  self: s,
  title: [*TaMaRa: \ An automated triple modular redundancy EDA flow for Yosys*],
  author: [Matt Young],
  date: datetime.today().display("[day] [month repr:long] [year]"),
  institution: [University of Queensland \ Prepared for YosysHQ and Sandia National Laboratories],
)

#set list(indent: 12pt)
#set enum(indent: 12pt)
// Colour links blue like LaTeX
#show cite: set text(fill: blue)
#show link: set text(fill: blue)
#show ref: set text(fill: blue)
#show footnote: set text(fill: blue)

// Extract methods
#let (init, slides, touying-outline, alert, speaker-note) = utils.methods(s)
#show: init

// Extract slide functions
#let (slide, empty-slide, focus-slide) = utils.slides(s)
#show: slides

= Background
== About me
#grid(columns: (10em, auto), gutter: 15pt,
[
    #image("grad_portrait.jpg", width: 100%)
],
[
Hi! I'm Matt Young, 21 years old from Brisbane, Australia.

Graduated Bachelor of Computer Science earlier in 2024 from the University of Queensland.

Currently studying Bachelor of Computer Science (Honours) at UQ, involves one year research thesis.

Despite the email, thesis is is *not* associated with my employer (Emesent).

// Passionate about digital hardware design, embedded systems, high performance/low-level software/hardware.
// Might take up a PhD in future :)
// Looking to in future take up a PhD, and eventually research/work in the area of CPU/GPU/ASIC design, or FPGAs,
// or similar.
]

)

== Motivation
Fault tolerant computing is important for safety critical sectors (aerospace, defence, medicine, etc.)

#pause
For space-based applications, Single Event Upsets (SEUs) are very common
- Must be mitigated to prevent catastrophic failure
- Caused by ionising radiation //striking transistors on a digital circuit

Even in terrestrial applications, SEUs can still occur
- Must be mitigated for high reliability applications

#pause
ASICs and FPGAs commonly deployed in space (and on Earth)...
#pause
but protection from SEUs remains expensive!

RAD750 CPU @Berger2001 is commonly used, but costs >\$200,000 USD @Hagedoorn2021!

// == Motivation
// RAD750 IMAGE
//
// RAD750 (PowerPC, ~200 MHz, 150 nm)
//
// #pause
//
// Deployed on:
//
// - James Webb Space Telescope
// - Kepler telescope
// - Curiosity rover
// - ...many more
//
// #pause
//
// Unit cost: \$338,797 USD (!)
//
// #pause
//
// Can we do better?

== Triple Modular Redundancy
#align(center)[
    #image("tmr_diagram.svg", width: 65%)
]

== Triple Modular Redundancy
TMR can be added manually...

but this is *time consuming* and *error prone*.
//another time consuming and error prone step in the _already_ complex design process.

Can we automate it?

= TaMaRa methodology
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
//ignored as they can't be extended

== Existing works
//Very important prior work done by #cite(<Johnson2010>, form: "prose") at BYU.
Two main paradigms:

- *Design-level approaches* ("thinking in terms of HDL")
    - Kulis @Kulis2017, Lee @Lee2017
- *Netlist-level approaches* ("thinking in terms of circuits")
    - Johnson @Johnson2010, Benites @Benites2018, Skouson @Skouson2020

== The TaMaRa algorithm

TaMaRa will mainly be netlist-driven, using Johnson's @Johnson2010 voter insertion algorithm.

Also aim to propagate a `(* triplicate *)` HDL annotation to select TMR granularity (similar to Kulis
@Kulis2017).

Runs after techmapping (i.e. after `abc` in Yosys)

#align(center)[
    #image("tamara_synthesis_flow.svg", width: 55%)
]

== The TaMaRa algorithm

Why netlist driven with the `(* triplicate *)` annotation?

#pause

- Removes the possibility of Yosys optimisation eliminating redundant TMR logic
- Removes the necessity of complex blackboxing logic and trickery to bypass the normal design flow
- Cell type shouldn't matter, TaMaRa targets FPGAs and ASICs
- Still allows selecting TMR granularity - *best of both worlds*

== Verification
// Designing an EDA pass means verification needs to be taken very seriously.
//
// #pause

//I plan to have a

Comprehensive verification procedure using formal methods, simulation and fuzzing.

Driven by SymbiYosys tools _eqy_ and _mcy_
- In turn driven by theorem provers/SAT solvers

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

Use one of Verilator, Icarus Verilog or Yosys' own cxxrtl to simulate a full design.
- Each simulator has different trade-offs
- Currently considering picorv32 or Hazard3 as the DUT
- Most likely will use Verilator or cxxrtl

#pause

Concept:
- Iterate over the netlist, randomly consider flipping a bit every cycle
- Write a self-checking testbench and ensure that the DUT responds correctly

== Technical implementation
Implemented in C++20, using CMake.

Load into Yosys: `plugin -i libtamara.so`

TMR is implemented as two separate commands: `tamara_propagate` and `tamara_tmr`

#pause

Run `tamara_propagate` after `read_verilog` to propagate the `(* triplicate *)` annotations.

#pause

Run `tamara_tmr` after techmapping to perform triplication and voter insertion (add TMR).

= Current status & future
== Current status
Mostly initial academic work: literature reviews, project proposals, etc.

`tamara_propagate` pass already basically complete (just under 100 lines of C++).

Work for the next \~6 months will focus on understanding, implementing and verifying Johnson's @Johnson2010
algorithm in Yosys, and exploring Beltrame's @Beltrame2015 verification.

== The future
#image("gantt_mermaid.svg", width: 100%)

== The future
This will be implemented for my Honours thesis over the next 1 year.
- Honours is kind of of like mini masters, it's an Australia-specific thing
- Supervised by Assoc. Prof. John Williams (former PetaLogix, Xilinx)
- Ideally would like to publish if all goes well

#pause

Programming hopefully finished _around_ February 2025, verification by April 2025.

#pause

Ideally, TaMaRa will be released open-source under MPL 2.0.
- Pending university IP shenanigans...

= Conclusion
== Summary
- TaMaRa: Automated triple modular redundancy EDA flow for Yosys
- Fully integrated into Yosys suite
- Takes any circuit, helps to prevent it from experiencing SEUs by adding TMR
- Netlist-driven algorithm based on Johnson's work @Johnson2010
- *Key goal:* "Click a button" and have any circuit run in space/in high reliability environments!

== References
#slide[
#set text(size: 10pt)
#bibliography("slides.bib", style: "institute-of-electrical-and-electronics-engineers", title: none)
]

// == Thank you!
// *Any questions?*

#focus-slide[Thank you! Any questions?]
