// Main thesis file.
#import "util/macros.typ": *

// Page layout
#set page(
    margin: (
        left: 30mm,
        right: 30mm,
        top: 30mm,
        bottom: 30mm
    )
)
// Colour links blue like LaTeX
#show cite: set text(fill: blue)
#show link: set text(fill: blue)
#show ref: set text(fill: blue)
#show footnote: set text(fill: blue)
// Font size
#set text(size: 12pt)
// Display
#set list(indent: 12pt)
#set math.equation(numbering: "(1)")

// Title
#include "pages/title.typ"
#set page(numbering: "i")
#pagebreak()

// Justify all paragraphs but only after the title page
#set par(justify: true)
// Initially show headings but without the numbering or the "Chapter" string
#show heading.where(level: 1): it => uqHeaderNoChapter(it)

// Letter of originality
#include "pages/letter.typ"
#pagebreak()

// Dedication
#include "pages/dedication.typ"
#pagebreak()

// Acknowledgements
#include "pages/acknowledgements.typ"
#pagebreak()

// Abstract
#include "pages/abstract.typ"
#pagebreak()

// Declaration
// #include "pages/declaration.typ"
// #pagebreak()

// Lists of things
#include "pages/contents.typ"

// Reset page counter (page counting starts from one on this page)
#set page(numbering: "1")
#pagebreak()

// Set page counter to Arabic numerals
#counter(page).update(1)

// From now on, display top level headers as "Chapter XX"
#set heading(numbering: "1.")
#show heading.where(level: 1): it => uqHeaderChapter(it)

// Thesis chapters
#include "pages/chapters/intro.typ"
#pagebreak()

#include "pages/chapters/method.typ"
#pagebreak()

#include "pages/chapters/results.typ"
#pagebreak()

#include "pages/chapters/conclusion.typ"
#pagebreak()

// Return to headers without chapter numbers
#set heading(numbering: none)
#show heading.where(level: 1): it => uqHeaderNoChapter(it)

// Appendices
#include "pages/appendices/example.typ"
#pagebreak()

// Bibliography
#include "pages/bibliography.typ"
