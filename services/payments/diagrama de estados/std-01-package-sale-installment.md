# Diagramas de Estados — Venta de Paquetes y Cuotas (`PackageSale` e `Installment`)

**Dominio:** Entradas por Venta de Paquetes (EDU-0002)  
**Tablas afectadas:** `PackageSale`, `Installment`, `InstallmentPayment` (`payments_db`)  
**Ilaciones asociadas:** ILA-PAG-0005, ILA-PAG-0006, ILA-PAG-0007, ILA-PAG-0008  

---

## 1. Ciclo de Vida y Transiciones de `PackageSale`

Representa la venta global de tratamiento de salud adquirida por un paciente. El estado refleja la situación comercial y financiera de la obligación de pago.

```mermaid
stateDiagram-v2
    [*] --> Pendiente : Registro de venta con abono inicial >= S/ 50 (Saldo > 0)
    [*] --> Completado : Venta liquidada al 100% en el abono de apertura

    state Pendiente {
        [*] --> Deuda_Inicial_Registrada
        Deuda_Inicial_Registrada --> Citas_Habilitadas : Notificación a InnovaByte
    }

    Pendiente --> Parcialmente_Pagado : Recepción de cuota parcial (Saldo restante > 0)
    Parcialmente_Pagado --> Parcialmente_Pagado : Nuevos cobros de cuotas intermedias (Saldo > 0)

    Pendiente --> Completado : Pago único que cubre la totalidad de la deuda
    Parcialmente_Pagado --> Completado : Cobro de última cuota (Deuda calculada = S/ 0.00)

    state Completado {
        [*] --> Deuda_En_Cero
        Deuda_En_Cero --> Regularizacion_Total_Notificada : Desbloqueo definitivo de citas
    }

    Pendiente --> Anulado : Solicitud de anulación confirmada (ILA-PAG-0008)
    Parcialmente_Pagado --> Anulado : Solicitud de anulación confirmada (ILA-PAG-0008)
    Completado --> Anulado : Anulación autorizada por auditoría / Gerencia

    state Anulado {
        [*] --> Borrado_Logico_Aplicado
        Borrado_Logico_Aplicado --> Cascada_Cuotas_Anuladas : Invalida abonos asociados
    }

    Completado --> [*]
    Anulado --> [*]
```

### Tabla de Transiciones de `PackageSale`

| Estado Origen | Evento / Disparador | Condición de Guarda | Estado Destino | Efecto / Acción en el Sistema |
| :--- | :--- | :--- | :--- | :--- |
| `[*]` | Petición POST `ENDPOINT-PAG-0001` | Abono inicial >= S/ 50 y < Total | `Pendiente` | Persiste venta y abono inicial; notifica a `API_InnovaByte`. |
| `[*]` | Petición POST `ENDPOINT-PAG-0001` | Abono inicial == Monto Total | `Completado` | Persiste venta y cuota inicial cancelada; habilita asistencias completas. |
| `Pendiente` | Petición PUT `ENDPOINT-PAG-0007` | Abono cuota > 0 y Saldo > 0 | `Parcialmente_Pagado` | Registra abono en `Installment`, ingreso en caja y desbloqueo de citas. |
| `Parcialmente_Pagado` | Petición PUT `ENDPOINT-PAG-0007` | Saldo restante > 0 | `Parcialmente_Pagado` | Inserta nueva cuota y persiste movimiento en `CashTransaction`. |
| `Pendiente` / `Parcialmente_Pagado` | Petición PUT `ENDPOINT-PAG-0007` | Sumatoria abonos == Monto Total | `Completado` | Regularización completa; notifica cierre de deuda a sistema clínico. |
| `Cualquier estado activo` | Petición DELETE `ENDPOINT-PAG-0008` | Venta no anulada previamente | `Anulado` | Borrado lógico (`status = 'anulado'`) en cascada para venta y cuotas. |

---

## 2. Ciclo de Vida y Transiciones de `Installment` (Cuota)

Modela la obligación o compromiso de pago periódico de una venta.

```mermaid
stateDiagram-v2
    [*] --> Pendiente : Creación de cuota proyectada con fecha de vencimiento
    [*] --> Pagada : Creación de abono inicial al contado (is_initial_payment = true)

    Pendiente --> Pagada_Parcial : Pago recibido menor al monto total de la cuota
    Pagada_Parcial --> Pagada_Parcial : Nuevos pagos fraccionados acumulados < Monto
    
    Pendiente --> Pagada : Pago recibido igual al monto de la cuota
    Pagada_Parcial --> Pagada : Pago complementario que cubre el 100% de la cuota

    Pendiente --> Vencida : Fecha actual > due_date y paid_amount < amount
    Vencida --> Pagada_Parcial : Amortización parcial posterior al vencimiento
    Vencida --> Pagada : Liquidación total posterior al vencimiento

    Pendiente --> Anulada : Anulación de venta padre (borrado lógico)
    Pagada_Parcial --> Anulada : Anulación de venta padre (borrado lógico)
    Pagada --> Anulada : Anulación de venta padre (borrado lógico)
    Vencida --> Anulada : Anulación de venta padre (borrado lógico)

    Pagada --> [*]
    Anulada --> [*]
```

### Tabla de Transiciones de `Installment`

| Estado Origen | Evento / Disparador | Condición de Guarda | Estado Destino | Acción / Consecuencia |
| :--- | :--- | :--- | :--- | :--- |
| `[*]` | Registro de venta | Cuota diferida futura | `Pendiente` | Genera registro de deuda por cobrar con fecha de vencimiento. |
| `[*]` | Registro de venta | Pago en mostrador | `Pagada` | Marca `is_initial_payment = true`, `paid_amount = amount`. |
| `Pendiente` | Pago en ventanilla | Pago parcial < amount | `Pagada_Parcial` | Actualiza `paid_amount` acumulado; genera `installment_payment`. |
| `Pendiente` / `Pagada_Parcial` | Pago en ventanilla | Pago acumulado == amount | `Pagada` | Salda la cuota; actualiza balance del paquete. |
| `Pendiente` | Verificación cronológica | NOW() > due_date | `Vencida` | Alerta de mora financiera para restricción de citas en admisión. |
| `Vencida` | Pago de regularización | Pago >= saldo de cuota | `Pagada` | Restablece estatus de paciente al día. |
| `Cualquier estado` | Anulación ILA-PAG-0008 | Evento de anulación de venta | `Anulada` | Borrado lógico (`status = 'anulado'`). |

---

## 3. Ciclo de Vida de `InstallmentPayment` (Movimiento de Cobro)

```mermaid
stateDiagram-v2
    [*] --> Registrado : Cobro en mostrador (Efectivo/Yape)
    Registrado --> Vinculado_A_Caja : Enlace automático a cash_transaction_id
    Vinculado_A_Caja --> Anulado : Anulación de la venta o transacción
    Vinculado_A_Caja --> Conciliado : Cuadre de caja diario de sede (Arqueo)
    Conciliado --> [*]
    Anulado --> [*]
```
