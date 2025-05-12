#import "@preview/peace-of-posters:0.5.5" as pop
#import "@preview/markly:0.3.0"

#let uq-theme = (
    "body-box-args": (
        inset: 0.6em,
        width: 100%,
        stroke: none,
        fill: rgb("#efedea")
    ),
    "body-text-args": (:),
    "heading-box-args": (
        inset: 0.6em,
        width: 100%,
        fill: rgb("#e6e2e0"),
    ),
    "heading-text-args": (
        // fill: rgb("#502379")
        fill: gradient.linear(rgb("#51247a"), rgb("#962a8b")),
    ),
    "title-text-args": (
        // fill: rgb("#502379")
        fill: gradient.linear(rgb("#51247a"), rgb("#962a8b")),
    )
)

#set page("a3", margin: 1cm, flipped: true)
#pop.set-poster-layout(pop.layout-a3)
#pop.update-poster-layout(
    title-size: 32pt,
    heading-size: 16pt,
)
#pop.set-theme(uq-theme)
#set text(size: pop.layout-a3.at("body-size"), font: "Roboto")
#let box-spacing = 1em
#set columns(gutter: box-spacing)
#set block(spacing: box-spacing)
#pop.update-poster-layout(spacing: box-spacing)

#pop.title-box(
    [
        *An Automated Triple Modular Redundancy EDA Flow for Yosys*
        #v(-2.5em) // hack to reduce spacing manually
    ],
    authors: [
        Matt Young -- Supervised by Assoc. Prof. John Williams
    ],
)

#columns(3, [
    #pop.column-box(heading: "Introduction")[
        #set text(size: 12pt)
        Safety-critical sectors require Application Specific Integrated Circuit (ASIC) designs and Field
        Programmable Gate Array (FPGA) gateware to be fault-tolerant. In particular, high-reliability
        spaceflight computer systems need to mitigate the effects of Single Event Upsets (SEUs) caused by
        ionising radiation. One common fault-tolerant design technique is Triple Modular Redundancy (TMR),
        which mitigates SEUs by triplicating key parts of the design and using voter circuits. Leveraging the
        open-source Yosys Electronic Design Automation (EDA) tool, in this work, I present *TaMaRa*: a novel
        fully automated TMR flow, implemented as a Yosys plugin.
    ]

    #pop.column-box(heading: "Single Event Upsets")[
        #set text(size: 12pt)
        SEUs are caused by ionising radiation striking a CMOS transistor on an integrated circuit, and
        inducing a small charge which can flip bits. This is dangerous, as it can invalidate the results of
        important calculations, potentially causing loss of life and/or property in safety-critical scenarios.
    ]

    #colbreak()

    #pop.column-box(heading: "Triple Modular Redundancy")[
        #set text(size: 12pt)
        Triple Modular Redundancy (TMR) mitigates SEUs by triplicating key parts of the design and using voter
        circuits to select a non-corrupted result if an SEU occurs (see @fig:tmr).

        #figure(
            image("images/tmr_diagram.svg", width: 80%),
            caption: [ Diagram demonstrating TMR being inserted into an abstract design ]
        ) <fig:tmr>

        // Typically, TMR is manually designed at the Hardware Description Language (HDL) level, for example,
        // by manually instantiating three copies of the target module, designing a voter circuit, and linking
        // them all together. However, this approach is an additional time-consuming and potentially
        // error-prone step in the already complex design pipeline.
    ]

    #colbreak()

    #pop.column-box(heading: [*TaMaRa* Methodology])[
        #set text(size: 12pt)
        // Typically, TMR is manually designed at the Hardware Description Language (HDL) level. However, this
        // approach is an additional time-consuming and potentially error-prone step in the already complex
        // design pipeline.

        The *TaMaRa* algorithm (@fig:algo), introduced in this work, automates the insertion of TMR at the
        post-synthesis netlist level.
        // It operates on Yosys' RTL Intermediate Intermediate Language (RTLIL)
        // representation, to turn create redundant circuits from any input HDL (SystemVerilog, VHDL, etc).

        #figure(
            image("images/algorithm.svg", width: 95%),
            caption: [ Description of the TaMaRa algorithm ]
        ) <fig:algo>
    ]
])

