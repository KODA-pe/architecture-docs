= ANEXOS

#pad(left: 1.4em)[
  La totalidad de los artefactos arquitectónicos, registros de decisiones (ADR), modelos de datos, modelos de dominio UML y fuentes editables del presente informe se encuentran versionados en el repositorio oficial del equipo en GitHub:

  - *Repositorio Principal en GitHub:* #link("https://github.com/KODA-pe/architecture-docs")[`https://github.com/KODA-pe/architecture-docs`]

  #figure(
    table(
      columns: (28%, 72%),
      table.header(
        [*Artefacto / Directorio*],
        [*Contenido y Ruta en el Repositorio*],
      ),
      [Decisiones Arquitectónicas (ADR)], [`/adr/0001` a `/adr/0005` — Monolito Modular, PostgreSQL con esquemas, discriminador `sede_id`, comunicación *in-process* y cobro manual sin pasarela.],
      [Vistas Generales C4 e Infraestructura], [`/infraestructure/arq-diagram_v2.md`, `/infraestructure/c4-c1-contexto.md` y `/infraestructure/c4-despliegue.md`.],
      [Arquitectura y Secuencias de Pagos], [`/services/payments/c4/` (C2 y C3), `/services/payments/diagrama de secuencias/payments-sequence-diagrams.md` y `/UML/payments/complete/step-01-domain-model.puml`.],
      [Arquitectura de Reportes y Personal], [`/services/report/report-service.md` y `/services/personal/personal-service.md`.],
      [Modelos de Base de Datos (ERD)], [`/databases/payment-service-bd-v02.md`, `/databases/report-service-db.md` y `/databases/personal-service-db.md`.],
      [Requisitos y Educciones], [`/README.md` (`EDU-0001` a `EDU-0022`) y `/rnf/RNF-0001.md` a `RNF-0015.md`.],
      [Informe Final en Typst], [`/final-architecture-report/main.typ` y diagramas vectoriales en `/final-architecture-report/assets/diagrams/`.],
    ),
    caption: [Índice de anexos y artefactos trazables en el repositorio GitHub.],
  )
]
