#import "@preview/cetz:0.3.2"
#import "@preview/cetz-plot:0.1.1"
#import "../../util/macros.typ": *

// needed to break tables across pages
// https://github.com/typst/typst/issues/977#issuecomment-2233710428
#show figure: set block(breakable: true)

= Results and Discussion <chap:results>
== Testbench suite <sec:testbenchsuite>
In order to test the TaMaRa algorithm, a number of SystemVerilog testbenches implementing various different
types of circuits were designed. This section will detail the testbench suite in full. In each of the
selections below, the attached table shows the circuit name, the SystemVerilog RTL describing the circuit, and
its schematic after running a standard Yosys synthesis script.

This list approaches circuits in their order of complexity: first starting with simple, single-bit
combinational circuits, and then progressing up to advanced, multi-bit, multi-cone, recurrent, sequential
circuits. This was also the order in which the TaMaRa algorithm was verified: starting with small, simple
circuits, and progressing to complex ones, verifying incrementally along the way.

=== Combinational circuits
The simplest type of digital circuit is a single-bit, purely combinational one. @tab:combinational lists these
single-bit combinational circuits. These were critical for initial, early implementation of the TaMaRa
algorithm, as their small size allowed for visual debugging using the Yosys `show` tool.

#figure(
  table(
    columns: 3,
    align: horizon,
    stroke: 0.5pt,
    [*Name*],
    [*SystemVerilog RTL*],
    [*Synthesised schematic*],
    [not],
    [
      ```systemverilog
    module inverter(
        input logic a,
        output logic o,
        (* tamara_error_sink *)
        output logic err
    );
    assign o = !a;
    endmodule
      ```
    ],
    [
      #image("../../diagrams/schematics/not.svg")
    ],
    [not\_slice],
    [
    ```systemverilog
    module not_slice(
        input logic a,
        input logic b,
        output logic[1:0] out,
        (* tamara_error_sink *)
        output logic err
    );
        assign out = { !a, !b };
    endmodule
    ```
    ],
    [
      #image("../../diagrams/schematics/not_slice.svg")
    ],

    [not\_swizzle\_low],
    [
    ```systemverilog
    module not_swizzle_low(
        input logic a,
        output logic[1:0] out,
        (* tamara_error_sink *)
        output logic err
    );
        assign out = { !a, 1'd0 };
    endmodule
    ```
    ],
    [
      #image("../../diagrams/schematics/not_swizzle_low.svg")
    ],

    [not\_swizzle\_high],
    [
    ```systemverilog
    module not_swizzle_high(
        input logic a,
        output logic[1:0] out,
        (* tamara_error_sink *)
        output logic err
    );
        assign out = { 1'd0, !a };
    endmodule
    ```
    ],
    [
      #image("../../diagrams/schematics/not_swizzle_high.svg")
    ],

    [mux\_1bit],
    [
        ```systemverilog
      module mux_1bit(
          input logic a,
          input logic b,
          input logic sel,
          output logic o
      );
          assign o = sel ? a : b;
      endmodule
      ```
    ],
    [
        #image("../../diagrams/schematics/mux_1bit.svg")
    ],
  ),
  caption: [ Table of single-bit combinational circuit designs ]
) <tab:combinational>

=== Multi-bit combinational circuits
Once the single-bit combinational circuits were confirmed to be working, the next set of tests involved
multi-bit combinational circuits, as shown in @tab:combinationalmulti. This is useful to ensure that the voter
builder, as described in @sec:voterinsertion, correctly inserts a voter for each bit in the bus; and also that
the wiring code can handle multi-bit edge signals.

