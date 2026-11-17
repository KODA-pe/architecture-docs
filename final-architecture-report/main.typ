#import "template.typ": report-template

#show: report-template

// Preliminares
#include "frontmatter/caratula.typ"
#pagebreak()

#include "frontmatter/historial-revisiones.typ"
#pagebreak()

#include "frontmatter/historial-versiones.typ"
#pagebreak()

#include "frontmatter/indice.typ"
#pagebreak()

// Cuerpo del reporte (numeración inicia en 1)
#counter(page).update(1)

#include "sections/01-descripcion-tema.typ"
#include "sections/02-metodologia.typ"
#include "sections/03-actas-trabajo.typ"
#include "sections/04-estado-del-arte.typ"
#include "sections/05-descripcion-artefacto.typ"
#include "sections/06-conclusiones.typ"
#include "sections/07-observaciones.typ"
#include "sections/08-bibliografia.typ"
#include "sections/09-anexos.typ"
