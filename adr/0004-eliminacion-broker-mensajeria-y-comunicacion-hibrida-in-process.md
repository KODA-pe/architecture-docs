# ADR-0004: Eliminación de Broker de Mensajería y Adopción de Comunicación Híbrida In-Process

## Metadatos
- **Estado:** Aceptado
- **Fecha:** 2026-09-20
- **Autores / Decisores:** Equipo de Arquitectura de Software, Equipos de Desarrollo (Pagos/Personal e InnovaByte)
- **Módulos Afectados:** Personal, Pagos, Reportes, Clínico

---

## 1. Contexto y Planteamiento del Problema

En iteraciones de diseño anteriores se contempló el uso de un broker de mensajería asíncrona:
- **En Fase 1 (Azure):** Azure Service Bus mediante tópicos y suscripciones con Dapr Sidecars.
- **En Fase 2 (VPS):** Un contenedor dedicado con **RabbitMQ**, implementando el patrón *Transactional Outbox* para publicar eventos de integración tales como `PaquetePagado` y `AsistenciaRegistrada`, que serían consumidos por un servicio externo a cargo del equipo de InnovaByte.

### ¿Por qué se introdujo un broker inicialmente?
El broker de mensajería se justificaba únicamente por una **frontera organizativa**: dos equipos de desarrollo independientes trabajaban con bases de código separadas, calendarios distintos y bases de datos aisladas.

### El Cambio de Escenario:
Ambos equipos de desarrollo acordaron **unificar el diseño de la base de datos y converger en un único monorepo modular**. Al desaparecer la frontera física de despliegue y organizativa:
- Mantener RabbitMQ añade una sobrecarga operativa injustificada: consumo de memoria RAM en el VPS, configuración de colas, gestión de reconexiones de red, manejo de mensajes envenenados (*dead-letter queues*) y complejidad en el patrón Outbox.
- **Riesgo de Consistencia Eventual en Flujos Críticos:** Cuando un paciente compra un paquete de sesiones en recepción (EDU-0002), el recepcionista requiere confirmación inmediata para habilitar la atención terapéutica en el acto. La consistencia eventual mediada por colas introducía ventanas de tiempo donde el módulo clínico aún no reflejaba el pago, generando fricción en la atención física al paciente.

---

## 2. Opciones Consideradas

### Opción A: Mantener Broker de Mensajería (RabbitMQ en VPS) con Patrón Outbox
- **Ventajas:** Desacoplamiento temporal estricto; capacidad de reintento asíncrono si un consumidor falla.
- **Desventajas:**
  - Punto adicional de fallo de infraestructura en el VPS.
  - Sobrecarga de código: tablas de outbox, procesos en segundo plano de sondeo (*polling worker*) o CDC.
  - Desfase temporal innecesario entre el cobro y la habilitación de atención clínica.
  - Dificultad para coordinar cancelaciones o reversiones de transacciones inmediatas.

### Opción B: Comunicación Únicamente Mediante Eventos en Memoria
- **Ventajas:** Alto desacoplamiento en código.
- **Desventajas:** Dificultad para garantizar transacciones ACID atómicas en operaciones de cobro y registro simultáneo; complejidad innecesaria para consultas simples que solo requieren leer un dato de validación.

### Opción C (Seleccionada): Eliminación de Broker y Adopción de Comunicación Híbrida In-Process
Se elimina completamente RabbitMQ del VPS y se adopta una **estrategia de comunicación híbrida en memoria**, clasificando las interacciones según la naturaleza del caso de uso:

```
                          ┌────────────────────────────────────────────────────────┐
                          │         COMUNICACIÓN INTER-MODULAR IN-PROCESS          │
                          └────────────────────────────────────────────────────────┘
                                     │                                  │
                  ┌──────────────────┴─────────────┐  ┌─────────────────┴────────────────┐
                  ▼                                │  ▼                                  │
    ┌───────────────────────────┐                  │ ┌───────────────────────┐           │
    │    LLAMADAS DIRECTAS      │                  │ │  EVENTOS EN MEMORIA   │           │
    │  (Interfaces de Servicio) │                  │ │(ApplicationEventPubl.)│           │
    └───────────────────────────┘                  │ └───────────────────────┘           │
                  │                                │                 │                   │
  • Comandos principales (Venta paquete)           │ • Notificaciones internas           │
  • Consultas (Validar paciente, DNI)              │ • Efectos secundarios (emails, logs)│
  • Validaciones de reglas de negocio              │ • Actualización de métricas/reportes│
  • Transacciones atómicas ACID (DB única)         │ • Reacciones asíncronas no críticas │
```