#figure(
  table(
    columns: 3,
    align: horizon,
    stroke: 0.5pt,
    [*Name*],
    [*SystemVerilog RTL*],
    [*Synthesised schematic*],
    [not\_2bit],
    [
      ```systemverilog
    module inverter(
        input logic[1:0] a,
        output logic[1:0] o,
        (* tamara_error_sink *)
        output logic err
    );
    assign o = ~a;
    endmodule
      ```
    ],
    [
      #image("../../diagrams/schematics/not_2bit.svg")
    ],

    [not\_32bit],
    [
      ```systemverilog
    module inverter(
        input logic[31:0] a,
        output logic[31:0] o,
        (* tamara_error_sink *)
        output logic err
    );
    assign o = ~a;
    endmodule
      ```
    ],
    [
      #image("../../diagrams/schematics/not_2bit.svg")
    ],

    [
        mux\_2bit
    ],
    [
        ```systemverilog
    module mux_2bit(
        input logic[1:0] a,
        input logic[1:0] b,
        input logic sel,
        output logic[1:0] o
    );
        assign o = sel ? a : b;
    endmodule
        ```
    ],
    [
        #image("../../diagrams/schematics/mux_2bit.svg")
    ],
    [
        mux\_32bit
    ],
    [
        ```systemverilog
    module mux_32bit(
        input logic[31:0] a,
        input logic[31:0] b,
        input logic sel,
        output logic[31:0] o
    );
        assign o = sel ? a : b;
    endmodule
        ```
    ],
    [
        #image("../../diagrams/schematics/mux_32bit.svg")
    ],

    [
        crc\_const\_variant3
    ],
    [
        ```systemverilog
    module crc_const_variant3(
        input logic[1:0] in,
        output logic[1:0] out
    );
        wire zero_wire = 1'b0;
        assign out = {in[0] ^ in[1], zero_wire};
    endmodule
        ```
    ],
    [
        #image("../../diagrams/schematics/crc_const_variant3.svg")
    ],

    [
        crc\_const\_variant4
    ],
    [
        ```systemverilog
    module crc_const_variant4(input logic[1:0] in, output logic[1:0] out);
        // (1'b1 - 1'b1) evaluates to 0
        assign out = {in[0] ^ in[1], (1'b1 - 1'b1)};
    endmodule
        ```
    ],
    [
        #image("../../diagrams/schematics/crc_const_variant4.svg")
    ],

    [
        crc\_const\_variant5
    ],
    [
        ```systemverilog
    module crc_const_variant5(input logic [1:0] in, output logic [1:0] out);
        // (in[1] & ~in[1]) always equals 0 regardless of in[1]
        assign out = {in[0] ^ in[1], (in[1] & ~in[1])};
    endmodule
        ```
    ],
    [
        #image("../../diagrams/schematics/crc_const_variant5.svg")
    ],
  ),
  caption: [ Table of multi-bit combinational circuit designs ]
) <tab:combinationalmulti>

=== Sequential circuits
In the previous sections, the testbenches were all combinational circuits, and did not use sequential elements
such as D-flip-flops. Combinational circuits are easy to design and especially easy to verify, but are not at
all representative of the majority of complex SystemVerilog designs. Hence, a number of sequential testbenches
are shown in @tab:sequentialcircuits.

#figure(
  table(
    columns: 3,
    align: horizon,
    stroke: 0.5pt,
    [*Name*],
    [*SystemVerilog RTL*],
    [*Synthesised schematic*],
    [not\_dff\_tmr],
    [
      ```systemverilog
    module not_dff_tmr(
        input logic a,
        input logic clk,
        output logic o,
        output logic err
    );
    logic ff = 0;

    always_ff @(posedge clk) begin
        ff <= a;
    end

    assign o = !ff;

    endmodule
      ```
    ],
    [
      #image("../../diagrams/schematics/not_dff_tmr.svg")
    ],
  ),
  caption: [ Table of sequential circuit designs ]
) <tab:sequentialcircuits>

=== Multi-cone circuits
Multi-cone circuits are indicative of the most complex, and realistic, industry designs. They consist of
multiple combinatorial sections connected by a sequential element, such as a DFF. These multi-cone designs are
shown in @tab:multiconecircuits.

