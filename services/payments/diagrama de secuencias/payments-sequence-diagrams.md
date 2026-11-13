# Diagramas de Secuencia Esenciales — Módulo de Pagos (`services/payments`)

Este documento consolida la vista dinámica del módulo de pagos en **4 diagramas esenciales** alineados con la arquitectura vigente: **Monolito Modular con Clean Architecture** ([ADR-0001](../../../adr/0001-adopcion-monolito-modular-clean-architecture.md)), **PostgreSQL unificado en esquema `pagos`** ([ADR-0002](../../../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md)), **discriminador `sede_id`** ([ADR-0003](../../../adr/0003-gestion-multisede-mediante-discriminador-sede-id.md)), **comunicación híbrida in-process** ([ADR-0004](../../../adr/0004-eliminacion-broker-mensajeria-y-comunicacion-hibrida-in-process.md)) y el **modelo relacional v2 (`installment` + `installment_payment`)** ([`payment-service-bd-v02.md`](../../../databases/payment-service-bd-v02.md)).

---

## Criterio de Reducción y Justificación

Anteriormente existían **18 diagramas** distribuidos en 5 archivos (`seq-01` a `seq-04` + maestro), donde 12 de ellos repetían el mismo flujo CRUD lineal (`UI -> Controller -> Service -> DB`) con cambios menores de campos o ventanas modales, y arrastraban supuestos obsoletos (`payments_db` aislada, llamadas HTTP a un InnovaByte externo y ausencia de `installment_payment`).

Se redujeron a **4 diagramas** bajo la regla de documentar dinámicamente solo flujos con **lógica de negocio compleja, transacciones multi-tabla o coordinación inter-modular**:

| Secuencia Conservada | Requisitos Cubiertos | Justificación Arquitectónica |
| :--- | :--- | :--- |
| **1. Venta de Paquete con Abono Inicial y Habilitación Clínica** | `EDU-0002` (`ILA-PAG-0005`), `EDU-0001`, `EDU-0005` | Único flujo con cálculos fiscales en backend (IGV 18%, descuento S/ 25, abono $\ge$ S/ 50), transacción ACID sobre 5 tablas y comunicación híbrida *in-process* (llamada síncrona a `clinico` + evento en memoria a `reportes`). |
| **2. Deuda Dinámica por DNI y Cobro de Cuota (`v02`)** | `EDU-0002` (`ILA-PAG-0006`, `ILA-PAG-0007`) | Ilustra la separación crítica del modelo `v02` entre obligación (`installment`) y pago real (`installment_payment` $\rightarrow$ `cash_transaction`), el cálculo de deuda al vuelo y el desbloqueo condicional de citas. |
| **3. Liquidación de Obligaciones (Comisiones / Gastos Fijos) y Excel** | `EDU-0005` (`ILA-PAG-0009..0011`), `EDU-0021` (`ILA-PAG-0013`) | Muestra la consulta *in-process* al módulo `personal`, la regla donde una obligación pendiente solo genera salida en `cash_transaction` al pagarse, y la exportación `.xlsx` sin mutar la BD. |
| **4. Patrón Transversal: Consulta, Edición y Anulación Lógica** | `EDU-0001` (`ILA-PAG-0001..0004`), `ILA-PAG-0008`, `0011..0016` | Condensa en un solo patrón los 12 diagramas CRUD repetitivos (egresos operativos, egresos fijos y anulaciones): filtro por `sede_id`/rol vía JWT, confirmación modal y borrado lógico (`status = 'ANNULLED'`). |

---

## 1. Venta de Paquete con Abono Inicial y Habilitación Clínica

Orquesta validaciones financieras en dominio, inserción atómica en `pagos` y habilitación inmediata de atenciones en el módulo `clinico` dentro de la misma transacción/solicitud.