#columns(3, [
    #pop.column-box(heading: [Prior literature])[
        #set text(size: 12pt)
        In the literature, there are two approaches to automated TMR:
        - *Design-level approaches* ("thinking in terms of HDL"): Treat the design as HDL _modules_, and
          introduce TMR by replicating these modules. Operates on HDL source code.
        - *Netlist-level approaches* ("thinking in terms of circuits"): Treat the design as a _circuit_ or
          _netlist_, which is internally represented as a graph. TMR is introduced using graph theory
            algorithms to _cut_ the graph in a particular way and insert voters.
        Design-level approaches are usually more intelligible and extensible, as they operate on HDL source
        code directly. However, it's difficult to account for EDA synthesis optimisations that can remove the
        redundancy. Whilst being less intelligible, netlist-level approaches can support many HDLs, and
        operate safely after optimisation.
    ]

    #colbreak()

    #pop.column-box(heading: "Results: Circuits")[
        #set text(size: 11pt)
        @fig:mux shows a netlist schematic for a simple 2-bit multiplexer, and @fig:muxtmr shows it after the
        application of TaMaRa TMR.

        #figure(
            image("images/mux_2bit.svg", width: 23%),
            caption: [ 2-bit multiplexer ]
        ) <fig:mux>

        #figure(
            image("images/mux_2bit_tmr.svg", width: 85%),
            caption: [ 2-bit multiplexer with TaMaRa TMR ]
        ) <fig:muxtmr>

        // #grid(
        //     columns: (10em, auto),
        //     [
        //         #figure(
        //             image("images/mux_2bit.svg", width: 50%),
        //             caption: [ 2-bit multiplexer ]
        //         ) <fig:mux>
        //     ],
        //     [
        //         #figure(
        //             image("images/mux_2bit_tmr.svg", width: 100%),
        //             caption: [ 2-bit multiplexer with TMR ]
        //         ) <fig:muxtmr>
        //     ]
        // )

    ]

    #colbreak()

    // TODO combine graphs into one
    #pop.column-box(heading: "Results: Reliability")[
        #set text(size: 11pt)
        TaMaRa demonstrates the capability of mitigating simulated SEU faults in a large-scale formally
        verified fault-injection campaign. When the voter is itself protected from faults (@fig:protected),
        the algorithm performs well; but in more realistic unprotected scenarios, faults can still occur
        (@fig:unprotected).

        #grid(
            columns: (auto, auto),
            [
                #figure(
                    image("images/fault_protected_mux_2bit.svg", width: 85%),
                    caption: [ Protected voter ]
                ) <fig:protected>
            ],
            [
                #figure(
                    image("images/fault_unprotected_mux_2bit.svg", width: 85%),
                    caption: [ Unprotected voter ]
                ) <fig:unprotected>
            ]
        )
    ]
])

// CRICOS 00025B • TEQSA PRV12080 

#pop.bottom-box(logo: image("images/uqlogo.png", width: 10%))[
    // #set text(fill: rgb("#502379"))
    // School of Electrical Engineering and Computer Science
    #grid(
        columns: (15em, 48em),
        gutter: 1em,
        [
            #set text(size: 14pt)
            *School of Electrical Engineering and Computer Science*
        ],
        [
            #set text(size: 14pt)
            *Acknowledgements*

            #set text(fill: black, size: 10pt)
            N. Engelhardt, George Rennie, Emil J. Tywoniak, Krystine Sherwin, Catherine "whitequark", Jannis
            Harder, John Williams, Peter Sutton, and my friends and family.
        ]
    )
]

// #columns(3, [
//     #pop.bottom-box(heading: "bruh")[
//         #set text(fill: rgb("#502379"))
//         School of Electrical Engineering and Computer Science
//     ]
//
//     #colbreak()
//
//     #pop.column-box(heading: none)[]
//
//     #colbreak()
//
//     #pop.column-box(heading: none)[
//         This will be very very large!
//     ]
// ])
