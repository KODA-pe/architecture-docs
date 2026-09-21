# ADR-0002: Base de Datos Unificada en PostgreSQL con Esquemas Lógicos

## Metadatos
- **Estado:** Aceptado
- **Fecha:** 2026-09-20
- **Autores / Decisores:** Equipo de Arquitectura de Software, Especialistas en Bases de Datos
- **Módulos Afectados:** Personal, Pagos, Reportes, Clínico (InnovaByte)

---

## 1. Contexto y Planteamiento del Problema

En la propuesta arquitectónica original basada en microservicios, se definió el patrón *Database per Service*, asignando bases de datos independientes en Azure SQL (`PersonalDB`, `PaymentsDB`, `ReportsDB`), sumado a una base de datos separada para el sistema clínico de InnovaByte.

Esta disposición planteaba serios inconvenientes técnicos y operativos:
1. **Multiplicación de Costos y Mantenimiento:** Administrar múltiples instancias de bases de datos o catálogos independientes en un VPS multiplica los requerimientos de memoria RAM, procesos de motor, configuración de pools de conexiones y rutinas de respaldo (backups).
2. **Imposibilidad de Integridad Referencial:** Dificultad para garantizar consistencia entre ventas de paquetes (`package_sale`), pacientes (`patient`), sedes (`branch`) y empleados (`employee`), obligando a duplicar datos o tolerar inconsistencias.
3. **Consolidación Compleja de Reportes:** El módulo de reportes (`report-service`) requería duplicar agregados mediante eventos consumidos de un broker para responder a consultas contables y de producción clínica, lo que introducía redundancia masiva y desfase temporal.

Se requería unificar la persistencia para optimizar recursos y garantizar transaccionalidad, pero conservando una clara separación de responsabilidades y límites de dominio entre módulos.

---

## 2. Opciones Consideradas

### Opción A: Base de Datos Dedicada por Servicio (Database per Service)
- **Ventajas:** Aislamiento total de almacenamiento; cero riesgo de colisión de tablas; escalabilidad de almacenamiento desacoplada.
- **Desventajas:**
  - Alto consumo de memoria en el VPS (múltiples catálogos e instancias de conexión).
  - Imposibilidad de ejecutar transacciones ACID nativas entre el módulo de pagos y el módulo clínico (p. ej., registrar venta de paquete y habilitar la terapia del paciente en el mismo acto).
  - Respaldos fragmentados y riesgo de desincronización en restauraciones de desastres.

### Opción B: Base de Datos Única con Esquema Único (`public`) sin Particionamiento
- **Ventajas:** Mínimo esfuerzo inicial de configuración.
- **Desventajas:** Alto riesgo de "acoplamiento a nivel de datos" (tablas compartidas indiscriminadamente, llaves foráneas cruzadas sin control, dificultad para auditar accesos por módulo).

### Opción C (Seleccionada): Base de Datos Única en PostgreSQL con Esquemas Lógicos Separados
- Despliegue de una única instancia de **PostgreSQL** en el VPS.
- Creación de esquemas lógicos independientes para cada contexto delimitado:
  - `personal`: Gestión de empleados, roles, especialidades, sucursales, turnos, asistencias e incidencias.
  - `pagos`: Transacciones de caja diaria, ventas de paquetes, cuotas (`installment`), pagos de cuotas (`installment_payment`), comisionistas y egresos fijos.
  - `reportes`: Vistas materializadas, tablas de hechos y agregados históricos para dashboards gerenciales.
  - `clinico`: Pacientes, fichas clínicas, evaluaciones, citas y atenciones fisioterapéuticas unificadas.
- Gestión unificada de migraciones con herramientas estándar de la industria (**Flyway** o **Liquibase**) integradas en el ciclo de vida de la aplicación Java/Spring Boot.

---

## 3. Decisión

Se decide **descartar el esquema de base de datos dedicada por servicio** y adoptar una **única base de datos en PostgreSQL estructurada mediante esquemas lógicos (`schemas`) independientes por módulo (`personal`, `pagos`, `reportes`, `clinico`)**.

### Políticas de Acceso a Datos:
1. **Límites Transaccionales de Escritura:** Cada módulo de la aplicación únicamente tiene permitido escribir en las tablas pertenecientes a su propio esquema lógico. Queda estrictamente prohibido que un módulo realice `INSERT`, `UPDATE` o `DELETE` directos en tablas de otro esquema; cualquier interacción de negocio debe realizarse a través de la capa de aplicación o servicios de dominio.
2. **Consultas de Reportes:** El esquema `reportes` puede consultar datos de los otros esquemas mediante vistas estructuradas optimizadas para lectura, eliminando la necesidad de duplicación asíncrona de datos.
3. **Integridad Referencial Controlada:** Las claves foráneas inter-módulos (por ejemplo, `package_sale.patient_id` refiriéndose a `clinico.paciente.id`) se declaran a nivel de motor para asegurar consistencia física de datos, sin que ello autorice el acoplamiento a nivel de código fuente.

---

## 4. Consecuencias

### Positivas
- **Ahorro Radical de Recursos:** Una única instancia de PostgreSQL consume sustancialmente menos memoria RAM y CPU en el VPS que múltiples bases de datos aisladas.
- **Backups y Recuperación Centralizados:** Se realizan respaldos consistentes de todo el estado del sistema (`pg_dump`) en un único punto en el tiempo, eliminando inconsistencias temporales en tareas de restauración.
- **Transaccionalidad ACID Inmediata:** Posibilidad de abrir transacciones de base de datos coordinadas en operaciones de negocio críticas que involucran finanzas y registro de atenciones.
- **Aislamiento Lógico Claro:** Los esquemas de PostgreSQL ofrecen una separación nítida en el catálogo (`search_path`), facilitando la navegación, mantenimiento y eventual migración si un módulo lo requiriese en el futuro.
- **Simplificación del Esquema de Reportes:** Se elimina la infraestructura de sincronización basada en eventos y tablas resumen redundantes; los reportes pueden alimentarse directamente o mediante vistas SQL altamente optimizadas con índices.

### Negativas / Riesgos y Mitigaciones
- **Riesgo de Acoplamiento a Nivel de Base de Datos:** Algún desarrollador podría intentar escribir consultas complejas con `JOIN` directos entre esquemas dentro de la lógica transaccional.
  - *Mitigación:* Pruebas de integración automatizadas y definición de usuarios de base de datos por módulo con permisos de esquema acotados, o validación estricta de repositorios mediante Spring Data JPA.
- **Cuello de Botella Único:** Toda la carga de I/O converge en un solo motor de base de datos.
  - *Mitigación:* PostgreSQL soporta holgadamente miles de transacciones por segundo para la carga esperada de las 3 sedes; se configurará un pool de conexiones optimizado (HikariCP) y se monitoreará el I/O en disco (SSD del VPS).

---

## 5. Trazabilidad con Requisitos

- **RNF-0002 (Integridad de Datos):** Integridad referencial nativa que previene datos huérfanos entre pagos, pacientes y personal.
- **RNF-0006 (Latencia de Consulta):** Consultas directas sobre PostgreSQL con índices compuestos sobre `sede_id` y fechas de operación.
- **RNF-0008 (Copias de Respaldo):** Simplificación del procedimiento de backup automatizado diario en un único archivo dump con retención en almacenamiento externo seguro.
- **RNF-0014 (Costo-Efectividad):** Reducción de costos de licencias y recursos de cómputo en el servidor VPS.
