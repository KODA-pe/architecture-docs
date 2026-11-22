#import "@preview/charged-ieee:0.1.4": ieee

#set text(lang: "en", region: "US")

#show: ieee.with(
  title: [Experience Applying a Hybrid Architecture Methodology (ADD, ADR, C4, and Clean Architecture) to a Multi-Branch Clinical Management System],
  abstract: [
    Software architecture design for small and medium-sized healthcare clinics frequently suffers from over-engineering when distributed styles are adopted without operational justification. This paper reports the experience of a software engineering team designing and academically validating *OMS - OmVital Management System* for a Peruvian physiotherapy clinic operating three physical branches in Arequipa, Peru. Starting from an initial cloud microservices proposal featuring isolated databases and an external message broker, we describe how a hybrid methodology—combining *Attribute-Driven Design* (ADD), *Architecture Decision Records* (ADR), the *C4 Model*, and *Clean Architecture*—guided a pivot toward a *Modular Monolith* in Java 21 / Spring Boot 3 backed by a single PostgreSQL instance with logical schemas on a self-hosted VPS. We document the resulting structural gains: infrastructure consolidation (from $\ge 6$ to 3 containers), by-design *in-process* ACID consistency, and documentation pruning (reducing 18 sequence diagrams to 4 essential flows in Payments with full traceability), alongside challenges and pre-deployment limitations.
  ],
  authors: (
    (
      name: "Rodrigo Alexander Fernandez Huarca",
      department: [Systems Engineering — UNSA],
      location: [Arequipa, Peru],
    ),
    (
      name: "Jeans Anthony Ajra Huacso",
      department: [Systems Engineering — UNSA],
      location: [Arequipa, Peru],
    ),
    (
      name: "Luis Guillermo Luque Condori",
      department: [Systems Engineering — UNSA],
      location: [Arequipa, Peru],
    ),
    (
      name: "Alexandra Raquel Quispe Arratea",
      department: [Systems Engineering — UNSA],
      location: [Arequipa, Peru],
    ),
    (
      name: "Ricardo Mauricio Chambilla Perca",
      department: [Systems Engineering — UNSA],
      location: [Arequipa, Peru],
    ),
    (
      name: "Jhonatan David Arias Quispe",
      department: [Systems Engineering — UNSA],
      location: [Arequipa, Peru],
    ),
    (
      name: "Pedro Luis Christian Zapana Romero",
      department: [Systems Engineering — UNSA],
      location: [Arequipa, Peru],
    ),
    (
      name: "Fernando Miguel Garambel Marin",
      department: [Systems Engineering — UNSA],
      location: [Arequipa, Peru],
    ),
    (
      name: "Paul Andree Cari Lipe",
      department: [Systems Engineering — UNSA],
      location: [Arequipa, Peru],
    ),
    (
      name: "Max Edu Ramirez Ccahuana",
      department: [Systems Engineering — UNSA],
      location: [Arequipa, Peru],
    ),
  ),
  index-terms: (
    "Software architecture",
    "Modular monolith",
    "C4 model",
    "Architecture decision records",
    "Clean architecture",
    "Clinical information systems",
  ),
  bibliography: bibliography("refs.bib"),
  figure-supplement: [Fig.],
  paper-size: "a4",
)

= Introduction

Digitalizing outpatient clinics in Latin America requires balancing tight operational budgets, high front-desk availability, and strict financial and clinical traceability. Nevertheless, early stages of software projects often gravitate toward complex distributed architectures—microservices, container orchestrators, and asynchronous message brokers—driven by industry trends rather than actual quality attributes @richards2020fundamentals @newman2021microservices.

This paper reports our engineering team's experience designing *OMS - OmVital Management System*, an integrated clinical and administrative platform for a Peruvian physiotherapy clinic operating three physical branches in Arequipa: *Principal (Cercado)*, *Hunter*, and *Cerro Colorado*. The system encompasses four core domains: personnel and biometric attendance (`personal`), daily cash, treatment packages, installments, external commissions, and fixed expenses (`pagos`), managerial analytics (`reportes`), and clinical care (`clinico`).

