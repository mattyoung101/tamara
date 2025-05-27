#import "../../util/macros.typ": *

= Conclusion
== Issues with the current implementation <chap:futurework>
Throughout the duration of this thesis, there have been a number of improvements and areas for future research
identified.

Firstly, in future work, it would be very important to address a number of limitations in the TaMaRa
algorithm. At this point, the algorithm is unfortunately unable to handle a number of critical circuits,
particularly circuits types that are commonly used in industry designs. This includes many (but not all)
circuits which use sequential elements such as DFFs, multi-cone circuits, recurrent circuits, and a small
number of combinatorial circuits with very complex bit swizzling. The critical flaw that causes this is the
lack of robustness of the wiring stage (@sec:wiring and @sec:wiringfixup). As an abstraction over any and all
circuits at various levels of the design process, RTLIL is extremely complex, and hence splicing an RTLIL
netlist to insert majority voters in all of these cases is very challenging. This is particularly the case
for both multi-cone circuits, circuits with complex bit manipulation, and especially when both are combined,
as can often happen in many industry designs.
// we could talk here about extractReplicaWire causing a lot of these problems but it's probably a bit too low
// level

One other area for improvement is the fact that TaMaRa currently does not handle memories. In its current
implementation, the tool adds a `(* tamara_ignore *)` annotation to all memory cells, and warns the user that
memories are not handled. Memory cells do not behave like other cells in Yosys, and it makes replicating them a
challenge, from both a design and verification perspective. On FPGAs, memory cells would likely require special handling
to be able to replicate them while respecting the FPGA's SRAM limitations. This could be similar, although
less of an issue, on ASICs as well. Likewise, verification of circuits with memory cells in them is a
challenge in Yosys. Memories cannot yet be directly proved by Yosys' built-in SAT solver, so would have to be
transformed into an array of flip-flops before they could be proved equivalent, which can be done with Yosys'
`memory` command.

In total, @tab:bugs shows a list of all bugs I am aware of in the algorithm:
#context [
#set par(justify: false)
#figure(
  table(
    columns: (auto, 20em, 8em),
    align: horizon,
    stroke: 0.5pt,
    [*Bug*],
    [*Description*],
    [*Overall impact*],

    [Multi-cone circuits are not handled correctly],
    [The wire rip-up phase fails for multi-cone circuits, dropping the intermediate wire connection between
    the two cones, and breaking the circuit.],
    [Severe. Multi-cone circuits would be very common in any typical industry design.],

    [Fuzzer cases can cause TaMaRa to crash],
    [Certain fuzzer-generated code can incorrectly convince TaMaRa that regular wiring is required (when there
    is only one attached SigChunk), when in
    fact special wiring is required. This causes an assert failure.],
    [Minor. Should not be common in real designs, but a bug nonetheless.],

    [MultiDriverFixer can crash on some designs],
    [The wiring code in MultiDriverFixer is not robust enough to handle re-wiring certain circuits, such as
    the picorv32 CPU. This causes an assert failure.],
    [Moderate. We would like to process picorv32 if possible.],

    [Multiple voters in the same cone cause multiple drivers on output],
    [A combination of failures in the voter insertion code and the wiring code can cause illegal multi-driver
  situations on the output signal of an RTL module. This is likely caused by a poor implementation of voter
    cut point selection.],
    [Severe. This, along with the first bug, means that multi-cone circuits cannot be handled.]
  ),
  caption: [ List of known TaMaRa bugs ]
) <tab:bugs>
]

