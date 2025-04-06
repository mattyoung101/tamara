#import "../../util/macros.typ": *

= Methodology <chap:method>
== Concept
In the previous @chap:lit, I presented a comprehensive literature review of existing automated TMR approaches.
One of the main limitations that these algorithms have is that none are specifically integrated into the Yosys
synthesis tool. I envision TaMaRa as a platform that provides a baseline TMR implementation that other
researchers can extend upon, and that industry users can experiment with, all the while supported both
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
gates, etc) instead of vendor-specific FPGA primitives like LUTs.
#TODO("whatever the solution for this is")

Whilst TaMaRa aims to be compatible with all existing designs with minimal changes, some preconditions are
necessary for the algorithm to process the circuit correctly.

Since the algorithm wants to work with all possible circuits, it cannot predict what the end user wants to do
with the voter error signal (if anything). As discussed in the literature review, the typical use case for the
error signal is to perform configuration scrubbing when upsets are detected. This, however, is a highly
vendor-specific process for FPGAs, and is not at all possible on ASICs. As TaMaRa targets FPGAs from any
vendor, and ASICs as well, a more general approach is necessary. To solve this problem, TaMaRa does not aim to
provide configuration scrubbing directly, instead leaving this for the end user. Instead, the end user can
attach an HDL annotation to indicate an output port on a module that TaMaRa should wire a global voter error
signal to. In SystemVerilog, this uses the `(* tamara_error_sink *)` annotation, as shown in @lst:errorsink:

#figure(
    ```systemverilog
    module my_module(
        input logic a,
        (* tamara_error_sink *)
        output logic err
    );
    ```,
    caption: [ SystemVerilog snippet demonstrating the use of the `(* tamara_error_sink *)` annotation ]
) <lst:errorsink>

End users are then free to implement configuration scrubbing using the tool and methodology appropriate to
their platform.

Additionally, while TaMaRa aims to require minimal or no changes to the circuit itself, there are changes
necessary to the synthesis pipeline. Unlike in normal Yosys synthesis scripts, the design cannot be lowered
directly to FPGA/ASIC primitives (LUTs, standard cells, etc). It first needs to be lowered to abstract logic
primitives (AND gates, NOT gates, etc) that TaMaRa can process, particularly, that it can generate voter
circuits in. Then, TaMaRa can be run, after which the design can be lowered to FPGA primitives or ASIC
standard cells. TaMaRa currently also requires the user to run the `splitcells` and `splitnets` commands
before it is invoked to split apart multi-bit buses and cells, which are not yet directly supported.

== Implementation
Over the course of this thesis, TaMaRa was successfully written from the ground up as a Yosys plugin. This
plugin consists of around 2,300 lines of C++20, and introduces one new command to Yosys: `tamara_tmr`.

TaMaRa is currently designed to only operate on one module, that being the top module. This is typical of
space applications. For example, consider a Verilog top module called `cpu_top` that contains a 32-bit RISC-V
CPU, along with its register file, ALU, memory and instruction decoder. To ensure full rad-hard reliability in
space, the whole `cpu_top` module needs to be triplicated. However, in the future, it would be a nice feature
to be able to have finer grained control over the parts of the design are triplicated. This does unfortunately
introduce some significant problems that will be elaborated on later.

=== TaMaRa TMR algorithm implementation
#figure(
    image("../../diagrams/classdiagram.svg"),
    caption: [ Class diagram of the TaMaRa codebase ]
) <fig:classdiagram>

TaMaRa consists of multiple C++ classes (@fig:classdiagram). Broadly speaking, these classes combine together
to form the following algorithm. This is also shown in @fig:algodiagram.

*RTLIL netlist analysis*

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

*Backwards breadth-first search*

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

*Combinatorial replication*

Once we have formed a logic cone, we are able to replicate all of the components inside it. This is a
relatively trivial operation and is simply a matter of using the Yosys API to instantiate two replicas for
each original node. These replicas are also marked with special TaMaRa annotations to indicate that they are
replicas, and what logic cone they belong to.

*Voter insertion*

With the combinatorial primitives in the circuit replicated, the next step is to generate and insert majority
voters to vote on the redundant logic, and thereby actually implement TMR. In the very beginning, the voter
circuit was designed manually; first by sketching the truth table by hand, then automatically converting this
to a logic schematic using Logisim @Burch2024. The Logisim circuit was then transformed manually into a series
of C++ macros that build an equivalent circuit in RTLIL. A formal equivalence check was performed between this
RTLIL design and the original truth table sketched by hand, which was correct.

#TODO("could we please be allowed a code snippet here to show this")

TaMaRa voters are always single-bit. Handling multi-bit signals is a two-stage process. Firstly, before TaMaRa
is run, the user is required to run the `splitcells` and `splitnets` commands, which break multi-bit cells and
multi-bit wires respectively into multiple single-bit instances. Whilst this handles most of the internals of
the circuit, the inputs/outputs to the circuit will still be multi-bit. For example, consider a module with an
`input logic [3:0] a`; the port `a` will still be 4-bits wide. To work with this, the voter generator is able
to split apart these multi-bit signals and attach a unique voter for each bit.

- Use `$reduce_or` to collapse multi-bit OR signals into one-bit
- Dynamically build OR chains to chain multiple logic cones together to vote on

