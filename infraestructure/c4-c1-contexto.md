# Diagrama C4 — Nivel 1: Contexto del Sistema

Vista de máximo nivel del **Sistema Integral Clínico y Administrativo**, mostrando quiénes operan la plataforma y con qué dispositivos externos interactúa, conforme a [ADR-0001](../adr/0001-adopcion-monolito-modular-clean-architecture.md) a [ADR-0005](../adr/0005-registro-financiero-manual-sin-pasarela-de-pagos.md).

```mermaid
flowchart TB
    classDef person fill:#08427B,stroke:#052E56,color:#FFFFFF,rx:8,ry:8
    classDef system fill:#1168BD,stroke:#0B4884,color:#FFFFFF,rx:6,ry:6
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,rx:6,ry:6

    Gerente["<b>Gerente General / Administrador</b><br/><i>[Persona: ACT-0001]</i><br/>Sedes, personal, egresos fijos,<br/>reportes y estadísticas"]:::person
    Cajera["<b>Recepcionista / Cajera</b><br/><i>[Persona: ACT-0002]</i><br/>Ventas, cuotas (Efectivo/Yape),<br/>egresos, comisiones y citas"]:::person
    Clinico["<b>Personal Clínico</b><br/><i>[Persona: Fisioterapeuta / Coord.]</i><br/>Evaluaciones, fichas,<br/>citas y evolución diaria"]:::person

    Sistema["<b>Sistema Integral Clínico y Administrativo</b><br/><i>[Software System]</i><br/>Monolito Modular (Java 21 / Spring Boot 3) + SPA Web<br/>Operación unificada para 3 sedes en Arequipa:<br/>Principal (Cercado), Hunter y Cerro Colorado"]:::system

    Biometrico["<b>Reloj Biométrico ZKTeco Sensefp M1b</b><br/><i>[Dispositivo Externo por Sede]</i><br/>Lectura de huella con buffer offline<br/>ante caída de red (RNF-0012)"]:::external
    Archivos["<b>Equipo Local del Usuario</b><br/><i>[Navegador / Sistema de Archivos]</i><br/>Descarga local de reportes Excel (.xlsx),<br/>PDF y constancias"]:::external

    Gerente -->|"Administra personal, finanzas y reportes<br/>[HTTPS / JWT]"| Sistema
    Cajera -->|"Registra cobros, caja y consultas DNI<br/>[HTTPS / JWT]"| Sistema
    Clinico -->|"Registra evaluaciones y evolución<br/>[HTTPS / JWT]"| Sistema
    Biometrico -->|"Envía marcaciones de asistencia<br/>[TCP/IP - HTTP]"| Sistema
    Sistema -->|"Exporta reportes y comprobantes<br/>[HTTPS Descarga]"| Archivos
```

## Alcance y Fronteras del Contexto

- **Unificación Clínica y Administrativa ([ADR-0001](../adr/0001-adopcion-monolito-modular-clean-architecture.md)):** El módulo clínico (antes concebido como sistema externo InnovaByte) forma parte del mismo sistema unificado; no aparece como sistema externo en C1.
- **Sin Pasarela de Pagos Externa ([ADR-0005](../adr/0005-registro-financiero-manual-sin-pasarela-de-pagos.md)):** Todos los pagos (Efectivo, Yape/Plin y Transferencia) se verifican y registran de forma presencial en mostrador por la Recepcionista o el Gerente. No existen integraciones con Niubiz, Culqi ni Stripe.
- **Pacientes y Derivadores:** No disponen de portal web ni acceso directo al sistema; interactúan presencialmente con Recepción y Personal Clínico.
- **Operación Multi-Sede ([ADR-0003](../adr/0003-gestion-multisede-mediante-discriminador-sede-id.md)):** Una sola instancia lógica atiende simultáneamente las sedes **Principal (Cercado)**, **Hunter** y **Cerro Colorado**.
