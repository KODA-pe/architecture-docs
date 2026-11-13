# Diagrama C4 — Nivel 2 (Payments): Contenedores y Fronteras Modulares

En un **Monolito Modular** ([ADR-0001](../../../adr/0001-adopcion-monolito-modular-clean-architecture.md)), el módulo `pagos` convive dentro del mismo contenedor desplegable (`Spring Boot 3`) que `personal`, `reportes` y `clinico`, comunicándose *in-process* ([ADR-0004](../../../adr/0004-eliminacion-broker-mensajeria-y-comunicacion-hibrida-in-process.md)) y persistiendo exclusivamente en su esquema lógico de PostgreSQL ([ADR-0002](../../../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md)).

```mermaid
C4Container
    title C2 — Contenedores y Fronteras del Módulo de Pagos (services/payments)

    Person(gerente, "Gerente General", "ACT-0001. Acceso total incluyendo egresos fijos.")
    Person(cajera, "Recepcionista / Cajera", "ACT-0002. Caja diaria, ventas, cuotas y comisiones.")

    Container(spa, "SPA Web", "Frontend Web", "Vistas de caja diaria, venta de paquetes, comisiones y gastos fijos.")
    Container(proxy, "Reverse Proxy", "Nginx / Caddy", "Terminación TLS 1.3 y enrutamiento REST.")

    Container_Boundary(monolito, "Monolito Modular (Java 21 / Spring Boot 3)") {
        Container(mod_pagos, "Módulo Pagos [Foco]", "Java / Clean Architecture", "Caja diaria (EDU-0001), paquetes y cuotas (EDU-0002), comisiones (EDU-0005), gastos fijos (EDU-0021).")
        Container(mod_clinico, "Módulo Clínico", "Java / Clean Architecture", "Pacientes, evaluaciones y agenda de sesiones.")
        Container(mod_personal, "Módulo Personal", "Java / Clean Architecture", "Sedes (sede_id), roles JWT y derivadores.")
        Container(mod_reportes, "Módulo Reportes", "Java / Clean Architecture", "Agregados gerenciales y estadísticas mensuales.")
    }

    Container_Boundary(pg, "Base de Datos Unificada (PostgreSQL)") {
        ContainerDb(db_pagos, "Esquema: pagos", "PostgreSQL Schema", "patient, package_sale, installment, installment_payment, cash_transaction, referrer, commission_record, fixed_expense.")
        ContainerDb(db_clinico, "Esquema: clinico", "PostgreSQL Schema", "paciente, cita_evaluacion, tratamiento_sesion.")
        ContainerDb(db_personal, "Esquema: personal", "PostgreSQL Schema", "branch (sede_id), employee, role.")
    }

    Rel(gerente, spa, "Opera caja, comisiones y gastos fijos", "HTTPS")
    Rel(cajera, spa, "Cobra paquetes, cuotas y egresos", "HTTPS")
    Rel(spa, proxy, "Envía comandos y consultas", "HTTPS / REST + JWT")
    Rel(proxy, mod_pagos, "Enruta /api/payments/**", "HTTP")

    Rel(mod_pagos, mod_clinico, "Valida paciente/evaluación y habilita/desbloquea citas", "Llamada directa @Transactional")
    Rel(mod_pagos, mod_personal, "Consulta sede_id, roles y derivadores", "Llamada directa in-process")
    Rel(mod_pagos, mod_reportes, "Emite eventos financieros (venta, mora, egreso)", "ApplicationEventPublisher")

    Rel(mod_pagos, db_pagos, "Lee y escribe transacciones financieras", "Spring Data JPA / JDBC")
    Rel(db_pagos, db_clinico, "FK lógica patient_id", "Integridad referencial")
    Rel(db_pagos, db_personal, "FK obligatoria sede_id", "Integridad referencial")

    UpdateLayoutConfig($c4ShapeInRow="2", $c4BoundaryInRow="2")
```

## Reglas de Frontera para `pagos`

- **Escritura Exclusiva ([ADR-0002](../../../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md)):** `pagos` solo ejecuta `INSERT` / `UPDATE` sobre el esquema `pagos`; cualquier cambio de estado clínico (habilitar paquete o desbloquear citas) se invoca a través de los puertos públicos de aplicación del módulo `clinico`.
- **Aislamiento Multi-Sede ([ADR-0003](../../../adr/0003-gestion-multisede-mediante-discriminador-sede-id.md)):** Cada movimiento en `cash_transaction`, `package_sale` y `fixed_expense` lleva `sede_id`, filtrado automáticamente según el contexto JWT de la Cajera o abierto a todas las sedes para el Gerente General.
- **Sin Pasarela Externa ([ADR-0005](../../../adr/0005-registro-financiero-manual-sin-pasarela-de-pagos.md)):** No existen adaptadores salientes hacia bancos o procesadores de tarjetas; la caja distingue internamente `CASH` (Efectivo), `YAPE` y `BANK_TRANSFER`.
