# Diagrama C4 — Nivel 1: Contexto del Sistema

Vista de máximo nivel del **Sistema Integral Clínico y Administrativo**, mostrando quiénes operan la plataforma y con qué dispositivos externos interactúa, conforme a las decisiones arquitectónicas vigentes ([ADR-0001](../adr/0001-adopcion-monolito-modular-clean-architecture.md) a [ADR-0005](../adr/0005-registro-financiero-manual-sin-pasarela-de-pagos.md)).

```mermaid
C4Context
    title C1 — Contexto del Sistema Clínico y Administrativo (3 Sedes en Arequipa)

    Person(gerente, "Gerente General / Administrador", "ACT-0001. Administra sedes, personal, turnos, asistencias, egresos fijos confidenciales, reportes y estadísticas.")
    Person(cajera, "Recepcionista / Cajera", "ACT-0002. Registra ventas de paquetes, cuotas en efectivo/Yape, egresos operativos, comisiones y consultas por DNI.")
    Person(clinico, "Personal Clínico", "Fisioterapeutas, técnicos y coordinador. Gestionan evaluaciones, fichas, citas y evolución diaria de pacientes.")

    System(sistema, "Sistema Integral Clínico y Administrativo", "Plataforma web unificada (Monolito Modular Java 21 / Spring Boot 3 + SPA Web) para las sedes Cercado, Hunter y Cerro Colorado.")

    System_Ext(biometrico, "Reloj Biométrico ZKTeco Sensefp M1b", "Dispositivo físico de marcación de huella en cada sede con buffer local para contingencia offline (RNF-0012).")
    System_Ext(archivos, "Equipo Local del Usuario", "Navegador y sistema de archivos local para descarga de reportes Excel (.xlsx), PDF y constancias.")

    Rel(gerente, sistema, "Gestiona personal, egresos fijos y reportes", "HTTPS / REST + JWT")
    Rel(cajera, sistema, "Registra cobros, caja diaria, comisiones y citas", "HTTPS / REST + JWT")
    Rel(clinico, sistema, "Registra evaluaciones, evolución y atenciones", "HTTPS / REST + JWT")
    Rel(biometrico, sistema, "Envía marcaciones de asistencia de personal", "TCP/IP - HTTP")
    Rel(sistema, archivos, "Descarga reportes contables y comprobantes", "HTTPS (Descarga)")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

## Alcance y Fronteras del Contexto

- **Unificación Clínica y Administrativa ([ADR-0001](../adr/0001-adopcion-monolito-modular-clean-architecture.md)):** El módulo clínico (anteriormente concebido como sistema externo InnovaByte) forma parte del mismo sistema unificado; no aparece como sistema externo en C1.
- **Sin Pasarela de Pagos Externa ([ADR-0005](../adr/0005-registro-financiero-manual-sin-pasarela-de-pagos.md)):** Todos los pagos (Efectivo, Yape/Plin y Transferencia) se verifican y registran de forma presencial en mostrador por la Recepcionista o el Gerente. No existen integraciones con Niubiz, Culqi ni Stripe.
- **Pacientes y Derivadores:** No disponen de portal web ni acceso directo al sistema; interactúan presencialmente con Recepción y Personal Clínico.
- **Operación Multi-Sede ([ADR-0003](../adr/0003-gestion-multisede-mediante-discriminador-sede-id.md)):** Una sola instancia lógica atiende simultáneamente las sedes **Principal (Cercado)**, **Hunter** y **Cerro Colorado**.
