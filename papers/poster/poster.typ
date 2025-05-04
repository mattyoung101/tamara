#import "@preview/peace-of-posters:0.5.5" as pop

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
        // fill: gradient.linear(rgb("#51247a"), rgb("#962a8b")),
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
        Matthew Lawrence Young -- Supervised by Assoc. Prof. John Williams
    ],
)

#columns(3, [
    #pop.column-box(heading: "Introduction")[
        #set text(size: 12pt)
        Safety-critical sectors require Application Specific Integrated Circuit (ASIC) designs and Field
        Programmable Gate Array (FPGA) gateware to be fault-tolerant. Particularly, high-reliability
        spaceflight computer systems need to mitigate the effects of Single Event Upsets (SEUs) caused by
        ionising radiation. One common fault-tolerant design technique is Triple Modular Redundancy (TMR),
        which mitigates SEUs by triplicating key parts of the design and using voter circuits. Leveraging the
        open-source Yosys Electronic Design Automation (EDA) tool, in this work, I present _TaMaRa_: a novel
        fully automated TMR flow, implemented as a Yosys plugin.
    ]

    #colbreak()

    #pop.column-box(heading: "Peace be with you")[
        #figure(caption: [
            'Doves [...] are used in many settings as symbols of peace, freedom or love.
            Doves appear in the symbolism of Judaism, Christianity, Islam and paganism, and of both
            military and pacifist groups.'
        ])[]
    ]

    #pop.column-box(heading: "Another one")[
        We are peaceful doves.
    ]

    #colbreak()

    #pop.column-box(heading: "Third Column")[]
])

#columns(3, [
    #pop.column-box(heading: "Methodology", stretch-to-next: true)[
        #lorem(10)
    ]

    #colbreak()

    #pop.column-box(heading: "Col2", stretch-to-next: true)[
        #lorem(10)
    ]

    #colbreak()

    #pop.column-box(heading: "Col3", stretch-to-next: true)[
        #lorem(10)
    ]
])

// uq purple: #502379


// CRICOS 00025B • TEQSA PRV12080 

#pop.bottom-box(logo: image("images/uqlogo.png", width: 15%))[
    // #set text(fill: rgb("#502379"))
    // School of Electrical Engineering and Computer Science
    #grid(
        columns: (15em, 25em),
        gutter: 3pt,
        [
            #set text(size: 18pt)
            *School of Electrical Engineering and Computer Science*
        ],
        [
            #set text(size: 14pt)
            *Acknowledgements*

            #set text(fill: black, size: 10pt)
            N. Engelhardt, George Rennie, Emil J. Tywoniak, Krystine
            Sherwin, Catherine "whitequark", Jannis Harder, Assoc. Prof. John Williams, Assoc. Prof. Peter
            Sutton, and my friends and family.
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
