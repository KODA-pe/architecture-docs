# Architectural Decision Records (ADR)

Este directorio contiene el registro formal de las decisiones arquitectónicas clave adoptadas para el sistema clínico y administrativo (RRHH, Pagos, Reportes y Módulo Clínico unificado).

Cada registro documenta el contexto del problema, las opciones analizadas y descartadas, la decisión final fundamentada y sus consecuencias tanto positivas como negativas, asegurando la trazabilidad y la evolución controlada de la arquitectura.

## Estándar y Estructura

Las decisiones siguen la plantilla estándar basada en **Michael Nygard / MADR (Markdown Architectural Decision Records)**:

- **Título y Código:** Identificador correlativo y título descriptivo.
- **Estado:** `Propuesto` | `Aceptado` | `Deprecado` | `Superado por [ADR-XXXX]`.
- **Fecha y Autores:** Momento de la decisión y responsables.
- **Contexto y Problema:** Motivación, restricciones del negocio y antecedentes de diseño.
- **Opciones Consideradas y Descartadas:** Análisis comparativo de alternativas.
- **Decisión:** Selección técnica acordada con su respectiva justificación.
- **Consecuencias:** Beneficios obtenidos y compromisos asumidos (trade-offs).
- **Trazabilidad:** Mapeo directo a los Requisitos de Usuario (EDU) y Requisitos No Funcionales (RNF).

---

## Índice de Decisiones Arquitectónicas

| Código | Título | Estado | Fecha | Resumen de la Decisión |
| :--- | :--- | :---: | :---: | :--- |
| [ADR-0001](0001-adopcion-monolito-modular-clean-architecture.md) | Adopción de Monolito Modular con Clean Architecture en Java Moderno | **Aceptado** | 2026-09-20 | Descarte de microservicios distribuidos (Kubernetes/Container Apps) en favor de un monolito modular monorepo en Java 21 / Spring Boot 3. |
| [ADR-0002](0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md) | Base de Datos Unificada en PostgreSQL con Esquemas Lógicos | **Aceptado** | 2026-09-20 | Reemplazo de bases de datos dedicadas por servicio por una única instancia PostgreSQL en VPS particionada en schemas (`personal`, `pagos`, `reportes`, `clinico`). |
| [ADR-0003](0003-gestion-multisede-mediante-discriminador-sede-id.md) | Estrategia Multi-Sede mediante Discriminador de Columna (`sede_id`) | **Aceptado** | 2026-09-20 | Descarte de arquitectura multi-tenant (BD/esquema por sede); uso de discriminador a nivel de fila (`sede_id`) para las 3 sedes físicas. |
| [ADR-0004](0004-eliminacion-broker-mensajeria-y-comunicacion-hibrida-in-process.md) | Eliminación de Broker de Mensajería y Adopción de Comunicación Híbrida In-Process | **Aceptado** | 2026-09-20 | Eliminación de RabbitMQ y Azure Service Bus. Comunicación directa para comandos/transacciones ACID y eventos en memoria (`ApplicationEventPublisher`) para efectos secundarios. |
| [ADR-0005](0005-registro-financiero-manual-sin-pasarela-de-pagos.md) | Registro Administrativo Interno de Pagos sin Pasarela Online Externa | **Aceptado** | 2026-09-20 | Descarte de pasarelas de pago online (Stripe/Niubiz) por requerimiento explícito del cliente. Modelo de caja diaria y pagos en efectivo/Yape con trazabilidad administrativa. |
