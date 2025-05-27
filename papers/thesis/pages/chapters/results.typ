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
  ),
  caption: [ Table of multi-bit combinatorial circuit designs ]
) <tab:combinatorialmulti>

#TODO("add crc const variant3/4/5")

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
#TODO("")

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

=== Fault injection studies: Protected voter
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
        #image("../../diagrams/fault_protected_not_tmr.svg", width: 80%)
    ],

    [not\_2bit],
    [
      #image("../../diagrams/fault_protected_not_2bit.svg", width: 80%)
    ],

    [not\_32bit],
    [
      #image("../../diagrams/fault_protected_not_32bit.svg", width: 80%)
    ],

    [
        mux_1bit
    ],
    [
        #image("../../diagrams/fault_protected_mux_1bit.svg", width: 80%)
    ],

    [
        mux_2bit
    ],
    [
        #image("../../diagrams/fault_protected_mux_2bit.svg", width: 80%)
    ],

    [
        mux_32bit
    ],
    [
        #image("../../diagrams/fault_protected_mux_32bit.svg", width: 80%)
    ],

    [
        not_swizzle_low
    ],
    [
        #image("../../diagrams/fault_protected_not_swizzle_low.svg", width: 80%)
    ],

    [
        not_swizzle_high
    ],
    [
        #image("../../diagrams/fault_protected_not_swizzle_high.svg", width: 80%)
    ],
  ),
  caption: [ Protected voter fault injection study results ]
) <tab:faultinjectprotected>

=== Fault injection studies: Unprotected voter
While the protected voter study in the prior section is useful for verifying the correctness of the voter
circuit itself, it is not representative of real-world fault scenarios. In the unprotected voter studies, we
subject the entire netlist to faults, including the voter circuit.

The Yosys script used to run these tests was the same as @lst:ignorevoter, except that the statements to
select only voters were removed. Results for this set of tests are shown in @tab:faultinjectunprotected. The
process remains stochastic, and the same parameters as in the protected voter experiments were used (10
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
        #image("../../diagrams/fault_unprotected_not_tmr.svg", width: 80%)
    ],

    [not\_2bit],
    [
      #image("../../diagrams/fault_unprotected_not_2bit.svg", width: 80%)
    ],

    [not\_32bit],
    [
      #image("../../diagrams/fault_unprotected_not_32bit.svg", width: 80%)
    ],

    [
        mux_1bit
    ],
    [
        #image("../../diagrams/fault_unprotected_mux_1bit.svg", width: 80%)
    ],

    [
        mux_2bit
    ],
    [
        #image("../../diagrams/fault_unprotected_mux_2bit.svg", width: 80%)
    ],

    [
        mux_32bit
    ],
    [
        #image("../../diagrams/fault_unprotected_mux_32bit.svg", width: 80%)
    ],

    [
        not_swizzle_low
    ],
    [
        #image("../../diagrams/fault_unprotected_not_swizzle_low.svg", width: 80%)
    ],

    [
        not_swizzle_high
    ],
    [
        #image("../../diagrams/fault_unprotected_not_swizzle_high.svg", width: 80%)
    ],
  ),
  caption: [ Unprotected voter fault injection study results ]
) <tab:faultinjectunprotected>

In many of these examples, the results are significantly worse than with the protected voter. This is because
the voter takes up the majority of the gate-area of the circuit in a number of these cases, meaning the
likelihood of the fault applying to the voter and hence invalidating it is much higher. In @tab:voterarea, I
calculate the percentage area that the voter accounts for.

#TODO("complete this table")

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
  ),
  caption: [ Voter area for different circuits ]
) <tab:voterarea>

This raises an interesting question for further research. There is an implication here that the area a voter
takes up is a very important characteristic that impacts how fault-tolerant a TMR circuit is. This, in turn,
suggests that area driven (or, alternatively, placement-driven) TMR approaches would be a valuable field to
investigate in future research. Regardless, since TaMaRa operates entirely in the synthesis phase without any
knowledge or consideration of the final area the voter takes, it makes sense that high voter areas as per
@tab:voterarea correspond with significantly reduced fault-tolerance in unprotected voter scenarios.

