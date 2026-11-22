= DESCRIPCIÓN DEL ARTEFACTO

#pad(left: 1.4em)[
  La arquitectura definitiva de *OMS - OmVital Management System* adopta un estilo híbrido de *Monolito Modular con Clean Architecture (Puertos y Adaptadores)* en *Java 21 LTS / Spring Boot 3*, respaldado por una *única base de datos PostgreSQL particionada en esquemas lógicos* (`personal`, `pagos`, `reportes`, `clinico`) y una interfaz *SPA Web* desacoplada por *HTTPS / REST + JWT*. Todo el sistema se despliega mediante *Docker Compose* en un *VPS único autoalojado*, operando las tres sedes físicas de Arequipa (*Cercado/Principal*, *Hunter* y *Cerro Colorado*) sin *brokers* externos ni pasarelas de pago online.
]

== Decisiones Arquitectónicas Vigentes (ADR)

#pad(left: 1.4em)[
  Las decisiones estructurales que gobiernan los diagramas siguientes se resumen en la Tabla 1.

  #figure(
    table(
      columns: (13%, 29%, 58%),
      table.header(
        [*Código*],
        [*Decisión Adoptada*],
        [*Justificación Técnica y de Negocio*],
      ),
      [ADR-0001], [Monolito Modular + Clean Architecture], [Reemplaza microservicios/Kubernetes por un único artefacto Java 21 / Spring Boot 3 en monorepo con fronteras modulares estrictas.],
      [ADR-0002], [PostgreSQL Único con Esquemas Lógicos], [Unifica la persistencia en 4 esquemas (`personal`, `pagos`, `reportes`, `clinico`), habilitando ACID y backups centralizados (`pg_dump`).],
      [ADR-0003], [Multi-Sede por Columna (`sede_id`)], [Descarta *multi-tenancy* por BD/esquema; permite rotación de terapeutas, continuidad de pacientes y consolidado gerencial inmediato.],
      [ADR-0004], [Comunicación Híbrida In-Process], [Elimina RabbitMQ/Outbox: usa llamadas directas `@Transactional` para consistencia inmediata y `ApplicationEventPublisher` para efectos `@Async`.],
      [ADR-0005], [Registro Manual sin Pasarela Online], [El 100% de cobros es presencial en mostrador (Efectivo, Yape/Plin, Transferencia); evita comisiones bancarias y alcance PCI-DSS.],
    ),
    caption: [Resumen de decisiones arquitectónicas vigentes (ADR-0001 a ADR-0005).],
  )
]

== Vistas Generales del Sistema (C4 Niveles 1, 2 y Despliegue)

#pad(left: 1.4em)[
  === Diagrama C4 Nivel 1: Contexto del Sistema

  Muestra al sistema unificado como una sola unidad lógica, sus tres perfiles de usuario (`ACT-0001` Gerente General, `ACT-0002` Cajera/Recepcionista y Personal Clínico) y sus únicas fronteras externas reales: el reloj biométrico *ZKTeco Sensefp M1b* por sede y la exportación local de reportes en el navegador del usuario.

  #figure(
    image("../assets/diagrams/sys-01-c4-c1-contexto.svg", width: 96%),
    caption: [Diagrama C4 Nivel 1 (Contexto) — Sistema Integral Clínico y Administrativo.],
  )

  === Diagrama C4 Nivel 2: Contenedores de Todo el Sistema

  Detalla los contenedores ejecutables y cómo los cuatro módulos internos (`personal`, `pagos`, `reportes`, `clinico`) colaboran en memoria dentro del monolito modular (`@Transactional` para consistencia inmediata y `ApplicationEventPublisher` para efectos `@Async`), persistiendo cada uno en su esquema lógico dedicado de PostgreSQL.

  #figure(
    image("../assets/diagrams/sys-02-c4-c2-contenedores.svg", width: 100%),
    caption: [Diagrama C4 Nivel 2 (Contenedores) — Arquitectura Unificada del Sistema Completo.],
  )

  === Diagrama de Despliegue C4: Todo el Sistema

  Representa el mapeo físico y de contenedores entre las tres sedes de Arequipa (navegador SPA y lector biométrico con buffer offline `RNF-0012`) y el servidor VPS único con Docker Compose y respaldos diarios `pg_dump`.

  #figure(
    image("../assets/diagrams/sys-03-c4-despliegue.svg", width: 95%),
    caption: [Diagrama de Despliegue C4 — Topología en Sedes Físicas y VPS Autoalojado.],
  )
]

== Módulo de Pagos (`services/payments`)

