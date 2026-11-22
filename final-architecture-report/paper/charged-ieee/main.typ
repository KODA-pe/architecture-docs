#import "@preview/charged-ieee:0.1.4": ieee

#set text(lang: "es", region: "PE")

#show: ieee.with(
  title: [Experiencia en la Aplicación de una Metodología Híbrida (ADD, ADR, C4 y Clean Architecture) para el Diseño Arquitectónico de un Sistema Clínico Multi-Sede],
  abstract: [
    El diseño arquitectónico de sistemas de información para pequeñas y medianas clínicas suele enfrentar el riesgo de sobre-ingeniería al adoptar estilos distribuidos sin justificación operativa. Este artículo reporta la experiencia de un equipo de ingeniería de software en el diseño y validación académica de *OMS - OmVital Management System* para una clínica de fisioterapia con tres sedes en Arequipa, Perú. Partiendo de una propuesta inicial basada en microservicios en la nube, bases de datos aisladas y un *broker* de mensajería, describimos cómo una metodología híbrida —integrando *Attribute-Driven Design* (ADD), *Architecture Decision Records* (ADR), el *Modelo C4* y *Clean Architecture*— guió un pivote hacia un *Monolito Modular* en Java 21 / Spring Boot 3 sobre una instancia única de PostgreSQL con esquemas lógicos en un VPS autoalojado. Documentamos los beneficios estructurales obtenidos: consolidación de infraestructura (de $\ge 6$ a 3 contenedores), consistencia ACID *in-process* por diseño y depuración documental (reducción de 18 a 4 diagramas de secuencia en Pagos manteniendo trazabilidad completa), junto con los desafíos y limitaciones previas al despliegue en producción.
  ],
  authors: (
    (
      name: "Rodrigo Alexander Fernandez Huarca",
      department: [Ing. de Sistemas — UNSA],
      location: [Arequipa, Perú],
    ),
    (
      name: "Jeans Anthony Ajra Huacso",
      department: [Ing. de Sistemas — UNSA],
      location: [Arequipa, Perú],
    ),
    (
      name: "Luis Guillermo Luque Condori",
      department: [Ing. de Sistemas — UNSA],
      location: [Arequipa, Perú],
    ),
    (
      name: "Alexandra Raquel Quispe Arratea",
      department: [Ing. de Sistemas — UNSA],
      location: [Arequipa, Perú],
    ),
    (
      name: "Ricardo Mauricio Chambilla Perca",
      department: [Ing. de Sistemas — UNSA],
      location: [Arequipa, Perú],
    ),
    (
      name: "Jhonatan David Arias Quispe",
      department: [Ing. de Sistemas — UNSA],
      location: [Arequipa, Perú],
    ),
    (
      name: "Pedro Luis Christian Zapana Romero",
      department: [Ing. de Sistemas — UNSA],
      location: [Arequipa, Perú],
    ),
    (
      name: "Fernando Miguel Garambel Marin",
      department: [Ing. de Sistemas — UNSA],
      location: [Arequipa, Perú],
    ),
    (
      name: "Paul Andree Cari Lipe",
      department: [Ing. de Sistemas — UNSA],
      location: [Arequipa, Perú],
    ),
    (
      name: "Max Edu Ramirez Ccahuana",
      department: [Ing. de Sistemas — UNSA],
      location: [Arequipa, Perú],
    ),
  ),
  index-terms: (
    "Arquitectura de software",
    "Monolito modular",
    "Modelo C4",
    "ADR",
    "Clean Architecture",
    "Sistemas clínicos",
  ),
  bibliography: bibliography("refs.bib", title: [Referencias]),
  figure-supplement: [Fig.],
  paper-size: "a4",
)

= Introducción

La digitalización de centros de salud ambulatorios en Latinoamérica impone restricciones simultáneas de presupuesto acotado, alta disponibilidad en ventanilla y trazabilidad financiera y clínica. Sin embargo, en etapas tempranas es frecuente adoptar arquitecturas distribuidas de alta complejidad —microservicios, orquestadores de contenedores y *brokers* de mensajería— impulsados más por tendencias tecnológicas que por los atributos de calidad reales del negocio @richards2020fundamentals @newman2021microservices.

