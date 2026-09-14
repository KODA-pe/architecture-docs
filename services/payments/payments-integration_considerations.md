# Payments – InnovaByte

## 1. Objetivo

Definir la estructura de integración entre Payments e InnovaByte, identificando los componentes, datos, comunicaciones y responsabilidades que deben acordarse entre ambos sistemas.

## 2. Arquitectura

Payments e InnovaByte funcionan como sistemas independientes, con responsabilidades propias.

* **Payments:** ventas, pagos, cuotas, ingresos y egresos.
* **InnovaByte:** información clínica y gestión de pacientes.
* **Integración:** mecanismos mediante los cuales ambos sistemas intercambian información.

## 3. Integración

Definir los puntos donde ambos sistemas necesitan interactuar:

| Interacción              | Sistema origen | Sistema destino | Información                      |
| ------------------------ | -------------- | --------------- | -------------------------------- |
| Consulta de paciente     | Payments       | InnovaByte      | Datos del paciente               |
| Registro de venta        | Payments       | InnovaByte      | Información del paquete y estado |
| Actualización de pago    | Payments       | InnovaByte      | Estado de pago                   |
| Habilitación de atención | Payments       | InnovaByte      | Estado de la venta/pago          |

## 4. Datos compartidos

### Información del paciente

| Dato                  | Origen     | Responsable |
| --------------------- | ---------- | ----------- |
| `external_patient_id` | InnovaByte | InnovaByte  |
| `full_name`           | InnovaByte | InnovaByte  |
| `id_number`           | InnovaByte | InnovaByte  |
| `phone`               | InnovaByte | InnovaByte  |
| `status`              | InnovaByte | InnovaByte  |

### Información de pagos

| Dato                   | Origen   | Responsable |
| ---------------------- | -------- | ----------- |
| Identificador de venta | Payments | Payments    |
| Paquete adquirido      | Payments | Payments    |
| Monto                  | Payments | Payments    |
| Estado del pago        | Payments | Payments    |
| Fecha de operación     | Payments | Payments    |

## 5. Responsabilidades

Definir qué sistema es responsable de crear, modificar y mantener cada información, evitando duplicidad o inconsistencias entre las bases de datos.

## 6. Flujos

Documentar los principales escenarios de integración:

* Consulta y validación de paciente.
* Registro de una venta.
* Registro de pagos o cuotas.
* Cambio de estado de una venta.
* Habilitación o actualización de la atención del paciente.

## 7. Consideraciones

* Identificadores compartidos entre sistemas.
* Mecanismos de comunicación.
* Seguridad y autenticación.
* Manejo de errores y disponibilidad.
* Consistencia e idempotencia.
* Versionado de los contratos.
* Trazabilidad de las operaciones.

## 8. Pendientes

Registrar las decisiones que deben definirse entre ambos equipos, como endpoints, eventos, estructuras de datos, autenticación y reglas específicas de integración.