#pad(left: 1.4em)[
  Gestiona la caja diaria (`EDU-0001`), venta de paquetes y cuotas (`EDU-0002`), comisiones a promotores/traumatólogos (`EDU-0005`) y gastos fijos mensuales (`EDU-0021`). El backend calcula internamente el 18% de IGV, el descuento de S/ 25 por evaluación en el día, valida el abono inicial mínimo de S/ 50, separa deuda (`installment`) de cobro efectivo (`installment_payment`) y aplica exclusivamente borrado lógico (`ANNULLED`).

  #figure(
    table(
      columns: (24%, 22%, 54%),
      table.header(
        [*Subdominio (EDU)*],
        [*Actor Autorizado*],
        [*Reglas Críticas y Tablas Afectadas (`schema: pagos`)*],
      ),
      [Caja Diaria (`EDU-0001`)], [`ACT-0001`, `ACT-0002`], [Ingresos/egresos en `cash_transaction` con `sede_id`; cierre diario separando `CASH` (Efectivo) y `YAPE`.],
      [Paquetes y Cuotas (`EDU-0002`)], [`ACT-0002`], [Consentimiento firmado obligatorio, +18% IGV, -S/ 25 mismo día, abono inicial $gt.eq$ S/ 50; deuda al vuelo y habilitación en `clinico`.],
      [Comisiones (`EDU-0005`)], [`ACT-0001`, `ACT-0002`], [Promotor (S/ 25 diario) o Traumatólogo (mensual) en `commission_record`; salida en caja al pagar y exportación `.xlsx`.],
      [Gastos Fijos (`EDU-0021`)], [`ACT-0001` (Exclusivo)], [Alquileres, sueldos, honorarios y servicios en `fixed_expense`; impacta `cash_transaction` solo al desembolsar.],
    ),
    caption: [Subdominios, control de acceso y reglas críticas del Módulo de Pagos.],
  )

  #figure(
    image("../assets/diagrams/mod-pagos-01-c3-componentes.svg", width: 100%),
    caption: [Diagrama C4 Nivel 3 (Componentes) — Módulo de Pagos bajo Clean Architecture.],
  )

  #figure(
    image("../assets/diagrams/mod-pagos-02-erd.svg", width: 100%),
    caption: [Diagrama ERD Simplificado (`schema: pagos` v02) — Separación entre deuda (`installment`) y cobro real (`installment_payment` / `cash_transaction`).],
  )

  #figure(
    image("../assets/diagrams/mod-pagos-03-secuencia.svg", width: 100%),
    caption: [Diagrama de Secuencia Esencial (Pagos) — Venta con abono inicial, cobro de cuota v02 y habilitación clínica in-process.],
  )
]

== Módulo de Reportes (`services/report`)

#pad(left: 1.4em)[
  Provee consolidados contables mensuales inmutables (`EDU-0007`) y gráficos de picos de producción (`EDU-0022`), con acceso exclusivo para el Gerente General (`ACT-0001`). Opera bajo aislamiento estricto de lectura (*Read-Only*) sobre `pagos` y `clinico`, escribiendo únicamente inserciones inmutables (`INSERT-only`) en `reportes.monthly_stats` y calculando consultas personalizadas de forma efímera en memoria RAM.

  #figure(
    image("../assets/diagrams/mod-reportes-01-c3-componentes.svg", width: 100%),
    caption: [Diagrama C4 Nivel 3 (Componentes) — Módulo de Reportes bajo Clean Architecture.],
  )

  #figure(
    image("../assets/diagrams/mod-reportes-02-erd.svg", width: 96%),
    caption: [Diagrama ERD Simplificado (`schema: reportes`) — Tabla consolidada `monthly_stats` y fuentes transversales Read-Only.],
  )

  #figure(
    image("../assets/diagrams/mod-reportes-03-secuencia.svg", width: 100%),
    caption: [Diagrama de Secuencia Esencial (Reportes) — Consolidación mensual inmutable y análisis estadístico en RAM.],
  )
]

== Módulo de Personal (`services/personal`)

#pad(left: 1.4em)[
  Administra sedes (`EDU-0009`), roles JWT (`EDU-0008`), fichas y especialidades de fisioterapeutas (`EDU-0004`, `EDU-0018`), turnos rotativos no solapados entre sedes (`EDU-0017`), marcación biométrica con contingencia offline (`EDU-0003`, `RNF-0012`) e incidencias laborales con bloqueo inmediato de agenda en el módulo clínico (`EDU-0019`).

  #figure(
    image("../assets/diagrams/mod-personal-01-c3-componentes.svg", width: 100%),
    caption: [Diagrama C4 Nivel 3 (Componentes) — Módulo de Personal bajo Clean Architecture.],
  )

  #figure(
    image("../assets/diagrams/mod-personal-02-erd.svg", width: 100%),
    caption: [Diagrama ERD Simplificado (`schema: personal`) — Maestro de sedes (`branch`), roles, turnos, asistencias y excepciones.],
  )

  #figure(
    image("../assets/diagrams/mod-personal-03-secuencia.svg", width: 100%),
    caption: [Diagrama de Secuencia Esencial (Personal) — Marcación biométrica con buffer offline y aprobación de incidencia con bloqueo clínico.],
  )
]
