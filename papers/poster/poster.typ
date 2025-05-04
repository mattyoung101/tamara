#import "@preview/peace-of-posters:0.5.5" as pop

#let uq-theme = (
    "body-box-args": (
        inset: 0.6em,
        width: 100%,
    ),
    "body-text-args": (:),
    "heading-box-args": (
        inset: 0.6em,
        width: 100%,
        fill: gradient.linear(rgb("#51247a"), rgb("#962a8b")),
        stroke: rgb(25, 25, 25),
    ),
    "heading-text-args": (
        fill: white,
    ),
)

#set page("a3", margin: 1cm, flipped: true)
#pop.set-poster-layout(pop.layout-a3)
#pop.set-theme(uq-theme)
#set text(size: pop.layout-a3.at("body-size"), font: "Inria Sans")
#let box-spacing = 1em
#set columns(gutter: box-spacing)
#set block(spacing: box-spacing)
#pop.update-poster-layout(spacing: box-spacing)

#pop.title-box(
    "An Automated Triple Modular Redundancy EDA Flow for Yosys",
    authors: "Matthew Lawrence Young",
    institutes: "University of Queensland",
)

#columns(3, [
    #pop.column-box(heading: "General Relativity")[
        Einstein's brilliant theory of general relativity
        starts with the field equations).
        $ G_(mu nu) + Lambda g_(mu nu) = kappa T_(mu nu) $
        However, they have nothing to do with doves.
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

// #columns(3, [
//     #pop.column-box(heading: "Col1")[]
//
//     #colbreak()
//
//     #pop.column-box(heading: "Col2")[]
//
//     #colbreak()
//
//     #pop.column-box(heading: "Col3", stretch-to-next: true)[
//         This will be very very large!
//     ]
// ])

#pop.bottom-box(logo: image("images/uqlogo.png"))[
    School of Electrical Engineering and Computer Science
]


