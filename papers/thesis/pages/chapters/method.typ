#import "../../util/macros.typ": *

= Methodology <chap:method>
== Concept
In the previous @chap:lit, I presented a comprehensive literature review of existing automated TMR approaches.
One of the main limitations that these algorithms have is that none are specifically integrated into the Yosys
synthesis tool. I envision TaMaRa as a platform that provides a baseline TMR implementation that other
researchers can extend upon, and that industry users can experiment with, all the while supporting both
FPGAs/ASICs and being fully integrated as part of a widely used open-source EDA synthesis tool. Operating
directly on Yosys' RTLIL intermediate representation ensures that any future optimisations Yosys gains, or any
languages it supports in future, can be immediately also supported by TaMaRa.

To design the TaMaRa algorithm, I synthesise existing approaches from the literature review to form a novel
approach suitable for implementation in Yosys. Specifically, I synthesise the voter insertion algorithms of
Johnson @Johnson2010, the RTL annotation-driven approach of Kulis @Kulis2017, and parts of the verification
methodology of Benites @Benites2018 and Beltrame @Beltrame2015, to form the TaMaRa algorithm and verification
methodology. Based on the dichotomy identified in @section:litintro, TaMaRa will be classified as a
_netlist-level_ approach, as the algorithms are designed by treating the design as a circuit (rather than
HDL).

I propose a modification to the synthesis flow that inserts TaMaRa before technology mapping. This means that
the circuit can be processed at a low level, with less concerns about optimisation removing the redundant TMR
logic, as has been observed in other approaches @Lee2017 and through conversation with the Yosys developers
@Engelhardt2024. However, some Yosys synthesis scripts do perform additional optimisation _after_ technology
mapping, which again risks the removal of the TMR logic. Yet, we also cannot operate after technology mapping,
since TaMaRa voter circuits are described using relatively high level circuit primitives (AND gates, NOT
gates, etc) instead of vendor-specific FPGA primitives like LUTs. The best solution to this likely involves an
upstream modification to Yosys that allows for certain optimisation passes to be selectively skipped; this is
further discussed in @chap:futurework.

Whilst TaMaRa aims to be compatible with all existing designs with minimal changes, some preconditions are
necessary for the algorithm to process the circuit correctly.

Since the algorithm is intended to work with all possible circuits, it cannot predict what the end user wants
to do with the voter error signal (if anything). As discussed in the literature review, the typical use case
for the error signal is to perform configuration scrubbing when upsets are detected. This, however, is a
highly vendor-specific process for FPGAs, and is not at all possible on ASICs.  To solve this problem, TaMaRa
does not aim to provide configuration scrubbing directly, instead leaving this for the end user. Instead, the
end user can attach an HDL annotation to indicate an output port on a module that TaMaRa should wire a global
voter error signal to. In SystemVerilog, this uses the `(* tamara_error_sink *)` annotation, as shown in
@lst:errorsink:

#figure(
    ```systemverilog
    module my_module(
        input logic a,
        (* tamara_error_sink *)
        output logic err
    );
    ```,
    caption: [ Usage of the `(* tamara_error_sink *)` annotation ]
) <lst:errorsink>

End users are then free to implement configuration scrubbing using the tool and methodology appropriate to
their platform.

Additionally, while TaMaRa aims to require minimal or no changes to the circuit itself, there are changes
necessary to the synthesis pipeline. Unlike in normal Yosys synthesis scripts, the design cannot be lowered
directly to FPGA/ASIC primitives (LUTs, standard cells, etc). It first needs to be lowered to abstract logic
primitives (AND gates, NOT gates, etc) that TaMaRa can process, particularly, that it can generate voter
circuits in. Then, TaMaRa can be run, after which the design can be lowered to FPGA primitives or ASIC
standard cells. TaMaRa currently also requires the user to run the `splitcells` and `splitnets` commands
before it is invoked to split apart multi-bit buses and cells, which are not yet directly supported. These
additional requirements may introduce a slight area overhead, but it would be possible to eliminate them in
the future through better algorithm design.

== Implementation
Over the course of this thesis, TaMaRa was successfully written from the ground up as a Yosys plugin. This
plugin consists of around 2,300 lines of C++20, and introduces one new command to Yosys: `tamara_tmr`.