Our goal is to document *how we arrived* at a pragmatic hybrid methodology, *how we applied it* to unify and simplify the architecture without sacrificing modularity, and what *advantages, challenges, and lessons learned* emerged compared to the initial distributed design.

= Evolution Toward the Adopted Methodology <sec:methodology>

== Starting Point: Friction in the Initial Proposal

At project inception, an organizational boundary separated two development fronts: the clinical module (*InnovaByte*) and the administrative modules (*Personal*, *Payments*, and *Reports*). Mirroring that boundary, the initial proposal specified: (1) cloud microservices deployed on Azure Container Apps / Kubernetes, (2) a *Database per Service* topology with four independent databases, (3) asynchronous messaging via RabbitMQ / Azure Service Bus with the *Transactional Outbox* pattern, and (4) an online payment gateway integration.

Evaluating this baseline against the clinic's 22 functional requirements and 15 non-functional requirements (NFRs) exposed four critical mismatches:
- *Operational cost overhead:* Maintaining multiple databases, clusters, and brokers exceeded the budget of a three-branch local clinic.
- *Eventual consistency at reception:* When selling a treatment package, receptionists must immediately enable therapy sessions; message queues introduced synchronization lag and required distributed *Sagas* for rollbacks @newman2021microservices.
- *Cross-branch data friction:* Weekly therapist rotation across branches and seamless patient history transfers between locations conflicted with physical multi-tenant isolation.
- *Documentation overload:* Early artifacts accumulated redundant and drifting diagrams—including 18 sequence diagrams in the Payments module covering nearly identical CRUD flows.

== Converging on a Four-Pillar Hybrid Methodology

Once both teams agreed to unify into a single monorepo and systematically weigh architectural trade-offs, we converged on four complementary pillars (illustrated in @fig:methodology):

1. *Attribute-Driven Design (ADD):* Every structural choice was anchored in measurable quality targets—a $lt.eq 1.5 "s"$ response latency goal, ACID atomicity for payments, offline resilience for branch biometric readers, and VPS cost-effectiveness @bass2021practice.
2. *Architecture Decision Records (ADR — MADR format):* Each architectural pivot was formally documented with context, discarded alternatives, decision rationale, and consequences @nygard2011adr.
3. *Progressive C4 Modeling:* Visual documentation followed progressive zoom levels (`C1` Context, `C2` Containers, `C3` Components, and Deployment), refined across faculty review cycles (`v0.1` $arrow.r$ `v0.2` $arrow.r$ `v1.0`) @brown2023c4.
4. *Clean / Hexagonal Architecture (Ports and Adapters):* Ensured that single-binary unification preserved strict domain boundaries and decoupled business rules from frameworks and persistence @martin2017clean @cockburn2005hexagonal.

#figure(
  placement: top,
  scope: "parent",
  image("figures/paper-fig1-methodology-en.svg", width: 98%),
  caption: [Evolution and workflow of the adopted hybrid methodology (`ADD + ADR + C4 + Clean Architecture`), from the initial distributed proposal to the validated unified architecture.],
) <fig:methodology>

= Practical Application in the Case Study <sec:application>

== Formalizing Architectural Pivots via ADRs

Applying ADD and MADR yielded five binding records (`ADR-0001` to `ADR-0005`), published in the project's architecture repository#footnote[Architecture artifacts and ADRs: `https://github.com/KODA-pe/architecture-docs`]. @tab:adrs contrasts the initial proposal against the unified solution.

