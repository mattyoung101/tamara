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
its schematic after running the following Yosys script:

```bash
read_verilog -sv $name
prep
splitcells
splitnets
show -colors 420 -format svg -prefix $output
```

This list approaches circuits in their order of complexity: first starting with simple, single-bit
combinatorial circuits, and then progressing up to advanced, multi-bit, multi-cone, recurrent, sequential
circuits. This was also the order in which the TaMaRa algorithm was verified: starting with small, simple
circuits, and progressing to complex ones, verifying incrementally along the way.

=== Combinatorial circuits
The simplest type of digital circuit is a single-bit, purely combinatorial one. @tab:combinatorial lists these
single-bit combinatorial circuits. These were critical for initial, early implementation of the TaMaRa
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
  caption: [ Table of single-bit combinatorial circuit designs ]
) <tab:combinatorial>

=== Multi-bit combinatorial circuits
Once the single-bit combinatorial circuits were confirmed to be working, the next set of tests involves
multi-bit combinatorial circuits, as shown in @tab:combinatorialmulti. This is useful to ensure that the voter
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
  caption: [ Table of multi-bit combinatorial circuit designs ]
) <tab:combinatorialmulti>

=== Sequential circuits
In the previous sections, the testbenches were all combinatorial circuits, and did not use sequential elements
such as D-flip-flops. Combinatorial circuits are easy to design and especially easy to verify, but are not at
all representative of the majority of complex SystemVerilog designs. Both Yosys' formal verification tools,
and the underlying Yices @Dutertre2014 SMT solver support sequential circuits, and they form a valuable part
of the testbench suite. Additionally, sequential circuits involve a clock signal, where the TaMaRa algorithm
must be careful to connect the clock signal correctly to the TMR replicas. These testbenches are shown in
@tab:sequentialcircuits.

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
Whilst sequential circuits more accurately represent complex industry designs than combinatorial circuits,
they are still not adequate test-cases for even the simplest industry designs. These designs typically connect
together multiple sequential circuits in a pipeline. These circuits challenge TaMaRa's multi-cone
capabilities, and additionally it's multi-voter insertion methodology. In the most complex case, it is
possible to have multi-cone, multi-voter, multi-bit circuits. These multi-cone designs are shown in
@tab:multiconecircuits.

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

== Formal verification
=== Equivalence checking
To ensure the reliability of the algorithm, an attempt was made to perform formal equivalence checking on all
of the combinatorial circuits. As of writing, there are 20 equivalence checks performed in total.

The follow circuits passed the equivalence check:

`not_2bit, not_32bit, not_tmr, voter, crc_min, crc_const_variant3, crc_const_variant4, crc_const_variant5,`
`mux_1bit, mux_2bit, bug7, not_swizzle_low, not_swizzle_high`

The following circuits failed the equivalence check:

`crc2, crc4, crc6, crc7, crc8, crc16, not_slice`

The reasons for these failures are covered later in the thesis, but in short are known faults in the current
implementation of the TaMaRa algorithm. For more info, see @tab:bugs.

== Fault injection
#TODO("reword this explanation, cover what type of faults are injected or do that in methodology")

I propose two main classes of fault injection studies. In the first class of tests, known as "Protected voter
tests", the voter circuit itself is ignored and not subject to faults. Whilst this is unrepresentative of
real-world faults, it enables us to explore the validity of the voter circuit on its own. Particularly, it
enables us to formally verify that the voter is able to protect a given circuit against a wide variety of
faults, and to understand how many faults this is before the test fails.

Ignoring the voter circuit was accomplished through the Yosys script in @lst:ignorevoter. The TaMaRa algorithm annotates each
cell and wire that is part of the voter with the `tamara_voter` RTLIL annotation.

#figure(
  ```bash
  # select only input signals
  select % a:tamara_voter %d
  # apply a random mutation (fault injection)
  mutate -list {faults} -seed {seed} -o /tmp/tamara_fault_injection
  # deselect, go back to top module
  select -clear
  # execute the fault injection command
  script /tmp/tamara_fault_injection
  ```,
  caption: [ Yosys script to deselect TaMaRa voter wires/cells ]
) <lst:ignorevoter>

=== Protected voter
@tab:faultinjectprotected presents the results for this protected voter fault-injection study. As the fault
injection process is stochastic, it uses a sample of 100 runs per fault. The circuits listed in this table
correspond to the suite of circuits presented in @tab:combinatorial, after they have been processed end-to-end
correctly by the TaMaRa algorithm.

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

@fig:allprotectedcomb shows the combined results of all combinatorial circuits under protected voter fault
injection tests.

#figure(
    image("../../diagrams/all_comb_prot.svg", width: 80%),
    caption: [ Comparison of all results for protected voter combinatorial circuits ]
) <fig:allprotectedcomb>

Generally, all circuits follow roughly the same inverse logarithmic curve, and are within a few percentage
points of each other. All tested circuits are able to mitigate 100% of injected faults when 1 fault is
injected, which is a very positive sign for the protected voter. With 2 injected faults, the effectiveness
ranges between roughly 40% and 75%, with `not_swizzle_low` performing the worst, and `mux_2bit` and `not_2bit`
performing the best. Interestingly, the only outliers here are the two 32-bit circuits: `not_32bit` and
`not_2bit`, which do not have an inverse logarithmic curve, rather an almost linear curve that's significantly
better than all of the other circuits. To investigate further, I performed a sweep of fault-injection tests
with a 1-bit, 2-bit, 4-bit, 8-bit, 16-bit, 24-bit and 32-bit multiplexer respectively, which is below shown in
@fig:muxbitsweep.

