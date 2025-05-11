#import "../../util/macros.typ": *

= Literature review <chap:lit>
== Introduction, methodology and terminology <section:litintro>
The automation of triple modular redundancy, as well as associated topics such as general fault-tolerant
computing methods and the effects of SEUs on digital hardware, have been studied a fair amount in academic
literature. Several authors have invented a number of approaches to automate TMR, at various levels of
granularity, and at various points in the FPGA/ASIC synthesis pipeline. This presents an interesting challenge
to systematically review and categorise. To address this, I propose that all automated TMR approaches can be
fundamentally categorised into the following dichotomy:

- *Design-level approaches* ("thinking in terms of HDL"): These approaches treat the design as _modules_, and
    introduce TMR by replicating these modules. A module could be anything from an entire CPU, to a
    register file, to even a single combinatorial circuit or AND gate. Once the modules are replicated, voters are
    inserted.
- *Netlist-level approaches* ("thinking in terms of circuits"): These approaches treat the design as a
    _circuit_ or _netlist_, which is internally represented as a graph. TMR is introduced using graph theory
    algorithms to _cut_ the graph in a particular way and insert voters.

Using these two design paradigms as a guiding point, I analyse the literature on automated TMR, as well as
background literature on fault-tolerant computing.

== Fault tolerant computing and redundancy
The application of triple modular redundancy to computer systems was first introduced into academia by Lyons
and Vanderkul @Lyons1962 in 1962. Like much of computer science, however, the authors trace the original
concept back to John von Neumann. In addition to introducing the application of TMR to computer systems, the
authors also provide a rigorous Monte-Carlo mathematical analysis of the reliability of TMR. One important
takeaway from this is that the only way to make a system reliably redundant is to split it into multiple
components, each of which is more reliable than the system as a whole. In the modern FPGA concept, this
implies applying TMR at an Register Transfer Level (RTL) module level, although as we will soon see, more
optimal and finer grained TMR can be applied. Although their Monte Carlo analysis shows that TMR dramatically
improves reliability, they importantly show that as the number of modules $M$ in the computer system
increases, the computer will eventually become less reliable. This is due to the fact that the voter circuits
may not themselves be perfectly reliable, and is important to note for FPGA and ASIC designs which may
instantiate hundreds or potentially thousands of modules.

Instead of triple modular redundancy, ASICs can be designed using rad-hardened CMOS process nodes or design
techniques. Much has been written about rad-hardened microprocessors, of which many are deployed (and continue
to be deployed) in space to this day. One such example is the RAD750 @Berger2001, a rad-hardened PowerPC CPU
for space applications designed by Berger et al. of BAE Systems. They claim "5-6 orders of magnitude" better
SEU performance compared to a stock PowerPC 750 under intense radiation conditions. The processor is
manufactured on a six-layer commercial 250 nm process node, using specialty design considerations for the RAM,
PLLs, and standard cell libraries. Despite using special design techniques, the process node itself is
standard commercial CMOS node and is not inherently rad-hardened. The authors particularly draw attention to
the development of a special SEU-hardened RAM cell, although unfortunately they do not elaborate on the exact
implementation method used. However, they do mention that these techniques increase the die area from 67
mm#super("2") in a standard PowerPC 750, to 120 mm#super("2") in the RAD750, a \~1.7x increase. Berger et al.
also used an extensive verification methodology, including the formal verification of the gate-level netlist
and functional VHDL simulation. The RAD750 has been deployed on numerous high-profile missions including the
James Webb Space Telescope and Curiosity Mars rover. Despite its wide utilisation, however, the RAD750 remains
extremely expensive - costing over \$200,000 USD in 2021 @Hagedoorn2021. This makes it well out of the reach
of research groups, and possibly even difficult to acquire for space agencies like NASA.

