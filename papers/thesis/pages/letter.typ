#let config = yaml("../config.yaml")

#align(right)[
    #config.author

    #config.email
]

#datetime.today().display("[day] [month repr:long] [year]")

#v(1em)

#config.head_of_school_long,

Head of School

School of Electrical Engineering and Computer Science

The University of Queensland

St Lucia QLD 4072

#v(6em)

Dear #config.head_of_school_short,

In accordance with the requirements of the Degree of #config.degrees_candidate in the School of
#config.faculty, I submit the following thesis entitled

#v(1em)

#align(center, [
    "#config.title"
])

#v(1em)

The thesis was performed under the supervision of #config.supervisor. I declare that the work submitted in the
thesis is my own, except as acknowledged in the text and footnotes, and that it has not previously been
submitted for a degree at the University of Queensland or any other institution.

#v(2em)

Yours sincerely,

#v(2em)

#config.author