#figure(
    image("../../diagrams/mux_bit_sweep_prot.svg", width: 80%),
    caption: [ Sweep of fault-injection tests on differing-width multiplexers, protected voters ]
) <fig:muxbitsweep>

=== Unprotected voter
While the protected voter study in the prior section is useful for verifying the correctness of the voter
circuit itself, it is not representative of real-world fault scenarios. In the unprotected voter studies, we
subject the entire netlist to faults, including the voter circuit.

The Yosys script used to run these tests was the same as @lst:ignorevoter, except that the statements to
select only voters were removed. Results for this set of tests are shown in @tab:faultinjectunprotected. The
process remains stochastic, and the same parameters as in the protected voter experiments were used (100
samples per fault).

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

@fig:allunprotectedcomb shows the combined results of all combinatorial circuits under unprotected voter fault
injection tests.

#figure(
    image("../../diagrams/all_comb_unprot.svg", width: 80%),
    caption: [ Comparison of all results for unprotected voter combinatorial circuits ]
) <fig:allunprotectedcomb>

In this case, rather than being an inverse logarithmic curve, all tests have a very sharp fall-off in the
percentage of mitigated faults, even between one and two faults. Note that, even in the case of one fault,
only between 50% and 60% of faults were mitigated, and this declines sharply to between roughly 5% and 15% at
two faults. Although this is an unfortunate result, as will be covered in @sec:analysis, the voter takes up
the vast majority of the circuit area in these tests, meaning it's much more likely to be the target of
faults, so this result does make sense on this test suite. Nonetheless, there's clear room for methodological
improvement here.

Also interesting to note is that, unlike in @fig:allprotectedcomb with the protected voters, these results are
all largely the same across all circuits. We do not see see any differences between 32-bit and 1-bit circuits
in their effectiveness at mitigating faults. To investigate this further, I performed the same multiplexer
sweep as before, but using unprotected voters, which is shown below in @fig:muxbitsweepunprot.

#figure(
    image("../../diagrams/mux_bit_sweep_unprot.svg", width: 70%),
    caption: [ Sweep of fault-injection tests on differing-width multiplexers, unprotected voters ]
) <fig:muxbitsweepunprot>

#TODO("explain why this occurs?")

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
fault-injection tests were run on the `mux_1bit` circuit. X compares the reliability of the multi-TMR
circuit to a regular TMR circuit.

#figure(
    image("../../diagrams/multi_tmr_mux_1bit_unprot.svg", width: 70%),
    caption: [ Multi-TMR vs. regular TMR for mux_1bit, unprotected voter ]
) <fig:muxltiunprot>

Whilst there is some notable improvement, it is definitely not significant enough to sacrifice the
considerable increase in area caused by triplicated voters. The exact reason _why_ triplicating the voters
doesn't improve reliability is probably an artefact of the test situation. As in many other tests, the test
circuits are too simple (in this case, a single 1-bit multiplexer), and the voter ends up taking significantly
more area than the circuit itself. This is covered further below in @sec:analysis.

=== Unmitigated circuits
To compare against a baseline, @fig:allunmitigatedcomb shows the results of fault injection on all
combinatorial circuits with no mitigation (i.e. no TMR) whatsoever.

#figure(
    image("../../diagrams/all_comb_unmit.svg", width: 75%),
    caption: [ Comparison of all results for unmitigated combinatorial circuits ]
) <fig:allunmitigatedcomb>

As expected, these largely result in 0% mitigation rate across the board. However, there's an interesting
spike up to 10% mitigated for some circuits at exactly two faults. My hypothesis here is that two faults being
injected into the circuit can, on occasion, cancel each other out.

=== Analysis <sec:analysis>
In many of the unprotected voter tests, the results are significantly worse than with the protected voter.
This is because the voter takes up the majority of the gate-area of the circuit in a number of these cases,
meaning the likelihood of the fault applying to the voter and hence invalidating it is much higher. In
@tab:voterarea, I calculate the percentage area that the voter accounts for by summing the wires and cells
reported by the Yosys `stat` command before and after voter insertion. The real effectiveness of the algorithm
in representative real-world tests is by comparing unprotected voter tests vs. unmitigated voter.

#TODO("complete this table for a few more representative circuits")

// these stats are wires + cells **WHEN ONLY THE VOTER IS SELECTED** so we need to figure out how to do that
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
    [ ], // total:

    [mux\_1bit],
    [], // total:

    [not\_dff\_tmr],
    [], // total:

    [not_swizzle_low],
    [], // total:
  ),
  caption: [ Voter area for different circuits ]
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

#TODO("bar graph of percentage difference with one fault across all circuits?")

Comparing unprotected vs. unmitigated circuits for a variety of circuits shows that the TaMaRa algorithm _is_
effective, compared to a control, against mitigating between one and three SEUs. As mentioned earlier, there
is inverse logarithmic shaped curve as the number of faults increases, showing an exponential decay in the
effectiveness of the algorithm until it eventually is no longer effective at mitigating more than 8 upsets.
This was hypothesised to happen in the early stages of drafting the algorithm, so it's a positive sign to see
it in reality. One of the biggest takeaways from this data is that single-voter TMR is not enough to mitigate
_all_ SEUs, and is certainly not enough to mitigate multi-bit upsets (MBUs). For space-fairing applications,
SEUs landing in the voter circuitry remains a serious issue, especially for smaller circuits. Based on the
results available, it does appear that smaller circuits (such as the ones tested in this chapter) suffer more
adversely from SEUs. It is likely that this issue becomes less serious on more complex circuits such as CPUs,
but the TaMaRa algorithm would need improvements in order to handle these more complicated circuits.
