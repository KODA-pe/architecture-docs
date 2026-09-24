# Diagramas de Secuencia — Egresos Fijos Mensuales

**Educción:** EDU-0021  
**Tabla afectada:** `FixedExpense` (`payments_db`)  
**Actores:** ACT-0001 (Gerente General) — Operación Confidencial  
**Ilaciones cubiertas:** ILA-PAG-0013, ILA-PAG-0014, ILA-PAG-0015, ILA-PAG-0016  

---

## 1. Crear Registro de Pago de Egreso Fijo (ILA-PAG-0013 v03.00)

Registro de rubros fijos estructurales por parte de la Gerencia General (alquileres, sueldos fijos, honorarios profesionales, servicios externos).

```mermaid
sequenceDiagram
    autonumber
    actor Gerente as ACT-0001 (Gerente General)
    participant UI as IGU-PAG-0010 (Gestión Egresos Fijos)
    participant Controller as FixedExpenseController
    participant Service as FixedExpenseService
    participant DB as payments_db (FixedExpense)

    Gerente->>UI: Inicia sesión con rol administrativo y abre IGU-PAG-0010
    UI-->>Gerente: Despliega formulario (SEL-0001, TXT-0001, TXT-0002)
    Gerente->>UI: Selecciona rubro en SEL-0001 ("Alquileres", "Honorarios", "Sueldos fijos", "Servicios externos")
    Gerente->>UI: Digita concepto (TXT-0001) y monto exacto (TXT-0002)
    Gerente->>UI: Presiona BTN-0001 ("Guardar Egreso")

    rect rgb(240, 245, 255)
    Note over UI: Validación y Persistencia
    alt Falta categoría, monto vacío o inválido
        UI-->>Gerente: Muestra notificación de error MSG-0001 ("Faltan datos obligatorios o formato inválido")
        Note over UI: Formulario permanece activo con datos ingresados
    else Datos válidos
        UI->>Controller: POST /api/payments/fixed-expenses (Payload DTO)
        activate Controller
        Controller->>Service: createFixedExpense(dto, userId)
        activate Service
        Service->>DB: INSERT INTO FixedExpense (category, description, amount, expense_date, is_paid, status)
        DB-->>Service: Confirmación (ID generado)
        Service->>DB: Cierra tabla y conexión payments_db
        Service-->>Controller: Egreso fijo registrado
        deactivate Service
        Controller-->>UI: HTTP 201 Created (MSG-0002)
        deactivate Controller
        UI->>UI: Limpia formulario
        UI-->>Gerente: Despliega notificación temporal MSG-0002 ("Egreso fijo registrado correctamente")
    end
    end
```

---

## 2. Consultar Historial de Egresos Fijos y Sumatoria (ILA-PAG-0014 v02.00)

Consulta mensual confidencial que procesa la cuadrícula de datos y computa de forma matemática automática la sumatoria total en un campo de solo lectura.

```mermaid
sequenceDiagram
    autonumber
    actor Gerente as ACT-0001 (Gerente General)
    participant UI as IGU-PAG-0011 (Historial Egresos Fijos)
    participant Controller as FixedExpenseController
    participant Service as FixedExpenseService
    participant DB as payments_db (FixedExpense)

    Gerente->>UI: Abre pantalla IGU-PAG-0011
    UI-->>Gerente: Despliega selector de mes SEL-0001 y cuadrícula vacía TBL-0001
    Gerente->>UI: Selecciona mes cronológico en SEL-0001 y presiona BTN-0001 ("Filtrar Historial")

    UI->>Controller: GET /api/payments/fixed-expenses?month={mes}&year={anio}
    activate Controller
    Controller->>Service: getMonthlyFixedExpenses(mes, anio)
    activate Service
    Service->>DB: SELECT * FROM FixedExpense WHERE EXTRACT(MONTH FROM expense_date) = :mes AND status != 'Anulado'
    DB-->>Service: Lista de egresos fijos
    Service->>DB: Cierra conexión (Solo Lectura)
    Service-->>Controller: DTO de egresos fijos
    deactivate Service
    Controller-->>UI: HTTP 200 OK (JSON)
    deactivate Controller

    alt No existen egresos en el periodo
        UI-->>Gerente: Notificación emergente MSG-0001 ("No se encontraron egresos registrados en el periodo seleccionado")
        Note over UI: TBL-0001 permanece vacía
    else Registros encontrados
        UI->>UI: Renderiza cuadrícula TBL-0001 con conceptos, rubros y montos
        UI->>UI: Calcula matemáticamente sumatoria: total = SUM(monto)
        UI->>UI: Asigna total en TXT-0011-TXT-0001 (campo bloqueado de solo lectura)
        UI-->>Gerente: Visualiza desglose y sumatoria total del mes
    end
```

---

## 3. Actualizar Registro de Egreso Fijo (ILA-PAG-0015 v02.00)

