# Diagramas de Secuencia — Entradas por Venta de Paquetes y Cuotas

**Educción:** EDU-0002  
**Tablas afectadas:** `Patient`, `PackageSale`, `Installment`, `InstallmentPayment`, `CashTransaction`, `CommissionRecord` (`payments_db`)  
**Actores:** ACT-0002 (Cajera), ORG-0003 (Sistema Frontend Clínico InnovaByte), `API_InnovaByte` (Módulo Clínico)  
**Ilaciones cubiertas:** ILA-PAG-0005, ILA-PAG-0006, ILA-PAG-0007, ILA-PAG-0008  

---

## 1. Crear Registro de Entrada de Dinero y Venta de Paquete (ILA-PAG-0005 v02.04)

Flujo de integración backend donde se recibe la venta desde el frontend clínico (ORG-0003), se recalculan las fórmulas financieras internamente, se persiste atómicamente en múltiples tablas y se notifica al módulo clínico para habilitar citas.

```mermaid
sequenceDiagram
    autonumber
    actor Cajera as ACT-0002 (Cajera)
    participant Front as ORG-0003 (Frontend Clínico)
    participant Endpoint as ENDPOINT-PAG-0001 (PackageSaleController)
    participant Service as PackageSaleService
    participant DB as payments_db
    participant Clinico as API_InnovaByte (Módulo Clínico)

    Cajera->>Front: Ingresa DNI, selecciona paquete, marca consentimiento, abono inicial
    Cajera->>Front: Presiona BTN-0005 ("Registrar Venta")
    Front->>Endpoint: HTTP POST /api/payments/package-sales (Payload JSON: dni, base_price, initial_payment, igv_flag, discount_flag, referrer_id?)
    activate Endpoint

    Endpoint->>Service: registerPackageSale(dto)
    activate Service

    rect rgb(240, 245, 255)
    Note over Service,DB: Verificación y Apertura Transaccional
    Service->>DB: Apertura conexión y tablas (Patient, PackageSale, Installment, CashTransaction)
    Service->>DB: SELECT * FROM Patient WHERE id_number = :dni
    DB-->>Service: Datos del paciente

    alt Paciente no encontrado
        Service-->>Endpoint: Throw PatientNotFoundException
        Endpoint-->>Front: HTTP 400 Bad Request (MSG-PAG-0001: "El DNI ingresado no pertenece a un paciente registrado")
        Front-->>Cajera: Muestra alerta de paciente no registrado
    else Paciente existe
        Note over Service: 1. Valida abono inicial >= S/ 50<br/>2. Calcula IGV (18%) si igv_flag=true<br/>3. Aplica descuento S/ 25 si discount_flag=true<br/>4. Determina total_amount
        alt Abono inicial < S/ 50
            Service-->>Endpoint: Throw InvalidInitialPaymentException
            Endpoint-->>Front: HTTP 400 Bad Request (MSG-PAG-0001: "Abono menor al mínimo permitido")
        else Montos válidos y consistentes
            Note over Service,DB: Transacción Atómica ACID
            Service->>DB: INSERT INTO PackageSale (patient_id, base_price, igv_amount, discount_amount, total_amount, status='pendiente', informed_consent=true)
            DB-->>Service: sale_id generado
            
            Service->>DB: INSERT INTO Installment (sale_id, amount=initial_payment, paid_amount=initial_payment, status='pagada', is_initial_payment=true)
            DB-->>Service: installment_id generado

            Service->>DB: INSERT INTO CashTransaction (type='ingreso', category='venta_paquete', amount=initial_payment, method='Efectivo/Yape')
            DB-->>Service: cash_transaction_id generado

            opt Si incluye referrer_id (derivador externo)
                Service->>DB: INSERT INTO CommissionRecord (referrer_id, sale_id, amount=default_comm, status='Pendiente', cash_transaction_id=null)
            end

            Service->>DB: COMMIT TRANSACTION y Cierra tablas

            Note over Service,Clinico: Notificación Inter-Módulos In-Process
            Service->>Clinico: POST /internal/clinical/patients/{id}/packages-enabled (sale_id, patient_id)
            Clinico-->>Service: HTTP 200 OK (Asistencias y Citas Habilitadas)

            Service-->>Endpoint: Registro exitoso
            deactivate Service
            Endpoint-->>Front: HTTP 200 OK (MSG-PAG-0002: "Entrada de dinero y abono inicial calculados y registrados exitosamente")
            deactivate Endpoint
            Front-->>Cajera: Muestra confirmación de registro y comprobante generado
        end
    end
    end
```

