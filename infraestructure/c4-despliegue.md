# Diagrama de Despliegue C4 — Todo el Sistema

Representa la topología física y de contenedores en producción sobre un **VPS único autoalojado**, operando las 3 sedes físicas en Arequipa (Cercado/Principal, Hunter y Cerro Colorado), de acuerdo con [ADR-0001](../adr/0001-adopcion-monolito-modular-clean-architecture.md), [ADR-0002](../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md) y [`arq-diagram_v2.md`](arq-diagram_v2.md).

```mermaid
C4Deployment
    title Diagrama de Despliegue C4 — Sistema Integral Clínico y Administrativo

    Deployment_Node(sedes, "Sedes Físicas (Arequipa)", "Cercado (Principal), Hunter, Cerro Colorado") {
        Deployment_Node(pc_sede, "Terminales de Recepción, Administración y Consultorios", "Windows / Linux / Browser") {
            Container(spa_web, "SPA Web", "Web Browser (HTTPS)", "Interfaz única para Gerencia, Cajera y Personal Clínico.")
        }
        Deployment_Node(hw_sede, "Hardware Biométrico en Sede", "ZKTeco Sensefp M1b + Terminal Local") {
            Container(zkteco, "Lector Biométrico & Buffer Offline", "Firmware ZKTeco / SQLite Local", "Captura huellas y retiene hasta 100,000 marcas ante cortes de internet (RNF-0012).")
        }
    }

    Deployment_Node(vps, "VPS Único Autoalojado", "Linux Server + Docker Engine / Docker Compose") {
        Deployment_Node(proxy_ctr, "Contenedor Reverse Proxy", "Docker: nginx / caddy") {
            Container(gateway, "Reverse Proxy & SSL Gateway", "Nginx / Caddy", "Terminación TLS 1.3, firewall perimetral y enrutamiento hacia API REST / estáticos SPA.")
        }

        Deployment_Node(app_ctr, "Contenedor Aplicación Backend", "Docker: Eclipse Temurin Java 21 LTS") {
            Container(monolito, "Monolito Modular", "Spring Boot 3 + Virtual Threads", "Módulos: personal, pagos, reportes, clinico. Comunicación in-process, HikariCP y migraciones Flyway/Liquibase.")
        }

        Deployment_Node(db_ctr, "Contenedor Base de Datos", "Docker: postgres + Volumen SSD") {
            ContainerDb(postgres, "PostgreSQL Unificado", "PostgreSQL", "Esquemas lógicos: personal, pagos, reportes, clinico. Índices compuestos (sede_id, fecha).")
        }
    }

    Deployment_Node(backup_node, "Almacenamiento Externo de Respaldos", "Object Storage / Servidor Remoto") {
        ContainerDb(backups, "Respaldos Diarios", "pg_dump cifrado", "Copia consistente diaria de toda la base de datos (ADR-0002).")
    }

    Rel(spa_web, gateway, "Consume API REST y estáticos", "HTTPS / TLS 1.3 + JWT")
    Rel(zkteco, gateway, "Sincroniza marcaciones en tiempo real o por lotes", "TCP/IP - HTTP sobre TLS")
    Rel(gateway, monolito, "Reenvía peticiones API", "HTTP (Red Bridge Docker)")
    Rel(monolito, postgres, "Ejecuta transacciones ACID y consultas", "JDBC / TCP 5432 (Red Bridge Docker)")
    Rel(postgres, backups, "Exporta respaldo diario programado", "pg_dump / SSH o HTTPS")
```

## Decisiones de Despliegue Clave

1. **VPS Único con Docker Compose ([ADR-0001](../adr/0001-adopcion-monolito-modular-clean-architecture.md)):** Se evita la sobrecarga de costo y operación de Kubernetes o PaaS distribuidos; todos los contenedores corren en un mismo host con reinicio automático (`restart: unless-stopped`).
2. **Cero Broker de Mensajería ([ADR-0004](../adr/0004-eliminacion-broker-mensajeria-y-comunicacion-hibrida-in-process.md)):** No existe contenedor RabbitMQ ni Azure Service Bus en el VPS; la comunicación entre módulos ocurre en memoria dentro del contenedor `clinical-monolith`.
3. **Instancia Única de PostgreSQL ([ADR-0002](../adr/0002-base-de-datos-unificada-postgresql-con-esquemas-logicos.md)):** Un solo volumen SSD y un único proceso `pg_dump` simplifican backups y garantizan consistencia referencial entre `pagos`, `personal`, `clinico` y `reportes`.
4. **Resiliencia en Sedes Periféricas (`RNF-0012`):** Si cae el enlace de internet en Hunter o Cerro Colorado, el reloj ZKTeco / buffer local retiene marcaciones y las sincroniza cronológicamente al restablecerse la conexión.
