# Infraestructura del Sistema

## Diagrama de arquitectura definitiva

**Archivo:** [arq-diagram_v2.md](arq-diagram_v2.md)

---

## Componentes de Infraestructura

- **Servidor VPS Único:** Servidor virtual privado autoalojado que aloja la totalidad de los servicios y datos del sistema, optimizando costos operativos (ver [ADR-0001](../adr/0001-adopcion-monolito-modular-clean-architecture.md)).
- **Reverse Proxy / SSL Gateway:** Nginx o Caddy como punto de entrada perimetral seguro para terminación HTTPS/TLS y enrutamiento hacia la aplicación web.
- **Monolito Modular (Backend):** Aplicación desarrollada en **Java moderno (Java 21 LTS / Spring Boot 3)** con principios de **Clean Architecture** / Arquitectura Hexagonal, empaquetada como un único contenedor Docker. Integra los módulos:
  - `personal`: Gestión de sedes, turnos, asistencias y personal.
  - `pagos`: Caja diaria, venta de paquetes, cuotas, gastos fijos y comisiones.
  - `reportes`: Estadísticas, métricas y agregados gerenciales.
  - `clinico`: Pacientes, historias clínicas y atenciones (unificado de InnovaByte).
- **Base de Datos Unificada (PostgreSQL):** Instancia única de PostgreSQL en contenedor VPS organizada mediante **esquemas lógicos separados** (`personal`, `pagos`, `reportes`, `clinico`), garantizando integridad referencial y transacciones ACID nativas (ver [ADR-0002](../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md)).
- **Estrategia Multi-Sede:** Gestión de las 3 sedes físicas (Hunter, Cerro Colorado, Principal) mediante discriminador de columna `sede_id` (ver [ADR-0003](../adr/0003-gestion-multisede-mediante-discriminador-sede-id.md)).
- **Orquestación y Migraciones:** Docker Compose para despliegue local en VPS y Flyway/Liquibase para control de versiones del esquema de base de datos.
- **Dispositivos y Clientes:** SPA Web (Administración y Recepción con autenticación JWT) y Reloj Biométrico en sede conectado por red local/HTTP hacia el Gateway.

---

## Mecanismos de Comunicación Interna (Sin Broker)

En concordancia con el [ADR-0004](../adr/0004-eliminacion-broker-mensajeria-y-comunicacion-hibrida-in-process.md), se ha eliminado RabbitMQ y Azure Service Bus. La comunicación entre módulos se gestiona de forma híbrida e in-process:

1. **Llamadas directas a interfaces de servicio (Application Ports):**
   - Comandos principales y transacciones atómicas que involucran cobro y habilitación clínica simultánea.
   - Consultas sincrónicas (validación de DNI, verificación de bloqueos de pacientes, disponibilidad de terapeutas).
2. **Bus de eventos en memoria (`ApplicationEventPublisher`):**
   - Notificaciones internas desacopladas.
   - Efectos secundarios que no deben bloquear la transacción principal (envío de correos, auditoría, logs).
   - Actualización asíncrona de agregados para el módulo de reportes.

---

## Registro Financiero y Pagos

Conforme a la decisión [ADR-0005](../adr/0005-registro-financiero-manual-sin-pasarela-de-pagos.md), no se utiliza ninguna pasarela de pago online externa (Stripe, Niubiz, etc.). Las transacciones reflejan la operativa real de caja presencial (Efectivo y Yape) con validación administrativa directa.
