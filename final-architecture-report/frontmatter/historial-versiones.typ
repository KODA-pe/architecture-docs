#import "../template.typ": frontmatter-title

// Página 3: Historial de Versiones

#frontmatter-title("HISTORIAL DE VERSIONES")

#table(
  columns: (13%, 11%, 40%, 36%),
  align: left + top,
  table.header(
    align(center)[*FECHA*],
    align(center)[*VERSIÓN*],
    align(center)[*DESCRIPCIÓN*],
    align(center)[*AUTORES*],
  ),
  [Noviembre 10 2026],
  [00.01],
  [Primera versión, se presenta una propuesta de arquitectura general, a espera de validación del ingeniero],
  [Rodrigo Alexander Fernandez Huarca],

  [Noviembre 11 2026],
  [00.02],
  [Segunda versión incrementada, especificidad en componentes del modelo C4],
  [
    Rodrigo Alexander Fernandez Huarca \
    Jeans Anthony Aja Huacso \
    Luis Guillemo Luque Condori
  ],

  [Noviembre 17 2026],
  [01.00],
  [\<Editar aqui\>],
  [
    Rodrigo Alexander Fernandez Huarca \
    Jeans Anthony Aja Huacso \
    Luis Guillemo Luque Condori
  ],
)
