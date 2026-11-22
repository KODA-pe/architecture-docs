= OBSERVACIONES

#pad(left: 1.4em)[
  Para preservar la integridad de la arquitectura final durante la fase de implementación y operación en producción, se formulan las siguientes observaciones técnicas:

  1. *Gobernanza de fronteras modulares en CI/CD:* Dado que los módulos comparten un mismo binario Java, debe incorporarse *ArchUnit* en las pruebas automatizadas del *pipeline* para rechazar compilaciones que importen entidades o repositorios internos de otro módulo saltándose los puertos de aplicación.

  2. *Aislamiento multi-sede en consultas (`sede_id`):* Toda consulta operativa ejecutada por perfiles de recepción (`ACT-0002`) debe aplicar de forma transparente el filtro contextual `sede_id` extraído del token JWT, respaldado por pruebas de integración y por índices B-Tree compuestos `(sede_id, fecha)` en las tablas de mayor movimiento (`attendance`, `cash_transaction`, `package_sale`).

  3. *Idempotencia en sincronización biométrica (`RNF-0012`):* El adaptador `OfflineBufferSyncAdapter` debe validar claves naturales compuestas `(employee_id, timestamp, branch_id)` al ingerir lotes tras cortes de internet, evitando duplicidad de marcaciones.

  4. *Verificación periódica de respaldos y permisos de BD:* Se recomienda automatizar pruebas periódicas de restauración sobre los volcados diarios `pg_dump` y configurar roles de base de datos acotados en PostgreSQL para asegurar que el módulo `reportes` opere estrictamente en modo lectura sobre `pagos` y `clinico`.

  5. *Depuración de artefactos históricos:* Aunque la documentación de servicios conserva notas de alineamiento, se recomienda mantener los ADRs y los diagramas C4 de este informe como única referencia contractual para el desarrollo.
]
