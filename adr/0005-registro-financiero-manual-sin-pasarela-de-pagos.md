# ADR-0005: Registro Administrativo Interno de Pagos sin Pasarela Online Externa

## Metadatos
- **Estado:** Aceptado
- **Fecha:** 2026-09-20
- **Autores / Decisores:** Equipo de Arquitectura de Software, Cliente / Dirección de la Clínica
- **Módulos Afectados:** Pagos, Reportes

---

## 1. Contexto y Planteamiento del Problema

El módulo de pagos administra los ingresos por ventas de paquetes de terapia física, sesiones individuales, evaluaciones, así como los egresos por caja chica, pago de comisiones a médicos derivadores y gastos fijos mensuales (alquileres, sueldos, servicios).

Durante la etapa de diseño funcional y técnico se evaluó la necesidad de integrar una pasarela de pagos digital en línea (como Niubiz, Culqi, Mercado Pago o Stripe) con webhooks y procesamiento automático de tarjetas de crédito/débito.

No obstante:
- **Mandato Explicito del Cliente:** La dirección de la clínica solicitó de manera terminante **no implementar ninguna pasarela de pago electrónica**.
- **Flujo Operativo Presencial:** El 100% de las transacciones de pacientes se efectúan presencialmente en el mostrador de recepción de cada sede (Cercado, Hunter y Cerro Colorado).
- **Medios de Pago Reales:** Los usuarios abonan exclusivamente mediante **Efectivo** físico, billeteras digitales móviles (**Yape / Plin**) o transferencias bancarias directas a las cuentas de la clínica.
- **Control de Caja:** La recepcionista valida físicamente la recepción del dinero (conteo de billetes o verificación de la notificación de Yape en el teléfono institucional de la sede) antes de emitir la constancia e ingresar el registro al sistema.

---

## 2. Opciones Consideradas

### Opción A: Integración con Pasarela de Pagos Online (Niubiz / Culqi / Stripe)
- **Ventajas:** Conciliación bancaria automatizada para transacciones con tarjeta; cobro autónomo por parte del paciente.
- **Desventajas:**
  - Costos financieros innecesarios: comisiones bancarias por transacción (3.5% a 5% + IGV) incompatibles con el margen de la clínica.
  - Complejidad arquitectónica elevada: cumplimiento normativo PCI-DSS, gestión de secretos de API bancarias, procesamiento de webhooks asíncronos con idempotencia y manejo de caídas de servicio del proveedor.
  - Desalineación con el cliente: no responde a la operativa real en ventanilla de la clínica.

### Opción B (Seleccionada): Registro Transaccional Administrativo Interno (Caja Diaria y Cuotas)
- El sistema no procesa cobros electrónicos directos ni almacena datos de tarjetas.
- Actúa como un **libro mayor financiero y administrativo interno**, donde el usuario autorizado (Recepcionista o Administrador) registra el ingreso o egreso de dinero tras haber verificado la operación física.
- Separación estricta entre la deuda/obligación comercial (`package_sale`, `installment`) y el movimiento real de fondos (`installment_payment`, `cash_transaction`).
- Soporte para cierre de caja diferenciando montos por método de pago (**Efectivo** vs. **Yape**), conforme a los requerimientos de **EDU-0001**.

---

## 3. Decisión

Se decide **descartar formalmente la integración de pasarelas de pago electrónicas externas**, implementando un **módulo de gestión y registro transaccional financiero puramente administrativo e interno**.

### Reglas de Diseño del Modelo Financiero:
1. **Registro Centralizado de Fondos (`cash_transaction`):** Toda entrada o salida de dinero real se registra en `pagos.cash_transaction`, indicando `type` ("ingreso" | "salida"), `amount`, `payment_method` ("Efectivo" | "Yape" | "Transferencia"), fecha, descripción y `sede_id`.
2. **Modelo de Pagos en Dos Fases (`v02`):**
   - `package_sale`: Representa la venta global acordada con el paciente, aplicando reglas de negocio (descuento de S/ 25 por evaluación el mismo día, recargo del 18% de IGV si solicita factura, validación de consentimiento informado firmado).
   - `installment`: Representa las cuotas o compromisos de pago (abono inicial mínimo de S/ 50 y cuotas subsiguientes de S/ 40).
   - `installment_payment`: Registra cada pago individual aplicado a una cuota, vinculándose bidireccionalmente con `cash_transaction`. Permite pagos fraccionados o múltiples abonos sobre una misma cuota sin desfasar la caja.
3. **Control y Cuadre de Caja:** El sistema permite el arqueo y cierre diario de caja por sede, comparando el total recaudado en efectivo físico con el consolidado en billeteras electrónicas (Yape).
4. **Comisiones y Gastos:** Las comisiones a promotores/traumatólogos (`commission_record`) y los gastos fijos (`fixed_expense`) se registran como obligaciones y solo generan una salida en `cash_transaction` cuando el administrador confirma su desembolso.

---

## 4. Consecuencias

### Positivas
- **Alineación Total con el Negocio:** El software refleja con exactitud la operativa diaria de las recepcionistas y del administrador en las sedes físicas.
- **Cero Comisiones a Intermediarios:** Se elimina el sobrecosto de pasarelas de pago digitales para la clínica.
- **Reducción de Superficie de Ataque y Riesgo Legal:** Al no almacenar números de tarjeta de crédito/débito ni procesar tokens bancarios, el sistema queda completamente exento del alcance y auditorías de normativas complejas como PCI-DSS.
- **Simplicidad de Implementación y Mantenimiento:** No existen dependencias de librerías de terceros (SDKs de pasarelas), caídas de APIs bancarias ni webhooks que fallen por timeout.
- **Consistencia Inmediata:** La inserción del pago en la base de datos es atómica y no depende de la respuesta asíncrona de ningún procesador externo.

### Negativas / Riesgos y Mitigaciones
- **Dependencia de la Diligencia Humana en Recepción:** Un error tipográfico de la cajera o la falta de verificación del comprobante de Yape puede generar discrepancias en caja.
  - *Mitigación:* Validación de montos mínimos obligatorios en la interfaz, confirmación obligatoria en operaciones sensibles, borrado lógico con trazabilidad de usuario y arqueo diario contrastado al cierre de turno.

---

## 5. Trazabilidad con Requisitos

- **EDU-0001 (Cash Management):** Arqueo y separación de caja entre "Efectivo" y "Yape", con registro de ingresos y egresos diarios.
- **EDU-0002 (Package Management):** Venta de paquetes con cuotas (inicial S/ 50, siguientes S/ 40) e inserción directa en base de datos.
- **EDU-0005 (External Commission Management):** Registro y pago administrativo de comisiones a médicos derivadores y promotores.
- **EDU-0021 (Fixed Expense Management):** Control administrativo de gastos fijos mensuales exclusivo para la administración.
- **RNF-0003 y RNF-0004 (Seguridad y Auditoría):** Registro inmutable de transacciones con identificación de usuario y sede.
