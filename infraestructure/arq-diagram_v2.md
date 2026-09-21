# Diagrama de Arquitectura Unificada (v2 Definitiva)

Arquitectura de producción basada en un **Monolito Modular con Clean Architecture** en **Java 21 / Spring Boot 3**, desplegado en un único **VPS autoalojado** con **PostgreSQL** y esquemas lógicos independientes.

> **Nota de Decisión:** Esta versión consolida la unificación de los equipos de desarrollo (RRHH/Pagos y Módulo Clínico), eliminando definitivamente el broker externo de mensajería (RabbitMQ / Azure Service Bus) en favor de llamadas transaccionales directas y eventos de dominio en memoria.

```mermaid
flowchart LR
    subgraph Entrada["Dispositivos y Usuarios"]
        UI["Usuarios Web<br/>(Administración, Recepción)"]
        Biometrico["Reloj Biométrico<br/>(Marcaciones de Sede)"]
    end

    subgraph VPS["VPS Único Autoalojado"]
        Gateway["Reverse Proxy / SSL Gateway<br/>(Nginx / Caddy)"]

        subgraph Monorepo["Monolito Modular (Java 21 / Spring Boot 3)"]
            subgraph Modulos["Módulos Internos de Dominio (Clean Architecture)"]
                Personal["Módulo Personal<br/>(Sedes, Turnos, Asistencias)"]
                Pagos["Módulo Pagos<br/>(Caja, Cuotas, Comisiones)"]
                Reportes["Módulo Reportes<br/>(Estadísticas y Agregados)"]
                Clinico["Módulo Clínico<br/>(Pacientes, Fichas, Citas)"]
            end

            subgraph Comunicacion["Estrategia de Comunicación Interna (In-Process)"]
                DirectCalls["Llamadas Directas (Interfaces de Servicio)<br/>• Comandos principales (Venta paquete)<br/>• Consultas y validaciones (DNI, deuda)<br/>• Transacciones atómicas ACID (DB única)"]
                EventBus["Bus de Eventos en Memoria (ApplicationEventPublisher)<br/>• Notificaciones internas entre módulos<br/>• Efectos secundarios (auditoría, alertas)<br/>• Actualización no bloqueante de reportes"]
            end

            DataAccess["Capa de Acceso a Datos<br/>(Spring Data JPA / Hibernate)"]
        end

        subgraph Datos["Base de Datos Unificada (PostgreSQL)"]
            subgraph Esquemas["Esquemas Lógicos Particionados"]
                SchemaPersonal[("schema: personal")]
                SchemaPagos[("schema: pagos")]
                SchemaReportes[("schema: reportes")]
                SchemaClinico[("schema: clinico")]
            end
        end

        Infra["Docker Compose<br/>(Orquestación de Contenedores en VPS)"]
        Migrations["Migraciones de Base de Datos<br/>(Flyway / Liquibase)"]
    end

    %% Flujos de entrada
    UI -->|HTTPS / REST + JWT| Gateway
    Biometrico -->|TCP/IP - HTTP Sede| Gateway
    Gateway --> Modulos

    %% Comunicación interna en el monolito
    Pagos <-->|Llamada directa / Transacción ACID| Clinico
    Personal <-->|Llamada directa / Consulta de disponibilidad| Clinico
    Pagos -.->|Publica evento en memoria| EventBus
    Personal -.->|Publica evento en memoria| EventBus
    EventBus -.->|Escucha y actualiza asíncronamente| Reportes

    %% Persistencia por esquema
    Modulos --> DataAccess
    DataAccess --> SchemaPersonal
    DataAccess --> SchemaPagos
    DataAccess --> SchemaReportes
    DataAccess --> SchemaClinico

    %% Infraestructura y despliegue
    Infra -.-> Gateway
    Infra -.-> Monorepo
    Infra -.-> Datos
    Migrations -.-> Datos
```

---

## Componentes y Principios Clave

1. **Proxy Inverso (Nginx / Caddy):** Termina conexiones SSL/TLS, distribuye solicitudes a los endpoints de la API REST y sirve como cortafuegos perimetral.
2. **Monolito Modular (Java 21 / Spring Boot 3):**
   - Todos los módulos se compilan y empaquetan en un solo artefacto ejecutable dentro de un contenedor Docker.
   - Cada módulo encapsula sus reglas de dominio, casos de uso y puertos según Clean Architecture.
3. **Comunicación Híbrida In-Process (ADR-0004):**
   - **Llamadas Directas:** Para operaciones que demandan consistencia inmediata y transaccionalidad ACID (ej. cobrar un paquete y habilitar sesiones terapéuticas al paciente simultáneamente).
   - **Eventos en Memoria (`ApplicationEventPublisher`):** Para desacoplar efectos secundarios, auditoría y actualización de agregados sin bloquear el hilo de ejecución principal.
4. **Base de Datos Unificada en PostgreSQL (ADR-0002):**
   - Una única instancia de base de datos dividida en 4 esquemas: `personal`, `pagos`, `reportes` y `clinico`.
   - Soporte multi-sede gobernado por la columna `sede_id` (ADR-0003).
5. **Cero Dependencias de Brokers Externos:** Se eliminó RabbitMQ, simplificando la operación y garantizando máxima estabilidad y bajo consumo de recursos en el servidor VPS.