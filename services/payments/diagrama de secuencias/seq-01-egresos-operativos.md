# Diagramas de Secuencia — Egresos Operativos Diarios

**Educción:** EDU-0001  
**Tabla afectada:** `CashTransaction` (`payments_db`)  
**Actores:** ACT-0001 (Gerente General), ACT-0002 (Cajera)  
**Ilaciones cubiertas:** ILA-PAG-0001, ILA-PAG-0002, ILA-PAG-0003, ILA-PAG-0004  

---

## 1. Crear Egreso Operativo Diario (ILA-PAG-0001 v02.04)

Describe la interacción desde que el usuario completa el formulario de salida hasta la persistencia física en `CashTransaction` con `type = 'salida'`.

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as ACT-0001 / ACT-0002 (Cajera / Gerente)
    participant UI as IGU-PAG-0001 (Registro Salidas)
    participant Controller as CashTransactionController
    participant Service as CashTransactionService
    participant DB as payments_db (CashTransaction)

    Usuario->>UI: Abre IGU-PAG-0001 (inicia sesión)
    UI-->>Usuario: Muestra formulario (SEL-0001, SEL-0002, TXT-0001, TXT-0002)
    Usuario->>UI: Selecciona categoría (SEL-0001), método (SEL-0002), digita monto (TXT-0001) y justificación (TXT-0002)
    Usuario->>UI: Presiona BTN-0001 ("Registrar Salida")

    rect rgb(240, 245, 255)
    Note over UI: Validación local / cliente
    alt Monto vacío, negativo o falta categoría/método
        UI-->>Usuario: Despliega error MSG-0001 ("Faltan datos obligatorios o el monto ingresado es inválido")
        Note over UI: Formulario permanece activo sin borrar datos
    else Datos válidos
        UI->>Controller: POST /api/payments/cash-transactions (payload)
        activate Controller
        Controller->>Service: createOperationalExpense(dto)
        activate Service
        Service->>DB: Abre conexión y apertura tabla CashTransaction
        Service->>DB: INSERT INTO CashTransaction(type='salida', category, amount, method, description, date)
        DB-->>Service: Confirmación de inserción (ID generado)
        Service->>DB: Cierra tabla y conexión payments_db
        Service-->>Controller: Transacción exitosa (ExpenseEntity)
        deactivate Service
        Controller-->>UI: HTTP 201 Created (JSON confirmación)
        deactivate Controller
        UI->>UI: Limpia campos de formulario
        UI-->>Usuario: Muestra notificación emergente MSG-0002 ("Salida de dinero registrada correctamente")
    end
    end
```

---

## 2. Consultar Historial de Egresos Operativos (ILA-PAG-0002 v03.00)

Operación estricta de solo lectura filtrando por fecha sobre `CashTransaction`.

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as ACT-0001 / ACT-0002
    participant UI as IGU-PAG-0002 (Historial Salidas)
    participant Controller as CashTransactionController
    participant Service as CashTransactionService
    participant DB as payments_db (CashTransaction)

    Usuario->>UI: Abre interfaz de historial IGU-PAG-0002
    UI-->>Usuario: Despliega selector de fecha DAT-0001 y lista vacía SEL-0001
    Usuario->>UI: Selecciona fecha en DAT-0001 y presiona BTN-0001 ("Buscar")

    rect rgb(240, 245, 255)
    Note over UI,Controller: Validación y Consulta
    alt Fecha vacía o formato inválido
        UI-->>Usuario: Despliega error MSG-0001 ("Debe seleccionar una fecha válida")
    else Fecha válida
        UI->>Controller: GET /api/payments/cash-transactions?type=salida&date={fecha}
        activate Controller
        Controller->>Service: getExpensesByDate(date)
        activate Service
        Service->>DB: SELECT * FROM CashTransaction WHERE type = 'salida' AND date = :date AND status != 'anulado'
        DB-->>Service: Conjunto de registros (List<CashTransaction>)
        Service->>DB: Cierra tabla y conexión payments_db (Solo Lectura)
        Service-->>Controller: Retorna lista de entidades
        deactivate Service
        Controller-->>UI: HTTP 200 OK (JSON List)
        deactivate Controller

        alt Lista vacía (0 registros)
            UI-->>Usuario: Muestra informativo MSG-0002 ("No hay salidas de dinero registradas en esta fecha")
        else Registros encontrados
            UI->>UI: Renderiza lista SEL-0001 con monto, concepto y método
            UI-->>Usuario: Visualiza egresos operativos en pantalla
        end
    end
    end
```