#figure(
  table(
    columns: 3,
    align: horizon,
    stroke: 0.5pt,
    [*Name*],
    [*SystemVerilog RTL*],
    [*Synthesised schematic*],
    [
        cones
    ],
    [
        ```systemverilog
module cones(
    input logic a,
    input logic clk,
    output logic out
);
    logic stage1;
    logic stage2;

    always_ff @(posedge clk) begin
        stage1 <= !a;
    end

    always_ff @(posedge clk) begin
        stage2 <= !stage1;
    end

    assign out = stage2;
endmodule
        ```
    ],
    [
        #image("../../diagrams/schematics/cones.svg")
    ],

    [
        cones\_min
    ],
    [
        ```systemverilog
module cones_min(
    input logic a,
    input logic clk,
    output logic out
);
    logic stage1;

    always_ff @(posedge clk) begin
        stage1 <= !a;
    end

    assign out = !stage1;
endmodule
        ```
    ],
    [
        #image("../../diagrams/schematics/cones_min.svg")
    ],

    [
        cones\_2bit
    ],
    [
        ```systemverilog
module cones_2bit(
    input logic[1:0] a,
    input logic clk,
    output logic[1:0] out
);
    logic[1:0] stage1;
    logic[1:0] stage2;

    always_ff @(posedge clk) begin
        stage1 <= ~a;
    end

    always_ff @(posedge clk) begin
        stage2 <= ~stage1;
    end

    assign out = stage2;
endmodule
        ```
    ],
    [
        #image("../../diagrams/schematics/cones_2bit.svg")
    ],
  ),
  caption: [ Table of multi-cone circuits ]
) <tab:multiconecircuits>

=== Feedback circuits
Feedback circuits are arguably the most complicated challenge for any algorithm that performs automated TMR
insertion. These designs consist of sequential circuits with logic loops that form a logical path from the
output of the circuit to the input. Without proper handling, these circuits could easily break the logic cone
identification system used in TaMaRa and other TMR-insertion algorithms. A simple feedback circuit design is
shown in @tab:feedbackcircuits.

#figure(
  table(
    columns: 3,
    align: horizon,
    stroke: 0.5pt,
    [*Name*],
    [*SystemVerilog RTL*],
    [*Synthesised schematic*],
    [
        recurrent\_dff
    ],
    [
        ```systemverilog
module recurrent_dff (
    input  logic clk,
    output logic q
);
    always_ff @(posedge clk) begin
        q <= ~q;
    end
endmodule

        ```
    ],
    [
        #image("../../diagrams/schematics/recurrent_dff.svg")
    ],

  ),
  caption: [ Table of feedback circuits ]
) <tab:feedbackcircuits>

== Processed circuits
In this section, we demonstrate the result of TaMaRa algorithm on the netlist of a simple, but representative
circuit. @fig:not2bitpretmr shows the schematic for the `not_2bit` circuit, a 2-bit multiplexer, before TMR.

#figure(
    image("../../diagrams/schematics/not_2bit.svg", width: 50%),
    caption: [ Schematic for the `not_2bit` circuit before TMR ]
) <fig:not2bitpretmr>

@fig:not2bitposttmr shows the schematic for the `not_2bit` circuit after TMR.

#figure(
    image("../../diagrams/schematics/not_2bit_tmr.svg", width: 100%),
    caption: [ Schematic for the `not_2bit` circuit after TMR ]
) <fig:not2bitposttmr>

There are several important things to note in this schematic. Firstly, and most obviously, note the large
increase in area
#footnote[Or at least, what _would_ become ASIC/FPGA area, as we are operating on a netlist.] -
TMR is a very high-area technique that more than triples the area utilisation. Observe that the `$not` cell
has been correctly triplicated, fanned out from the input `a` wire. Following that, the pink, green, and
purple cells show the unpacking of this 2-bit bus into multiple 1-bit voters, which are then stitched back
together again on the right-hand side. You will see that part of these signals go directly to the output `o` -
which is now the corrected and voted upon output. Some signals continue on to a `$reduce_or` cell, which
performs a bitwise-OR upon all error signals, and routes this to the output `err` signal. Importantly, observe
in @fig:not2bitpretmr that in the original circuit, this `err` signal was completely unconnected - TaMaRa has
both generated the error signal logic, and connected it up successfully.

