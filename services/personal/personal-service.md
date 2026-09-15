# Resumen y Arquitectura Genérica del Servicio de Personal

El servicio de personal administra la identidad, asignación laboral, control de asistencia e incidencias del talento humano de la clínica sobre la base de datos centralizada (esquema **personal** / **DB_staff_db**). Su operación cubre el registro de sedes físicas, ficha integral de fisioterapeutas, programación semanal de turnos, captura de marcaciones de asistencia (presenciales y biométricas) y la gestión de permisos o vacaciones. Trabaja con las tablas **employee**, **role**, **branch**, **specialization**, **employee_specialization**, **shift_assignment**, **attendance** y **exception**.

La lógica general se apoya en cinco principios arquitectónicos y de negocio:

- **Aislamiento multi-sede:** un empleado tiene una sede contractual base, pero el sistema permite la asignación dinámica de turnos y marcación de asistencia en cualquiera de las sedes de Arequipa (Cercado, Hunter y Cerro Colorado) sin conflicto de identidad.
- **Tolerancia a fallos de red (Resiliencia Offline - RNF-0012):** ante caídas del enlace de internet en las sedes periféricas, el registro de asistencia mediante reloj biométrico o terminal local almacena eventos en un buffer de contingencia local, garantizando sincronización posterior sin pérdida de marcas.
- **Diferenciación de reglas laborales:** la asistencia aplica políticas diferenciadas según el tipo de contrato: el personal fijo genera alertas administrativas ante tardanzas sin descuento automático, mientras que los practicantes/internos acumulan minutos estrictos en una "bolsa de horas" sujeta a compensación los fines de semana.
- **Inmutabilidad y trazabilidad de excepciones:** toda licencia médica, permiso o vacación aprobada bloquea automáticamente la disponibilidad del terapeuta e informa al módulo clínico para impedir el agendamiento indebido de citas.
- **Seguridad perimetral y roles:** el acceso a la creación de personal y asignación salarial/contractual es exclusivo del Administrador (ACT-0001), validando identidades mediante tokens criptográficos JWT (RNF-0003).
- **Eficiencia de costos e infraestructura unificada:** en alineación con las restricciones presupuestarias de la clínica (decisión validada con el cliente y el docente), el servicio se despliega dentro de un VPS autoalojado bajo contenedor Docker, eliminando costos excesivos de servicios PaaS en la nube y compartiendo esquema lógico en la base de datos unificada con InnovaByte.

---

## 1. Arquitectura Genérica del Sistema (Nivel 2 con Trazabilidad RNF)

El Servicio de Personal adopta una **Arquitectura Heterogénea**, combinando un estilo **Distribuido Cliente-Servidor** para desacoplar las interfaces web de usuario del backend, con una organización interna basada en el patrón de **Arquitectura Hexagonal (Puertos y Adaptadores)**.

Siguiendo las directrices del docente Dr. Percy Huertas, este diagrama representa la **Vista de Nivel 2**, incorporando la trazabilidad explícita de los Requisitos No Funcionales (RNF) en cada conector y puerto de integración:

