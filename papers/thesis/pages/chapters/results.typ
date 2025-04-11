#import "../../util/macros.typ": *

= Results
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
  ),
  caption: [ Table of combinatorial circuit designs ]
) <tab:combinatorial>

=== Multi-bit combinatorial circuits
Once the single-bit combinatorial circuits were confirmed to be working, the next

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
      _Identical to above_
    ],
  ),
  caption: [ Table of combinatorial circuit designs ]
) <tab:combinatorialmulti>

=== Sequential circuits

=== Multi-cone circuits

=== Feedback circuits

== Formal verification
=== Equivalence checking
- Unsure how to systematically show equivalence checking results?
- Maybe by the numbers?

=== Fault injection
- Description of fault injection setup, some circuit diagrams, and proof that it passes the formal
  verification

=== Multi-bit fault injection studies
- Graph
  - X axis: Number of faults
  - Y axis: Passing test cases #sym.div Number of cells + wires in the circuit post-TMR
  - Normalised failure rate, higher is better

#figure(
  table(
    columns: 4,
    align: horizon,
    stroke: 0.5pt,
    [*Circuit name*],
    [*Faults until failure*],
    [*Normalisation \ factor*],
    [*Normalised \ failure rate*],
    [not\_2bit],
    [7],
    [63],
    [0.11],

    [not\_32bit],
    [18],
    [903],
    [0.019]
  ),
  caption: [ Fault injection study results ]
) <tab:faultinject>

== RTL fuzzing
- Unsure how to show this systematically either

== Applying TaMaRa to advanced circuits
- CPU design if applicable