Although, as will be covered later in this section, there is some trouble formally verifying circuits that use
DFFs, it is still possible to process them successfully with the TaMaRa algorithm. @fig:notdfftmr_schematic
shows the schematic of a simple circuit using a DFF and a NOT gate, before TMR, and
@fig:notdfftmr_schematic_after shows the same circuit after TMR processing. In this example, note the
triplication of _both_ the DFF and the NOT gate, and the successful connection between the two.

#figure(
    image("../../diagrams/schematics/not_dff_tmr.svg", width: 70%),
    caption: [ Schematic for the `not_dff_tmr` circuit before TMR ]
) <fig:notdfftmr_schematic>

#figure(
    image("../../diagrams/not_dff_tmr.svg", width: 100%),
    caption: [ Schematic for the `not_dff_tmr` circuit after TMR ]
) <fig:notdfftmr_schematic_after>

== Formal verification
=== Equivalence checking
To ensure the reliability of the algorithm, an attempt was made to perform formal equivalence checking on all
of the combinational circuits. As of writing, there are 20 equivalence checks performed in total.

The follow circuits passed the equivalence check:

`not_2bit, not_32bit, not_tmr, voter, crc_min, crc_const_variant3, crc_const_variant4, crc_const_variant5,`
`mux_1bit, mux_2bit, bug7, not_swizzle_low, not_swizzle_high`

The following circuits failed the equivalence check:

`crc2, crc4, crc6, crc7, crc8, crc16, not_slice`

The reasons for these failures are covered later in the thesis, but in short are known faults in the current
implementation of the TaMaRa algorithm. For more info, see @tab:bugs.

== Fault injection
I propose three main classes of fault injection studies. In the first class of tests, known as "Protected
voter tests", the voter circuit itself is ignored and not subject to faults. Whilst this is unrepresentative
of real-world faults, it enables us to explore the validity of the voter circuit on its own. Particularly, it
enables us to formally verify that the voter is able to protect a given circuit against a wide variety of
faults, and to understand how many faults this is before the test fails. In the second class of tests, known
as "Unprotected voter tests", we inject faults into the entire circuit, including potentially into the voter.
In the third and final class of tests, known as "Unmitigated tests", we do not apply any TMR at all, which is
useful as a baseline control to compare against.

@fig:mutation demonstrates the effects of fault injection, showing the circuit `not_tmr` with a single fault injected
after TMR. The fault is highlighted in red.

#figure(
  image("../../diagrams/mutation.svg", width: 100%),
  caption: [ Result of applying a mutation (SEU) to the `not_tmr` circuit ]
) <fig:mutation>

In this case, the `mutate` command has randomly chosen to insert an additional inverter after the triplicated
`$not` gate in the original circuit, but before the voter. This is a formal simulation of an SEU that could
then be corrected by the voter circuit. The `mutate` command has many different faults it can inject to
simulate SEUs, including "stuck-at-0" or "stuck-at-1" situations, in addition to inverters.

Due to the stochastic nature of this process, multiple samples of each fault are taken and the mean mitigation
rate is calculated. In this case, I perform 100 samples for each number (i.e. 100x 1 fault, 100x 2 faults,
100x 3 faults, etc).

=== Protected voter
@tab:faultinjectprotected presents the results for this protected voter fault-injection study. As the fault
injection process is stochastic, it uses a sample of 100 runs per fault. The circuits listed in this table
correspond to the suite of circuits presented in @tab:combinational, after they have been processed end-to-end
correctly by the TaMaRa algorithm.