```mermaid
flowchart LR
    subgraph ADAPTADORES_IN["Adaptadores de Entrada (Primarios)"]
        UI_ADMIN["SPA Web Administración<br/>(Gestión Sedes y Terapeutas)"]
        UI_RECEPCION["SPA Web Recepción<br/>(Consulta Turnos y Horarios)"]
        DVC_BIO["Dispositivo Biométrico ZKTeco<br/>(Lector de Huella en Sede)"]
    end

    subgraph HEXAGONO_PERSONAL["HEXÁGONO DEL SUBSISTEMA DE PERSONAL"]
        subgraph PUERTOS_IN["Puertos de Entrada"]
            P_SEDES["StaffManagementPort<br/>[RNF-0006: Latencia &le; 1.5s]"]
            P_TURNOS["ShiftSchedulingPort<br/>[Validación No-Solapamiento]"]
            P_ASIS["AttendanceServicePort<br/>[RNF-0012: Ingesta Asistencia]"]
            P_EXCEP["ExceptionPolicyPort<br/>[Bloqueo Agenda Citas]"]
            P_AUTH["AuthSecurityPort<br/>[RNF-0003: JWT & Roles]"]
        end

        subgraph CORE_DOMINIO["Núcleo del Dominio (Reglas Puras de OmVital)"]
            E_TERAP["Entidad Physiotherapist<br/>(Contrato y Especialidad)"]
            E_TURNO["Entidad ShiftAssignment<br/>(Regla: No solapar sedes/horas)"]
            E_ASIS["Entidad Attendance<br/>(Tolerancia 10m, Bolsa horas)"]
            E_EXCEP["Entidad Exception<br/>(Bloqueo disponibilidad)"]
            
            E_TERAP --- E_TURNO
            E_TURNO --- E_ASIS
            E_TERAP --- E_EXCEP
        end

        subgraph PUERTOS_OUT["Puertos de Salida"]
            PO_DB["StaffRepositoryPort<br/>[RNF-0006: SQL Transaccional]"]
            PO_INNOVA["ExternalAgendaSyncPort<br/>[Contrato API InnovaByte]"]
            PO_SYNC["OfflineBufferSyncPort<br/>[RNF-0012: Sincronización Buffer]"]
            PO_EVENT["EventPublisherPort<br/>[Publicación a Broker VPS]"]
        end
    end

    subgraph ADAPTADORES_OUT["Adaptadores de Salida (Secundarios)"]
        DB_STAFF[("BD Unificada VPS<br/>(Esquema: personal)")]
        INNOVABYTE["Módulo Clínico InnovaByte<br/>(Agenda de Citas)"]
        BROKER_VPS["Broker de Eventos VPS<br/>(RabbitMQ / NATS)"]
        CACHE_LOCAL["Buffer Local en Sede<br/>(SQLite / Memoria Reloj)"]
    end

    UI_ADMIN -->|HTTPS / REST + JWT [RNF-0003]| P_SEDES
    UI_ADMIN -->|HTTPS / REST + JWT [RNF-0003]| P_TURNOS
    UI_ADMIN -->|HTTPS / REST + JWT [RNF-0003]| P_EXCEP
    UI_RECEPCION -->|HTTPS / REST + JWT [RNF-0003]| P_AUTH
    DVC_BIO -->|TCP/IP - Wi-Fi Sede [RNF-0012, DVC-0030]| P_ASIS

    P_SEDES --> CORE_DOMINIO
    P_TURNOS --> CORE_DOMINIO
    P_ASIS --> CORE_DOMINIO
    P_EXCEP --> CORE_DOMINIO
    P_AUTH --> CORE_DOMINIO

    CORE_DOMINIO --> PO_DB
    CORE_DOMINIO --> PO_INNOVA
    CORE_DOMINIO --> PO_SYNC
    CORE_DOMINIO --> PO_EVENT

    PO_DB --> DB_STAFF
    PO_INNOVA --> INNOVABYTE
    PO_EVENT --> BROKER_VPS
    PO_SYNC --> CACHE_LOCAL
```

---

## 2. Gestión de Sedes, Fisioterapeutas y Turnos (Responsable: Fernando Garambel)

Cubre las educciones **EDU-0004** (Gestión de Fisioterapeutas), **EDU-0009** (Gestión de Sedes), **EDU-0017** (Asignación de Turnos por Sede) y **EDU-0018** (Gestión Integral de Personal).