#TODO("Yosys 'show' result of VoterBuilder OR chain and $reduce_or")

*Wiring*

The most complex element of the TaMaRa algorithm is, by far, the wiring logic. As a generalised
representation of RTL at various stages of synthesis, RTLIL is extremely complex. Handling complex, recurrent,
multi-bit circuits with elements like bit-selects, slicing and splicing is very challenging.

- We need to figure out how our actual hodge-podge wiring code works and put it in here

*Wiring fix-up*

TaMaRa's wiring logic is so complicated that often, it produces errors. Hence, TaMaRa wiring cannot simply be
done in a single stage. Instead, a multi-stage process was developed that uses a second pass to detect and
"fix-up" cases of invalid wiring.

*Search continuation*

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

=== Software engineering considerations
TaMaRa is a highly complex project that, during the course of this one year thesis, developed into a
substantial and complicated codebase. Far from just being a research project, this thesis is also a software
engineering project as well. This means that, in addition to the usual research considerations, there are also
a number of software engineering considerations that are noted here.

The TaMaRa algorithm itself is complex, and it builds on top of the very complex Yosys codebase. In addition,
the very process of EDA synthesis is highly non-trivial; akin to writing a compiler. This means that an
extensive verification methodology is required not just as a once-off, but throughout development. While the
verification methodology is covered throughout @section:verification, there are some important software
engineering considerations about _how_ this was implemented.

In particular, I implemented a regression test suite, which is common in large-scale software projects. The
regression test script is written in Python, and reads the list of tests to run from a YAML document. This
script is capable of running both Yosys script tests as well as formal equivalence checking tests using the
`eqy` tool. The script also keeps track of prior results and recently failed tests, so that regressions can be
easily detected. This tool was an essential part of the TaMaRa development process, as it allowed major
refactors to be performed without the worry of breaking any prior tests.

Another issue that was encountered during the development of TaMaRa was the problems associated with
maintaining a codebase over a long-term period.

#TODO("")
- Poor design decisions that we had initially (RTLILWireConnections)
- Not using SigSpec

== Verification <section:verification>
Due to its potential for use in safety critical sectors like aerospace and defence, comprehensive verification
and testing of the TaMaRa flow is extremely important in this thesis. We want to verify to a very high level
of accuracy that TaMaRa both works by preventing SEUs to an acceptable standard, and also does not change the
underlying behaviour of the circuits it processes.

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
size allowed for visual debugging using Yosys' `show` command. For example, one of the most important tests
was `not_dff_tmr.sv`, a simple NOT-gate into a D-flip-flop, whose SystemVerilog code is shown in
@lst:notdfftmr.

#figure(
    ```systemverilog
    (* tamara_triplicate *)
    module not_dff_tmr(
        input logic a,
        input logic clk,
        output logic o,
        (* tamara_error_sink *)
        output logic err
    );

    logic ff;

    always_ff @(posedge clk) begin
        ff <= a;
    end

    assign o = !ff;

    `ifndef TAMARA
    assign err = 0;
    `endif

    endmodule
    ```,
    caption: [ SystemVerilog source code for `not_dff_tmr`, a key initial testbench ]
) <lst:notdfftmr>

=== Formal verification
For TaMaRa specifically, formal verification is abstracted through the use of Yosys' `eqy` tool, and by
extension its usage of the `sby`(SymbiYosys) tool. `eqy` is used for formal equivalence checking between two
circuits, and is responsible for partitioning the input circuit to a form suitable for equivalence checking.
This is then sent on to `sby`, which in turn transforms the circuit into a suitable SMT proof for an SMT
solver. TaMaRa was going to use the Bitwuzla @Niemetz2023 solver, but due to upstream issues with both Yosys
and Bitwuzla, settled for using the industry standard Yices @Dutertre2014, which is quite fast. Yosys also
features a `mutate` command that was originally written to verify the correctness of self-checking
testbenches. Essentially, it injects faults into a design and verifies that the self-checking testbench
correctly flags these mutated designs as invalid.

The purpose of applying equivalence checking to the TaMaRa verification flow is to formally prove (for
specific circuits, at least) that the tool holds up two of its key guarantees: that it does not change the
underlying behaviour of the circuit during processing, and that it actually protects the circuit from SEUs. We
could also check this using testbenches, or for simple combinatorial circuits by comparing the truth table
manually, but SMT-based formal equivalence checking supports all circuit types and is more robust and
reliable. If the formal equivalence check passes, we can be absolutely certain that the behaviour of the
circuit has not changed, for all possible inputs; and for sequential circuits, for all possible inputs _and_
all possible states.

The first guarantee, that the TaMaRa algorithm does not change the behaviour of the circuit, can be verified
directly by using the formal equivalence checker and SMT solver. However, verifying the second guarantee -
that TaMaRa actually protects against SEUs - is more challenging. To this, I devised a method that combines
the `mutate` command with the equivalence checker. The _gold_ circuit (the circuit to be verified against) is
set to be the original design, with no faults and no TaMaRa replicas. The _gate_ circuit (the circuit that is
being verified) is set to the original circuit, with TaMaRa replicas, and then with a certain number of
mutations. This methodology operates under the realisation that if the replicated circuit correctly masks
faults, it should then also have the same behaviour as the non-replicated circuit minus the faults.

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