#figure(
  table(
    columns: 2,
    align: horizon,
    stroke: 0.5pt,
    [*Circuit name*],
    [*Fault injection results*],
    [
        not\_tmr
    ],
    [
        #image("../../diagrams/fault_protected_not_tmr.svg", width: 60%)
    ],

    [not\_2bit],
    [
      #image("../../diagrams/fault_protected_not_2bit.svg", width: 60%)
    ],

    [not\_32bit],
    [
      #image("../../diagrams/fault_protected_not_32bit.svg", width: 60%)
    ],

    [
        mux_1bit
    ],
    [
        #image("../../diagrams/fault_protected_mux_1bit.svg", width: 60%)
    ],

    [
        mux_2bit
    ],
    [
        #image("../../diagrams/fault_protected_mux_2bit.svg", width: 60%)
    ],

    [
        mux_32bit
    ],
    [
        #image("../../diagrams/fault_protected_mux_32bit.svg", width: 60%)
    ],

    [
        not_swizzle_low
    ],
    [
        #image("../../diagrams/fault_protected_not_swizzle_low.svg", width: 60%)
    ],

    [
        not_swizzle_high
    ],
    [
        #image("../../diagrams/fault_protected_not_swizzle_high.svg", width: 60%)
    ],
    [
        crc_const_variant3
    ],
    [
        #image("../../diagrams/fault_protected_crc_const_variant3.svg", width: 60%)
    ],
    [
        crc_const_variant4
    ],
    [
        #image("../../diagrams/fault_protected_crc_const_variant4.svg", width: 60%)
    ],
    [
        crc_const_variant5
    ],
    [
        #image("../../diagrams/fault_protected_crc_const_variant5.svg", width: 60%)
    ],
  ),
  caption: [ Protected voter fault injection study results ]
) <tab:faultinjectprotected>

@fig:allprotectedcomb shows the combined results of all combinational circuits under protected voter fault
injection tests.

#figure(
    image("../../diagrams/all_comb_prot.svg", width: 80%),
    caption: [ Comparison of all results for protected voter combinational circuits ]
) <fig:allprotectedcomb>

Generally, all circuits follow roughly the same inverse logarithmic curve, and are within a few percentage
points of each other. All tested circuits are able to mitigate 100% of injected faults when one fault is
injected, which proves the voter is functioning as designed in isolation. With two injected faults, the
effectiveness ranges between roughly 40% and 75%, with `not_swizzle_low` performing the worst, and `mux_2bit`
and `not_2bit` performing the best. Interestingly, the only outliers here are the two 32-bit circuits:
`not_32bit` and `not_2bit`, which do not have an inverse logarithmic curve, rather an almost linear curve
that's significantly better than all of the other circuits. To investigate further, I performed a sweep of
fault-injection tests with a 1-bit, 2-bit, 4-bit, 8-bit, 16-bit, 24-bit and 32-bit multiplexer respectively,
which is shown in @fig:muxbitsweep.

#figure(
    image("../../diagrams/mux_bit_sweep_prot.svg", width: 80%),
    caption: [ Sweep of fault-injection tests on differing-width multiplexers, protected voters ]
) <fig:muxbitsweep>

This result shows that wider circuits are more resilient with protected voters. Lower bit-count circuits
follow the standard inverse-logarithmic decay as seen in the majority of circuits in @fig:allprotectedcomb,
but higher bit-count circuits are more linear (particularly observe `mux_32bit`). The exact reasoning why this
is the case is not immediately clear, but very likely this is due to the fact that the `splitnets` command
used in the synthesis script extracts multi-bit buses into individual cells, creating more area on the netlist
for faults to be injected into, rather than accumulating in a single spot.

=== Unprotected voter
While the protected voter study in the prior section is useful for verifying the correctness of the voter
circuit itself, it is not representative of real-world fault scenarios. In the unprotected voter studies, we
subject the entire netlist to faults, including the voter circuit.

The Yosys script used to run these tests was the same, except that the statements to select only voters were
removed. Results for this set of tests are shown in @tab:faultinjectunprotected. The process remains
stochastic, and the same parameters as in the protected voter experiments were used (100 samples per fault).

#pagebreak()

