# Diagramas de Estados — Transacciones de Caja y Egresos Fijos (`CashTransaction` y `FixedExpense`)

**Dominios:** Egresos Operativos Diarios (EDU-0001) y Egresos Fijos Mensuales (EDU-0021)  
**Tablas afectadas:** `CashTransaction`, `FixedExpense` (`payments_db`)  
**Ilaciones asociadas:** ILA-PAG-0001, ILA-PAG-0003, ILA-PAG-0004, ILA-PAG-0013, ILA-PAG-0015, ILA-PAG-0016  

---

## 1. Ciclo de Vida y Transiciones de `CashTransaction` (Movimiento de Caja)

`CashTransaction` es el libro mayor transaccional donde convergen todos los ingresos (ventas, cuotas) y salidas (caja chica, comisiones, gastos fijos).

```mermaid
stateDiagram-v2
    [*] --> Activo : Registro de ingreso o egreso verificado físicamente

    state Activo {
        [*] --> Vigente_Para_Arqueo
        Vigente_Para_Arqueo --> Contabilizado_En_Sede : Impacta balance en tiempo real
    }

    Activo --> Modificado : Actualización de concepto, método o monto (ILA-PAG-0003)
    Modificado --> Modificado : Nuevas correcciones autorizadas
    Modificado --> Activo : Revalidación de balance

    Activo --> Anulado : Confirmación en modal IGU-PAG-0004 (ILA-PAG-0004)
    Modificado --> Anulado : Confirmación en modal IGU-PAG-0004 (ILA-PAG-0004)

    state Anulado {
        [*] --> Borrado_Logico : status = 'anulado'
        Borrado_Logico --> Excluido_Del_Balance_Caja : Se descuenta del arqueo activo
        Excluido_Del_Balance_Caja --> Registro_Inmutable_Auditoria : Se conserva fila en payments_db
    }

    Activo --> Conciliado : Cierre de turno / Arqueo diario de caja en sede
    Modificado --> Conciliado : Cierre de turno / Arqueo diario de caja en sede

    Conciliado --> [*]
    Anulado --> [*]
```

### Tabla de Transiciones de `CashTransaction`

| Estado Origen | Disparador / Evento | Condición de Guarda | Estado Destino | Acción en el Sistema |
| :--- | :--- | :--- | :--- | :--- |
| `[*]` | Registro de salida (ILA-PAG-0001) | Monto > 0, categoría y método válidos | `Activo` | Inserta registro con `type = 'salida'`; resta del saldo de caja de la sede. |
| `[*]` | Venta o cuota (ILA-PAG-0005, 0007) | Pago confirmado en mostrador | `Activo` | Inserta registro con `type = 'ingreso'`; suma al saldo de caja (Efectivo/Yape). |
| `Activo` | Actualizar salida (ILA-PAG-0003) | Monto modificado válido | `Modificado` | Sobreescribe atributos en tabla; recalcula totales para arqueo. |
| `Activo` / `Modificado` | Anular salida (ILA-PAG-0004) | Confirmación `BTN-0016` y estado != 'anulado' | `Anulado` | Borrado lógico (`status = 'anulado'`). El movimiento deja de computarse en el arqueo. |
| `Activo` / `Modificado` | Cierre diario de caja | Validación de arqueo físico vs. sistema | `Conciliado` | Bloquea modificaciones sobre transacciones del turno cerrado. |

---

## 2. Ciclo de Vida y Transiciones de `FixedExpense` (Egreso Fijo Mensual)

Gestiona los compromisos estructurales del negocio (Alquileres, Sueldos, Honorarios, Servicios externos). Operación confidencial y exclusiva de Gerencia General.

```mermaid
stateDiagram-v2
    [*] --> Registrado : Creación por Gerente General (ILA-PAG-0013, is_paid = false)
    [*] --> Pagado : Registro con desembolso inmediato (is_paid = true)

    state Registrado {
        [*] --> Obligacion_Pendiente
        Obligacion_Pendiente --> Visible_En_Sumatoria_Mes : Consulta mensual (ILA-PAG-0014)
    }

    Registrado --> Modificado : Ajuste de concepto o monto con confirmación (ILA-PAG-0015)
    Modificado --> Modificado : Reajustes adicionales
    Modificado --> Registrado : Datos confirmados

    Registrado --> Pagado : Confirmación de pago y desembolso efectivo
    Modificado --> Pagado : Confirmación de pago y desembolso efectivo

    state Pagado {
        [*] --> Enlace_Cash_Transaction : Genera CashTransaction (salida)
        Enlace_Cash_Transaction --> Imputacion_Contable_Final
    }

    Registrado --> Anulado : Confirmación en modal IGU-PAG-0014 (ILA-PAG-0016)
    Modificado --> Anulado : Confirmación en modal IGU-PAG-0014 (ILA-PAG-0016)

    state Anulado {
        [*] --> Borrado_Logico_Gasto : status = 'Anulado'
        Borrado_Logico_Gasto --> Excluido_De_Sumatoria_Mes : No afecta balances contables futuros
    }

    Pagado --> [*]
    Anulado --> [*]
```

### Tabla de Transiciones de `FixedExpense`

| Estado Origen | Disparador / Evento | Condición de Guarda | Estado Destino | Acción en el Sistema |
| :--- | :--- | :--- | :--- | :--- |
| `[*]` | Registro IGU-PAG-0010 (ILA-PAG-0013) | Categoría fija válida y monto > 0 | `Registrado` | Inserta egreso fijo en `FixedExpense`; computa en sumatoria de `IGU-PAG-0011`. |
| `Registrado` | Edición IGU-PAG-0012 (ILA-PAG-0015) | Confirmación en `IGU-PAG-0013`, monto > 0 | `Modificado` | Actualiza descripción/monto; recalcula sumatoria automática de solo lectura. |
| `Registrado` / `Modificado` | Desembolso de fondos | Autorización y pago realizado | `Pagado` | Asigna `is_paid = true`, `payment_date = NOW()` y vincula a `cash_transaction_id`. |
| `Registrado` / `Modificado` | Anulación IGU-PAG-0014 (ILA-PAG-0016) | Confirmación `BTN-0001` y estado != 'Anulado' | `Anulado` | Borrado lógico (`status = 'Anulado'`); se excluye de la sumatoria total mensual. |