```mermaid
sequenceDiagram
    autonumber
    actor Cajera as ACT-0002 (Cajera)
    participant UI as SPA Web (Recepción)
    participant Ctrl as PackageSaleController
    participant UC as PackageSaleUseCase
    participant Clinico as Módulo Clínico (In-Process)
    participant DB as PostgreSQL (schema: pagos)
    participant Bus as ApplicationEventPublisher

    Cajera->>UI: Ingresa DNI, precio base, abono inicial, consentimiento y flags (IGV/eval.)
    UI->>Ctrl: POST /api/payments/package-sales (JWT con sede_id)
    Ctrl->>UC: registerPackageSale(cmd, sedeId)

    UC->>Clinico: findPatientAndSameDayEval(dni)
    alt Paciente no existe en clinico
        Clinico-->>UC: NotFound
        UC-->>Ctrl: PatientNotFoundException
        Ctrl-->>UI: HTTP 400 ("DNI no pertenece a un paciente registrado")
    else Paciente válido
        Note over UC: Reglas de dominio:<br/>• Consentimiento informado firmado = true<br/>• Abono inicial >= S/ 50<br/>• +18% IGV si requiere factura<br/>• -S/ 25 si evaluación es el mismo día

        alt Regla de negocio incumplida (ej. abono < S/ 50)
            UC-->>Ctrl: DomainValidationException
            Ctrl-->>UI: HTTP 400 Bad Request
        else Datos válidos (Transacción ACID)
            UC->>DB: INSERT pagos.package_sale (sede_id, status='PARTIALLY_PAID'/'PAID')
            UC->>DB: INSERT pagos.installment (is_initial_payment=true)
            UC->>DB: INSERT pagos.cash_transaction (type='INFLOW', sede_id, method)
            UC->>DB: INSERT pagos.installment_payment (installment_id, cash_tx_id)
            opt Incluye derivador externo (referrer_id)
                UC->>DB: INSERT pagos.commission_record (status='PENDING')
            end

            UC->>Clinico: notifyPackagePaid(externalPatientId, saleId)
            Clinico-->>UC: Asistencias y plan habilitados (misma TX)
            UC->>Bus: publish(PackageSaleCompletedEvent)
            Note right of Bus: Módulo Reportes escucha @Async AFTER_COMMIT

            UC-->>Ctrl: SaleCreatedDTO
            Ctrl-->>UI: HTTP 201 Created
        end
    end
```

---

## 2. Consulta de Deuda Dinámica y Cobro de Cuota (`v02`)

La deuda nunca se almacena como columna estática: se calcula en tiempo real restando las cuotas abonadas. Cada cobro crea un `installment_payment` vinculado a `cash_transaction` y desbloquea citas si regulariza el saldo.

```mermaid
sequenceDiagram
    autonumber
    actor Cajera as ACT-0002 (Cajera)
    participant UI as SPA Web (Recepción)
    participant Ctrl as PackageSaleController
    participant UC as InstallmentCollectionUseCase
    participant DB as PostgreSQL (schema: pagos)
    participant Clinico as Módulo Clínico (In-Process)

    Note over Cajera,DB: A. Consulta de deuda al vuelo por DNI (Solo Lectura)
    Cajera->>UI: Busca paciente por DNI
    UI->>Ctrl: GET /api/payments/package-sales/history?dni={dni}
    Ctrl->>UC: getHistoryAndDebt(dni, sedeId)
    UC->>DB: SELECT package_sale + SUM(installment.paid_amount) WHERE status != 'ANNULLED'
    DB-->>UC: Ventas y saldo pendiente = total_amount - sum_paid
    UC-->>Ctrl: DebtSummaryDTO
    Ctrl-->>UI: HTTP 200 OK

    Note over Cajera,Clinico: B. Cobro de cuota subsiguiente (ej. S/ 40)
    Cajera->>UI: Registra pago de cuota (monto, método: Efectivo/Yape)
    UI->>Ctrl: POST /api/payments/installments/{id}/payments (JWT con sede_id)
    Ctrl->>UC: payInstallment(installmentId, amount, method, sedeId)
    UC->>DB: SELECT installment & package_sale
    alt Venta anulada o cuota ya saldada
        UC-->>Ctrl: InvalidSaleStateException
        Ctrl-->>UI: HTTP 400 Bad Request
    else Cuota con saldo pendiente (Transacción ACID)
        UC->>DB: INSERT pagos.cash_transaction (type='INFLOW', category='INSTALLMENT_COLLECTION', sede_id)
        UC->>DB: INSERT pagos.installment_payment (installment_id, cash_tx_id, amount)
        UC->>DB: UPDATE pagos.installment (paid_amount += amount, status)
        UC->>DB: Recalcula saldo de package_sale (actualiza status='PAID' si saldo == 0)
        opt Regulariza mora o deuda pendiente
            UC->>Clinico: unblockFutureAppointments(externalPatientId, saleId)
        end
        UC-->>Ctrl: PaymentRegisteredDTO
        Ctrl-->>UI: HTTP 200 OK
    end
```

---

## 3. Liquidación de Comisiones Externas / Gastos Fijos y Exportación Excel

