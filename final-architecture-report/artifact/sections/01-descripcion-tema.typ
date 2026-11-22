= DESCRIPCIÓN DEL TEMA A TRATAR

#pad(left: 1.4em)[
  El presente documento describe la arquitectura de software definitiva del sistema *OMS - OmVital Management System*, una plataforma clínica y administrativa integral diseñada a medida para una clínica peruana de fisioterapia y rehabilitación física con operación distribuida en tres sedes físicas de la ciudad de Arequipa: *Principal (Cercado)*, *Hunter* y *Cerro Colorado*.

  En sus iteraciones iniciales, el proyecto contemplaba un desarrollo desacoplado entre el sistema clínico (*InnovaByte*) y tres microservicios administrativos (*Personal*, *Pagos* y *Reportes*), apoyados en bases de datos independientes, servicios PaaS en la nube y un broker de mensajería asíncrona. Sin embargo, el análisis conjunto de las restricciones presupuestarias, el volumen transaccional real de la clínica y la necesidad de consistencia inmediata en ventanilla motivaron la *unificación formal en un Monolito Modular bajo Clean Architecture* implementado en *Java 21 LTS / Spring Boot 3* sobre una *única base de datos PostgreSQL particionada por esquemas lógicos*, desplegado en un *VPS único autoalojado*.

  El informe documenta de forma visual y estructurada esta arquitectura unificada mediante el modelo *C4* (Contexto, Contenedores, Componentes y Despliegue), los diagramas entidad-relación simplificados y las secuencias dinámicas esenciales de los módulos de *Pagos*, *Reportes* y *Personal*, sirviendo como plano técnico de referencia directa para el equipo de ingeniería de software.
]