Este artículo documenta la experiencia del equipo en el diseño de *OMS - OmVital Management System*, una plataforma clínica y administrativa para una clínica peruana de fisioterapia con tres sedes en Arequipa: *Principal (Cercado)*, *Hunter* y *Cerro Colorado*. El sistema integra cuatro dominios: personal y asistencia biométrica (`personal`), caja diaria, paquetes, cuotas, comisiones y gastos fijos (`pagos`), analítica gerencial (`reportes`) y atención terapéutica (`clinico`).

Exponemos *cómo llegamos* a una metodología híbrida pragmática, *cómo la aplicamos* para simplificar la arquitectura sin perder modularidad y qué *ventajas, desafíos y lecciones aprendidas* surgieron frente a la propuesta distribuida inicial.

= Evolución hacia la Metodología Adoptada <sec:metodologia>

== Punto de Partida: Fricciones de la Propuesta Inicial

Inicialmente existía una frontera organizativa entre dos frentes: el módulo clínico (*InnovaByte*) y los módulos administrativos (*Personal*, *Pagos* y *Reportes*). Reflejando esa separación, la primera propuesta adoptó: (1) microservicios en nube PaaS (Azure Container Apps / Kubernetes), (2) *Database per Service* con cuatro bases de datos independientes, (3) mensajería asíncrona con RabbitMQ / Azure Service Bus y patrón *Transactional Outbox*, y (4) una pasarela de pagos online externa.

Al contrastar esta propuesta con los 22 requisitos funcionales y 15 requisitos no funcionales (NFR) del negocio surgieron cuatro fricciones críticas:
- *Sobrecosto operativo:* Mantener múltiples bases de datos, clústeres y *brokers* superaba el presupuesto de una clínica local.
- *Consistencia eventual en ventanilla:* Al vender un paquete de terapias, la recepcionista debe habilitar la atención clínica de inmediato; las colas asíncronas introducían desfase y exigían *Sagas* para reversiones @newman2021microservices.
- *Fricción multi-sede:* La rotación semanal de fisioterapeutas entre sedes y la continuidad del historial de pacientes al cambiar de sucursal chocaban con esquemas *multi-tenant* físicos.
- *Sobrecarga documental:* La documentación temprana acumuló diagramas redundantes y desalineados (p. ej., 18 diagramas de secuencia en Pagos para operaciones CRUD casi idénticas).

== Convergencia en una Metodología Híbrida de Cuatro Pilares

Tras unificar ambos equipos en un monorepo y evaluar los compromisos (*trade-offs*) del dominio, consolidamos cuatro pilares complementarios (@fig:metodologia):

1. *Attribute-Driven Design (ADD):* Cada decisión estructural se derivó de objetivos medibles de calidad: meta de latencia $lt.eq 1.5 "s"$, atomicidad ACID en caja, resiliencia offline de lectores biométricos en sede y costo-efectividad en VPS @bass2021practice.
2. *Architecture Decision Records (ADR — formato MADR):* Cada pivote se formalizó documentando contexto, opciones descartadas, decisión y consecuencias @nygard2011adr.
3. *Modelo C4 Progresivo:* Jerarquía visual (`C1` Contexto, `C2` Contenedores, `C3` Componentes y Despliegue) refinada en ciclos de revisión docente (`v0.1` $arrow.r$ `v0.2` $arrow.r$ `v1.0`) @brown2023c4.
4. *Clean Architecture / Hexagonal:* Aisló el núcleo de dominio puro mediante puertos e interfaces explícitas, evitando el acoplamiento dentro del monolito @martin2017clean @cockburn2005hexagonal.

#figure(
  placement: top,
  scope: "parent",
  image("figures/paper-fig1-methodology-es.svg", width: 98%),
  caption: [Evolución y ciclo de la metodología híbrida adoptada (`ADD + ADR + C4 + Clean Architecture`) desde la propuesta distribuida inicial hasta la arquitectura unificada validada.],
) <fig:metodologia>

= Aplicación Práctica en el Caso de Estudio <sec:aplicacion>

== Formalización de Pivotes mediante ADR

La aplicación de ADD y MADR se materializó en cinco registros (`ADR-0001` a `ADR-0005`), disponibles en el repositorio de arquitectura del proyecto#footnote[Repositorio de artefactos y ADRs: `https://github.com/KODA-pe/architecture-docs`]. La @tab:adrs contrasta la propuesta inicial frente a la solución unificada.

