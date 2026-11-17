# Diagrama C4 — Nivel 2 (Payments): Contenedores y Fronteras Modulares

En un **Monolito Modular** ([ADR-0001](../../../adr/0001-adopcion-monolito-modular-clean-architecture.md)), el módulo `pagos` convive dentro del mismo contenedor desplegable (`Spring Boot 3`) que `personal`, `reportes` y `clinico`, comunicándose *in-process* ([ADR-0004](../../../adr/0004-eliminacion-broker-mensajeria-y-comunicacion-hibrida-in-process.md)) y persistiendo exclusivamente en su esquema lógico de PostgreSQL ([ADR-0002](../../../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md)).

```mermaid
flowchart TB
    classDef person fill:#08427B,stroke:#052E56,color:#FFFFFF,rx:8,ry:8
    classDef container fill:#438DD5,stroke:#2E6295,color:#FFFFFF,rx:6,ry:6
    classDef focus fill:#1168BD,stroke:#0B4884,stroke-width:3px,color:#FFFFFF,rx:6,ry:6
    classDef db fill:#1168BD,stroke:#0B4884,color:#FFFFFF
    classDef dbMuted fill:#64748B,stroke:#475569,color:#FFFFFF

    subgraph Actores["Usuarios de Pagos"]
        direction LR
        Gerente["<b>Gerente General</b><br/><i>[ACT-0001]</i><br/>Acceso total + egresos fijos"]:::person
        Cajera["<b>Recepcionista / Cajera</b><br/><i>[ACT-0002]</i><br/>Caja, ventas, cuotas, comisiones"]:::person
    end

    SPA["<b>SPA Web</b><br/><i>[Frontend Web]</i><br/>Vistas de caja, paquetes, comisiones y gastos"]:::container
    Proxy["<b>Reverse Proxy</b><br/><i>[Nginx / Caddy]</i><br/>Terminación TLS 1.3 y enrutamiento REST"]:::container

    subgraph Monolito["Contenedor: Monolito Modular (Java 21 / Spring Boot 3)"]
        direction TB
        ModPagos["<b>Módulo Pagos [Foco]</b><br/><i>[Clean Architecture]</i><br/>Caja (EDU-0001), Paquetes/Cuotas (EDU-0002),<br/>Comisiones (EDU-0005), Gastos Fijos (EDU-0021)"]:::focus

        subgraph Vecinos["Módulos Vecinos (In-Process)"]
            direction LR
            ModClinico["<b>Módulo Clínico</b><br/>Pacientes, evaluaciones<br/>y citas"]:::container
            ModPersonal["<b>Módulo Personal</b><br/>Sedes (sede_id), roles<br/>JWT y derivadores"]:::container
            ModReportes["<b>Módulo Reportes</b><br/>Estadísticas y agregados<br/>gerenciales"]:::container
        end
    end

    subgraph PG["Contenedor: PostgreSQL Unificado"]
        direction LR
        DbPagos[("<b>schema: pagos</b><br/>package_sale, installment,<br/>installment_payment, cash_transaction,<br/>commission_record, fixed_expense")]:::db
        DbClinico[("<b>schema: clinico</b><br/>paciente,<br/>cita_evaluacion")]:::dbMuted
        DbPersonal[("<b>schema: personal</b><br/>branch (sede_id),<br/>employee, role")]:::dbMuted
    end

    Gerente -->|"HTTPS"| SPA
    Cajera -->|"HTTPS"| SPA
    SPA -->|"HTTPS / REST + JWT"| Proxy
    Proxy -->|"Enruta /api/payments/**"| ModPagos

    ModPagos -->|"Llamada directa @Transactional<br/>(habilita / desbloquea citas)"| ModClinico
    ModPagos -->|"Consulta in-process<br/>(sede_id, derivadores)"| ModPersonal
    ModPagos -.->|"ApplicationEventPublisher<br/>(eventos post-commit)"| ModReportes

    ModPagos -->|"Spring Data JPA / JDBC"| DbPagos
    DbPagos -.->|"FK patient_id"| DbClinico
    DbPagos -.->|"FK sede_id"| DbPersonal

    style Actores fill:transparent,stroke:none
    style Monolito fill:#EFF6FF,stroke:#3B82F6,stroke-width:2px
    style Vecinos fill:#F8FAFC,stroke:#93C5FD,stroke-dasharray: 4 4
    style PG fill:#F8FAFC,stroke:#64748B,stroke-width:2px
```

## Reglas de Frontera para `pagos`

- **Escritura Exclusiva ([ADR-0002](../../../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md)):** `pagos` solo ejecuta `INSERT` / `UPDATE` sobre el esquema `pagos`; cualquier cambio de estado clínico (habilitar paquete o desbloquear citas) se invoca a través de los puertos públicos de aplicación del módulo `clinico`.
- **Aislamiento Multi-Sede ([ADR-0003](../../../adr/0003-gestion-multisede-mediante-discriminador-sede-id.md)):** Cada movimiento en `cash_transaction`, `package_sale` y `fixed_expense` lleva `sede_id`, filtrado automáticamente según el contexto JWT de la Cajera o abierto a todas las sedes para el Gerente General.
- **Sin Pasarela Externa ([ADR-0005](../../../adr/0005-registro-financiero-manual-sin-pasarela-de-pagos.md)):** No existen adaptadores salientes hacia bancos o procesadores de tarjetas; la caja distingue internamente `CASH` (Efectivo), `YAPE` y `BANK_TRANSFER`.
