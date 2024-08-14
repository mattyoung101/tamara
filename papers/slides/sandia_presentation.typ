#import "@preview/touying:0.4.2": *

#let s = themes.metropolis.register(aspect-ratio: "16-9")

// Set the numbering of section and subsection
//#let s = (s.methods.numbering)(self: s, section: "1.", "1.1")

// Set the speaker notes configuration
// #let s = (s.methods.show-notes-on-second-screen)(self: s, right)

// Global information configuration
#let s = (s.methods.info)(
  self: s,
  title: [*TaMaRa: \ An automated triple modular redundancy EDA flow for Yosys*],
  author: [Matt Young],
  date: datetime.today().display("[day] [month repr:long] [year]"),
  institution: [University of Queensland \ Prepared for YosysHQ and Sandia National Laboratories],
)

// Extract methods
#let (init, slides, touying-outline, alert, speaker-note) = utils.methods(s)
#show: init

// #show strong: alert

// Extract slide functions
#let (slide, empty-slide) = utils.slides(s)
#show: slides

= Background
== About me
#grid(columns: (10em, auto), gutter: 15pt,
[
    #image("grad_portrait.jpg", width: 100%)
],
[
Matt Young, 21 years old from Brisbane, Australia.

Graduated Bachelor of Computer Science earlier in 2024 from the University of Queensland.

Currently studying Bachelor of Computer Science (Honours) at UQ, which includes a one year research thesis.

Passionate about digital hardware design, embedded systems, high performance/low-level software/hardware.
Might take up a PhD in future :)
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

#pause
Even in terrestrial applications, SEUs can still occur
- Must be mitigated for high reliability applications

#pause
ASICs and FPGAs commonly deployed in space (and on Earth)...
#pause
but protection from SEUs remains expensive!

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
TODO describe TMR

== Triple Modular Redundancy
TMR can be added manually...

#pause

but this is *time consuming* and *error prone*.
//another time consuming and error prone step in the _already_ complex design process.

#pause

Let's automate it!

= TaMaRa methodology
== Concept
Implement TMR as a pass in an EDA synthesis tool.
- Integrated with the rest of the flow
- Easy to use
- Fully automated

#pause

*Goal*: Pick any design, of any complexity, "press a button" and have it be rad-hardened.

#pause

Yosys @Shah2019 is the best (and the only) open-source, research grade EDA synthesis tool.
#pause
- Proprietary vendor tools (Synopsys, Cadence, Xilinx, etc) immediately discarded
- Can't be extended to add custom passes
//ignored as they can't be extended

== Existing works
Very important prior work done by #cite(<Johnson2010>, form: "prose") at BYU.

#pause

TODO algorithm

== The TaMaRa algorithm

TODO

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
//- Most likely will use Verilator or possibly cxxrtl

#pause

Concept:
- Iterate over the netlist, randomly consider flipping a bit every cycle
- Write a self-checking testbench and ensure that the DUT responds correctly

== Technical implementation
Currently implemented in C++20, using CMake.

#pause

Load into Yosys: `plugin -i libtamara.so`

#pause

TMR is implemented as two separate commands: `tmr` and `tmr_finalise`

#pause

Run `tmr` after synthesis, but before techmapping.

#pause

Run `tmr_finalise` just before techmapping (ensuring no more optimisation passes will run).

= Current status & future
== Current status
TODO

Mostly focused around literature reviews, scoping out the problem, formulating requirements, etc.

Skeleton plugin does exist.

== The future
This will be implemented for my Honours thesis over the next 1 year.
- Honours is kind of of like mini masters, it's an Australia-specific thing.
- Supervised by Assoc. Prof. John Williams (former PetaLogix, Xilinx)

#pause

Programming hopefully finished _around_ January 2025.

#pause

Ideally, TaMaRa will be released open-source under the MPL 2.0.
- Pending university IP shenanigans...

= Conclusion
== Summary
- Automated triple modular redundancy EDA flow for Yosys
- Takes any circuit, helps to prevent it from experiencing SEUs
- Click a button and have any circuit run in space/in high reliability environments!

== Bibliography
#bibliography("slides.bib", style: "institute-of-electrical-and-electronics-engineers", title: none)

== Thank you!
*Any questions?*