#figure(
  placement: top,
  scope: "parent",
  caption: [Comparativa entre la Arquitectura Inicial y la Arquitectura Unificada por Decisión (ADR)],
  table(
    columns: (11%, 26%, 30%, 33%),
    align: (left, left, left, left),
    inset: (x: 6pt, y: 3.5pt),
    stroke: (x, y) => if y <= 1 { (top: 0.6pt, bottom: 0.4pt) } else { (bottom: 0.25pt + luma(210)) },
    fill: (x, y) => if y > 0 and calc.rem(y, 2) == 0 { rgb("#f5f7fa") },
    table.header[*ADR*][*Propuesta Inicial*][*Decisión Definitiva*][*Impacto Principal*],
    [ADR-0001], [Microservicios en Azure / Kubernetes], [Monolito Modular + Clean Architecture (Java 21 / Spring Boot 3)], [Un solo artefacto Docker y pipeline CI/CD; fronteras modulares estrictas @fowler2015monolithfirst.],
    [ADR-0002], [4 bases de datos aisladas (*DB per Service*)], [PostgreSQL único con 4 esquemas (`personal`, `pagos`, `reportes`, `clinico`)], [Transacciones ACID nativas, integridad referencial y backup único (`pg_dump`) @postgresql2024docs.],
    [ADR-0003], [Evaluación *multi-tenant* por sede], [Discriminador de columna `sede_id` + filtro JWT], [Rotación flexible de personal y reportes consolidados con `GROUP BY sede_id` @vernon2013ddd.],
    [ADR-0004], [RabbitMQ / Azure Service Bus + Outbox], [Comunicación híbrida *in-process* (`@Transactional` + `ApplicationEventPublisher`)], [Cero latencia de cola en cobros; efectos `@Async` desacoplados en memoria.],
    [ADR-0005], [Pasarela de pagos online (Niubiz/Culqi)], [Registro manual de caja (Efectivo, Yape/Plin, Transferencia)], [Alineación 100% presencial; cero comisiones bancarias y exención PCI-DSS.],
  ),
) <tab:adrs>

== Vistas C4 Resultantes y Despliegue

El Modelo C4 comunicó la arquitectura en niveles progresivos. La @fig:c2 muestra el diagrama de Contenedores (C2), donde los cuatro módulos operan en un único proceso Java 21 con Virtual Threads detrás de un *Reverse Proxy* (`Nginx` / `Caddy`), coordinándose síncronamente vía puertos (`Pagos` $arrow.l.r$ `Clínico`, `Personal` $arrow.l.r$ `Clínico`) y asíncronamente en memoria hacia `Reportes`. En Despliegue (@fig:despliegue), producción converge en tres contenedores Docker en un VPS autoalojado, mientras las sedes toleran caídas de red mediante el reloj *ZKTeco Sensefp M1b* y un buffer local SQLite.

#figure(
  placement: top,
  scope: "parent",
  image("figures/paper-fig2-c2-es.svg", width: 95%),
  caption: [Diagrama C4 Nivel 2 (Contenedores) resultante de la metodología: Monolito Modular en Java 21 / Spring Boot 3 y PostgreSQL unificado por esquemas lógicos.],
) <fig:c2>

#figure(
  placement: top,
  image("figures/paper-fig3-deploy-es.svg", width: 100%),
  caption: [Diagrama de Despliegue C4: operación en tres sedes físicas y contenedorización con Docker Compose en VPS único.],
) <fig:despliegue>

== Refinamiento del Dominio y Depuración Documental

La revisión bajo Clean Architecture corrigió primero el modelo relacional del módulo de Pagos (`services/payments`) para reflejar fielmente la operación contable. En el diseño refinado, la obligación de pago (`installment`) se separa del movimiento real de dinero (`installment_payment` $arrow.r$ `cash_transaction`), permitiendo abonos parciales sin desfasar el arqueo diario de caja.

En paralelo, una auditoría de los 18 diagramas de secuencia originales reveló que 12 repetían exactamente la misma interacción CRUD lineal. Aplicando un criterio de valor arquitectónico, se consolidaron en *4 secuencias esenciales* —venta con habilitación clínica, cobro de cuota con deuda al vuelo, liquidación de comisiones/gastos fijos con Excel y un patrón transversal de consulta, edición y anulación lógica— mapeadas en una matriz de trazabilidad que preserva la cobertura completa de los cuatro subdominios.

= Ventajas Encontradas y Resultados <sec:ventajas>

La experiencia aportó beneficios estructurales medibles en el diseño y en la productividad del equipo (@tab:metricas):