=== Analysis of fault injection results <sec:analysis>
Synthesising the data from all of the prior tests, we can reveal some interesting properties of the TaMaRa
algorithm and the characteristics of its robustness against SEUs.

#figure(
    image("../../diagrams/multi_fault_mux_2bit.svg", width: 70%),
    caption: [ Unmitigated vs. protected voter for the mux\_2bit circuit ]
) <fig:unmitvsprotected>

#TODO("more examples here, in a 2x2 table")

Firstly, comparing
unprotected #footnote([In which the voter is allowed to have faults injected into it.])
vs.
unmitigated #footnote([In which there is no TaMaRa TMR applied at all.])
circuits for a variety of circuits shows that the TaMaRa algorithm _is_ effective, compared to a control,
against mitigating a number of SEUs.
The fact that 100% of faults are mitigated when only one fault is injected is a positive sign, as it indicates
the algorithm is working as intended to mitigate _single_ event upsets. Also observe the inverse logarithmic
shaped curve as the number of faults increases, showing an exponential decay in the effectiveness of the
algorithm until it eventually is no longer effective at mitigating more than 8 upsets.

#figure(
    image("../../diagrams/all_comb_prot.svg", width: 85%),
    caption: [ Comparison of all results for protected voter combinatorial circuits ]
) <fig:allprotectedcomb>

@fig:allprotectedcomb shows the combined results of all combinatorial circuits under protected voter fault
injection tests. Generally, all circuits follow roughly the same inverse logarithmic curve, and are within a
few percentage points of each other. All tested circuits are able to mitigate 100% of injected faults, which
is a very positive sign for the protected voter. With 2 injected faults, the effectiveness ranges between
roughly 40% and 75%, with `not_swizzle_low` performing the worst, and `mux_2bit` and `not_2bit` performing the
best. Interestingly, the only outliers here are the two 32-bit circuits: `not_32bit` and `not_2bit`, which do
not have an inverse logarithmic curve, rather an almost linear curve that's significantly better than all of
the other circuits. This would appear to confirm my earlier hypothesis that more complex circuits, and
in particular circuits where the voter does _not_ consist of the majority of logic elements, perform better
under fault injection.

To investigate further, I performed a sweep of fault-injection tests with a 2-bit, 4-bit, 8-bit, 16-bit,
24-bit and 32-bit multiplexer respectively, which is shown in Figure XX.

#TODO("")

#figure(
    image("../../diagrams/all_comb_unprot.svg", width: 80%),
    caption: [ Comparison of all results for unprotected voter combinatorial circuits ]
) <fig:allunprotectedcomb>

@fig:allunprotectedcomb shows the combined results of all combinatorial circuits under unprotected voter fault
injection tests. In this case, rather than being an inverse logarithmic curve, all tests have a very sharp
fall-off in the percentage of mitigated faults, even between one and two faults. Note that, even in the case
of one fault, only between 50% and 60% of faults were mitigated, and this declines sharply to between roughly
5% and 15% at two faults. Although this is an unfortunate result, recall from @tab:voterarea that the voter
takes up the vast majority of the circuit area in these tests, meaning it's much more likely to be the target
of faults, so this result does make sense on this test suite. Nonetheless, there's clear room for
methodological improvement here. Also interesting to note is that, unlike in @fig:allprotectedcomb with the
protected voters, these results are all largely the same across all circuits.

#figure(
    image("../../diagrams/all_comb_unmit.svg", width: 70%),
    caption: [ Comparison of all results for unmitigated combinatorial circuits ]
) <fig:allunmitigatedcomb>

To compare against a baseline, @fig:allunmitigatedcomb shows the results of fault injection on all
combinatorial circuits with no mitigation (i.e. no TMR) whatsoever. These largely result, as expected, in 0%
mitigation rate across the board. However, there's an interesting spike up to 10% mitigated for the `not_tmr`
circuit at exactly two faults. My hypothesis here is that two faults being injected into the circuit can, on
occasion, cancel each other out.

== RTL fuzzing
#TODO("")
- Unsure how to show this systematically either