In addition to commercial CMOS process nodes, there are also specialty rad-hardened process nodes designed by
several fabs. One such example is Skywater Technologies' 90 nm FD-SOI ("Fully Depleted Silicon-On-Insulator")
node. The FD-SOI process, in particular, has been shown to have inherent resistance to SEUs and ionising
radiation due to its top thin silicon film and buried insulating oxide layer @Zhao2014. Despite this,
unfortunately, FD-SOI is an advanced process node that is often expensive to manufacture.

Instead of the above, with a sufficiently reliable TMR technique (that this research ideally would like to
help create), it should theoretically be possible to use a commercial-off-the-shelf (COTS) FPGA for mission
critical space systems, reducing cost enormously - this is one of the key value propositions of automated TMR
research. Of course, TMR is not flawless: its well-known limitations in power, performance and area (PPA) have
been documented extensively in the literature, particularly by Johnson @Johnson2010 @Johnson2010a. Despite
this, TMR does have the advantage of being more general purpose and cost-effective than a specially designed
ASIC like the RAD750. TMR can be applied to any design, FPGA or ASIC, at various different levels of
granularity and hierarchy, allowing for studies of different trade-offs. For ASICs in particular, unlike the
RAD750, TMR as a design technique does not need to be specially ported to new process nodes: an automated TMR
approach could be applied to a circuit on a 250 nm or 25 nm process node without any major design changes.
Nonetheless, specialty rad-hardened ASICs will likely to see future use in space applications. In fact, it's
entirely possible that a rad-hardened FPGA _in combination_ with an automated TMR technique is the best way of
ensuring reliability.

// TODO more background literature on other approaches to rad-hardening: rad-hardened CMOS and TMR CPUs and
// scrubbing

// TODO more literature defining probabilities and effects of SEUs on ASICs/FPGAs in space

== Netlist-level approaches
Recognising that prior literature focused mostly around manual or theoretical TMR, and the limitations of a
manual approach, Johnson and Wirthlin @Johnson2010 introduced four algorithms for the automatic insertion of
TMR voters in a circuit, with a particular focus on timing and area trade-offs. Together with the thesis this
paper was based on @Johnson2010a, these two publications form the seminal works on automated TMR for digital
EDA. Johnson's algorithm operates on a post-synthesis netlist before technology mapping. First, he creates
three copies of the original circuit, then triplicates component instantiations and wire nets, and finally
connects the nets in such a way that the behaviour of the original circuit is preserved. This is described as
the "easy part" of TMR - the more complex step is selecting both a valid _and_ optimal placement for majority
voters. Johnson identifies four main classes of voters. Note that in this section, "SRAM scrubbing" refers to
Johnson's method of dynamic runtime reconfiguration of the FPGA configuration SRAM to correct SEUs.

1. *Reducing voters*: Combines the output from three TMR replicas into a single output, in other words,
    a single majority voter. Used on circuit outputs.
2. *Partitioning voters*: Used to increase reliability within a circuit by partitioning it, and applying TMR
    separately to each partition. Johnson states that if only reducing voters were used in a circuit, errors
    would be masked from SRAM scrubbing as long as they only occur in one replica at a time. In addition,
    multiple SEUs in close proximity can prevent the TMR redundancy from working correctly. Partitioning
    voters have the benefit of dividing the circuit into independent partitions that can tolerate SEUs
    independently. One important takeaway that Johnson mentions is that there is an optimal balance between
    the number of partitions, which increases the likelihood of separate SEUs affecting multiple partitions,
    and having _too many_ partitions which reduces reliability due to the voters being affected. This relates
    to the early research conducted by Lyons and Vanderkul @Lyons1962.
3. *Clock domain crossing voters*: These are used due to the special considerations when TMR circuits cross
    multiple clock domains. In particular, metastability effects are a serious consideration for clock domain
    crossing voters. Johnson implements this type of voter using a small train of consecutive flip-flops to
    attempt to reduce the probability of metastable values propagating. However, for TaMaRa, due to the very
    tight time constraints of an Honours thesis, we will likely not consider multiple clock domains, and thus
    metastable voters will not be required.