### 2.1. Crear y actualizar ficha de fisioterapeuta con especialidades
- El Administrador inicia sesión y accede al formulario de alta/edición de personal.
- Ingresa datos de identidad: DNI/cédula, nombres, apellidos, correo institucional, teléfono, tipo de contrato (permanente, temporal, internista) y selecciona una o más especialidades (Traumatología, Masoterapia, Kinesiología) adjuntando enlaces a certificados.
- Validaciones:
  - Unicidad de documento de identidad y correo electrónico.
  - Validación de formato de teléfono y campos obligatorios no nulos.
  - En caso de fisioterapeutas titulados, al menos una especialidad acreditada es obligatoria.
- Si todo es válido:
  - Se persiste atómicamente en **employee**, **specialization** y la tabla relacional **employee_specialization**.
  - Se devuelve código de estado 201 (Creado) o 200 (Actualizado).
- Postcondición: el profesional queda activo en el sistema, listo para programación horaria.

### 2.2. Asignación y control de turnos no solapados entre sedes
- El Administrador selecciona un empleado, una sede de destino (Cercado, Hunter o Cerro Colorado), los días de la semana y el rango horario (hora inicio y hora fin).
- Validaciones de regla de negocio:
  - **Incompatibilidad horaria:** el sistema verifica que el fisioterapeuta no cuente con un turno asignado en otra sede en el mismo día y en un intervalo de tiempo superpuesto.
  - **Margen de traslado:** el sistema sugiere una separación mínima de 45 minutos si el empleado debe cambiar de sede física en un mismo día.
- Si no hay solapamiento:
  - Se guarda el registro en **shift_assignment**.
  - Se genera un evento de sincronización hacia el puerto de interoperabilidad con InnovaByte.
- Postcondición: el fisioterapeuta queda habilitado en la grilla de disponibilidad de esa sede.

### 2.3. Consulta de disponibilidad para el módulo clínico externo (Contrato InnovaByte)
- El módulo externo de citas de InnovaByte invoca el puerto `ExternalAgendaSyncPort` consultando la disponibilidad de terapeutas para una fecha y sede específicas.
- El servicio de Personal filtra empleados activos, cruza sus turnos asignados en **shift_assignment** y descuenta aquellos que posean registros aprobados en **exception**.
- Retorna un payload JSON optimizado con identificador de terapeuta, nombre, especialidades validadas y bloques horarios libres.
- Postcondición: operación de solo lectura, aislada de la base de datos clínica.

---

## 3. Control de Asistencia y Marcación Biométrica (Responsable: Alexandra)

Cubre la educción **EDU-0003** (Gestión de Asistencia) y el requisito no funcional **RNF-0012** (Integración con Lector Biométrico ZKTeco Sensefp M1b / DVC-0030).

### 3.1. Procesamiento de marcación biométrica en sede
- El empleado coloca su huella en el lector biométrico instalado en la sede.
- El dispositivo realiza el emparejamiento 1:N internamente y envía el identificador de usuario y timestamp hacia el adaptador del servicio.
- Validaciones:
  - Existencia y estado activo del empleado en **employee**.
  - Detección de marcación previa del día en **attendance** para conmutar lógicamente entre "Entrada" (`clock_in`) y "Salida" (`clock_out`).
- Cálculo de reglas de negocio:
  - Cruce con el horario oficial en **shift_assignment**.
  - Si la entrada supera la tolerancia (10 minutos), calcula minutos exactos de tardanza.
  - Si es practicante, suma minutos a la bolsa de horas a compensar. Si es personal fijo, genera notificación de aviso sin deducción automática.
- Postcondición: registro persistido en **attendance** con `registration_method = "Biométrico"`.

### 3.2. Mecanismo de contingencia offline y sincronización
- Si se pierde la conectividad a internet en la sede, el dispositivo ZKTeco retiene las marcas en su memoria local (hasta 100,000 registros). Alternativamente, el terminal de recepción almacena los eventos en un buffer SQLite local.
- Al restaurarse el enlace de red, el puerto `OfflineBufferSyncPort` procesa en lote las marcaciones pendientes respetando el orden cronológico original de los timestamps.