---

## 3. Actualizar Registro de Egreso Operativo (ILA-PAG-0003 v03.00)

Edición de atributos de una salida registrada previamente en el sistema.

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as ACT-0001 / ACT-0002
    participant UI as IGU-PAG-0003 (Edición de Salidas)
    participant Controller as CashTransactionController
    participant Service as CashTransactionService
    participant DB as payments_db (CashTransaction)

    Usuario->>UI: Selecciona egreso de la lista y abre IGU-PAG-0003
    UI->>UI: Carga datos actuales en campos (SEL-0001, SEL-0002, TXT-0001, TXT-0002)
    Usuario->>UI: Modifica valores requeridos y presiona BTN-0001 ("Actualizar Salida")

    rect rgb(240, 245, 255)
    Note over UI: Validación y persistencia
    alt Monto vacío, negativo o datos incompletos
        UI-->>Usuario: Despliega error MSG-0001 ("Faltan datos obligatorios o el monto modificado es inválido")
        Note over UI: Formulario permanece activo con datos intactos
    else Modificación válida
        UI->>Controller: PUT /api/payments/cash-transactions/{id} (payload modificado)
        activate Controller
        Controller->>Service: updateExpense(id, updateDto)
        activate Service
        Service->>DB: UPDATE CashTransaction SET category = :cat, method = :met, amount = :amt, description = :desc WHERE id = :id
        DB-->>Service: Confirmación de actualización
        Service->>DB: Cierra tabla y conexión
        Service-->>Controller: Entidad actualizada
        deactivate Service
        Controller-->>UI: HTTP 200 OK (JSON)
        deactivate Controller
        UI-->>Usuario: Notificación emergente MSG-0002 ("Egreso operativo actualizado correctamente")
        UI->>UI: Redirige a pantalla de historial IGU-PAG-0002
    end
    end
```

---

## 4. Anular Registro de Egreso Operativo (ILA-PAG-0004 v03.01)

Mitigación de riesgos operativos mediante ventana modal de advertencia y borrado lógico.

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as ACT-0001 / ACT-0002
    participant UI as IGU-PAG-0002 / IGU-PAG-0004 (Historial y Detalle)
    participant Modal as IGU-PAG-0004-MOD-0001 (Modal Advertencia)
    participant Controller as CashTransactionController
    participant Service as CashTransactionService
    participant DB as payments_db (CashTransaction)

    Usuario->>UI: Selecciona egreso y presiona BTN-0002 ("Ver más" / Detalle)
    UI->>Modal: Despliega ventana emergente de advertencia para anulación
    Modal-->>Usuario: Solicita confirmación definitiva

    alt Usuario cancela la acción
        Usuario->>Modal: Cierra modal / Cancelar
        Modal-->>UI: Retorna a la vista sin alterar datos
    else Usuario confirma anulación
        Usuario->>Modal: Presiona BTN-0016 ("Confirmar Anulación")
        Modal->>Controller: PATCH /api/payments/cash-transactions/{id}/cancel
        activate Controller
        Controller->>Service: cancelExpense(id)
        activate Service
        Service->>DB: SELECT status FROM CashTransaction WHERE id = :id
        DB-->>Service: Registro actual

        alt Registro inexistente o ya anulado (status == 'anulado')
            Service-->>Controller: Error de estado
            Controller-->>Modal: HTTP 400 Bad Request / MSG-0001
            Modal-->>Usuario: Muestra error ("El registro de salida no fue encontrado o ya se encuentra anulado")
        else Registro activo válido
            Service->>DB: UPDATE CashTransaction SET status = 'anulado' WHERE id = :id (Borrado lógico)
            DB-->>Service: Confirmación de actualización
            Service->>DB: Cierra tabla y conexión
            Service-->>Controller: Estado anulado exitosamente
            deactivate Service
            Controller-->>UI: HTTP 200 OK (MSG-0002)
            deactivate Controller
            UI->>Modal: Cierra ventana emergente
            UI->>UI: Actualiza cuadrícula de historial
            UI-->>Usuario: Notificación emergente MSG-0002 ("Egreso operativo anulado correctamente")
        end
    end
```
