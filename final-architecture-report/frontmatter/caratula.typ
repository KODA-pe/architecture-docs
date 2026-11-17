#import "../config.typ": report-config

// Página 1: Carátula

#v(0.5cm)

#grid(
  columns: (45%, 55%),
  gutter: 0.5cm,
  align: (left + horizon, center + horizon),
  image("../assets/unsa-logo.png", width: 100%),
  [
    #set text(weight: "bold", size: 11pt)
    #report-config.universidad \
    #report-config.escuela \
    \
    #report-config.curso \
    #report-config.semestre
  ],
)

#v(2.2cm)

#align(center)[
  #highlight(fill: yellow)[
    #text(weight: "bold", size: 11pt)[#report-config.resultado-estudiante]
  ]
]

#v(1.6cm)

#align(center)[
  #text(weight: "bold", size: 11.5pt)[#report-config.proyecto]
]

#v(2.0cm)

#align(center)[
  #text(size: 11pt)[
    #report-config.titulo \
    #v(0.3em)
    #report-config.version
  ]
]

#v(2.2cm)

#align(center)[
  #text(size: 11pt)[INTEGRANTES]
]

#v(0.8cm)

#align(center)[
  #grid(
    columns: (auto, auto),
    column-gutter: 2.8cm,
    row-gutter: 0.55em,
    align: left,
    ..report-config.integrantes-col1.zip(report-config.integrantes-col2).map(((a, b)) => (
      highlight(fill: a.color)[#text(size: 11pt)[#a.nombre]],
      highlight(fill: b.color)[#text(size: 11pt)[#b.nombre]],
    )).flatten()
  )
]

#v(1fr)

#align(center)[
  #text(size: 11pt)[
    #report-config.fecha \
    #v(0.2em)
    #report-config.lugar
  ]
]

#v(1.5cm)