---

## 2. Consultar Historial de Paquetes y Deuda Dinámica por DNI (ILA-PAG-0006 v02.05)

Operación de lectura backend donde la deuda no se lee de una columna estática, sino que se calcula en tiempo real restando los abonos registrados en `Installment` al `total_amount` de `PackageSale`.

```mermaid
sequenceDiagram
    autonumber
    actor Cajera as ACT-0002 (Cajera)
    participant Front as ORG-0003 (Frontend Clínico)
    participant Endpoint as ENDPOINT-PAG-0006 (PackageSaleController)
    participant Service as PackageSaleService
    participant DB as payments_db

    Cajera->>Front: Ingresa DNI y solicita búsqueda de historial
    Front->>Endpoint: HTTP GET /api/payments/packages/history?dni={dni}
    activate Endpoint
    Endpoint->>Service: getPatientPackageHistory(dni)
    activate Service

    Service->>DB: SELECT * FROM Patient WHERE id_number = :dni
    DB-->>Service: Resultado paciente

    alt Paciente no registrado
        Service-->>Endpoint: Throw PatientNotFoundException
        Endpoint-->>Front: HTTP 404 Not Found (MSG-PAG-0003: "Paciente no encontrado")
        Front-->>Cajera: Muestra advertencia en pantalla
    else Paciente existe
        Service->>DB: SELECT * FROM PackageSale WHERE patient_id = :patient_id AND status != 'anulado'
        DB-->>Service: Lista de ventas del paciente (PackageSale[])
        
        loop Para cada venta encontrada
            Service->>DB: SELECT SUM(paid_amount) FROM Installment WHERE sale_id = :sale_id AND status != 'anulado'
            DB-->>Service: total_pagado
            Note over Service: Cálculo al vuelo:<br/>deuda_actual = total_amount - total_pagado
        end

        Service->>DB: Cierra tablas (Patient, PackageSale, Installment) y conexión
        Service-->>Endpoint: DTO estructurado (Paciente, Ventas, DeudaCalculada)
        deactivate Service
        Endpoint-->>Front: HTTP 200 OK (MSG-PAG-0004: JSON estructurado)
        deactivate Endpoint
        Front->>Front: Renderiza tabla de compras y balance de saldos
        Front-->>Cajera: Visualiza historial y deuda actual en pantalla
    end
```

---

## 3. Actualizar Registro de Entrada: Cobro de Cuota y Regularización (ILA-PAG-0007 v02.01)

Registro de pagos parciales posteriores (ej. S/ 40) que amortizan la deuda de una venta y desbloquean reservas de citas en el sistema clínico.