4. *Synchronisation voters*: These are required when SRAM scrubbing is used with TMR that
    includes sequential logic (i.e. FFs, so most designs). These are meant to restore correct register state
    after FPGAs are repaired by SRAM scrubbing. Again due to time constraints and the vendor-specific nature
    of the process, TaMaRa will leave SRAM scrubbing up to the end user, using the provided error signal from
    the majority voters. Rather than supporting dynamic SRAM scrubbing (as in Bridford et al. @Bridford2008),
    we will suggest users simply reset the device when a fault is detected.

One other consideration that Johnson takes into account is illegal or undesirable voter cuts (a "voter cut" is
his terminology for splicing a netlist and inserting a majority voter). He notes that some netlist cuts are
illegal, for example, some Xilinx FPGAs do not support configurable routing between different types of
primitives, particularly DSP primitives. He also very interestingly notes that there are undesirable, but not
strictly illegal cuts that may be performed. These would, for example, break high speed carry chains on Xilinx
devices and impact performance. This is a very interesting observation, as it implies the possibility of a
placement/routing aware TMR algorithm. This is a fascinating topic for future research, but time does not
permit its implementation in TaMaRa. Instead, TaMaRa will likely leave design legalisation to Nextpnr and not
strictly consider performance when inserting voters. The majority of Johnson's work, and the complexity he
describes, concerns the insertion of synchronisation voters using graph theory algorithms such as Strongly
Connected Components (SCC). For TaMaRa, we declared that we do not need synchronisation voters, as we do not
perform dynamic SRAM scrubbing, instead fully rebooting the device if we detect a fault. This should mean that
TaMaRa is a lot easier to implement. Nonetheless, however, I believe it may be possible to use some of
Johnson's SCC algorithm to elegantly decompose a netlist into partitions, and insert partition voters. We will
most likely insert reducing voters and partitioning voters, and if time permits, clock domain crossing voters
as well.

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
This is quite a complex process, and was also designed before Yosys was introduced in 2013. It would be
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
Arguably, the most important takeaway from Benites' work is the use of equivalence checking in the TMR
verification stage. This is especially important since Johnson @Johnson2010 did not formally verify his
approach. Benites' usage of formal verification, in particular, equivalence checking, is an excellent starting
point to design the verification methodology for TaMaRa.

Xilinx, the largest designer of FPGAs, also has a netlist-level TMR software package known as TMRTool
@Xilinx2017. This implements a Xilinx proprietary algorithm known as XTMR, which differs from traditional TMR
approaches in that it also aims to correct faults introduced into the circuit by SEUs (rather than just
masking their existence). Xilinx also aims to
address single-event transients ("SETs"), where ionising radiation causes voltage spikes on the FPGA routing
fabric. TMRTool follows a similar approach to the other netlist-level algorithms described above, with some
small improvements and Xilinx-specific features. The flow first triplicates all inputs, combinatorial logic
and routing. Then, it inserts voters downstream in the circuit, particularly on finite state machine (FSM)
feedback paths. One important difference is that, at this point in the flow, Xilinx also decides to triplicate
the voters themselves. This means there is no single point of failure (which improves redundancy), although it
has a higher area cost than approaches that do not triplicate voters. In addition, TMRTool is designed to be
used with configuration scrubbing. Xilinx has much further research on FPGA configuration scrubbing
@Bridford2008. The two main approaches are either a full reboot, or a partial runtime reconfiguration. Since
the FPGA configuration is stored in an SRAM that's read at boot-up, a full reboot will naturally reconfigure
the device, and thus correct any logic/routing issues caused by SEUs. However, a more efficient solution is
only re-flashing the sectors of the FPGA that are known to be affected by SEUs. This is known as partial
runtime reconfiguration. Unfortunately, as noted in the Xilinx documentation, this partial reconfiguration is
a vendor-specific process. It would not be possible to design a multi-vendor runtime reconfiguration approach,
and worse still, much of this specification is still undocumented and proprietary, precluding its integration
with Yosys or Nextpnr. Despite this, we could provide end-users with an error signal from the majority voter,
which could be used to one form of reconfiguration if desired. The two most relevant components of TMRTool to
the TaMaRa algorithm are its consideration of feedback paths for FSMs, and its consideration of redundant
clock domains. Both of these considerations are mentioned in the other netlist-level approaches, but it seems
to occupy a considerable amount of engineering time and effort for Xilinx, and thus can be expected to be a
significant issue for TaMaRa as well. TMRTool's FSM feedback is important to ensure the synchronisation of
triplicated redundant FSMs, but unfortunately requires manual verification in some cases to ensure Xilinx's
synthesis has not introduced problems to the design. Finally, TMRTool also has a very flexible architecture.
The implementation strategy can be customised to various different approaches. Most are Xilinx-specific, but
two relevant ones to TaMaRa are "Standard" and "Don't Touch". "Standard" works by triplicating the underlying
FPGA primitives and inserting voters, as usual. "Don't Touch", however, is important to be added to FPGA
primitives that cannot be replicated, and avoids TMR entirely. This would be very beneficial to add as an
option to the TaMaRa algorithm.

