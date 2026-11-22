#import "../template.typ": frontmatter-title

// Página 2: Historial de Revisiones

#frontmatter-title("HISTORIAL DE REVISIONES")

#table(
  columns: (14%, 49%, 13%, 12%, 12%),
  align: (left, left, left, center, center),
  table.header(
    align(center)[*FECHA*],
    align(center)[*OBSERVACIONES*],
    align(center)[*VERSIÓN*],
    table.cell(fill: yellow, align: center)[*NOTA*],
    table.cell(fill: yellow, align: center)[*V°B°*],
  ),
  [Noviembre 10 2026],
  [Agregar especificidad en los componentes de los diagramas del Modelo C4],
  [00.01],
  [],
  [],

  [Noviembre 13 2026],
  [El esquema sigue un orden correcto y los componentes están claramente diferenciados],
  [00.02],
  [],
  [],

  [#v(1.2em)], [], [], [], [],
)