#figure(
  table(
    columns: 2,
    align: horizon,
    stroke: 0.5pt,
    [*Circuit name*],
    [*Fault injection results*],
    [
        not\_tmr
    ],
    [
        #image("../../diagrams/fault_unprotected_not_tmr.svg", width: 60%)
    ],

    [not\_2bit],
    [
      #image("../../diagrams/fault_unprotected_not_2bit.svg", width: 60%)
    ],

    [not\_32bit],
    [
      #image("../../diagrams/fault_unprotected_not_32bit.svg", width: 60%)
    ],

    [
        mux_1bit
    ],
    [
        #image("../../diagrams/fault_unprotected_mux_1bit.svg", width: 60%)
    ],

    [
        mux_2bit
    ],
    [
        #image("../../diagrams/fault_unprotected_mux_2bit.svg", width: 60%)
    ],

    [
        mux_32bit
    ],
    [
        #image("../../diagrams/fault_unprotected_mux_32bit.svg", width: 60%)
    ],

    [
        not_swizzle_low
    ],
    [
        #image("../../diagrams/fault_unprotected_not_swizzle_low.svg", width: 60%)
    ],

    [
        not_swizzle_high
    ],
    [
        #image("../../diagrams/fault_unprotected_not_swizzle_high.svg", width: 60%)
    ],

    [
        crc_const_variant3
    ],
    [
        #image("../../diagrams/fault_unprotected_crc_const_variant3.svg", width: 60%)
    ],
    [
        crc_const_variant4
    ],
    [
        #image("../../diagrams/fault_unprotected_crc_const_variant4.svg", width: 60%)
    ],
    [
        crc_const_variant5
    ],
    [
        #image("../../diagrams/fault_unprotected_crc_const_variant5.svg", width: 60%)
    ],
  ),
  caption: [ Unprotected voter fault injection study results ]
) <tab:faultinjectunprotected>

@fig:allunprotectedcomb shows the combined results of all combinational circuits under unprotected voter fault
injection tests.

#figure(
    image("../../diagrams/all_comb_unprot.svg", width: 80%),
    caption: [ Comparison of all results for unprotected voter combinational circuits ]
) <fig:allunprotectedcomb>

In this case, rather than being an inverse logarithmic curve, all tests have a very sharp fall-off in the
percentage of mitigated faults, even between one and two faults. Note that, even in the case of one fault,
only between 50% and 60% of faults were mitigated, and this declines sharply to between roughly 5% and 15% at
two faults. Although this is an unfortunate result, as will be covered in @sec:analysis, the voter takes up
the vast majority of the circuit area in these tests, meaning it's much more likely to be the target of
faults, so this result does make sense on this test suite. Nonetheless, there's clear room for improvement in
the algorithm here.

Also interesting to note is that, unlike in @fig:allprotectedcomb with the protected voters, these results are
all largely the same across all circuits. We do not see see any differences between 32-bit and 1-bit circuits
in their effectiveness at mitigating faults. To investigate this further, I performed the same multiplexer
sweep as before, but using unprotected voters, which is shown below in @fig:muxbitsweepunprot.

#figure(
    image("../../diagrams/mux_bit_sweep_unprot.svg", width: 70%),
    caption: [ Sweep of fault-injection tests on differing-width multiplexers, unprotected voters ]
) <fig:muxbitsweepunprot>

// not exactly sure why this occurs? if i knew i'd write about it :/

=== Multi-TMR
As we have seen in the prior sections, a serious issue with TMR setups is that the voters themselves can be
subject to SEUs. As long as the voter occupies area on the circuit die, it will always be a target of SEUs.
Nevertheless, it is possible (in theory) to reduce the probability that a bit strikes and disables a voter, by
triplicating the voter itself. This is commonly done in highly safety-critical scenarios such as spaceflight
computing, as it increases area cost immensely but does help to protect the circuit.