On the lower level side, Hindman et al. @Hindman2011 introduce an ASIC standard-cell based automated TMR
approach. When digital circuits are synthesised into ASICs, they are technology mapped onto standard cells
provided by the foundry as part of their Process Design Kit (PDK). For example, SkyWater Technology provides
an open-source 130 nm ASIC PDK, which contains standard cells for NAND gates, muxes and more @skywater. The
authors design a TMR flip-flop cell, known as a "Triple Redundant Self Correcting Master-Slave Flip-Flop"
(TRSCMSFF), that mitigates SEUs at the implementation level. Since this is so low level and operates below the
entire synthesis/place and route pipeline, their approach has the advantage that _any_ design - including
proprietary encrypted IP cores that are (unfortunately) common in industry - can be made redundant. Very
importantly, the original design need not be aware of the TMR implementation, so this approach fulfills my
goal of making TMR available seamlessly to designers. The authors demonstrate that the TRSCMSFF cell adds
minimal overhead to logic speed and power consumption, and even perform a real-life radiation test under a
high energy ion beam. Overall, this is an excellent approach for ASICs. However, this approach, being
standard-cell specific, cannot be applied to FPGA designs. Rather, the FPGA manufacturers themselves would
need to apply this method to make a series of specially rad-hardened devices. It would also appear that
designers would have to port the TRSCMSFF cell to each fab and process node they intend to target. While
TaMaRa will have worse power, performance and area (PPA) trade-offs on ASICs than this method, it is also more
general in that it can target FPGAs _and_ ASICs due to being integrated directly into Yosys. Nevertheless, it
would appear that for the specific case of targeting the best PPA trade-offs for TMR on ASICs, the approach
described in @Hindman2011 is the most optimal one available.

// future research topic! design a rad hardened FPGA using this approach!

== Design-level approaches
Several authors have investigated applying TMR directly to HDL source code. One of the most notable examples
was introduced by Kulis @Kulis2017, through a tool he calls "TMRG". TMRG operates on Verilog RTL by
implementing the majority of a Verilog parser and elaborator from scratch. It takes as input Verilog RTL, as
well as a selection of Verilog source comments that act as annotations to guide the tool on its behaviour. In
turn, the tool modifies the design code and outputs processed Verilog RTL that implements TMR, as well as
Synopsys Design Compiler design constraints. Like the goal of TaMaRa, the TMRG approach is designed to target
both FPGAs and ASICs, and for FPGAs, Kulis correctly identifies the issue that not all FPGA blocks can be
replicated. For example, a design that instantiates a PLL clock divider on an FPGA that only contains one PLL
could not be replicated. Kulis also correctly identifies that optimisation-driven synthesis tools such as
Yosys and Synopsys DC will eliminate TMR logic as part of the synthesis pipeline, as the redundancy is, by
nature, redundant and subject to removal. In Yosys, this occurs specifically in the `opt_share` and
`opt_clean` passes according to specific advice from the development team @Engelhardt2024. However, unlike
Synopsys DC, Yosys is not constraint driven, which means that Kulis' constraint-based approach to preserving
TMR logic through optimisation would not work in this case.  Finally, since TMRG re-implements the majority of
a synthesis tool's frontend (including the parser and elaborator), it is limited to only supporting Verilog.
Yosys natively supports Verilog and some SystemVerilog, with plugins @synlig providing more complete SV and
VHDL support. Since TaMaRa uses Yosys' existing frontend, it should be more reliable and useable with many
more HDLs.

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

