= METODOLOGÍA DEL PROCESO

#pad(left: 1.4em)[
  La definición arquitectónica del sistema se ejecutó siguiendo un enfoque iterativo y trazable orientado por atributos de calidad, combinando cuatro pilares metodológicos:

  1. *Diseño Guiado por Atributos (ADD) y Trazabilidad EDU–RNF:* Cada decisión técnica se derivó directamente de las educciones funcionales (`EDU-0001` a `EDU-0022`) y de los requisitos no funcionales críticos (`RNF-0001` a `RNF-0015`), priorizando latencia de respuesta $lt.eq 1.5 "s"$ en recepción, integridad transaccional ACID en cobros, resiliencia offline en lectores biométricos (`RNF-0012`) y eficiencia de costos en infraestructura.

  2. *Registro de Decisiones Arquitectónicas (ADR — formato MADR):* Los dilemas estructurales y descartes de alternativas (microservicios, multi-tenancy por BD/esquema, RabbitMQ y pasarelas de pago online) se formalizaron en cinco registros (`ADR-0001` a `ADR-0005`), garantizando transparencia y trazabilidad para futuros mantenedores.

  3. *Modelado Visual Progresivo con Modelo C4 y UML/ERD:* Para facilitar la comprensión por parte del ingeniero de software sin abrumar con detalle redundante, se aplicó zoom progresivo desde la vista de Contexto (`C1`), Contenedores (`C2`) y Despliegue global hasta el nivel de Componentes (`C3`), complementado por esquemas ERD por módulo y diagramas de secuencia filtrados estrictamente a flujos con lógica de dominio compleja o coordinación inter-modular.

  4. *Clean Architecture (Arquitectura Hexagonal — Puertos y Adaptadores):* Cada módulo interno separa estrictamente el núcleo de dominio puro (entidades, objetos de valor y reglas de negocio) de los adaptadores de entrada (controladores REST, filtros JWT) y salida (persistencia JPA, adaptadores *in-process* y exportación de archivos).
]