#figure(
  placement: top,
  scope: "parent",
  caption: [Comparison Between Initial Proposal and Unified Architecture by Decision (ADR)],
  table(
    columns: (11%, 26%, 30%, 33%),
    align: (left, left, left, left),
    inset: (x: 6pt, y: 3.5pt),
    stroke: (x, y) => if y <= 1 { (top: 0.6pt, bottom: 0.4pt) } else { (bottom: 0.25pt + luma(210)) },
    fill: (x, y) => if y > 0 and calc.rem(y, 2) == 0 { rgb("#f5f7fa") },
    table.header[*ADR*][*Initial Proposal*][*Final Decision*][*Primary Impact*],
    [ADR-0001], [Cloud Microservices (Azure / Kubernetes)], [Modular Monolith + Clean Architecture (Java 21 / Spring Boot 3)], [Single Docker artifact and CI/CD pipeline with strict module boundaries @fowler2015monolithfirst.],
    [ADR-0002], [4 isolated databases (*DB per Service*)], [Single PostgreSQL with 4 schemas (`personal`, `pagos`, `reportes`, `clinico`)], [Native ACID transactions, referential integrity, and unified `pg_dump` backups @postgresql2024docs.],
    [ADR-0003], [Physical multi-tenancy per branch], [Column discriminator (`sede_id`) + JWT context filter], [Flexible staff rotation and instant consolidated reporting via `GROUP BY sede_id` @vernon2013ddd.],
    [ADR-0004], [RabbitMQ / Azure Service Bus + Outbox], [Hybrid *in-process* communication (`@Transactional` + `ApplicationEventPublisher`)], [Zero queue latency on payments; non-blocking `@Async` side effects in memory.],
    [ADR-0005], [Online payment gateway (Niubiz/Culqi)], [Manual cash ledger (Cash, Yape/Plin, Bank Transfer)], [100% aligned with in-person counter operations; zero gateway fees and PCI-DSS exemption.],
  ),
) <tab:adrs>

== Resulting C4 Views and Deployment Topology

Using the C4 Model enabled clear communication across abstraction levels. @fig:c2 depicts the resulting Container diagram (C2), where all four modules execute within a single Java 21 Virtual Threads process behind a Reverse Proxy (`Nginx` / `Caddy`), coordinating synchronously through application ports (`Payments` $arrow.l.r$ `Clinical`, `Personal` $arrow.l.r$ `Clinical`) and asynchronously in memory toward `Reports`.

In the Deployment view (@fig:deploy), production infrastructure consolidates into three Docker containers on a single self-hosted VPS, while peripheral branches tolerate internet outages through the *ZKTeco Sensefp M1b* internal memory and a local SQLite contingency buffer.

#figure(
  placement: top,
  scope: "parent",
  image("figures/paper-fig2-c2-en.svg", width: 95%),
  caption: [Resulting C4 Level 2 (Container) diagram: Modular Monolith in Java 21 / Spring Boot 3 backed by a unified schema-partitioned PostgreSQL database.],
) <fig:c2>

#figure(
  placement: top,
  image("figures/paper-fig3-deploy-en.svg", width: 100%),
  caption: [C4 Deployment diagram: three physical branches in Arequipa connected to a Docker Compose stack on a single self-hosted VPS.],
) <fig:deploy>

== Domain Refinement and Documentation Pruning

Clean Architecture modeling first corrected the Payments relational schema (`services/payments`) to mirror real-world accounting. Separating debt obligations (`installment`) from actual cash movements (`installment_payment` $arrow.r$ `cash_transaction`) cleanly supports partial payments without distorting daily cash reconciliation.

In parallel, auditing the 18 original sequence diagrams revealed that 12 repeated identical linear CRUD flows. Applying an architectural value filter consolidated them into *4 essential sequences*—package sale with clinical enablement, installment collection with on-the-fly debt calculation, commission/fixed-expense settlement with Excel export, and a single cross-cutting query/edit/logical-annulment pattern—backed by a traceability matrix preserving full coverage across all four subdomains.

= Observed Advantages and Results <sec:advantages>

Our experience yielded structural design and team-productivity gains (summarized in @tab:metrics):

