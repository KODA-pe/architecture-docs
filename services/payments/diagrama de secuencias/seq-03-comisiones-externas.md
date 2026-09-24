# Diagramas de Secuencia — Comisiones Externas

**Educción:** EDU-0005  
**Tabla afectada:** `CommissionRecord` (`payments_db`) e integración de lectura con `personal_db` (Subsistema de Personal)  
**Actores:** ACT-0001 (Gerente General), ACT-0002 (Cajera)  
**Ilaciones cubiertas:** ILA-PAG-0009, ILA-PAG-0010, ILA-PAG-0011, ILA-PAG-0012  

---

## 1. Crear Registro de Pago o Deuda de Comisión Externa (ILA-PAG-0009 v03.00)

Describe la interacción con la interfaz IGU-PAG-0005, consultando al módulo de Personal para autocompletar los datos de transferencia del referidor.

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as ACT-0001 / ACT-0002 (Cajera / Gerente)
    participant UI as IGU-PAG-0005 (Registro Comisiones)
    participant Controller as CommissionController
    participant Service as CommissionService
    participant PersonalSvc as PersonalModuleService
    participant DB as payments_db (CommissionRecord)

    Usuario->>UI: Abre interfaz de registro de comisiones IGU-PAG-0005
    UI->>Controller: GET /api/personal/referrers/active
    Controller->>PersonalSvc: getActiveReferrers()
    PersonalSvc-->>Controller: Lista de derivadores (Promotores y Traumatólogos)
    Controller-->>UI: Carga lista en desplegable SEL-0001

    Usuario->>UI: Selecciona derivador en SEL-0001
    UI->>PersonalSvc: Obtener detalle y canal de pago del derivador
    alt Derivador es Promotor Externo
        PersonalSvc-->>UI: Retorna número de teléfono / Yape
    else Derivador es Médico Traumatólogo
        PersonalSvc-->>UI: Retorna número de cuenta bancaria CCI
    end
    UI->>UI: Bloquea y muestra dato financiero en TXT-0001 (solo lectura)

    Usuario->>UI: Digita monto (TXT-0002, ej. S/ 25) y selecciona estado en SEL-0002 ("Pagado" o "Pendiente")
    Usuario->>UI: Presiona BTN-0001 ("Registrar Comisión")

    rect rgb(240, 245, 255)
    Note over UI: Validación y Persistencia
    alt Derivador no seleccionado, monto vacío o inválido
        UI-->>Usuario: Muestra error MSG-0001 ("Faltan datos obligatorios o el monto ingresado es inválido")
        Note over UI: Formulario permanece activo con selección intacta
    else Datos válidos
        UI->>Controller: POST /api/payments/commissions (Payload: referrer_id, amount, status)
        activate Controller
        Controller->>Service: createCommissionRecord(dto)
        activate Service
        Service->>DB: INSERT INTO CommissionRecord (referrer_id, amount, status, commission_date)
        DB-->>Service: Confirmación (ID generado)
        
        opt Si el usuario marcó estado = "Pagado"
            Service->>DB: INSERT INTO CashTransaction (type='salida', category='pago_comision', amount=:amount)
            Service->>DB: UPDATE CommissionRecord SET cash_transaction_id = :tx_id, payment_date = NOW()
        end

        Service->>DB: Cierra tabla y conexión payments_db
        Service-->>Controller: Comisión registrada
        deactivate Service
        Controller-->>UI: HTTP 201 Created (MSG-0002)
        deactivate Controller
        UI->>UI: Limpia campos del formulario
        UI-->>Usuario: Muestra notificación emergente MSG-0002 ("Registro de comisión creado exitosamente")
    end
    end
```

---

## 2. Consultar Historial de Comisiones y Exportar Reporte a Excel (ILA-PAG-0010 v02.00)

Filtro mensual de comisiones por médico traumatólogo con generación y descarga local de archivo `.xlsx`.

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as ACT-0001 / ACT-0002
    participant UI as IGU-PAG-0006 (Historial Comisiones)
    participant Controller as CommissionController
    participant Service as CommissionService
    participant PersonalSvc as PersonalModuleService
    participant DB as payments_db (CommissionRecord)
    participant ExcelGen as ExcelExportService

    Usuario->>UI: Abre pantalla IGU-PAG-0006
    UI->>PersonalSvc: Carga médicos traumatólogos aliados en SEL-0002
    Usuario->>UI: Selecciona mes en SEL-0001 y médico en SEL-0002
    Usuario->>UI: Presiona BTN-0001 ("Filtrar Historial")

    UI->>Controller: GET /api/payments/commissions?month={mes}&referrerId={medicoId}
    activate Controller
    Controller->>Service: getCommissionsByPeriod(mes, medicoId)
    activate Service
    Service->>DB: SELECT * FROM CommissionRecord WHERE referrer_id = :medicoId AND EXTRACT(MONTH FROM commission_date) = :mes AND status != 'Anulado'
    DB-->>Service: Registros de comisiones
    Service->>DB: Cierra conexión (Solo Lectura)
    Service-->>Controller: Lista de comisiones y acumulado
    deactivate Service
    Controller-->>UI: HTTP 200 OK (JSON)
    deactivate Controller

    alt No existen comisiones en el periodo
        UI-->>Usuario: Muestra alerta MSG-0001 ("No se encontraron comisiones en el periodo seleccionado")
        Note over UI: Cuadrícula TBL-0001 permanece vacía
    else Registros encontrados
        UI->>UI: Renderiza cuadrícula TBL-0001 y total acumulado
        UI-->>Usuario: Visualiza tabla detallada con pacientes y montos
        
        opt Usuario solicita reporte
            Usuario->>UI: Presiona BTN-0002 ("Exportar a Excel")
            UI->>Controller: POST /api/payments/commissions/export-excel (filtros)
            Controller->>ExcelGen: generateCommissionWorkbook(data)
            ExcelGen-->>Controller: Archivo binario .xlsx estructurado
            Controller-->>UI: HTTP 200 OK (application/vnd.openxmlformats...)
            UI->>UI: Dispara descarga en el navegador del usuario
            UI-->>Usuario: Notificación MSG-0002 ("Reporte exportado correctamente")
        end
    end
```