---

## 3. Decisión

Se decide **eliminar de forma definitiva RabbitMQ, Azure Service Bus y el patrón Outbox**, adoptando un modelo de **comunicación interna híbrida in-process en Java / Spring Boot**:

### 1. Llamadas Directas mediante Interfaces de Servicio de Aplicación:
Se emplearán para operaciones que exigen respuesta sincrónica, validación estricta o participación en una única transacción de base de datos (`@Transactional`):
- **Comandos Principales:** Registro de venta de paquete (`PackageSale`) con habilitación simultánea del plan de sesiones en el esquema clínico.
- **Consultas Inter-Módulo:** Consulta de datos básicos y estado del paciente por DNI antes de emitir un cobro; consulta de turnos activos para validar asignaciones.
- **Validaciones de Negocio:** Comprobación de que el paciente no mantenga bloqueos médicos antes de vender un paquete.
- **Implementación Técnica:** Inyección de interfaces de servicio de la capa de aplicación (ej. `PatientQueryPort`, `AppointmentBookingPort`). Se prohíbe terminantemente inyectar entidades de dominio o repositorios JPA de un módulo en otro.

### 2. Eventos de Dominio en Memoria (`ApplicationEventPublisher`):
Se emplearán para desacoplar efectos secundarios que no deben comprometer ni ralentizar la transacción principal:
- **Notificaciones Internas:** Alertas administrativas al registrar una incidencia médica laboral (`EDU-0019`).
- **Efectos Secundarios:** Registro de auditoría administrativa, emisión de comprobantes en PDF asíncronos o alertas de tardanza.
- **Actualización de Métricas:** Notificación de ventas o asistencias para refrescar cachés de estadísticas gerenciales sin bloquear la respuesta HTTP al usuario.
- **Implementación Técnica:** Publicación mediante `ApplicationEventPublisher` de Spring y consumo mediante `@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)` o `@Async` para ejecuciones no bloqueantes.

---

## 4. Consecuencias

### Positivas
- **Eliminación de Infraestructura Redundante:** El VPS prescinde del contenedor de RabbitMQ, liberando recursos sustanciales de memoria RAM y procesamiento.
- **Cero Latencia y Consistencia Inmediata:** Las transacciones financieras de paquetes y cuotas actualizan directamente el estado de habilitación de atenciones en la base de datos PostgreSQL, garantizando consistencia ACID sin desfase de sincronización.
- **Arquitectura de Código Limpia y Comprensible:** Se elimina el boilerplate de workers de outbox, serializadores de mensajes, reintentos exponenciales y desduplicadores de eventos.
- **Aislamiento Preservado:** Al comunicarse mediante interfaces de aplicación bien tipadas en Java y eventos en memoria, los módulos no se acoplan a nivel de tablas ni estructuras internas.

### Negativas / Riesgos y Mitigaciones
- **Riesgo de Acoplamiento Temporal en Llamadas Directas:** Una falla en una llamada directa dentro de una transacción provocará el rollback de toda la operación.
  - *Mitigación:* Este comportamiento es precisamente el deseado para transacciones financieras y clínicas (si no se puede habilitar la atención, no debe registrarse el cobro como completado sin aviso). Para operaciones no críticas, se delega estrictamente al bus de eventos en memoria con `@Async`.

---

## 5. Trazabilidad con Requisitos

- **EDU-0002 (Venta de Paquetes):** Registro de venta e inmediata habilitación de terapia para el paciente sin intermediación de colas.
- **EDU-0003 y EDU-0019 (Asistencia e Incidencias):** Notificación inmediata al personal administrativo ante bajas y ausencias sin colas externas.
- **RNF-0006 (Tiempo de Respuesta $\le 1.5\text{ s}$):** Eliminación de retardos de encolamiento y entrega asíncrona en operaciones de recepción.
- **RNF-0014 (Eficiencia de Recursos):** Reducción de la huella de memoria del VPS al eliminar el broker de mensajería.
