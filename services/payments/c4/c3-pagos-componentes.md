# Diagrama C4 — Nivel 3 (Payments): Componentes Internos (Clean Architecture)

Descompone el interior del **Módulo Pagos** siguiendo Clean Architecture / Hexagonal ([ADR-0001](../../../adr/0001-adopcion-monolito-modular-clean-architecture.md)), en total correspondencia con el modelo de dominio [`step-01-domain-model.puml`](../../../UML/payments/complete/step-01-domain-model.puml) y el esquema v2 [`payment-service-bd-v02.md`](../../../databases/payment-service-bd-v02.md).

```mermaid
flowchart TB
    classDef comp fill:#85BBF0,stroke:#5D9CEC,color:#0F172A,rx:6,ry:6
    classDef core fill:#1168BD,stroke:#0B4884,color:#FFFFFF,rx:6,ry:6
    classDef ext fill:#64748B,stroke:#475569,color:#FFFFFF,rx:6,ry:6
    classDef db fill:#1168BD,stroke:#0B4884,color:#FFFFFF

    Proxy["<b>Reverse Proxy / SPA Web</b><br/><i>[HTTP + JWT]</i>"]:::ext

    subgraph ModuloPagos["Módulo Pagos (services/payments) — Clean Architecture"]
        direction TB

        SecFilter["<b>JwtBranchContextFilter</b><br/><i>[Spring Security Filter]</i><br/>Valida JWT, rol (ACT-0001/0002) y fija contexto sede_id"]:::comp

        subgraph Presentacion["Capa de Presentación (Adaptadores Primarios)"]
            direction LR
            CtrlCash["<b>CashTransactionController</b><br/>EDU-0001: egresos diarios<br/>y arqueo Efectivo/Yape"]:::comp
            CtrlSale["<b>PackageSaleController</b><br/>EDU-0002: ventas, cuotas<br/>y deuda por DNI"]:::comp
            CtrlComm["<b>CommissionController</b><br/>EDU-0005: comisiones<br/>y exportación Excel"]:::comp
            CtrlExp["<b>FixedExpenseController</b><br/>EDU-0021: gastos fijos<br/>(solo Gerente ACT-0001)"]:::comp
        end

        subgraph Aplicacion["Capa de Aplicación (Casos de Uso)"]
            direction LR
            UcCash["<b>CashManagementUseCase</b><br/>Crear, consultar, editar<br/>y anular caja diaria"]:::comp
            UcSale["<b>PackageSale & InstallmentUC</b><br/>IGV 18%, desc. S/ 25, abono >= S/ 50,<br/>consentimiento y deuda al vuelo"]:::comp
            UcComm["<b>CommissionManagementUC</b><br/>Cálculo de comisiones, pago<br/>a caja y reporte mensual"]:::comp
            UcExp["<b>FixedExpenseUseCase</b><br/>Gastos fijos y salida a caja<br/>al confirmar pago"]:::comp
        end

        subgraph Dominio["Capa de Dominio (Núcleo Puro Java)"]
            Domain["<b>Aggregates, Value Objects & Output Ports</b><br/>PackageSale, Installment, InstallmentPayment, CashTransaction, Referrer, CommissionRecord, FixedExpense, Money<br/>Interfaces: *Repository, ClinicalNotificationPort, DomainEventPublisher"]:::core
        end

        subgraph Infra["Capa de Infraestructura (Adaptadores Secundarios)"]
            direction LR
            JpaAdp["<b>JpaPaymentsAdapter</b><br/>Spring Data JPA / Hibernate<br/>sobre schema: pagos"]:::comp
            ClinAdp["<b>InProcessClinicalAdapter</b><br/>Llamada directa @Transactional<br/>(ClinicalNotificationPort)"]:::comp
            PersAdp["<b>InProcessPersonalAdapter</b><br/>Consulta sede_id y<br/>derivadores"]:::comp
            EvtAdp["<b>SpringEventPublisherAdapter</b><br/>Publica eventos de dominio<br/>(ApplicationEventPublisher)"]:::comp
            XlsxAdp["<b>ExcelCommissionExporter</b><br/>Genera archivo .xlsx<br/>para cuadre contable"]:::comp
        end
    end

    subgraph Destinos["Persistencia, Módulos Vecinos y Salida"]
        direction LR
        DbPagos[("<b>PostgreSQL</b><br/>schema: pagos<br/>(8 tablas v2)")]:::db
        ModClinico["<b>Módulo Clínico</b><br/>Habilitación / desbloqueo<br/>de citas"]:::ext
        ModPersonal["<b>Módulo Personal</b><br/>Sedes (branch) y<br/>derivadores"]:::ext
        ModReportes["<b>Módulo Reportes</b><br/>Listeners @Async<br/>(métricas)"]:::ext
        XlsxOut["<b>Descarga .xlsx</b><br/>Stream binario HTTP"]:::ext
    end

    Proxy -->|"Peticiones /api/payments/**"| SecFilter
    SecFilter --> CtrlCash & CtrlSale & CtrlComm & CtrlExp

    CtrlCash --> UcCash
    CtrlSale --> UcSale
    CtrlComm --> UcComm
    CtrlExp --> UcExp

    UcCash & UcSale & UcComm & UcExp --> Domain
    UcComm --> XlsxAdp

    Domain --> JpaAdp & ClinAdp & PersAdp & EvtAdp

    JpaAdp -->|"SQL / JDBC"| DbPagos
    ClinAdp -->|"In-Process"| ModClinico
    PersAdp -->|"In-Process"| ModPersonal
    EvtAdp -.->|"Event Bus en memoria"| ModReportes
    XlsxAdp -->|"application/vnd.openxmlformats"| XlsxOut

    style ModuloPagos fill:#EFF6FF,stroke:#3B82F6,stroke-width:2px
    style Presentacion fill:#F8FAFC,stroke:#93C5FD
    style Aplicacion fill:#F8FAFC,stroke:#93C5FD
    style Dominio fill:#DBEAFE,stroke:#1D4ED8
    style Infra fill:#F8FAFC,stroke:#93C5FD
    style Destinos fill:transparent,stroke:none
```

## Trazabilidad de Reglas de Negocio en los Componentes

| Componente | Responsabilidad Crítica | Referencia |
| :--- | :--- | :--- |
| `JwtBranchContextFilter` | Restringe `FixedExpenseController` a `ACT-0001` y aplica filtro `sede_id` a `ACT-0002` | [ADR-0003](../../../adr/0003-gestion-multisede-mediante-discriminador-sede-id.md) |
| `PackageSale & InstallmentUC` | Recalcula IGV (18%) y descuento (S/ 25) en backend; exige abono inicial $\ge$ S/ 50 y consentimiento informado | [`payments-service.md`](../payments-service.md) |
| `Dominio` (`Installment` vs `InstallmentPayment`) | Separa la deuda (`installment`) del movimiento real (`installment_payment` -> `cash_transaction`) permitiendo pagos parciales | [`payment-service-bd-v02.md`](../../../databases/payment-service-bd-v02.md) |
| `InProcessClinicalAdapter` | Habilita sesiones y desbloquea citas dentro de la misma transacción o inmediatamente post-pago, sin colas RabbitMQ | [ADR-0004](../../../adr/0004-eliminacion-broker-mensajeria-y-comunicacion-hibrida-in-process.md) |
| `JpaPaymentsAdapter` | Garantiza borrado lógico (`ANNULLED`) en anulaciones, conservando historial de auditoría | [`payments-service.md`](../payments-service.md) |