Edición de egresos por reajustes salariales o correcciones de digitación con ventana modal preventiva.

```mermaid
sequenceDiagram
    autonumber
    actor Gerente as ACT-0001 (Gerente General)
    participant UI as IGU-PAG-0011 (Historial Egresos Fijos)
    participant Modal as IGU-PAG-0012 (Modal de Edición)
    participant Confirm as IGU-PAG-0013 (Ventana Confirmación)
    participant Controller as FixedExpenseController
    participant Service as FixedExpenseService
    participant DB as payments_db (FixedExpense)

    Gerente->>UI: Selecciona egreso en TBL-0001 y presiona BTN-0002 ("Editar Egreso")
    UI->>Modal: Despliega modal superpuesto precargando concepto (TXT-0001) y monto (TXT-0002)
    Gerente->>Modal: Modifica concepto o ajusta monto numérico
    Gerente->>Modal: Presiona BTN-0001 ("Actualizar Egreso")

    Modal->>Confirm: Despliega advertencia ("¿Está seguro de guardar los cambios en este registro de egreso fijo?")
    Gerente->>Confirm: Presiona BTN-0001 ("Confirmar")

    rect rgb(240, 245, 255)
    Note over Modal,DB: Validación y Persistencia
    alt Monto vacío o formato no numérico
        Confirm->>Confirm: Cierra advertencia
        Modal-->>Gerente: Muestra notificación de error MSG-0001 ("Datos de monto inválidos")
        Note over Modal: Modal permanece activo con datos intactos
    else Modificación válida
        Confirm->>Controller: PUT /api/payments/fixed-expenses/{id} (Payload DTO)
        activate Controller
        Controller->>Service: updateFixedExpense(id, dto)
        activate Service
        Service->>DB: UPDATE FixedExpense SET description = :desc, amount = :amt WHERE id = :id
        DB-->>Service: Confirmación de actualización
        Service->>DB: Cierra conexión
        Service-->>Controller: Egreso fijo actualizado
        deactivate Service
        Controller-->>UI: HTTP 200 OK (MSG-0002)
        deactivate Controller
        Confirm->>Confirm: Cierra ventana de confirmación
        Modal->>Modal: Cierra formulario modal
        UI->>UI: Actualiza cuadrícula TBL-0001 y recalcula sumatoria total
        UI-->>Gerente: Notificación temporal MSG-0002 ("Egreso fijo actualizado exitosamente")
    end
    end
```

---

## 4. Anular Registro de Egreso Fijo (ILA-PAG-0016 v02.00)

Borrado lógico con ventana de advertencia de impacto contable en IGU-PAG-0014.

```mermaid
sequenceDiagram
    autonumber
    actor Gerente as ACT-0001 (Gerente General)
    participant UI as IGU-PAG-0011 (Historial Egresos Fijos)
    participant Modal as IGU-PAG-0014 (Modal Advertencia Contable)
    participant Controller as FixedExpenseController
    participant Service as FixedExpenseService
    participant DB as payments_db (FixedExpense)

    Gerente->>UI: Selecciona egreso en TBL-0001 y presiona BTN-0003 ("Eliminar Egreso")
    UI->>Modal: Despliega ventana emergente ("¿Está seguro de anular este egreso fijo? Esta acción afectará los reportes contables")

    alt Gerente presiona Cancelar
        Gerente->>Modal: Cancelar operación
        Modal->>Modal: Cierra ventana sin alterar la base de datos
    else Gerente confirma anulación
        Gerente->>Modal: Presiona BTN-0001 ("Confirmar Anulación")
        Modal->>Controller: PATCH /api/payments/fixed-expenses/{id}/cancel
        activate Controller
        Controller->>Service: cancelFixedExpense(id)
        activate Service

        Service->>DB: SELECT status FROM FixedExpense WHERE id = :id
        DB-->>Service: Estado actual

        alt Registro ya posee estado "Anulado" o no existe
            Service-->>Controller: Throw InvalidExpenseStateException
            Controller-->>Modal: HTTP 400 Bad Request (MSG-0001)
            Modal-->>Gerente: Notificación MSG-0001 ("El egreso ya fue anulado previamente")
            Modal->>Modal: Cierra ventana
        else Registro activo
            Service->>DB: UPDATE FixedExpense SET status = 'Anulado' WHERE id = :id (Borrado Lógico)
            DB-->>Service: Confirmación de actualización
            Service->>DB: Cierra conexión
            Service-->>Controller: Anulación exitosa
            deactivate Service
            Controller-->>UI: HTTP 200 OK (MSG-0004)
            deactivate Controller
            Modal->>Modal: Cierra ventana de confirmación
            UI->>UI: Actualiza cuadrícula TBL-0001 y recalcula sumatoria
            UI-->>Gerente: Notificación emergente MSG-0004 ("Egreso fijo anulado exitosamente")
        end
    end
```