As a general purpose algorithm, TaMaRa does support this - quite simply in fact - by running the `tamara_tmr`
command twice in a row. This will triplicate the circuit, and then triplicate it once more. To demonstrate
this, @fig:mux1bittmr shows the `mux_1bit` circuit with one round of triplication, and @fig:mux1bitmultitmr
shows the result of triplicating it twice. Observe the very large area increase, as each voter is voted on
itself by another voter.

#figure(
    image("../../diagrams/mux_1bit_tmr.svg", width: 70%),
    caption: [ Application of TaMaRa TMR once to the mux\_1bit circuit ]
) <fig:mux1bittmr>

#figure(
    image("../../diagrams/mux_1bit_tmr_multi.svg", width: 100%),
    caption: [ Application of TaMaRa TMR twice to the mux\_1bit circuit ]
) <fig:mux1bitmultitmr>

Next, to determine if this actually has any effectiveness on the reliability of the circuit, the previous
fault-injection tests were run on the `mux_1bit` circuit. @fig:muxltiunprot compares the reliability of the multi-TMR
circuit to a regular TMR circuit.

#figure(
    image("../../diagrams/multi_tmr_mux_1bit_unprot.svg", width: 70%),
    caption: [ Multi-TMR vs. regular TMR for mux_1bit, unprotected voter ]
) <fig:muxltiunprot>

Whilst there is some notable improvement, it is definitely not significant enough to sacrifice the
considerable increase in area caused by triplicated voters. The exact reason _why_ triplicating the voters
doesn't improve reliability is probably an artefact of the test situation. As in many other tests, the test
circuits are too simple (in this case, a single 1-bit multiplexer), and the voter ends up taking significantly
more area than the circuit itself. This is covered in @sec:analysis.

=== Unmitigated circuits
To compare against a baseline, @fig:allunmitigatedcomb shows the results of fault injection on all
combinational circuits with no mitigation (i.e. no TMR) whatsoever.

#figure(
    image("../../diagrams/all_comb_unmit.svg", width: 75%),
    caption: [ Comparison of all results for unmitigated combinational circuits ]
) <fig:allunmitigatedcomb>

As expected, these largely result in 0% mitigation rate across the board. However, there's an interesting
spike up to 10% mitigated for some circuits at exactly two faults. My hypothesis here is that two faults being
injected into the circuit can, on occasion, cancel each other out.

=== Error signal verification
As covered in the methodology chapter, TaMaRa adds voters with an "error" signal that is intended to be set
high whenever an SEU is detected at any point in the entire circuit. This is an important signal to ensure is
correct, as it could be used to reset the device when faults occur, which is critical to ensuring SEUs don't
propagate and "pile up" on physical devices. Yet, as this error signal itself is subject to SEUs, it is
possible that it could be incorrect if it is struck by an SEU.

With a small modification to the testing script used in the prior sections, it is possible to investigate this
using formal methods. Rather than proving a miter circuit, we can ask the SAT solver to prove whether or not
the error signal is set to '1', given that we know we are injecting faults into the circuit.

@fig:errunprotnottmr shows the result of this experiment on the `not_tmr` circuit with unprotected voters.

#figure(
  image("../../diagrams/fault_err_unprotected_not_tmr.svg", width: 80%),
  caption: [ Testing for error signal validity on `not_tmr` circuit ]
) <fig:errunprotnottmr>

There are a few notable things with this result. Firstly, unlike the other results in this chapter, there's
not an obvious trend here. The percentage of correctly set error signals does not obviously linearly,
logarithmically or exponentially increase, and there's either some noise or bizarre behaviour when between
five and seven faults are injected. Also interesting to note is that, at best, only around 55% of the time is
the error signal set correctly, and this is with eight faults. More realistically, in the case of a single
fault, the error signal is set correctly only 30% of the time. However, as more faults are injected, the
correctness of the error signal improves. This does seem to make some statistical sense, as the increased
number of faults injected into the circuit seems more likely to trip the combinational path that sets the
error signal to '1'. Comparatively, injecting a fault in just the right place to cause the error signal to be
stuck at '0' would be statistically less likely.

