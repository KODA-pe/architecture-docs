= CONCLUSIONES

== Del marco conceptual

#pad(left: 1.4em)[
  La adopción combinada del estilo de *Monolito Modular* y *Clean Architecture* demostró que el desacople lógico y la alta mantenibilidad no exigen distribuir físicamente el sistema en microservicios. Para una organización con límites acotados y tres sedes locales, la separación en capas (Presentación, Aplicación, Dominio e Infraestructura) mediante puertos e interfaces explícitas previene el acoplamiento indebido sin introducir latencia de red, complejidad de *Sagas* ni sobrecostos de orquestación en la nube.

  Asimismo, la utilización del *Modelo C4* junto con *Registros de Decisiones Arquitectónicas (ADR)* y diagramas de secuencia filtrados exclusivamente a flujos críticos evita la sobrecarga documental, entregando al ingeniero de software una guía visual comprensible, uniforme y directamente trazable a requisitos funcionales (`EDU`) y no funcionales (`RNF`).
]

== Del producto

#pad(left: 1.4em)[
  Para *OMS - OmVital Management System*, la unificación en *Java 21 / Spring Boot 3* con *PostgreSQL por esquemas lógicos* y discriminador `sede_id` resuelve de raíz los problemas operativos identificados en la clínica: habilita la atención clínica inmediata tras el cobro en recepción mediante transacciones ACID *in-process*, permite la rotación flexible de fisioterapeutas entre Cercado, Hunter y Cerro Colorado, y consolida la rentabilidad gerencial en tiempo real sin *brokers* externos ni pasarelas de pago innecesarias.

  El despliegue contenedorizado mediante *Docker Compose* en un único VPS autoalojado, complementado con el buffer offline del lector biométrico ZKTeco y respaldos diarios centralizados (`pg_dump`), equilibra disponibilidad, seguridad y viabilidad económica para la clínica.
]
