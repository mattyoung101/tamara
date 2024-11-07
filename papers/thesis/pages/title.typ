#let config = yaml("../config.yaml")

#align(center, [
    #image("../util/assets/uqlogo.png", width: 65%)
])

#v(24pt)

#align(center, text(24pt)[
    *#config.title*
])

#v(2em)

#align(center, text(14pt)[
        by
])

#align(center, text(18pt)[
    #config.author
])

#align(center, text(16pt)[
    #box(width: 75%)[School of #config.faculty, University of Queensland.]
])

#v(128pt)

#align(center, text(16pt)[
    _ Submitted for the degree of \ #config.degrees_candidate \ in #config.month #config.year _
])