It is worth mentioning that not all of the causes of these failures are technical: there is a large human
aspect as well. In other words, a lot of these failures were caused by oversights or errors on my part.
Although I knew the wiring stage of the algorithm was going to be complex, I failed to consider _just how_
complex it would be. Particularly, I failed to account for the challenges of working with RTLIL in general,
not just dealing with complicated circuits. This includes seemingly ordinary tasks like querying the
neighbours of a particular cell that end up being very complicated and require manual work. Whilst I
understood that recurrent circuits would pose an issue from the beginning of the project and planned around
this, I failed to realise that multi-bit buses would also be an issue. This caused a loss of time mid-way
through the project to understand this issue and determine the best way to resolve it, which is something that
should have been planned out from the start. Related to this, I failed to properly and deeply understand
Yosys' internals, including RTLIL, from an early stage. This was because I dived into programming TaMaRa too
quickly, and didn't spend enough time reading Yosys code and the documentation available to understand its
structure and approach. A good example of this is that I implemented a union type `tamara::RTLILAnyPtr` as a
`std::variant<RTLIL::Wire *, RTLIL::Cell *>`, as I believed Yosys did not have this type. However, as it turns
out, this is identical to the Yosys `RTLIL::SigSpec` type definition. Unfortunately, while Yosys has good
documentation for its end-user commands, it does not have very good internal documentation at all, which makes
it easy to miss concepts like this. Nevertheless, I _should_ have spent more time reading the Yosys codebase
much more carefully, particularly existing passes that perform similar operations to TaMaRa. My belief is that
a large amount of the headaches caused working with Yosys were my lack of understanding how RTLIL is designed,
and "working against the grain" as it were with the tool.

Likewise, there are some limitations in the verification methodology that need to be addressed. Whilst I do
believe that the verification proofs are strong for the circuits we were able to prove, there are a number of
circuits that I was unable to prove, mainly those that use sequential logic. The main issue is an unexpected
result when injecting numerous faults into the circuit. As shown in Figure #TODO("figure"), after a certain number of
faults, even an unmitigated circuit (without any TMR at all!) is apparently able to mitigate 100% of the
injected faults. This is a result that should not be possible, and is likely a methodological error caused by
the sheer number of faults being introduced into a small circuit cancelling each other out. Likewise, however,
we unfortunately cannot process more complex circuits due to the fundamental algorithmic issues described
above. This puts us in a difficult situation where, for this thesis, I was unfortunately able to prove
sequential circuits at all. I can say that from a detailed visual analysis, certain sequential circuits appear
correct, but without the SAT proofs (or an equivalently rigorous testbench), we cannot say this for sure.
Additionally, on the formal verification side of things, it would be very useful - and relatively easy - to
formally prove that the `err` signal is set high when a fault is injected, and low when there is no fault.
This could be achieved by adding a set of RTL `$assert` statements into the test designs.

One other issue identified in the methodology (@chap:method) was an issue regarding the potential for the TMR
logic to be optimised as Yosys. As we covered in the literature review, one major problem in all prior TMR
approaches is that they have poor approaches to handling the synthesis tool incorrectly detecting TMR logic as
redundant and removing it. I planned to address this in TaMaRa by running the algorithm post-synthesis,
pre-techmapping, ideally after all optimisation had been run. Unfortunately, in practice, this line is not so
clear cut. The technology mapping happens in stages, during which certain optimisation passes are run.
Importantly, after the final technology mapping pass, a final full optimisation step is run, which in
principle would remove TaMaRa's redundant TMR logic. There are a number of solutions to this, but likely the
best involves a modification to the upstream Yosys tool. Ideally, each optimisation pass would respect a
scratchpad variable to optionally disable it. For example, `opt_share`, which is the main pass that would
remove redundant logic, would respect `opt.share.disable = true` as a scratchpad variable and prevent itself
from running. This approach was not implemented in this thesis, as it would require discussion with Yosys
maintainers and a pull request to be merged, but could perhaps be useful future work.