TaMaRa is currently designed to only operate on one module, that being the top module. This is typical of
space applications. For example, consider a Verilog top module called `cpu_top` that contains a 32-bit RISC-V
CPU, along with its register file, ALU, memory and instruction decoder. To ensure full rad-hard reliability in
space, the whole `cpu_top` module needs to be triplicated. However, in the future, it would be a nice feature
to be able to have finer grained control over the parts of the design are triplicated. This does unfortunately
introduce some significant problems that will be elaborated on later.

#figure(
    image("../../diagrams/classdiagram.svg"),
    caption: [ Class diagram of the TaMaRa codebase ]
) <fig:classdiagram>

TaMaRa consists of multiple C++ classes (@fig:classdiagram). Broadly speaking, these classes combine together
to form the following algorithm. This is also shown in @fig:algodiagram.

=== Voter design
Voters are one of the most important parts of a TMR circuit, and so I believed it was extremely important to
design them and verify them with a high degree of assurance. In the very beginning, the voter circuit was
designed manually; first by sketching the truth table by hand, then automatically converting this to a logic
schematic using Logisim Evolution @Burch2024. The Logisim circuit was then transformed manually into a series
of C++ macros that build an equivalent circuit in RTLIL. A formal equivalence check was performed between this
RTLIL design and the original truth table sketched by hand, which was correct.

The voter consists of three input signals: _a_, _b_ and _c_, which are respectively the 1-bit inputs from each
of the triplicated elements. The voter then has two output signals: _out_ and _err_. _out_ is the majority
voted combination of the three inputs, i.e. the inputs with any SEUs removed. The _err_ signal is set to '1'
if and only if a fault was detected. This could be used for diagnostics, or to perform a configuration reset
if possible on FPGAs, and reboot on ASICs.

Given these constraints, the truth table for a majority voter can be described as follows (@tab:sotrue):

#figure(
  table(
    columns: 5,
    align: horizon,
    stroke: 0.5pt,
    [*a*],
    [*b*],
    [*c*],
    [*out*],
    [*err*],
    [0], [0], [0], [0], [0],
    [0], [0], [1], [0], [1],
    [0], [1], [0], [0], [1],
    [0], [1], [1], [1], [1],
    [1], [0], [0], [0], [1],
    [1], [0], [1], [1], [1],
    [1], [1], [0], [1], [1],
    [1], [1], [1], [1], [0],
  ),
  caption: [ Truth table for a single-bit majority voter ]
) <tab:sotrue>

Using techniques such as Karnaugh mapping @Karnaugh1953, this truth table can be optimally mapped to a
combinatorial circuit. In this case, Logisim Evolution @Burch2024 was used, which produced the following
result as shown in @fig:logisim. This circuit consists of 3 NOT gates, 6 AND gates, and 4 OR gates. These are
all two-input gates.

#figure(
    image("../../diagrams/logisim.png"),
    caption: [ Logisim Evolution schematic for voter circuit ]
) <fig:logisim>

Using a series of macros, this can be translated into C++ code that generates RTLIL circuits. First, we define
a series of macros like `WIRE`, `NOT`, `AND` and `OR` that add RTLIL objects to the current module with the
correct `tamara_voter` annotation, which is expected to be applied to all voter logic elements. Then, I
performed a direct, manual translation as shown in @lst:macro:

#figure(
    ```cpp
    // NOT
    // a -> not0 -> and2
    WIRE(not0, and2);
    NOT(0, a, not0_and2_wire);

    // b -> not1 -> and3
    WIRE(not1, and3);
    NOT(1, b, not1_and3_wire);

    // c -> not2 -> and5
    WIRE(not2, and5);
    NOT(2, c, not2_and5_wire);

    // AND
    // b, c -> and0 -> or0
    WIRE(and0, or0);
    AND(0, b, c, and0_or0_wire);

    // a, c -> and1 -> or0
    WIRE(and1, or0);
    AND(1, a, c, and1_or0_wire);

    // and so on, and so on...
    ```,
    caption: [ Partial listing of C++ macros to generate a voter ]
) <lst:macro>

When applied in Yosys, a schematic similar to the Logisim circuit is generated, as shown in @fig:yosysvoter:

#figure(
    image("../../diagrams/schematics/voter.svg"),
    caption: [ Voter schematic generated by Yosys ]
) <fig:yosysvoter>