---

## 3. Actualizar Estado o Monto de Comisión Externa (ILA-PAG-0011 v02.00)

Edición de comisión en ventana modal con ventana previa de confirmación para mitigación de riesgos financieros.

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as ACT-0001 / ACT-0002
    participant UI as IGU-PAG-0006 (Historial Comisiones)
    participant Modal as IGU-PAG-0007 (Modal de Edición)
    participant Confirm as IGU-PAG-0008 (Ventana Confirmación)
    participant Controller as CommissionController
    participant Service as CommissionService
    participant DB as payments_db (CommissionRecord)

    Usuario->>UI: Selecciona registro en TBL-0001 y presiona BTN-0003 ("Editar Comisión")
    UI->>Modal: Despliega modal superpuesto con datos precargados
    Usuario->>Modal: Modifica estado a "Pagado" (SEL-0001) o ajusta monto (TXT-0001)
    Usuario->>Modal: Presiona BTN-0001 ("Actualizar")

    Modal->>Confirm: Despliega ventana emergente ("¿Está seguro de guardar los cambios?")
    Usuario->>Confirm: Presiona BTN-0001 ("Confirmar")

    rect rgb(240, 245, 255)
    Note over Modal,DB: Validación y Persistencia
    alt Monto vacío o formato inválido
        Confirm->>Confirm: Cierra advertencia
        Modal-->>Usuario: Notificación emergente MSG-0001 ("Datos inválidos")
        Note over Modal: Modal permanece activo con datos intactos
    else Datos válidos
        Confirm->>Controller: PUT /api/payments/commissions/{id} (Payload: amount, status)
        activate Controller
        Controller->>Service: updateCommission(id, dto)
        activate Service
        Service->>DB: UPDATE CommissionRecord SET amount = :amount, status = :status WHERE id = :id
        
        opt Si el estado cambió a "Pagado" y no tenía egreso previo
            Service->>DB: INSERT INTO CashTransaction (type='salida', category='pago_comision', amount=:amount)
            Service->>DB: UPDATE CommissionRecord SET payment_date = NOW(), cash_transaction_id = :tx_id WHERE id = :id
        end

        DB-->>Service: Confirmación de actualización
        Service->>DB: Cierra conexión payments_db
        Service-->>Controller: Comisión actualizada
        deactivate Service
        Controller-->>UI: HTTP 200 OK (MSG-0003)
        deactivate Controller
        Confirm->>Confirm: Cierra ventana de confirmación
        Modal->>Modal: Cierra modal de edición
        UI->>UI: Actualiza cuadrícula TBL-0001 con nueva información
        UI-->>Usuario: Notificación emergente MSG-0003 ("Comisión actualizada exitosamente")
    end
    end
```

---

## 4. Anular Registro de Comisión Externa (ILA-PAG-0012 v02.00)

Borrado lógico con advertencia estricta en IGU-PAG-0009.

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as ACT-0001 / ACT-0002
    participant UI as IGU-PAG-0006 (Historial Comisiones)
    participant Modal as IGU-PAG-0009 (Modal Advertencia Anulación)
    participant Controller as CommissionController
    participant Service as CommissionService
    participant DB as payments_db (CommissionRecord)

    Usuario->>UI: Selecciona comisión en TBL-0001 y presiona BTN-0004 ("Eliminar Comisión")
    UI->>Modal: Despliega ventana emergente ("¿Está seguro de anular esta comisión?")
    
    alt Usuario presiona Cancelar
        Usuario->>Modal: Presiona Cancelar
        Modal->>Modal: Cierra ventana sin alterar datos
    else Usuario confirma anulación
        Usuario->>Modal: Presiona BTN-0001 ("Confirmar Anulación")
        Modal->>Controller: PATCH /api/payments/commissions/{id}/cancel
        activate Controller
        Controller->>Service: cancelCommission(id)
        activate Service

        Service->>DB: SELECT status FROM CommissionRecord WHERE id = :id
        DB-->>Service: Estado actual

        alt Registro ya posee estado "Anulado" o no existe
            Service-->>Controller: Throw InvalidCommissionStateException
            Controller-->>Modal: HTTP 400 Bad Request (MSG-0001)
            Modal-->>Usuario: Muestra error ("La comisión ya fue anulada previamente")
            Modal->>Modal: Cierra ventana emergente
        else Registro activo ("Pendiente" o "Pagado")
            Service->>DB: UPDATE CommissionRecord SET status = 'Anulado' WHERE id = :id (Borrado Lógico)
            DB-->>Service: Confirmación
            Service->>DB: Cierra conexión
            Service-->>Controller: Anulación exitosa
            deactivate Service
            Controller-->>UI: HTTP 200 OK (MSG-0004)
            deactivate Controller
            Modal->>Modal: Cierra ventana emergente
            UI->>UI: Actualiza cuadrícula TBL-0001
            UI-->>Usuario: Notificación emergente MSG-0004 ("Comisión anulada exitosamente")
        end
    end
```
