
## 1. Personal‑Service (Gestión de personal, roles, sucursales, turnos, asistencias y excepciones)

**Notas:**
- `Employee` cubre fisioterapeutas, recepcionistas e internos.
- Las especialidades de los fisioterapeutas se manejan con una relación muchos-a-muchos.
- `satisfaction_level` es un campo numérico (ej. 1‑5) que almacena la satisfacción del fisioterapeuta.
- `Attendance` guarda las marcas de entrada/salida, la tardanza calculada y si fue automática (biométrico) o manual.

---

## 2. Payment‑Service (Caja diaria, venta de paquetes, comisiones externas y gastos fijos)

**Notas:**
- `Patient` mantiene un registro mínimo de pacientes para búsquedas y consultas de deuda, referenciando al ID del módulo clínico.
- `CashTransaction` cubre tanto ingresos como egresos. `payment_method` puede ser "Cash" o "Yape". `category` permite diferenciar cobro de paquetes, sesiones, informes, gastos operativos o pago de comisiones.
- `PackageSale` registra la venta con las reglas de negocio aplicadas (IGV, descuento por evaluación). El estado puede ser "pending", "partially_paid", "fully_paid".
- `Installment` modela los pagos parciales (inicial mínimo S/50, siguientes S/40), cada uno vinculado a la venta.
- `Referrer` guarda al "shopper" o traumatólogo afiliado, con su información de pago y comisión por defecto.
- `CommissionRecord` almacena las comisiones ganadas por paciente. Para el cálculo mensual del traumatólogo se puede sumar por mes y referidor.

---

## 3. Report‑Service (Reportes administrativos y estadísticas)

**Notas:**
- Este servicio no almacena datos transaccionales, solo **agregados** para responder rápido a los reportes.
- `DailyIncomeSummary` se construye a partir de eventos de `CashTransaction` (creados, actualizados) consumidos desde el broker. El campo `net_cash_balance` podría calcularse como total inflows menos total operating expenses.
- `MonthlyStats` es una tabla de hechos por mes que agrega pacientes únicos, ingresos totales, IVA recolectado, etc., alimentada por eventos de `PackageSale` y `CashTransaction`.
- `PackageSaleSummary` permite consultas más detalladas (listado plano de ingresos por ventas) para el reporte administrativo que exige contabilidad, sin acoplarse al servicio de pagos.

---
