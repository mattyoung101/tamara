// Contains general macros to be used across the template

#let uqHeaderSize = 26pt

#let uqHeaderNoChapter(it) = {
    v(3em)

    text(uqHeaderSize)[* #it.body * ]

    v(1em)
}

#let uqHeaderChapter(it) = {
    v(3em)

    // #counter(heading).display( it.numbering )
    text(uqHeaderSize)[* Chapter #counter(heading).display("1") *]

    v(-15pt)

    text(uqHeaderSize)[* #it.body * ]

    v(1em)
}
