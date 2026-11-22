// Plantilla base del documento: tipografía, página, encabezados, tablas e índice

#let report-template(body) = {
  set page(
    paper: "a4",
    margin: (top: 2.2cm, bottom: 2.2cm, left: 2.5cm, right: 2.5cm),
    numbering: "1",
    footer: none,
  )

  set text(
    font: ("Carlito", "Liberation Sans"),
    size: 11pt,
    lang: "es",
    region: "PE",
  )

  set par(
    justify: false,
    leading: 0.55em,
  )

  // Numeración de secciones: 1., 6.1., etc.
  set heading(numbering: "1.1.")

  show heading.where(level: 1): it => {
    v(0.55em)
    block(sticky: true)[
      #text(weight: "bold", size: 11pt)[
        #if it.numbering != none {
          counter(heading).display(it.numbering)
          h(0.5em)
        }
        #upper(it.body)
      ]
    ]
    v(0.15em)
  }

  show heading.where(level: 2): it => {
    v(0.45em)
    block(sticky: true, inset: (left: 1.4em))[
      #text(weight: "bold", size: 11pt)[
        #if it.numbering != none {
          counter(heading).display(it.numbering)
          h(0.35em)
        }
        #it.body
      ]
    ]
    v(0.1em)
  }

  // Estilo de tabla estándar del reporte
  set table(
    stroke: 0.75pt + black,
    inset: 6pt,
    align: left + top,
  )

  body
}

// Helper para títulos centrados de páginas preliminares (sin numeración)
#let frontmatter-title(title) = {
  align(center)[
    #text(weight: "bold", size: 11pt)[#upper(title)]
  ]
  v(1em)
}

// Helper para placeholders sin llenar del formato original
#let placeholder(body) = {
  text(body)
}