### 3.3. Justificación y regularización manual de marcaciones
- El Administrador revisa el consolidado de asistencias.
- Ante fallos comprobados del lector o comisiones de servicio externas, puede ingresar una justificación documentada para regularizar la asistencia de un empleado.

---

## 4. Gestión de Excepciones Laborales, Licencias y Vacaciones (Responsables: Max y Pedro)

Cubre la educción **EDU-0019** (Registro de Incidencias Laborales y Excepciones).

### 4.1. Registro y aprobación de permisos o licencias médicas
- Registro formal de la incidencia: tipo de excepción (médica, vacacional, personal, capacitación), fechas de inicio y fin, horas comprometidas a recuperar y documentación sustentatoria.
- Flujo de estados: el registro nace como "Pendiente" y requiere la aprobación formal del Administrador para pasar a "Aprobado".
- Regla de negocio crítica:
  - Al aprobarse la excepción, el sistema emite automáticamente una notificación al módulo clínico externo (InnovaByte) para **bloquear la agenda del fisioterapeuta** en las fechas señaladas, impidiendo que los recepcionistas agenden pacientes en dichos horarios.

### 4.2. Control de compensación de horas
- Para ausencias que conllevan compromiso de recuperación (`committed_hours`), el sistema lleva el saldo restante conforme el empleado cubre turnos extraordinarios en fines de semana.

---

## 5. Control de Roles, Permisos y Autenticación (Responsable: Jhonatan)

Cubre la educción **EDU-0008** (Gestión de Roles y Permisos).

### 5.1. Autenticación y emisión de tokens
- Verificación de credenciales de usuario contra credenciales encriptadas.
- Generación de token JWT firmado que encapsula los claims del usuario: identificador, sede base, rol y permisos específicos por módulo.

### 5.2. Autorización granular de operaciones
- Middleware perimetral que valida que únicamente los usuarios con rol Administrador puedan invocar comandos de escritura en **employee**, **shift_assignment** y **exception**.
- El rol Recepcionista queda restringido estrictamente a operaciones de lectura de horarios y registro manual de asistencia por contingencia.

---

## 6. Persistencia y Efectos en la Base de Datos

El Servicio de Personal gestiona en forma exclusiva el esquema **personal** dentro de la base de datos unificada en el VPS:

- **employee:** datos demográficos, tipo de contrato, sede principal y nivel de satisfacción.
- **role:** definición de perfiles y permisos en formato JSON (`permissions`).
- **branch:** registro de sedes (Cercado, Hunter, Cerro Colorado), direcciones y horarios de funcionamiento.
- **specialization & employee_specialization:** catálogo de especialidades kinésicas y asignación N:M a fisioterapeutas.
- **shift_assignment:** programación temporal de turnos por sede, día y horas.
- **attendance:** log histórico transaccional de marcaciones, minutos de tardanza y método de registro.
- **exception:** registro de licencias, descansos y vacaciones con estado de aprobación.

---

## 7. Requisitos No Funcionales (RNF) y Mitigación de Riesgos

- **RNF-0003 (Arquitectura y Stack Tecnológico):** Despliegue en contenedor Docker sobre VPS autoalojado bajo proxy reverso Nginx, compartiendo servidor con InnovaByte para minimizar costos de operación mensual.
- **RNF-0006 (Rendimiento y Tiempo de Respuesta):** Inserción transaccional de marcaciones de asistencia y consultas de agenda con tiempos de respuesta en pantalla $\le 1.5$ segundos.
- **RNF-0012 (Control Biométrico y Resiliencia):** Tolerancia a fallos mediante buffer local ante caídas de enlace en sedes periféricas; sincronización automática al restablecerse la conexión sin duplicidad de marcas.
- **Seguridad de Datos Médicos y Laborales:** Cifrado de contraseñas, transporte seguro bajo HTTPS/TLS 1.3 y aislamiento lógico por esquemas respecto a finanzas e historias clínicas.
