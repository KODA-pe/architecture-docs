# Bases de Datos del Sistema

El sistema utiliza una **única base de datos relacional en PostgreSQL** alojada en el servidor VPS, particionada lógicamente mediante **esquemas (schemas)** independientes por cada módulo del dominio.

Para mayor detalle sobre esta decisión arquitectónica y el manejo de multi-sede sin multi-tenancy, consultar:
- [ADR-0002: Base de Datos Unificada en PostgreSQL con Esquemas Lógicos](../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md)
- [ADR-0003: Estrategia Multi-Sede mediante Discriminador de Columna (sede_id)](../adr/0003-gestion-multisede-mediante-discriminador-sede-id.md)

---

## 1. Esquema `personal` (Gestión de personal, roles, sucursales, turnos, asistencias y excepciones)

**Diagrama:** [personal-service-db.md](personal-service-db.md)

**Entidades principales:**
- `employee`: datos base del personal (fisioterapeutas, recepcionistas, internos).
- `role`: permisos por rol en formato `json`.
- `branch`: sucursales y horarios de atención (Cercado, Hunter, Cerro Colorado).
- `specialization` y `employee_specialization`: especialidades y relación muchos a muchos.
- `shift_assignment`: turnos programados por colaborador y sucursal (`sede_id`).
- `attendance`: marcas de entrada/salida y control de tardanzas/ausencias.
- `exception`: incidencias laborales (bajas, permisos, vacaciones) con bloqueo automático de agenda.

**Notas de diseño:**
- `employee` unifica la ficha de fisioterapeutas, recepcionistas e internos.
- `attendance` registra el origen de la marca (reloj biométrico o manual) y la sede física donde ocurrió.
- `shift_assignment` y `attendance` incluyen la llave foránea `sede_id` hacia `branch`.

---

## 2. Esquema `pagos` (Caja diaria, venta de paquetes, cuotas, comisiones externas y gastos fijos)

**Diagrama:** [payment-service-bd-v02.md](payment-service-bd-v02.md) *(Versión v2 validada)*

**Entidades principales:**
- `patient`: referencia del paciente (unificado con el módulo clínico).
- `package_sale`: venta global del paquete de tratamiento, descuentos y reglas de IGV.
- `installment`: compromiso de cuota programada (inicial de S/ 50, siguientes de S/ 40).
- `installment_payment`: registro del pago efectivo aplicado a una cuota, vinculado a caja.
- `cash_transaction`: movimientos físicos de entrada y salida de dinero por sede.
- `referrer`: promotores externos y médicos traumatólogos afiliados.
- `commission_record`: registro de comisión devengada por paciente referido.
- `fixed_expense`: gastos fijos mensuales (alquileres, sueldos, servicios de sede).

**Notas de diseño (v2):**
- **Separación entre Deuda y Cobro:** `installment` modela la obligación de pago, mientras que `installment_payment` registra cada abono real. Esto permite pagos parciales y múltiples pagos sobre una misma cuota sin desfasar la contabilidad.
- **Caja Diaria Centralizada:** Toda transacción real de dinero en efectivo, Yape o transferencia impacta en `cash_transaction` con su respectivo `sede_id` para control y arqueo de caja diario (ver [ADR-0005](../adr/0005-registro-financiero-manual-sin-pasarela-de-pagos.md)).

---

## 3. Esquema `reportes` (Reportes administrativos y estadísticas)

**Diagrama:** [report-service-db.md](report-service-db.md)

**Entidades principales:**
- `daily_income_summary`: resumen diario de ingresos, egresos y balance por sede.
- `monthly_stats`: hechos y agregados mensuales de producción, pacientes atendidos y ventas.
- `package_sale_summary`: vista/tabla consolidada para reportes administrativos y conciliación contable.

**Notas de diseño:**
- Al convivir en la misma base de datos PostgreSQL unificada (ADR-0002), este esquema se alimenta directamente mediante vistas SQL optimizadas o suscriptores de eventos en memoria (`ApplicationEventPublisher`), eliminando la necesidad de consumir eventos desde brokers externos de mensajería.

---

## 4. Esquema `clinico` (Pacientes, citas, evaluaciones y tratamientos)

Esquema unificado correspondiente a la integración del dominio clínico (anteriormente a cargo de InnovaByte):
- `paciente`: ficha maestra del paciente, datos demográficos y antecedentes.
- `cita_evaluacion`: programación y registro de evaluaciones terapéuticas iniciales.
- `tratamiento_sesion`: control de sesiones de terapia realizadas con cargo a los paquetes pagados.