== TMR verification
While Benites @Benites2018 @Benites2018a discusses verification of the automated TMR process, and other
authors @Lee2017 @Hindman2011 @Berger2001 also use various different verification/testing
methodologies, there is also some literature that exclusively focuses on the verification aspect. Verification
is one of the most important parts of this process due to the safety-critical nature of the devices TMR is
typically deployed to. Additionally, there are interesting trade-offs between different verification
methodologies, particularly fault injection vs. formal verification.

Beltrame @Beltrame2015 uses a divide and conquer approach for TMR netlist verification. Specifically,
identifying limitations with prior fault-injection simulation and formal verification techniques, he presents
an approach described as fault injection combined with formal verification: instead of simulating the entire
netlist with timing accurate simulation, he uses a behavioural timeless simulation of small submodules ("logic
cones") extracted by automatic analysis. The algorithm then has three main phases:
1. Triplet identification: Determine all the FF (flip-flop) triplets present in each logic cone.
2. TMR structure analysis: Perform exhaustive fault injection on valid configurations.
3. Clock and reset tree verification: Assure that no FF triplets have common clock or set/reset lines.
This seems to be an effective and rigorous approach, as Beltrame mentions he was able to find TMR bugs in the
radiation-hardened netlist of a LEON3 processor. Importantly, the code for the tool appears is available on
GitHub as _InFault_. It would be highly worthwhile investigating the use of this tool for verification, as it
has already been proven in prior research and may overall save time. That being said, a quick analysis of the
code appears to reveal it to be "research quality" (i.e. zero documentation and seems partially unfinished).
Another problematic issue is that the code does not seem to readily compile under a modern version of GCC or
Clang, and would require manual fixing in order to do so. Finally, the _InFault_ tool implements a custom
Verilog frontend for reading designs. This has the exact same problem as Kulis' @Kulis2017 custom Verilog
frontend: it's not clear to what standard this is implemented. We may have to write a custom RTLIL or EDIF
frontend to ingest Yosys netlists. The main question is whether resolving these issues would take more time
than implementing formal verification ourselves in Yosys. One other important limitation not yet mentioned in
Beltrame's approach is the presence of false positives. Beltrame's "splitting algorithm" requires a tunable
threshold which, if set too low, may cause false positive detections of invalid TMR FFs. These false positives
require manual inspection of the netlist graph in order to understand. This is extremely problematic for large
designs, as it would seem to require many laborious hours from an engineer familiar with the _InFault_
algorithm to determine if any given detection was a false positive or not. It's also not immediately clear
what the range of suitable thresholds for this value are that would prevent or possibly eliminate false
positives.

// In this case, we may even prefer false _negatives_ (under the
// assumption that a sufficiently safety-critical design will be manually tested) than combing through many false
// positives.

Even if we do not end up using Beltrame's @Beltrame2015 approach in its entirety (for example, if the false
positives are a significant issue or if it's too much work to read Yosys designs), we may nonetheless be able
to repurpose parts of his work for TaMaRa. One aspect that would work particularly well inside of Yosys
itself is step 3 from the algorithm, clock and reset tree verification. Yosys already has tools to identify
clock and reset lines, so it should not be too much extra work to build a pass that verifies the clock and
resets in the netlist are suitable for TMR. In addition, parts of Beltrame's algorithm may be implementable
using other Yosys formal verification tools, particularly SymbiYosys. His terminology as well, particularly
the use of "logic cones", will likely be critical in the development of TaMaRa.

== Formal verification
Formal verification is increasingly being pursued in the development of FPGAs and ASICs as part of a
comprehensive design verification methodology. The foundations for the formal verification of digital circuits
extend back to traditional Boolean algebra and set theory in discrete mathematics. Building on these
foundations, digital circuit verification can be represented as a Boolean satisfiability ("SAT") problem. The
SAT problem asks us to prove whether or not there is a consistent assignment of input variables to a circuit
to make the circuit evaluate to _true_. This forms the basic primitive, the underlying problem to solve, for
nearly all circuit formal verification tasks; including both formal property verification and equivalence
checking. Despite SAT's usefulness, Karp @Karp1972 proved via the Cook-Levin theorem that it is an
NP-complete problem (i.e. there is likely no polynomial time solution). Despite this, there exist a number of
fast-enough SAT solvers @Sorensson2005 @Audemard2018, that make the verification of Boolean circuits using SAT
a tractable problem.

However, on large and complex designs, using SAT solvers directly on multi-bit buses can be slow. Instead,
Satisfiability Modulo Theories (SMT) solvers can be used instead. SMT is a generalisation of SAT that
introduces richer types such as bit vectors, integers, and reals @Barrett2018. Solving satisfiability modulo
theories is still at least NP-complete, sometimes undecidable. Most SMT solvers either depend on or "call out"
to an underlying SAT solver. One such SMT solver that uses this approach is Bitwuzla @Niemetz2023. Others,
however, such as Z3 @Moura2008 include their own SAT logic and other methods for computing solutions. The
speed of SMT solvers is very important when performing formal verification of digital circuits, and there is a
yearly SMT solving competition to encourage the development and analysis of high-performance SMT solvers
@Weber2019.

Formal equivalence checking uses formal techniques to verify that two circuits are equivalent in
functionality. #TODO("how does this work and cite; Miter circuits, etc. particularly focus on miter")

== RTL fuzzing <section:rtlfuzz>
In the software world, "fuzzing" refers to a process of randomly generating inputs designed to induce
problematic behaviour in programs. Typically, fuzzing is started by referencing an initial corpus, and the
program under test is then instrumented to add control flow tracking code. The goal of the fuzzer is to
generate inputs such that the program reaches 100% instrumented branch coverage once the fuzzing process is
completed.

While fuzzing is typically started from an initial corpus, there has also been interest in fuzzing languages
directly without any initial examples, using information from the language's grammar. One example is Holler's
LangFuzz @Holler2012, which uses a tree formed by the JavaScript grammar to generate random, but valid,
JavaScript code. Mozilla developers have used LangFuzz successfully to find numerous bugs in their
SpiderMonkey JavaScript engine. Generating code from the grammar directly also has the advantage of making the
fuzzing process significantly more efficient, as the fuzzer tool has the _a priori_ knowledge necessary to
"understand" the language. Compared to using a general purpose random fuzzer that typically generates and
mutates test cases on a byte-by-byte basis @Fioraldi2020, grammar fuzzers should be able to get significantly
higher coverage of a target program much more efficiently.

Although these techniques are typically used for software projects, they can also be useful for hardware,
particularly for EDA tools; given that Verilog is more or less just another programming language. RTL fuzzing
is an emerging technique that can be useful to generate large-scale coverage of Verilog design files for EDA
tools. Herklotz @Herklotz2020 describes "Verismith", a tool capable of generating random and correct Verilog
RTL. This is useful for TaMaRa verification, because it allows us to investigate _en masse_ whether the tool
changes the behaviour of the underlying circuit. It also allows us to quickly find, reproduce, minimise and
fix challenging designs, which should hopefully lead to a more reliable algorithm with better coverage of
industry-standard designs.
