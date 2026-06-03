
# Contexto del Proyecto

Sistema clínico. Solo se desarrolla la parte de RRHH y pagos. La parte clínica la maneja otro equipo (InnovaByte).

## Servicios a desarrollar

- **personal-service:** doctores, horarios, roles, asistencia, sucursales, excepciones.
- **payment-service:** pagos de sesiones/paquetes de pacientes, pago a doctores externos, gastos fijos.
- **report-service:** reportes administrativos planos y estadísticas gráficas para gerencia.

## Documentacion tecnica

- **Bases de datos:** [databases/README.md](databases/README.md)
- **Infraestructura:** [infraestructure/README.md](infraestructure/README.md)

---

# REQUISITOS (EDU)

## Servicio: Payment

### EDU-0001 – Cash Management
- **Actores:** Administrador, Recepcionista
- **Importancia:** Vital
- CRUD de transacciones diarias de caja (ingresos y egresos).
- Ingresos: cobro de paquetes, sesiones individuales, informes terapéuticos.
- Egresos: gastos operativos, pago de comisiones externas.
- El cierre de caja debe separar montos en "Efectivo" y "Yape".
- Los gastos fijos mensuales (salarios, alquiler) se manejan aparte en EDU-0021.

### EDU-0002 – Package Management
- **Actores:** Administrador, Recepcionista
- **Importancia:** Vital
- CRUD de venta de paquetes o sesiones individuales.
- Reglas de negocio al crear:
  - Confirmación obligatoria de firma de Consentimiento Informado físico.
  - Si pide factura/recibo, agregar 18% IGV al precio base.
  - Si compra el paquete el mismo día de su evaluación, descontar S/25 del total.
- Pagos en cuotas: pago inicial mínimo S/50, cuotas subsiguientes de S/40.
- Si un paciente no paga su cuota, no se le niega la terapia del día, pero se registra la deuda y se bloquean futuras reservas notificando al módulo clínico.
- Al registrar la venta, notificar vía API al equipo clínico que el paquete está pagado.

### EDU-0005 – External Commission Management
- **Actores:** Administrador, Recepcionista
- **Importancia:** Vital
- Maneja pagos de comisiones a personas externas a la organización.
- Dos tipos de comisionistas:
  - "Referrer" (shopper): pago diario de S/25 condicionado a que el paciente tenga al menos 1 sesión.
  - "Traumatólogo afiliado": externo con alianza estratégica, pago mensual acumulativo por paciente referido con receta de rehabilitación.
- Registrar método de pago (Yape/teléfono o cuenta bancaria).
- Ver historial y generar reporte mensual filtrado por médico con lista de pacientes referidos.
- Cambiar estatus de pendiente a pagado, corregir montos, eliminar lógicamente.

### EDU-0021 – Fixed Expense Management
- **Actores:** Administrador
- **Importancia:** Vital
- CRUD de gastos fijos mensuales, independiente de la caja diaria.
- Categorías: Alquiler de locales, Honorarios profesionales (contabilidad), Salarios de personal fijo (titulados, técnicos, internos, recepción), Servicios externos (seguridad, teléfono).
- Acceso exclusivo y confidencial del administrador.

---

## Servicio: Personal

### EDU-0003 – Attendance Management
- **Actores:** Administrador
- **Fuente:** FUE-0008
- **Importancia:** Vital
- CRUD de registro de asistencia del personal en las 3 sucursales (Hunter, Cerro Colorado, Principal).
- Crear automáticamente (reloj biométrico) o manualmente marcaciones de entrada/salida.
- Calcular tardanzas y ausencias automáticamente.
- Regla de negocio: personal permanente solo recibe alertas; internos llevan control estricto de minutos (banco de horas a compensar).
- Modificar para justificar ausencias, corregir errores de lector o aplicar reglas por tipo de empleado.

### EDU-0004 – Physiotherapist Management
- **Actores:** Administrador
- **Importancia:** Vital
- Registrar datos personales, turnos, ubicación y nivel de satisfacción de cada fisioterapeuta.

### EDU-0008 – Role Management
- **Actores:** Administrador
- **Importancia:** Vital
- CRUD de roles de usuario con permisos por módulo.
- Administrador: acceso a módulos financieros y reportes.
- Recepcionista: solo acceso a registro de pagos.

### EDU-0009 – Branch Management
- **Actores:** Administrador
- **Importancia:** Vital
- CRUD de sucursales (nombre, dirección, horario de atención).

### EDU-0017 – Shift Assignment by Location
- **Actores:** Administrador
- **Importancia:** Alta
- CRUD de asignación de turnos a fisioterapeutas y recepcionistas.
- Cada turno: días, hora inicio, hora fin, sucursal asignada.

### EDU-0018 – Personnel Management
- **Actores:** Administrador
- **Importancia:** Alta
- CRUD de personal (fisioterapeutas, recepcionistas, internos).
- Datos: personales, tipo de contrato, ubicación, horario.
- Fisioterapeutas: registrar especialidades.
- Exponer vía API los terapeutas activos y sus especialidades para el módulo de citas del otro equipo.

### EDU-0019 – Personnel Exception Log
- **Actores:** Administrador
- **Importancia:** Alta
- CRUD de incidencias laborales: bajas médicas, ausencias, permisos, licencias, vacaciones.
- Cada incidencia: empleado, razón, fechas, horas comprometidas, estado de aprobación.
- Al registrar, bloquear automáticamente la disponibilidad del empleado y notificar al equipo clínico para que no aparezca en citas disponibles.

---

## Servicio: Report

### EDU-0007 – Administrative Report Management
- **Actores:** Administrador
- **Importancia:** Vital
- Generar reportes planos con resumen de ingresos y facturas emitidas en un rango de fechas.
- Visualizar en pantalla y exportar a Excel estructurado.
- Modificar filtros, eliminar historial guardado.

### EDU-0022 – Statistics Management
- **Actores:** Administrador
- **Importancia:** Vital
- Generar gráficos estadísticos (barras, torta) de picos de producción (meses con mayor/menor ingreso y pacientes).
- Visualizar en dashboard, modificar parámetros/filtros, eliminar gráficos guardados.
