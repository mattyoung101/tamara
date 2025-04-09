#import "../../util/macros.typ": *

= Results
== Applying TaMaRa to simple circuits
- This section will mostly contain circuit diagrams of the TaMaRa algorithm applied to various circuits, and
  descriptions of what it has done

=== Combinatorial circuits

=== Multi-bit combinatorial circuits

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
