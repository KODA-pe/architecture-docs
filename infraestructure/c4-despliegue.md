# Diagrama de Despliegue C4 — Todo el Sistema

Representa la topología física y de contenedores en producción sobre un **VPS único autoalojado**, operando las 3 sedes físicas en Arequipa (Cercado/Principal, Hunter y Cerro Colorado), de acuerdo con [ADR-0001](../adr/0001-adopcion-monolito-modular-clean-architecture.md), [ADR-0002](../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md) y [`arq-diagram_v2.md`](arq-diagram_v2.md).

```mermaid
flowchart TB
    classDef container fill:#438DD5,stroke:#2E6295,color:#FFFFFF,rx:6,ry:6
    classDef db fill:#1168BD,stroke:#0B4884,color:#FFFFFF
    classDef device fill:#6B7280,stroke:#4B5563,color:#FFFFFF,rx:6,ry:6

    subgraph Sedes["Sedes Físicas Arequipa: Cercado (Principal), Hunter, Cerro Colorado"]
        direction LR
        subgraph PC["Terminales Web de Sede"]
            SPA["<b>SPA Web</b><br/><i>[Navegador HTTPS]</i><br/>Gerencia, Cajera y Clínico"]:::container
        end
        subgraph HW["Hardware Biométrico de Sede"]
            ZKTeco["<b>ZKTeco Sensefp M1b + Buffer Local</b><br/><i>[Firmware / SQLite Offline]</i><br/>Retiene hasta 100,000 marcas (RNF-0012)"]:::device
        end
    end

    subgraph VPS["VPS Único Autoalojado (Linux + Docker Engine / Docker Compose)"]
        direction TB
        subgraph ProxyCtr["Contenedor: reverse-proxy"]
            Gateway["<b>Reverse Proxy / SSL Gateway</b><br/><i>[Nginx / Caddy]</i><br/>Terminación TLS 1.3, estáticos SPA y firewall"]:::container
        end

        subgraph AppCtr["Contenedor: clinical-monolith (Java 21 LTS)"]
            Monolito["<b>Monolito Modular</b><br/><i>[Spring Boot 3 + Virtual Threads]</i><br/>Módulos: personal, pagos, reportes, clinico<br/>Bus in-process, HikariCP, Flyway/Liquibase"]:::container
        end

        subgraph DbCtr["Contenedor: postgres-db (Volumen SSD)"]
            Postgres[("<b>PostgreSQL Unificado</b><br/><i>[Instancia Única]</i><br/>Esquemas: personal, pagos,<br/>reportes, clinico + índices sede_id")]:::db
        end
    end

    subgraph BackupNode["Almacenamiento Externo de Respaldos"]
        Backup[("<b>Respaldo Diario</b><br/><i>[pg_dump cifrado]</i><br/>Copia consistente ADR-0002")]:::db
    end

    SPA -->|"HTTPS / TLS 1.3 + JWT"| Gateway
    ZKTeco -->|"TCP/IP - HTTP sobre TLS<br/>(tiempo real o lote offline)"| Gateway
    Gateway -->|"HTTP (Red Bridge Docker)"| Monolito
    Monolito -->|"JDBC / TCP 5432 (Red Bridge)"| Postgres
    Postgres -->|"pg_dump diario programado"| Backup

    style Sedes fill:#F8FAFC,stroke:#94A3B8,stroke-dasharray: 5 5
    style PC fill:#FFFFFF,stroke:#CBD5E1
    style HW fill:#FFFFFF,stroke:#CBD5E1
    style VPS fill:#EFF6FF,stroke:#3B82F6,stroke-width:2px
    style ProxyCtr fill:#FFFFFF,stroke:#93C5FD
    style AppCtr fill:#FFFFFF,stroke:#93C5FD
    style DbCtr fill:#FFFFFF,stroke:#93C5FD
    style BackupNode fill:#F8FAFC,stroke:#94A3B8,stroke-dasharray: 5 5
```

## Decisiones de Despliegue Clave

1. **VPS Único con Docker Compose ([ADR-0001](../adr/0001-adopcion-monolito-modular-clean-architecture.md)):** Se evita la sobrecarga de costo y operación de Kubernetes o PaaS distribuidos; todos los contenedores corren en un mismo host con reinicio automático (`restart: unless-stopped`).
2. **Cero Broker de Mensajería ([ADR-0004](../adr/0004-eliminacion-broker-mensajeria-y-comunicacion-hibrida-in-process.md)):** No existe contenedor RabbitMQ ni Azure Service Bus en el VPS; la comunicación entre módulos ocurre en memoria dentro del contenedor `clinical-monolith`.
3. **Instancia Única de PostgreSQL ([ADR-0002](../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md)):** Un solo volumen SSD y un único proceso `pg_dump` simplifican backups y garantizan consistencia referencial entre `pagos`, `personal`, `clinico` y `reportes`.
4. **Resiliencia en Sedes Periféricas (`RNF-0012`):** Si cae el enlace de internet en Hunter o Cerro Colorado, el reloj ZKTeco / buffer local retiene marcaciones y las sincroniza cronológicamente al restablecerse la conexión.