== Future work
During the course of this thesis, I was also able to uncover some upstream Yosys bugs
#footnote([https://github.com/YosysHQ/yosys/issues/4599])
#footnote([https://github.com/YosysHQ/yosys/issues/4909]) using the Verismith fuzzer tool. This does raise the
question about what further bugs are lurking within Yosys. In my opinion, a valuable research effort would be
a large-scale fuzzing of Yosys, not just to uncover crashes, but to formally prove equivalence between
optimisation passes. This would be a relatively straightforward process of generating Verilog with Verismith,
and then performing a Miter-SAT equivalence check between the optimised and unoptimised passes. I have drafted
up a script that does this, and have found what I believe to be a few issues (i.e. non-equivalent results)
with the `split_cells` pass, which I plan to report in the future. The main issue with this is being able to
triage results into a minimised and useful form to report to maintainers, which is quite a non-trivial task.

One other verification technique that would be interesting to explore is that of _bitstream fault-injection._
This was planned earlier in development with a tool known as the `ecp5_shotgun`, which was going to be used to
inject faults into the FPGA bitstream on a Lattice ECP5 FPGA, and test its behaviour in the real world. For
FPGAs in particular, one of the biggest problems with their usage in space is that their configuration SRAM
("CRAM") takes up significantly more area than the actual LUTs themselves, thus making it more susceptible to
SEUs. When a fault occurs, it has the effect of actually _changing_ the circuit entirely, which could be
significantly harder to correct. This is an area that would benefit from further research.

Finally, in addition to all the above improvements, there are also some new research directions I have
identified to explore. Interestingly, in many of these test cases, the voter circuit occupies a significantly
larger area compared to the main circuit. This raises the possibility of an area-driven, or even a
placement-driven approach to TMR. To elaborate on that concept, in addition to performing TMR at the synthesis
level, we would modify th EDA placer to attempt to place ASIC/FPGA cells in such a way as to mitigate
multi-bit upsets, and potentially single-event upsets, between replicas of the TMR. In essence, this would
involve placing the ASIC/FPGA to maximise frequency while minimising the probability of a particle striking
both replicas in a single TMR block. Likewise, although I have performed formal equivalence-based fault
injection studies in this thesis, if the TaMaRa algorithm was powerful enough to handle industry-standard
circuits such as CPUs, it would be very interesting to fabricate a chip or design an FPGA using the TaMaRa
algorithm and subject it to real radiation. Similarly, it would be interesting to compare the performance of
non-TMR techniques such as Error Correcting Codes (ECCs) in real-world radiation scenarios. Potentially,
Hamming or Bose–Chaudhuri–Hocquenghem (BCH) codes could provide similar or greater SEU-mitigation performance
at the cost of significantly less area, particularly in microprocessor designs. This could also be combined
with techniques such as rolling back and re-issuing instructions when faults occur, or issuing each
instruction three times and comparing the result. Finally, although not as advanced as the prior ideas, it
would be interesting to better understand _why_ particular circuits perform better or worse when injected
under TMR, as this could answer questions raised in @sec:analysis.

All in all, I think there are a number of interesting avenues to pursue in radiation-hardening research for
integrated circuits, and I do intend to pursue these through a PhD.

== Summary
In this thesis, I have presented _TaMaRa_: an automated Triple Modular Redundancy EDA flow for Yosys. In
@chap:intro, I introduced the background and the concept of the TaMaRa algorithm. In @chap:lit, I performed an
extensive literature review of automated-TMR over many years of academic literature, and divided the
literature into two main approaches: design-level and netlist-level. In @chap:method, I described the TaMaRa
algorithm in detail, and explained how it uses a backwards-BFS logic-cone based approach to find and replicate
TMR elements without changing circuit behaviour. I also introduced the extensive verification methodology I
used. In @chap:results, I presented a number of test circuits, as well as comprehensive formally-verified
fault-injection studies. Finally, in the prior section of this chapter, I presented a detailed analysis of
future work and improvements for the TaMaRa algorithm. While it may be early days for TaMaRa algorithm, my
hope is that this algorithm and future research that I perform in this space will be beneficial to many.

Thank you for reading.

#align(right)[#sym.qed]