- *Reducción estructural de infraestructura y costos proyectados:* Pasar de servicios PaaS en la nube, cuatro bases de datos, un *broker* y comisiones de pasarela a 3 contenedores en un VPS simplifica despliegue, monitoreo y respaldos (`pg_dump`).
- *Consistencia ACID por diseño:* El cobro en recepción y la habilitación de sesiones clínicas ocurren en una única transacción *in-process*, eliminando saltos de red y estados intermedios inconsistentes.
- *Validación ágil:* La progresión `C1` $arrow.r$ `C2` $arrow.r$ `C3` agilizó las revisiones docentes (`v0.1` a `v1.0`), detectando vacíos de componentes tempranamente.
- *Documentación digerible:* Reducir en 77.8% las secuencias de Pagos (18 a 4) conservó el 100% de trazabilidad funcional (caja diaria, paquetes/cuotas, comisiones y gastos fijos) eliminando ruido y referencias obsoletas.
- *Evolución abierta:* Exigir puertos explícitos y dominio puro por módulo @martin2017clean permite extraer cualquier módulo en el futuro con mínima fricción.

#figure(
  placement: top,
  caption: [Indicadores Comparativos del Impacto Metodológico],
  table(
    columns: (44%, 26%, 30%),
    align: (left, center, center),
    inset: (x: 5pt, y: 3.5pt),
    stroke: (x, y) => if y <= 1 { (top: 0.6pt, bottom: 0.4pt) } else { (bottom: 0.25pt + luma(210)) },
    fill: (x, y) => if y > 0 and calc.rem(y, 2) == 0 { rgb("#f5f7fa") },
    table.header[*Dimensión Evaluada*][*Enfoque Inicial*][*Enfoque Final*],
    [Instancias de BD], [4 aisladas], [1 (4 esquemas)],
    [Brokers externos], [RabbitMQ / ASB], [0 (*in-process*)],
    [Pasarelas externas], [Evaluada], [0 (ADR-0005)],
    [Contenedores en VPS], [$gt.eq 6$], [3 (Docker Compose)],
    [Secuencias en Pagos], [18 (5 archivos)], [4 (1 archivo)],
    [Trazabilidad de reqs.], [Parcial], [100% mapeada],
  ),
) <tab:metricas>

= Desafíos, Lecciones Aprendidas y Limitaciones <sec:desafios>

El proceso también expuso riesgos técnicos y límites de alcance que condicionan la etapa de implementación:

1. *Documentación heredada:* Tras aprobar los ADR, documentos previos aún citaban RabbitMQ o bases separadas. *Lección:* todo pivote requiere una fase explícita de alineamiento documental.
2. *Disciplina contra el acoplamiento:* Un monorepo facilita inyectar repositorios ajenos o cruzar esquemas. *Mitigación:* pruebas automáticas *ArchUnit* en CI/CD y permisos *Read-Only* en PostgreSQL para `reportes`.
3. *Aislamiento multi-sede:* Usar `sede_id` exige rigor en el filtrado por token JWT y pruebas por rol (*Gerente General* vs. *Recepcionista/Cajera*).
4. *Ergonomía visual:* Las primeras vistas C4 presentaron flechas cruzando textos; migrar a gráficos vectoriales por capas confirmó que la legibilidad visual es un requisito de primera clase.
5. *Limitaciones:* Los resultados corresponden a diseño y revisión académica; la latencia bajo carga pico (65 pacientes/día) y la sincronización offline ZKTeco se validarán en producción.

= Conclusiones y Trabajo Futuro <sec:conclusiones>

Combinar *ADD*, *ADR*, *Modelo C4* y *Clean Architecture* permitió fundamentar decisiones pragmáticas y evitar la sobre-ingeniería en *OMS - OmVital Management System*. El *Monolito Modular* con PostgreSQL por esquemas y comunicación *in-process* maximizó la coherencia técnica, redujo costos y generó un plano claro para ingeniería.

Como trabajo futuro se contempla implementar los cuatro módulos en Java 21 / Spring Boot 3 con *ArchUnit* en CI/CD, realizar pruebas de carga con índices `(sede_id, fecha)` y validar en campo el buffer offline ZKTeco y la restauración de `pg_dump`.

= Agradecimientos

Los autores agradecen al *Dr. Percy Huertas Niquen*, docente del curso de Diseño y Arquitectura de Software de la Universidad Nacional de San Agustín, por su guía metodológica y constante retroalimentación técnica durante el desarrollo de la arquitectura.
