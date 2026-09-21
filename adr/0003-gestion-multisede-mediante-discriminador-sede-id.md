# ADR-0003: Estrategia Multi-Sede mediante Discriminador de Columna (sede_id)

## Metadatos
- **Estado:** Aceptado
- **Fecha:** 2026-09-20
- **Autores / Decisores:** Equipo de Arquitectura de Software, Dirección de Operaciones
- **Módulos Afectados:** Personal, Pagos, Reportes, Clínico

---

## 1. Contexto y Planteamiento del Problema

La clínica opera en tres sedes físicas distribuidas en la ciudad de Arequipa:
1. **Sede Principal (Cercado)**
2. **Sede Hunter**
3. **Sede Cerro Colorado**

Se evaluó si el sistema debía adoptar un patrón formal de **Arquitectura Multi-Tenant** (tenencia múltiple), considerando cada sede como un inquilino (*tenant*) independiente, con aislamiento físico o lógico de sus datos.

Las características operativas y de negocio de la clínica indican lo siguiente:
- Las tres sedes forman parte de una única entidad jurídica y comercial centralizada.
- **Rotación de Personal (EDU-0017):** Los fisioterapeutas y recepcionistas no están anclados estáticamente a una sede; la administración programa turnos rotativos en diferentes sedes durante la misma semana laboral.
- **Continuidad de Atención del Paciente:** Un paciente evaluado clínicamente en una sede puede recibir sesiones de tratamiento en otra sede por conveniencia horaria o cercanía.
- **Consolidación Financiera y Gerencial (EDU-0007, EDU-0022):** La Gerencia General requiere visualizar tanto la operación individual de cada sede como el consolidado global de ingresos, asistencias, gastos fijos y rentabilidad en tiempo real.
- El volumen de transacciones diario en las tres sedes es manejable de forma centralizada sin requerir particiones físicas de base de datos.

---

## 2. Opciones Consideradas

### Opción A: Multi-Tenancy con Base de Datos por Sede (Database per Tenant)
- **Ventajas:** Aislamiento total de datos por sede; posibilidad de restaurar o migrar una sede por separado.
- **Desventajas:**
  - Enorme sobrecarga de infraestructura (3 bases de datos adicionales solo para sedes).
  - Imposibilidad de manejar de forma limpia a un terapeuta o paciente con presencia en más de una sede sin duplicar registros y credenciales.
  - Reportes gerenciales consolidados sumamente complejos y lentos, requiriendo consultas distribuidas (*cross-database queries*) o procesos ETL nocturnos.
  - Mayor costo de mantenimiento y pipelines de migración repetitivos.

### Opción B: Multi-Tenancy con Esquema por Sede (Schema per Tenant)
- **Ventajas:** Aislamiento lógico dentro de la misma instancia de PostgreSQL; separación de catálogos.
- **Desventajas:**
  - Complejidad en herramientas de migración (ejecutar cada cambio de esquema 3 o más veces).
  - Enrutamiento dinámico de conexiones (`CurrentTenantResolver`) en cada petición HTTP, aumentando el riesgo de errores en la capa de persistencia.
  - Dificultad para relaciones referenciales compartidas (empleados, pacientes y especialidades globales).

### Opción C (Seleccionada): Modelo de Datos Unificado con Discriminador de Columna (`sede_id`)
- Todas las tablas que registran operaciones vinculadas a una ubicación geográfica incorporan una columna foránea obligatoria (`sede_id` / `branch_id`) referenciando a la tabla maestra `branch` del esquema `personal`.
- Tablas alcanzadas: `attendance`, `shift_assignment`, `cash_transaction`, `fixed_expense`, `package_sale`, `cita_atencion`.
- Aislamiento de acceso gobernado a nivel de la capa de aplicación:
  - **Recepcionista / Cajera:** Sus consultas y registros quedan filtrados automáticamente por el contexto de la sede a la que está asignada en su turno de trabajo actual.
  - **Administrador / Gerente:** Posee privilegios globales para consultar y operar sobre cualquier sede o generar reportes agregados que comparen el rendimiento entre sedes.

---

## 3. Decisión

Se decide **descartar formalmente una arquitectura Multi-Tenant** (tanto por base de datos como por esquema) y adoptar un **modelo unificado gobernado por un discriminador de columna (`sede_id`)**.

### Directrices de Implementación:
1. **Modelado Relacional:** La tabla `personal.branch` almacena la información maestra de las sedes (nombre, dirección, horario de atención).
2. **Llave Foránea Obligatoria:** Toda entidad de transacción física (marcas de asistencia, transacciones de caja, ventas presenciales, gastos fijos, turnos) debe declarar `sede_id INT NOT NULL REFERENCES personal.branch(id)`.
3. **Indexación Estratégica:** Se crearán índices compuestos de tipo B-Tree en PostgreSQL combinando `(sede_id, fecha)` en las tablas de mayor volumen transaccional (`attendance`, `cash_transaction`, `package_sale`), garantizando que las consultas filtradas por sede se resuelvan en milisegundos.
4. **Filtro Transparente en Capa de Aplicación:** En Java/Spring Data JPA se implementarán filtros contextuales (por ejemplo, vía anotaciones Hibernate `@Filter` o especificaciones JPA contextualizadas con el token JWT de la sesión del usuario) para garantizar que las recepcionistas solo operen sobre los datos de su sede asignada.

---

## 4. Consecuencias

### Positivas
- **Simplicidad Arquitectónica Extrema:** Cero infraestructura adicional de gestión de tenants; esquema de base de datos limpio y estandarizado.
- **Flexibilidad Operativa:** El personal y los terapeutas pueden registrarse una sola vez en el sistema y ser asignados a diferentes sedes en distintos días de la semana sin conflictos de identidad ni duplicidad de datos.
- **Reportes y Analítica Inmediata:** La generación de estadísticas comparativas (sedes con mayor afluencia, picos de ingresos por sede, gastos fijos consolidados) se ejecuta mediante una simple cláusula `GROUP BY sede_id` en PostgreSQL, sin pipelines ETL ni consultas complejas.
- **Escalabilidad Sencilla:** Incorporar una cuarta o quinta sede física en el futuro requiere únicamente insertar una nueva fila en `personal.branch`, sin necesidad de alterar código ni ejecutar migraciones DDL.

### Negativas / Riesgos y Mitigaciones
- **Riesgo de Fuga de Datos entre Sedes:** Si un desarrollador olvida incluir el filtro de `sede_id` en una consulta de recepción, un usuario de una sede podría visualizar registros de otra.
  - *Mitigación:* Pruebas de integración automatizadas que validen el aislamiento por rol; uso de filtros de persistencia automáticos a nivel de sesión y validación de permisos en los casos de uso de la capa de aplicación.

---

## 5. Trazabilidad con Requisitos

- **EDU-0003 (Asistencia):** Marcación de personal en las 3 sedes físicas con identificación unificada.
- **EDU-0009 (Gestión de Sedes):** Mantenimiento maestro de sucursales (Hunter, Cerro Colorado, Principal).
- **EDU-0017 (Asignación de Turnos):** Programación semanal flexible de terapeutas por sede sin restricciones de tenant.
- **EDU-0001 (Caja Diaria):** Control de caja por sede física independiente y consolidado gerencial.
- **RNF-0003 (Seguridad y Control de Acceso):** Restricción de permisos y visibilidad según el rol y sede asignada en el token JWT.