```mermaid
sequenceDiagram
    autonumber
    actor Cajera as ACT-0002 (Cajera)
    participant Front as ORG-0003 (Frontend Clínico)
    participant Endpoint as ENDPOINT-PAG-0007 (InstallmentController)
    participant Service as InstallmentService
    participant DB as payments_db
    participant Agendamiento as API_InnovaByte (Agendamiento Citas)

    Cajera->>Front: Ingresa cuota (ej. S/ 40) para una venta existente y confirma
    Front->>Endpoint: HTTP PUT /api/payments/sales/{sale_id}/installments (Payload: amount, payment_method)
    activate Endpoint
    Endpoint->>Service: processInstallmentPayment(sale_id, amount, method)
    activate Service

    Service->>DB: SELECT * FROM PackageSale WHERE id = :sale_id
    DB-->>Service: Datos de la venta

    alt Venta no existe o deuda totalmente cancelada
        Service-->>Endpoint: Throw InvalidSaleOperationException
        Endpoint-->>Front: HTTP 400 Bad Request (MSG-PAG-0005: "Venta no encontrada o deuda previamente cancelada")
        Front-->>Cajera: Notifica error de venta o sin saldo pendiente
    else Venta vigente con saldo
        Service->>DB: INSERT INTO Installment (sale_id, amount=:amount, paid_amount=:amount, status='pagada', is_initial_payment=false)
        DB-->>Service: installment_id

        Service->>DB: INSERT INTO CashTransaction (type='ingreso', category='cobro_cuota', amount=:amount, method=:method)
        DB-->>Service: cash_transaction_id

        Note over Service: Recalcula saldo restante de la venta
        Service->>DB: SELECT total_amount - SUM(paid_amount) AS saldo FROM Installment i JOIN PackageSale s ON i.sale_id = s.id WHERE s.id = :sale_id
        DB-->>Service: saldo_restante

        opt Si saldo regularizado o cumple umbral de desbloqueo
            Note over Service,Agendamiento: Notificación de regularización
            Service->>Agendamiento: POST /internal/scheduling/patients/{id}/unblock-appointments (patient_id, sale_id)
            Agendamiento-->>Service: HTTP 200 OK (Citas desbloqueadas)
        end

        opt Si saldo_restante == 0
            Service->>DB: UPDATE PackageSale SET status = 'cancelado' WHERE id = :sale_id
        end

        Service->>DB: COMMIT TRANSACTION y Cierra tablas
        Service-->>Endpoint: Cuota registrada con éxito
        deactivate Service
        Endpoint-->>Front: HTTP 200 OK (MSG-PAG-0006: "Cuota registrada exitosamente")
        deactivate Endpoint
        Front-->>Cajera: Despliega mensaje de éxito y recibo actualizado
    end
```

---

## 4. Anular Registro de Entrada de Dinero (ILA-PAG-0008 v02.00)

Borrado lógico en cascada sobre la venta y sus correspondientes cuotas asociadas.

```mermaid
sequenceDiagram
    autonumber
    actor Cajera as ACT-0002 (Cajera)
    participant Front as ORG-0003 (Frontend Clínico)
    participant Endpoint as ENDPOINT-PAG-0008 (PackageSaleController)
    participant Service as PackageSaleService
    participant DB as payments_db

    Cajera->>Front: Selecciona venta a anular y acepta ventana de confirmación modal
    Front->>Endpoint: HTTP DELETE /api/payments/package-sales/{sale_id}/cancel
    activate Endpoint
    Endpoint->>Service: cancelPackageSale(sale_id)
    activate Service

    Service->>DB: SELECT status FROM PackageSale WHERE id = :sale_id
    DB-->>Service: Estado actual

    alt Venta no encontrada o ya se encuentra anulada
        Service-->>Endpoint: Throw SaleAlreadyCancelledException
        Endpoint-->>Front: HTTP 400 Bad Request (MSG-PAG-0007: "Venta no encontrada o previamente anulada")
        Front-->>Cajera: Muestra error de estado en pantalla
    else Venta activa
        Note over Service,DB: Borrado Lógico Transaccional
        Service->>DB: UPDATE PackageSale SET status = 'anulado' WHERE id = :sale_id
        Service->>DB: UPDATE Installment SET status = 'anulado' WHERE sale_id = :sale_id
        Service->>DB: UPDATE CommissionRecord SET status = 'Anulado' WHERE sale_id = :sale_id AND status != 'Pagado'
        DB-->>Service: Confirmación de actualización en tablas
        Service->>DB: COMMIT y Cierra conexión
        Service-->>Endpoint: Operación exitosa
        deactivate Service
        Endpoint-->>Front: HTTP 200 OK (MSG-PAG-0008: "Registro de entrada de dinero anulado exitosamente")
        deactivate Endpoint
        Front->>Front: Actualiza cuadrícula de ventas (marca registro tachado/anulado)
        Front-->>Cajera: Muestra notificación de anulación exitosa
    end
```