Distingue el registro de la obligación (`PENDING` / `is_paid=false`) de su desembolso real en caja (`cash_transaction` tipo `OUTFLOW`), e integra lectura con `personal` y descarga `.xlsx`.

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as ACT-0001 (Gerente) / ACT-0002 (Cajera)
    participant UI as SPA Web
    participant Ctrl as Commission / FixedExpenseController
    participant UC as Commission / FixedExpenseUseCase
    participant Personal as Módulo Personal (In-Process)
    participant DB as PostgreSQL (schema: pagos)
    participant Excel as ExcelCommissionExporter

    Note over Usuario,DB: A. Registro y liquidación a caja (Comisión o Gasto Fijo - solo ACT-0001 en gastos fijos)
    Usuario->>UI: Selecciona derivador (o rubro fijo), monto y estado (Pendiente / Pagado)
    opt Es comisión externa
        UI->>Ctrl: GET /api/payments/referrers/active
        Ctrl->>Personal: getActiveReferrersAndPaymentInfo()
        Personal-->>Ctrl: Teléfono Yape o cuenta bancaria (solo lectura)
        Ctrl-->>UI: Autocompleta datos de pago
    end

    UI->>Ctrl: POST /api/payments/commissions (o /fixed-expenses)
    Ctrl->>UC: registerOrSettle(cmd, sedeId, role)
    UC->>DB: INSERT commission_record (o fixed_expense)
    opt Si se confirma pago inmediato (status='PAID' / is_paid=true)
        UC->>DB: INSERT pagos.cash_transaction (type='OUTFLOW', sede_id)
        UC->>DB: UPDATE registro SET cash_transaction_id = tx_id, payment_date = NOW()
    end
    UC-->>Ctrl: Registro creado
    Ctrl-->>UI: HTTP 201 Created

    Note over Usuario,Excel: B. Reporte mensual filtrado por traumatólogo y descarga Excel (Solo Lectura)
    Usuario->>UI: Filtra mes + médico y presiona "Exportar a Excel"
    UI->>Ctrl: GET /api/payments/commissions/export?month={m}&referrerId={id}
    Ctrl->>UC: exportMonthlyCommissions(month, referrerId)
    UC->>DB: SELECT commission_record + patient + referrer WHERE status != 'ANNULLED'
    UC->>Excel: buildWorkbook(records)
    Excel-->>UC: byte[] (.xlsx)
    UC-->>Ctrl: Stream binario
    Ctrl-->>UI: HTTP 200 OK (Descarga local .xlsx sin alterar BD)
```

---

## 4. Patrón Transversal: Consulta, Edición y Anulación Lógica

Aplica de manera uniforme a **Egresos Operativos (`EDU-0001`)**, **Gastos Fijos (`EDU-0021`)**, **Edición/Anulación de Comisiones (`EDU-0005`)** y **Anulación de Ventas (`EDU-0002`)**.

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as ACT-0001 / ACT-0002
    participant UI as SPA Web + Modal Confirmación
    participant Filter as JwtBranchContextFilter
    participant Ctrl as Payments REST Controller
    participant UC as Payments UseCase
    participant DB as PostgreSQL (schema: pagos)

    Usuario->>UI: Ejecuta consulta por fecha/mes, edición o anulación
    opt Operación sensible (Actualizar o Anular)
        UI->>UI: Despliega modal de confirmación obligatorio
        Usuario->>UI: Confirma acción
    end

    UI->>Filter: HTTP GET / PUT / PATCH (.../annul) + JWT
    Filter->>Filter: Valida rol (ACT-0001 exclusivo para gastos fijos) y extrae sede_id
    Filter->>Ctrl: Petición autorizada con contexto de sede
    Ctrl->>UC: execute(id, sedeId, dto?)

    alt Solo Lectura (Historial / Arqueo Caja Efectivo vs Yape)
        UC->>DB: SELECT ... WHERE sede_id = :sedeId AND status != 'ANNULLED'
        DB-->>UC: Lista filtrada (con sumatoria o desglose Efectivo/Yape)
    else Edición o Anulación (Borrado Lógico)
        UC->>DB: SELECT status FROM tabla WHERE id = :id AND sede_id = :sedeId
        alt No existe o ya está ANNULLED
            UC-->>Ctrl: InvalidStateException
            Ctrl-->>UI: HTTP 400 / 404 ("Registro no encontrado o ya anulado")
        else Registro activo
            UC->>DB: UPDATE tabla SET status = 'ANNULLED' (o actualiza campos)
            Note right of DB: Si se anula PackageSale, cascada lógica a Installment y CommissionRecord pendiente
            UC-->>Ctrl: Operación confirmada
        end
    end
    Ctrl-->>UI: HTTP 200 OK
```

### Mapa de Operaciones Cubiertas por el Patrón Transversal

| Dominio | Operaciones Cubiertas | Tabla en `schema: pagos` | Regla Específica |
| :--- | :--- | :--- | :--- |
| **Egresos Operativos (`EDU-0001`)** | Crear, consultar por fecha, editar, anular | `cash_transaction` (`type='OUTFLOW'`) | Arqueo diario separa totales en `CASH` (Efectivo) y `YAPE` |
| **Venta de Paquetes (`EDU-0002`)** | Anular venta | `package_sale`, `installment`, `commission_record` | Anulación en cascada lógica (comisiones no pagadas pasan a `ANNULLED`) |
| **Comisiones Externas (`EDU-0005`)** | Editar estado/monto, anular | `commission_record` (+ `cash_transaction` si pasa a `PAID`) | Requiere modal de confirmación |
| **Egresos Fijos (`EDU-0021`)** | Consultar historial mensual con sumatoria, editar, anular | `fixed_expense` | Acceso exclusivo `ACT-0001` (Gerente General) |
