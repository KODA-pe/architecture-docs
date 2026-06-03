# Infraestructura

## Diagrama de arquitectura

**Archivo:** [arq-diagram.md](arq-diagram.md)

## Componentes

- **Usuarios y dispositivos:** administracion, recepcion y reloj biometrico.
- **API Management:** gateway central para enrutar solicitudes a microservicios.
- **Container Apps Environment:** hospedaje de microservicios en Azure.
- **Dapr Sidecar:** service invocation y pub/sub por servicio.
- **Service Bus:** mensajeria asincrona por topics/queues.
- **Azure SQL:** base de datos dedicada por servicio.
- **Equipo externo (InnovaByte):** suscriptor externo de eventos clinicos.

## Flujos clave

- **Ingreso de solicitudes:** UI y biometrico -> API Management -> servicio destino.
- **Persistencia:** cada servicio escribe solo en su base de datos.
- **Eventos:** Dapr publica eventos en Service Bus para integraciones internas y externas.

## Eventos de negocio

- **PaquetePagado:** payment-service publica; report-service e InnovaByte consumen.
- **AsistenciaRegistrada:** personal-service publica; report-service consume.