=== Analysis <sec:analysis>
In all of the unprotected voter tests, the results are significantly worse than with the protected voter.
This is because the voter takes up the majority of the gate-area of the circuit in a number of these cases,
meaning the likelihood of the fault applying to the voter and hence invalidating it is much higher. In
@tab:voterarea, I calculate the percentage area that the voter accounts for by summing the wires and cells
reported by the Yosys `stat` command before and after voter insertion. The real effectiveness of the algorithm
in representative real-world tests is by comparing unprotected voter tests vs. unmitigated voter.

// these stats are wires + cells **WHEN ONLY THE VOTER IS SELECTED** so we need to figure out how to do that
// select only voter: select a:tamara_voter
#figure(
  table(
    columns: 2,
    align: horizon,
    stroke: 0.5pt,
    [*Circuit name*],
    [*Area taken by voter*],
    [not\_2bit],
    [ 90.4% ], // total: 33 + 30; voter: 30 + 27

    [not\_32bit],
    [ 99.3% ], // total: 483 + 420; voter: 480 + 417

    [not\_tmr],
    [ 90.9% ], // total: 17 + 16; voter: 17 + 13

    [mux\_1bit],
    [ 63.2% ], // total: 8 + 11; voter: 7 + 5

    [not\_dff\_tmr],
    [ 64.3% ], // total: 23 + 19; voter: 13 + 14

    // [not_swizzle_low],
    // [], // total:
  ),
  caption: [ Voter area for different representative circuits ]
) <tab:voterarea>

This raises an interesting question for further research. There is an implication here that the area a voter
takes up is a very important characteristic that impacts how fault-tolerant a TMR circuit is. This, in turn,
suggests that area driven (or, alternatively, placement-driven) TMR approaches would be a valuable field to
investigate in future research. Regardless, since TaMaRa operates entirely in the synthesis phase without any
knowledge or consideration of the final area the voter takes, it makes sense that high voter areas as per
@tab:voterarea correspond with significantly reduced fault-tolerance in unprotected voter scenarios.

Although the protected voter tests are useful for proving the fundamental correctness of the algorithm, they
are not representative of real-world fault-injection scenarios. In the real world, radiation can (and will)
strike voter circuits. A sampling of unprotected vs. unmitigated circuit results are shown in @tab:resultgrid.

#figure(
  table(
    columns: 2,
    align: horizon,
    stroke: 0.5pt,
    [
      #image("../../diagrams/multi_fault_mux_2bit.svg")
    ],
    [
      #image("../../diagrams/multi_fault_not_2bit.svg")
    ],
    [
      #image("../../diagrams/multi_fault_not_swizzle_low.svg")
    ],
    [
      #image("../../diagrams/multi_fault_crc_const_variant3.svg")
    ]
  ),
  caption: [ Sample of unprotected vs. unmitigated circuit results ]
) <tab:resultgrid>

// bar graph of percentage difference with one fault across all circuits?
// I had considered this and started on it (generate_bar_graph.py) but I think it'll just be ugly

Comparing unprotected vs. unmitigated circuits for a variety of circuits shows that the TaMaRa algorithm _is_
effective, compared to a control, against mitigating between one and three SEUs. As mentioned earlier, there
is inverse logarithmic shaped curve as the number of faults increases, showing an exponential decay in the
effectiveness of the algorithm until it eventually is no longer effective at mitigating more than eight upsets.
This was hypothesised to happen in the early stages of drafting the algorithm, so it's a positive sign to see
it in reality. One of the biggest takeaways from this data is that single-voter TMR is not enough to mitigate
_all_ SEUs, and is certainly not enough to mitigate multi-bit upsets (MBUs). For space-faring applications,
SEUs landing in the voter circuitry remain a serious issue, especially for smaller circuits. Based on the
results available, it does appear that smaller circuits (such as the ones tested in this chapter) suffer more
adversely from SEUs. It is likely that this issue becomes less serious on more complex circuits such as CPUs,
but the TaMaRa algorithm would need improvements in order to handle these more complicated circuits.
