# Diagramas de Secuencia Consolidados — Servicio de Pagos (`payments-service`)

Este documento consolida la arquitectura dinámica y las secuencias de interacción para el módulo de pagos, cubriendo los 4 dominios funcionales y los 16 requisitos del catálogo formal (**ILA-PAG-0001** a **ILA-PAG-0016**).

---

## Estructura de Documentación

Los diagramas detallados por caso de uso se encuentran modularizados en los siguientes artefactos:

| Archivo | Dominio Operativo | Requisitos Cubiertos | Actores Principales |
| :--- | :--- | :--- | :--- |
| [seq-01-egresos-operativos.md](file:///c:/Users/luisg/OneDrive/Documentos/Universidad/8vo/Arquitectura/architecture-docs/services/payments/diagrama%20de%20secuencias/seq-01-egresos-operativos.md) | Egresos Operativos Diarios | ILA-PAG-0001 a ILA-PAG-0004 | ACT-0001 (Gerente), ACT-0002 (Cajera) |
| [seq-02-entradas-ventas-paquetes.md](file:///c:/Users/luisg/OneDrive/Documentos/Universidad/8vo/Arquitectura/architecture-docs/services/payments/diagrama%20de%20secuencias/seq-02-entradas-ventas-paquetes.md) | Entradas por Ventas y Cuotas | ILA-PAG-0005 a ILA-PAG-0008 | ACT-0002, ORG-0003 (Frontend Clínico), API_InnovaByte |
| [seq-03-comisiones-externas.md](file:///c:/Users/luisg/OneDrive/Documentos/Universidad/8vo/Arquitectura/architecture-docs/services/payments/diagrama%20de%20secuencias/seq-03-comisiones-externas.md) | Comisiones Externas | ILA-PAG-0009 a ILA-PAG-0012 | ACT-0001, ACT-0002, Módulo de Personal |
| [seq-04-egresos-fijos-mensuales.md](file:///c:/Users/luisg/OneDrive/Documentos/Universidad/8vo/Arquitectura/architecture-docs/services/payments/diagrama%20de%20secuencias/seq-04-egresos-fijos-mensuales.md) | Egresos Fijos Mensuales | ILA-PAG-0013 a ILA-PAG-0016 | ACT-0001 (Gerente General) |

---

## 1. Patrón Arquitectónico de Interacción Dinámica

En concordancia con los registros de decisiones arquitectónicas **ADR-0001** (Clean Architecture en Monolito Modular) y **ADR-0004** (Comunicación In-Process), el servicio de pagos organiza sus llamadas dinámicas en 4 capas:

```mermaid
sequenceDiagram
    autonumber
    box rgb(235, 240, 255) Capa de Presentación
        participant UI as Frontend / IGU
        participant Controller as REST Controller
    end
    box rgb(240, 255, 240) Capa de Aplicación y Dominio
        participant Service as Application Service
        participant Domain as Domain Model & Rules
    end
    box rgb(255, 245, 235) Capa de Infraestructura
        participant Repo as Repository
        participant DB as PostgreSQL (payments_db)
    end
    box rgb(250, 240, 255) Integraciones
        participant External as Módulo Clínico / Personal
    end

    UI->>Controller: HTTP Request (JSON / Params)
    Controller->>Service: Execute Use Case (DTO)
    Service->>Domain: Valida reglas de negocio (monto >= S/50, cálculos IGV/descuentos)
    Domain-->>Service: Reglas validadas / Datos computados
    Service->>Repo: Persistir cambios atómicos
    Repo->>DB: INSERT / UPDATE / SELECT (Transacción ACID)
    DB-->>Repo: Confirmación de persistencia
    Repo-->>Service: Entidad persistida

    opt Evento o Notificación In-Process
        Service->>External: Dispatch Domain Event / Direct Call (API_InnovaByte)
        External-->>Service: ACK (Habilitar citas / desbloqueo)
    end

    Service-->>Controller: Return Result DTO
    Controller-->>UI: HTTP Response (200 / 201 / 400 / 404)
    UI-->>UI: Renderiza vista / Alerta emergente MSG
```

---

## 2. Secuencia Maestra End-to-End: Venta de Paquete, Cobro de Cuota y Cierre de Caja

```mermaid
sequenceDiagram
    autonumber
    actor Cajera as ACT-0002 (Cajera)
    participant UI as Sistema Frontend
    participant PaymentCtrl as Payments API
    participant PaymentSvc as PaymentService
    participant DB as payments_db
    participant ClinicalSvc as ClinicalModule

    Note over Cajera,ClinicalSvc: 1. Apertura y Venta con Abono Inicial (ILA-PAG-0005)
    Cajera->>UI: Registra venta (DNI, Paquete, Abono S/ 50, Consentimiento)
    UI->>PaymentCtrl: POST /api/payments/package-sales
    PaymentCtrl->>PaymentSvc: createSaleWithInitialPayment(dto)
    PaymentSvc->>DB: BEGIN TRANSACTION
    PaymentSvc->>DB: INSERT PackageSale (status='pendiente')
    PaymentSvc->>DB: INSERT Installment (paid_amount=50, is_initial=true)
    PaymentSvc->>DB: INSERT CashTransaction (type='ingreso', amount=50)
    PaymentSvc->>DB: COMMIT
    PaymentSvc->>ClinicalSvc: notifyPackageSold(patient_id, sale_id)
    ClinicalSvc-->>PaymentSvc: Habilitación asistencias confirmada
    PaymentSvc-->>PaymentCtrl: SaleCreatedDTO
    PaymentCtrl-->>UI: HTTP 201 Created

    Note over Cajera,ClinicalSvc: 2. Cobro de Cuota Subsiguiente de S/ 40 (ILA-PAG-0007)
    Cajera->>UI: Paciente abona cuota parcial S/ 40
    UI->>PaymentCtrl: PUT /api/payments/sales/{id}/installments
    PaymentCtrl->>PaymentSvc: payInstallment(sale_id, amount=40)
    PaymentSvc->>DB: INSERT InstallmentPayment + INSERT CashTransaction(ingreso=40)
    PaymentSvc->>DB: Recalcular deuda al vuelo
    PaymentSvc->>ClinicalSvc: notifyInstallmentPaid(patient_id)
    PaymentSvc-->>PaymentCtrl: InstallmentPaidDTO
    PaymentCtrl-->>UI: HTTP 200 OK

    Note over Cajera,ClinicalSvc: 3. Consulta de Deuda Dinámica (ILA-PAG-0006)
    Cajera->>UI: Búsqueda por DNI de paciente
    UI->>PaymentCtrl: GET /api/payments/packages/history?dni={dni}
    PaymentCtrl->>PaymentSvc: calculateDynamicDebt(dni)
    PaymentSvc->>DB: SELECT total_amount - SUM(paid_amount)
    DB-->>PaymentSvc: saldo_calculado
    PaymentSvc-->>PaymentCtrl: DebtSummaryDTO
    PaymentCtrl-->>UI: HTTP 200 OK (Renderiza estado de cuenta al vuelo)
```
