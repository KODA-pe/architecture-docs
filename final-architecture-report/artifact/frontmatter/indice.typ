#import "../template.typ": frontmatter-title

// Página 4: Índice General (generado automáticamente a partir de las secciones)

#frontmatter-title("INDICE GENERAL")

#align(right)[
  #text(weight: "bold", size: 11pt)[Pag.]
]

#v(0.2em)

#show outline.entry: it => {
  let num = if it.element.numbering != none {
    numbering(it.element.numbering, ..counter(heading).at(it.element.location()))
  }
  let indent-left = if it.level == 1 { 0em } else { 1.8em }
  pad(left: indent-left)[
    #link(it.element.location())[
      #if num != none {
        num
        h(0.5em)
      }
      #it.element.body
      #box(width: 1fr, repeat[.])
      #it.page()
    ]
  ]
}

#outline(
  title: none,
  depth: 2,
)
