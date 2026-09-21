# ADR-0001: Adopción de Monolito Modular con Clean Architecture en Java Moderno

## Metadatos
- **Estado:** Aceptado
- **Fecha:** 2026-09-20
- **Autores / Decisores:** Equipo de Arquitectura de Software, Equipo de Desarrollo Clínico y Administrativo
- **Módulos Afectados:** Personal, Pagos, Reportes, Clínico (InnovaByte)

---

## 1. Contexto y Planteamiento del Problema

En las etapas tempranas de concepción del sistema clínico se consideró una arquitectura distribuida basada en microservicios independientes, desplegados en la nube (Azure Container Apps con Dapr y Azure API Management o Kubernetes).

Sin embargo, tras analizar en profundidad el dominio del problema y los requisitos funcionales (EDU) y no funcionales (RNF):
- El sistema cuenta con únicamente tres módulos de soporte administrativo y financiero (**Personal**, **Pagos**, **Reportes**) más el módulo de dominio clínico (**Clínico**).
- El volumen transaccional esperado corresponde a una operación clínica local en tres sedes físicas de Arequipa (Cercado, Hunter y Cerro Colorado), con concurrencia moderada.
- Los costos de infraestructura en la nube pública (PaaS en Azure) y la sobrecarga cognitiva, operacional y de depuración de una malla de microservicios con Kubernetes resultaban desproporcionados e injustificados.
- Existía un alto riesgo de latencia de red innecesaria en operaciones cotidianas y problemas de consistencia distribuida entre límites de servicios estrechamente relacionados.

Se requería una solución arquitectónica que garantizara un alto orden interno, límites modulares estrictos y alta mantenibilidad, sin la penalización de costo ni la complejidad operacional de los microservicios distribuidos.

---

## 2. Opciones Consideradas

### Opción A: Microservicios en Contenedores Distribuidos (Kubernetes / Azure Container Apps)
- **Ventajas:** Despliegue independiente por servicio; escalabilidad horizontal granular; aislamiento de fallos por proceso.
- **Desventajas:**
  - Sobrecosto severo de infraestructura en nube y mantenimiento de clusters.
  - Complejidad en orquestación, observabilidad distribuida (trazas distribuidas, mallas de servicios) y configuración de redes virtuales.
  - Complejidad de transacciones distribuidas (patrón Saga) para operaciones que involucran cobro y habilitación clínica inmediata.
  - Desproporcionado para un equipo de desarrollo acotado y solo 3-4 módulos de negocio.

### Opción B: Monolito Tradicional Espagueti
- **Ventajas:** Muy rápido de iniciar en fases muy tempranas; despliegue trivial en un solo artefacto.
- **Desventajas:** Alto acoplamiento; violación constante de responsabilidades; base de código inmanejable a mediano plazo; difícil paralelización del trabajo entre desarrolladores.

### Opción C (Seleccionada): Monolito Modular con Clean Architecture en Monorepo (Java Moderno)
- Estructuración de la solución en un único repositorio (**Monorepo**) que compila y empaqueta un solo artefacto ejecutable desplegable en un contenedor Docker sobre un VPS autoalojado.
- Organización interna dividida en módulos de negocio desacoplados (`personal`, `pagos`, `reportes`, `clinico`), cada uno estructurado bajo los principios de **Clean Architecture** / **Hexagonal (Puertos y Adaptadores)**:
  - Capa de Dominio (Entidades puras, objetos de valor, reglas de negocio).
  - Capa de Aplicación (Casos de uso, puertos de entrada y salida, DTOs).
  - Capa de Infraestructura (Adaptadores JPA/Hibernate, repositorios de persistencia, integración con periféricos).
  - Capa de Presentación (Controladores REST / adaptadores web).
- Plataforma tecnológica: **Java moderno (Java 21 LTS / Spring Boot 3)** aprovechando Virtual Threads (Project Loom) para concurrencia ligera, alta performance en I/O y soporte maduro para modularidad interna.

---

## 3. Decisión

Se decide **descartar formalmente la arquitectura de microservicios y Kubernetes**, adoptando un **Monolito Modular gobernado por Clean Architecture en un Monorepo con Java 21 y Spring Boot 3**.

La solución se ejecutará en un único contenedor de aplicación sobre un **VPS autoalojado**, gestionado detrás de un proxy inverso (Nginx / Caddy). Cada módulo mantendrá su aislamiento conceptual mediante paquetes y contratos de interfaz bien definidos, prohibiendo dependencias cíclicas y accesos directos a capas internas de persistencia de otros módulos.

---

## 4. Consecuencias

### Positivas
- **Eficiencia Operativa y de Costos:** Se reduce drásticamente el costo mensual de infraestructura al prescindir de clústeres gestionados de Kubernetes o servicios PaaS de Azure, operando eficientemente en un VPS económico.
- **Simplicidad de Despliegue y Mantenimiento:** Un único pipeline de CI/CD, una sola imagen Docker y un solo proceso que monitorear en producción.
- **Rendimiento Óptimo y Baja Latencia:** La comunicación intermodular ocurre in-process (en memoria), eliminando la latencia de serialización JSON/HTTP, round-trips de red y sobrecargas de sockets.
- **Transaccionalidad Confiable (ACID):** Capacidad de ejecutar operaciones transaccionales coordinadas entre módulos cuando el negocio lo exige, sin necesidad de orquestadores de transacciones distribuidas.
- **Facilidad de Pruebas:** Pruebas unitarias e integrales sencillas de ejecutar sin necesidad de simular entornos distribuidos complejos o dependencias de red externas.
- **Camino de Evolución Abierto:** Al mantener límites modulares claros con Clean Architecture, si en el futuro algún módulo específico requiriese escalar de forma independiente, su extracción a un servicio separado es directa y con mínima fricción.

### Negativas / Riesgos y Mitigaciones
- **Riesgo de Acoplamiento Indebido:** En un mismo código base existe la tentación de realizar referencias directas a repositorios o entidades ajenas.
  - *Mitigación:* Definición estricta de interfaces públicas por módulo en la capa de aplicación y aplicación de herramientas de control arquitectónico (como ArchUnit en Java) en el pipeline de compilación para rechazar dependencias indebidas.
- **Despliegue Todo o Nada:** Un error crítico en un módulo detiene el proceso completo de la aplicación.
  - *Mitigación:* Pruebas automatizadas en CI/CD, manejo resiliente de excepciones a nivel de controlador/filtro y reinicio automático de contenedores mediante políticas de Docker (`restart: unless-stopped`).

---

## 5. Trazabilidad con Requisitos

- **RNF-0001 (Disponibilidad):** Simplifica la alta disponibilidad mediante monitorización de un único proceso y reinicio ágil.
- **RNF-0006 (Rendimiento y Latencia):** Garantiza tiempos de respuesta $\le 1.5\text{ s}$ al eliminar la sobrecarga de saltos de red entre microservicios.
- **RNF-0014 (Costo-Efectividad de Infraestructura):** Cumple con el objetivo presupuestario de la clínica y las directrices del cliente para operar en VPS autoalojado.
- **EDU-0001 a EDU-0022:** Facilita la implementación coherente de los casos de uso administrativos y financieros en un entorno unificado.
