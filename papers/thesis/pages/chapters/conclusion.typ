#import "../../util/macros.typ": *

= Conclusion
== Future work <chap:futurework>
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
as can often happen in many industry designs. #TODO("talk about this being extractReplicaWire's fault?")
#TODO("and also sort of _going against the grain_ of how Yosys internals are meant to work")

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
  caption: [ Table of single-bit combinatorial circuit designs ]
) <tab:bugs>
]

It is worth mentioning that not all of the causes of these failures are technical: there is a large human
aspect as well. In other words, a lot of these failures were caused by oversights or errors on my part.
Although I knew the wiring stage of the algorithm was going to be complex, I failed to consider _just how_
complex it would be. Whilst I understood that recurrent circuits would pose an issue from the beginning of the
project and planned around this, I failed to realise that multi-bit buses would also be an issue. This caused
a loss of time mid-way through the project to understand this issue and determine the best way to resolve it,
which is something that should have been planned out from the start.

#TODO("more on this, person failings")
- diving into programming too quickly
- failed to realise how difficult RTLIL was; time budgeting issue
- failed to research RTLIL and Yosys internals properly (SigSpec etc)
- failed to account for multi-bit buses early on

Likewise, there are some limitations in the verification methodology that need to be addressed. Whilst I do
believe that the verification proofs are strong for the circuits we were able to prove, there are a number of
circuits that I was unable to prove, mainly those that use sequential logic. The main issue is an unexpected
result when injecting numerous faults into the circuit. As shown in Figure XX, after a certain number of
faults, even an unmitigated circuit (without any TMR at all!) is apparently able to mitigate 100% of the
injected faults. This is a result that should not be possible, and is likely a methodological error caused by
the sheer number of faults being introduced into a small circuit cancelling each other out. Likewise, however,
we unfortunately cannot process more complex circuits due to the fundamental algorithmic issues described
above. This puts us in a difficult situation where, for this thesis, I was unfortunately able to prove
sequential circuits at all. I can say that from a detailed visual analysis, certain sequential circuits appear
correct, but without the SAT proofs (or an equivalently rigorous testbench), we cannot say this for sure.

#TODO("solution to L21 method.typ (opt removes TMR)")

#TODO("more stuff")
- upstream yosys bugs uncovered using fuzzer

#TODO("actual future work")
- handle memories
- phd plans (placement driven TMR)
- prove that "err" is set high when a fault is injected
