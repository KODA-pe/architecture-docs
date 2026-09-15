
flowchart LR
    subgraph Entrada["Entrada"]
        UI["Usuarios (admin, recepción)"]
        Biometrico["Reloj Biométrico"]
    end

    subgraph VPS["VPS autoalojado (sin Azure)"]
        Gateway["Gateway / Reverse Proxy<br/>Nginx / Traefik / Kong"]
        Broker["Broker de eventos<br/>RabbitMQ / Kafka / NATS<br/>(opcional, para eventos externos)"]
    end

    subgraph Monorepo["Monorepo (un solo repositorio)"]
        subgraph Servicio["Servicio único (ASP.NET Core)"]
            API["API / Módulos internos<br/>Personal, Pagos, Reportes"]
            DBContext["Acceso a datos<br/>EF Core / Dapper"]
        end
        Migrations["Migraciones / Scripts SQL"]
        Infra["Docker Compose / K3s<br/>Configuración e infra"]
    end

    subgraph Datos["Base de datos única (VPS)"]
        DB[("DB única<br/>PostgreSQL / MySQL / SQL Server")]
        subgraph Esquemas["Esquemas lógicos"]
            SchemaPersonal[("personal")]
            SchemaPagos[("pagos")]
            SchemaReportes[("reportes")]
        end
        DB --- SchemaPersonal
        DB --- SchemaPagos
        DB --- SchemaReportes
    end

    subgraph Externo["Equipo InnovaByte"]
        InnovaByte["Módulo Clínico<br/>(suscriptor de eventos)"]
    end

    %% Flujos de entrada
    UI --> Gateway
    Biometrico --> Gateway

    %% Gateway al servicio único
    Gateway --> API

    %% Servicio único a la base de datos
    API --> DBContext
    DBContext --> DB

    %% Eventos hacia el exterior
    API -- "PaquetePagado" --> Broker
    API -- "AsistenciaRegistrada" --> Broker
    Broker -- "PaquetePagado" --> InnovaByte
    Broker -- "AsistenciaRegistrada" --> InnovaByte

    %% Relación del monorepo con la infraestructura
    Migrations -.-> DB
    Infra -.-> Servicio
    Infra -.-> Gateway
    Infra -.-> Broker