Using a SystemVerilog translation of the Boolean function implementing a voter (@lst:svmajvoter), the RTLIL
generated voter was formally verified to be correctly implemented. Further details on the formal verification
procedure are presented later in @section:formalverif.

#figure(
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
    ```,
    caption: [ SystemVerilog implementation of 1-bit majority voter ]
) <lst:svmajvoter>

=== RTLIL netlist analysis
In Yosys, although RTLIL is used to model the netlist, the connections between cells and wires are not
immediately available for use in TaMaRa. Instead, we first perform a topological analysis of all the cells and
wires in the netlist. We consider output and input ports for cells, and also uniquely consider wires as well.
The aim is to construct a `tamara::RTLILWireConnections` object, which is a mapping between the name of a wire
or cell (which is guaranteed to be unique in an RTLIL design), and the set of wires or cells it may be
connected to on a backwards traversal. The last element is important, because this data structure also acts as
an efficient cache to use when searching the circuit on a backwards-BFS. During this step, we also construct
other similar data structures that are used to lookup `RTLIL::SigSpec` objects, which are unique in RTLIL and
can be used to represent RTL concepts like constants and wires. An example of this construction is shown in
@fig:rtlilset.

#figure(
    image("../../diagrams/rtlil_set.svg", width: 70%),
    caption: [ Demonstration of RTLILWireConnections construction ]
) <fig:rtlilset>

=== Backwards breadth-first search <sec:search>
The key step of the TaMaRa algorithm is mapping out and tracking the combinatorial logic primitives that are
located in between sequential logic primitives in a given design. This enables us to correctly replicate the
design, without introducing sequential delays that would invalidate the circuit's design. In order to achieve
this, I perform a breadth-first search (BFS) search, operating backwards _from_ the output of the circuit
_towards_ the input of the circuit. The reason we operate backwards is under the assumption that the _outputs_
of a circuit naturally depend on both the combinatorial and sequential path through the circuit; so, by
working from outputs backwards to inputs, we naturally cover only the essential circuit elements and guarantee
we won't miss anything. This is the same approach used by Beltrame @Beltrame2015.

On the backwards BFS, when we reach a flip-flop or an IO node (i.e. an input to the circuit), we wrap up the
search #footnote([This is not quite the same as terminating the search immediately; it's important that we
    consider remaining items in the BFS queue before instantly terminating the search.]) and declare the
current collected RTLIL primitives as part of a single _logic cone_.

TaMaRa's definition of a logic cone is shown in @fig:logiccone. The first combinatorial logic cone is shown in
blue, the second in green; both of these would be discovered separately by the backwards BFS.

#figure(
    image("../../diagrams/logic_cone.svg", width: 85%),
    caption: [ Description of TaMaRa's definition of logic cones ]
) <fig:logiccone>

=== Combinatorial replication
Once we have formed a logic cone, we are able to replicate all of the components inside it. This is a
relatively trivial operation and is simply a matter of using the Yosys API to instantiate two replicas for
each original node. These replicas are also marked with special TaMaRa annotations to indicate that they are
replicas, and what logic cone they belong to.

=== Voter insertion <sec:voterinsertion>
With the combinatorial primitives in the circuit replicated, the next step is to generate and insert majority
voters to vote on the redundant logic, and thereby actually implement TMR.

TaMaRa voters are always single-bit. Handling multi-bit signals is a two-stage process. Firstly, before TaMaRa
is run, the user is required to run the `splitcells` and `splitnets` commands, which break multi-bit cells and
multi-bit wires respectively into multiple single-bit instances. Whilst this handles most of the internals of
the circuit, the inputs/outputs to the circuit will still be multi-bit. For example, consider a module with an
`input logic [3:0] a`; the port `a` will still be 4-bits wide. To work with this, the voter generator is able
to split apart these multi-bit signals and attach a unique voter for each bit. When these chains are built,
the voter builder dynamically inserts a Yosys `$reduce_or` cell to OR together all the error signals from all
voters. The voter builder is able to detect when this cell is necessary or not, and if it's not necessary,
emits a `$buf` cell to improve PPA.

For multi-cone designs, the voter builder is also capable of building a tree structure of OR gates to bubble
up the individual voter error signals to a global error signal. It is worth noting that this tree-like
structure will significantly increase the combinatorial critical path delay of the circuit, and it would be
better replaced with more optimal structures in future work.

On any given logic cone, we define the "voter cut point" to be the location in the logic cone netlist where we
should splice the circuit and insert the majority voter. Currently, TaMaRa determines the voter cut point
during the backwards BFS. It is set to be the first node encountered on the backwards BFS that fulfills the
following criteria:
- It is not the very first node in the entire backwards BFS (i.e. this would be the output cell); and
- It is not a _terminal node_ (i.e. not an `IONode` or an `FFNode`); and
- It is not an `ElementWireNode`

The voter cut point is set once and only once per node. Once it is set, it's not immediately used by the
backwards BFS, but rather passed onto the wiring stage for later use.

// NOTE: Originally I said here we should have a show result of the OR tree chain, but I think that's broken
// rn

=== Wiring <sec:wiring>
The most complex (and error prone) element of the TaMaRa algorithm is, by far, the wiring logic. As a
generalised representation of RTL at various stages of synthesis, RTLIL is extremely complex. Handling
complex, recurrent, multi-bit circuits with elements like bit-selects, slicing and splicing is very
challenging. TaMaRa approaches this on a "best effort" basis, but is currently unable to handle all wiring
types present in Yosys. In essence, the wiring logic is similar to performing "surgery" on the circuit;
cutting and splicing complicated RTLIL primitives that can be challenging to re-attach correctly. The wiring
logic remains the single biggest limitation in the TaMaRa algorithm, and is often the sole reason that more
complex circuits cannot yet be processed.

The first step of the wiring process is to insert the majority voter, which was covered separately in the
prior section @sec:voterinsertion. Specifically, the voter cut point is determined from the earlier backwards
BFS stage, and a procedure
#footnote([
    It should be noted that this procedure is one of the largest causes of errors and other crashes in circuit
    processing, and should likely be overhauled in future work.
])
is used to extract the correct wires from replicated elements in the circuit to
use as the `A`, `B`, `C`, `OUT` and `ERR` ports of the voter. This is then passed to the voter inserter to
insert directly into the circuit.

Once the voter has been inserted, and holding a reference to the RTLIL output wire of the circuit, the set of
RTLIL `SigSpec`s attached to the output wire are located. This is mainly used to determine if multiple wires,
bits, chunks or other similarly complex RTLIL primitives are attached to the wire. If there is only one single
`SigSpec` attached, then wiring logic "stitches together" the voter output port directly to the original
circuit. If there are multiple `SigSpecs`s, then the wiring logic finds the `SigSpec`s that are attached to
the _output_ of the voter on the _original_ circuit before modification. Then, it stitches together this
original `SigSpec` and the rest of the circuit. This is a very large (and poor) assumption, so we also warn
the user if our assumptions do not hold; for example, if there are _multiple_ `SigSpec`s originally attached
to the voter output wire, which is currently not handled.

// NOTE: Originally I said we should have a decision tree here, but I don't think it's necessary as it'd only
// have two branches anyway

=== Wiring fix-up <sec:wiringfixup>
TaMaRa's wiring logic currently cannot handle the entire circuit in a single pass. Hence, TaMaRa wiring cannot
simply be done in a single stage. Instead, a multi-stage process was developed that uses a second pass to
detect and "fix-up" cases of invalid wiring. This is achieved by sub-classing a `tamara::FixWalker` interface,
which is in turn processed by a `tamara::FixWalkerManager`. This utility walks the RTLIL circuit using the
visitor pattern @Gamma1994, and invokes methods on the `tamara::FixWalker` accordingly.

At present, the main problem to fix up is situations in which cells can have multiple drivers. This occurs
when replicating wires connecting the cells. A second pass is necessary in order to correctly connect the
replicated wires to the replicated cells. This special case is detected by a `tamara::FixWalker` instance that
specifically looks for cells:
- Which are driven by 3 wires; and
- Which drive 3 wires; and
- Where each of the driven wires have a `(* tamara_cone *)` annotation (i.e. they have been replicated by
  TaMaRa); and
- Where each of the driver wires have a `(* tamara_cone *)` annotation

@fig:fixwalkerbefore shows the schematic of a circuit before the multi-driver fixer described above was run.
From the schematic, it is clear that the `ff` wire has multiple drivers, and drives multiple cells.

#figure(
    image("../../diagrams/schematics/fix_walker_before.svg"),
    caption: [ Schematic of circuit before running the multi-driver fixer ]
) <fig:fixwalkerbefore>

After running the multi-driver fixer, @fig:fixwalkerafter shows that the multi-driver cell has been detected
and repaired successfully.

#figure(
    image("../../diagrams/schematics/fix_walker_after.svg"),
    caption: [ Schematic of circuit after running the multi-driver fixer ]
) <fig:fixwalkerafter>


=== Search continuation
For multi-cone circuits with more than one logic cone between the inputs and outputs, the algorithm needs to
continue analysing the circuit. During the search stage as described in @sec:search, there is an additional
step where the TaMaRa algorithm checks for successor logic cones and therefore if a continued search is
required.

During the search, if the input node of a logic cone is connected to other cells, and those cells have not yet
been explored as part of a previous search, then the input node is added to a queue of successor nodes. These
successor nodes are searched using exact same process, essentially taking the algorithm back to @sec:search,
and repeating until no more successor nodes remain (i.e. the input of the circuit is reached). This is further
illustrated in @fig:searchcontinuation.

A global set of successor nodes that have been already explored is maintained, so that recurrent circuits do
not produce infinite searching loops.

#figure(
    image("../../diagrams/search_continuation.svg", width: 85%),
    caption: [ Demonstration of search continuation for two circuits ]
) <fig:searchcontinuation>

=== Summary
In summary, the algorithm can be briefly described as follows:

1. Analyse the RTLIL netlist to generate `tamara::RTLILWireConnections` mapping; which is a mapping between an
    RTLIL Cell or Wire and the other Cells or Wires it may be connected to.
2. For each output port in the top module:
    1. Perform a backwards breadth-first search through the RTLIL netlist to form a logic cone
    2. Replicate all combinatorial RTLIL primitives inside the logic cone
    3. Generate and insert the necessary voter(s) for each bit
    4. Wire up the newly formed netlist, including connected the voters
3. Perform any necessary fixes to the wiring, if required
4. With the initial search complete, compute any follow on/successor logic cones from the initial terminals
5. Repeat step 2 but for each successor logic cone
6. Continue until no more successors remain

#figure(
    image("../../diagrams/algorithm.svg", width: 85%),
    caption: [ Logic flow of the TaMaRa TMR algorithm ]
) <fig:algodiagram>

In general, the TaMaRa code is designed to be robust to any and all user inputs, and easy to debug when the
algorithm does not work as expected. This is achieved by a combination of detailed, friendly error reporting
and copious `assert` statements available in debug builds. For example, if a user specifies an error port
marked `(* tamara_error_sink *)` that is multi-bit, which is not supported, TaMaRa will print an error
explaining this in detail. The algorithm also performs self-checking using `assert` statements throughout the
process to catch internal errors that may occur.

The friendly error reporting is designed as a "first line of defence" for the most common user errors, and the
addition of asserts plays an important role in debugging end user crashes. Ideally, TaMaRa will rather crash
then generate an impossible design. All of this combines together to hopefully make a tool that users can be
confident deploying in rad-hardened, safety critical scenarios.

== Verification <section:verification>
Due to its potential for use in safety critical sectors like aerospace and defence, comprehensive verification
and testing of the TaMaRa flow is extremely important in this thesis. We want to verify to a very high level
of accuracy that TaMaRa both works by preventing SEUs to an acceptable standard, and also does not change the
underlying behaviour of the circuits it processes.

TaMaRa is a highly complex project that, during the course of this one year thesis, developed into a
substantial and complicated codebase. Not only is the TaMaRa algorithm itself complex, but it is also
dependent on top of the very complex Yosys codebase. In addition, the very process of EDA synthesis is highly
non-trivial; in some ways, akin to writing a compiler. This means that an extensive verification methodology
is required not just as a once-off, but throughout development.

To ensure this verification could be achieved, I implemented a regression test suite, which is common in
large-scale software projects. The regression test script is written in Python, and reads the list of tests to
run from a YAML document. This script is capable of running both Yosys script tests as well as formal
equivalence checking tests using the `eqy` tool. The script also keeps track of prior results and recently
failed tests, so that regressions can be easily detected. This tool was an essential part of the TaMaRa
development process, as it allowed major refactors to be performed without the worry of breaking any prior
tests.

=== Manual verification
The design and use of RTL testbenches has, and continues to be important when designing FPGA and ASIC
projects. Likewise, RTL testbenches are very important when designing EDA tools. Compared to FPGA/ASIC design,
when working on EDA tools, having a representative sample of a large number of projects is the most important
aspect. For TaMaRa, I sourced a number of representative small open-source Verilog projects with acceptable
licences for inclusion in the `test` directory. These designs include:
- Various cyclic redundancy check (CRC) calculators of varying bit-depths
    - Tests TaMaRa's handling of combinatorial circuits
- Small RISC-V CPUs: picorv32, femtorv32, minimax, Browndeer Technologies' rv8
    - CPUs are highly representative of large Verilog projects, and include complex combinatorial and
        sequential circuits

In addition, I also wrote a number of much smaller testbenches to target specific bugs or specific features in
TaMaRa. These were very important in the initial development and verification of the algorithm, as their tiny
size allowed for visual debugging using Yosys' `show` command. These circuits are documented in full in
@sec:testbenchsuite.

=== Formal verification <section:formalverif>
For TaMaRa specifically, formal verification is abstracted through the use of Yosys' `miter` and `sat`
commands. Yosys' built-in SAT solver is based on MiniSAT @Sorensson2005, which is a widely-used and powerful
SAT solver, although is not as powerful as SMT solvers. Nonetheless, it suffices for these small test
circuits. Yosys also features a `mutate` command that was originally written to verify the correctness of
self-checking testbenches. Essentially, it statically injects various types of faults, including SEU
equivalents, into the design's netlist, which is then usually used to prove that the testbench fails when the
circuit is modified. This is repurposed for a similar use-case in TaMaRa, to instead prove that faults are
mitigated when the circuit is processed through the algorithm.

Formal equivalence checking is used in the TaMaRa verification flow to formally prove (for specific circuits,
at least) that the tool holds up two of its key guarantees: that it does not change the underlying behaviour
of the circuit during processing, and that it actually protects the circuit from SEUs. We could also check
this using testbenches, or for simple combinatorial circuits by comparing the truth table manually, but
SAT-based formal equivalence is actually easier to implement, and provides significantly stronger proofs of
correctness. If the formal equivalence check passes, we can be absolutely certain that the behaviour of the
circuit has not changed, for all possible inputs; and for sequential circuits, for all possible inputs _and_
all possible states the circuit may be in.
#footnote([Although, it should be noted that there are specific constraints with Yosys' `sat` solver in
    regards to the number of clock cycles it considers when proving sequential circuits.])

The first guarantee, that the TaMaRa algorithm does not change the behaviour of the circuit, can be verified
directly by using the formal equivalence checker and SAT solver. However, verifying the second guarantee -
that TaMaRa actually protects against SEUs - is more challenging. To do this, I devised a method that combines
the `mutate` command with the equivalence checker. The _gold_ circuit (the circuit to be verified against) is
set to be the original design, with no faults and no TaMaRa replicas. The _gate_ circuit (the circuit that is
being verified) is set to the original circuit, with TaMaRa replicas, and then with a certain number of
mutations. This methodology operates under the realisation that if the _gate_ correctly masks faults using its
voter, then should then have the same behaviour as the _gold_ circuit, and thus be equivalent. This is shown
below in @fig:verification.

#figure(
    image("../../diagrams/verification.svg", width: 60%),
    caption: [ Diagram of TaMaRa verification methodology ]
) <fig:verification>

=== RTL fuzzing techniques
As mentioned in @section:rtlfuzz, RTL fuzzing is an emerging technique for generating large-scale coverage of
Verilog design files for EDA tools. Hence, part of the TaMaRa verification flow involves using Verismith
@Herklotz2020  to generate small random Verilog designs, and running TaMaRa end-to-end on these designs.
Initially, we will be looking for crashes, assert failures and memory errors using AddressSanitizer, but later
we will also use Yosys' eqy tool to prove that the designs stay the same before and after TaMaRa runs. Using
the GNU Parallel tool, this work can be trivially distributed across multiple cores. Running TaMaRa with the
Verismith fuzzer on 8192 small designs takes around 5 minutes on an AMD Ryzen 9 5950X workstation.

To simplify the above, a shell script was developed to run this process end-to-end, and automatically clean up
tests that did not fail; leaving only failed tests left over. With automatic timestamped directories, this is
potentially a tool that could run as part of a continuous integration (CI) workflow for automatic validation.