- *Structural infrastructure and projected cost efficiency:* Replacing cloud PaaS clusters, four database engines, a broker, and gateway fees with 3 Docker containers on a single VPS simplifies deployment, monitoring, and backups (`pg_dump`).
- *By-design ACID consistency:* Front-desk operations (recording payment and immediately enabling therapy sessions) execute inside a single *in-process* ACID transaction, eliminating network hops and eventual-consistency windows.
- *Communication clarity and rapid review:* Across academic review iterations (`v0.1` to `v1.0`), the `C1` $arrow.r$ `C2` $arrow.r$ `C3` hierarchy exposed missing component details early and accelerated validation.
- *Maintainable, noise-free documentation:* Cutting Payments sequence diagrams by 77.8% (from 18 down to 4) preserved 100% traceability across daily cash, package sales, external commissions, and fixed expenses while removing redundant boilerplate.
- *Evolutionary readiness:* Enforcing pure domain cores and explicit ports per module @martin2017clean keeps the extraction path open if any module later requires independent scaling.

#figure(
  placement: top,
  caption: [Comparative Indicators of Methodological Impact],
  table(
    columns: (44%, 26%, 30%),
    align: (left, center, center),
    inset: (x: 5pt, y: 3.5pt),
    stroke: (x, y) => if y <= 1 { (top: 0.6pt, bottom: 0.4pt) } else { (bottom: 0.25pt + luma(210)) },
    fill: (x, y) => if y > 0 and calc.rem(y, 2) == 0 { rgb("#f5f7fa") },
    table.header[*Evaluated Dimension*][*Initial Baseline*][*Final Design*],
    [Database instances], [4 isolated], [1 (4 schemas)],
    [External brokers], [RabbitMQ / ASB], [0 (*in-process*)],
    [Payment gateways], [Evaluated], [0 (ADR-0005)],
    [VPS containers], [$gt.eq 6$], [3 (Docker Compose)],
    [Payments sequences], [18 (5 files)], [4 (1 file)],
    [Req. / NFR traceability], [Partial], [100% mapped],
  ),
) <tab:metrics>

= Challenges, Lessons Learned, and Limitations <sec:challenges>

Applying the methodology also surfaced important challenges and lessons:

1. *Drift with legacy documentation:* After approving the ADRs, older service documents still referenced RabbitMQ and separate databases. *Lesson:* every architectural pivot requires an explicit alignment pass and deprecation notices to prevent conflicting guidance.
2. *Coupling discipline in a monorepo:* Sharing a single JVM invites shortcuts such as cross-module repository injection or cross-schema transactional joins. *Mitigation:* enforce architectural fitness tests via *ArchUnit* in CI/CD and scoped PostgreSQL roles (e.g., strict *Read-Only* access for `reportes` over `pagos`).
3. *Multi-branch data isolation:* Using `sede_id` instead of per-branch databases demands consistent JWT-driven filtering and role-based integration tests (*General Manager* vs. *Receptionist/Cashier*).
4. *Diagram ergonomics:* Early experimental C4 diagrams suffered from arrows crossing text labels; switching to cleanly routed layered vector graphics proved that visual readability is a first-class architectural concern.
5. *Limitations:* Findings reflect architectural design and academic review phases; runtime latency under peak load (65 patients/day) and field validation of ZKTeco offline synchronization remain to be measured in production.

= Conclusions and Future Work <sec:conclusions>

Combining *ADD*, *ADRs*, *C4*, and *Clean Architecture* enabled grounded trade-offs and avoided over-engineering in *OMS - OmVital Management System*. The *Modular Monolith* with schema-partitioned PostgreSQL and *in-process* communication maximized coherence, reduced projected infrastructure costs, and delivered a clear engineering blueprint.

Future work includes: (1) implementing all four modules in Java 21 / Spring Boot 3 with *ArchUnit* CI/CD checks, (2) benchmarking VPS latency with `(sede_id, date)` indexes, and (3) validating ZKTeco offline buffer idempotency and `pg_dump` recovery drills.

= Acknowledgments

The authors thank *Dr. Percy Huertas Niquen*, Software Design and Architecture instructor at Universidad Nacional de San Agustín, for his methodological guidance and technical feedback throughout the architecture's design and refinement.
