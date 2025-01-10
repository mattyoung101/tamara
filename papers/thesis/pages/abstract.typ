= Abstract
Safety-critical sectors require Application Specific Integrated Circuit (ASIC) designs and Field Programmable
Gate Array (FPGA) gateware to be fault-tolerant. In particular, space-fairing computers need to mitigate the
effects of Single Event Upsets (SEUs) caused by ionising radiation. One common fault-tolerant design technique
is Triple Modular Redundancy (TMR), which mitigates SEUs by triplicating key parts of the design and using
voter circuits. Typically, this is manually implemented by designers at the Hardware Description Language
(HDL) level, but this is error-prone and time-consuming. Leveraging the power and flexibility of the
open-source Yosys Electronic Design Automation (EDA) tool, in this thesis I present *TaMaRa*: a novel
fully automated TMR flow, implemented as a Yosys plugin. I describe the design and implementation of the TaMaRa
tool, and present extensive test results using a combination of manual tests, formal verification and RTL
fuzzing techniques.
