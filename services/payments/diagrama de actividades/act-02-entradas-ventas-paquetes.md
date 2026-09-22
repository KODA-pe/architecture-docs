# Diagrama de Actividades — Entradas por Venta de Paquetes

**Educcion:** EDU-0002  
**Tablas afectadas:** Patient, PackageSale, Installment, CashTransaction, CommissionRecord (payments_db)  
**Actores:** ACT-0002 (Cajera), ORG-0003 (Sistema Frontend InnovaByte), API_InnovaByte (Modulo Clinico)

---

## Crear venta de paquete con abono inicial (ILA-PAG-0005 v02.04 y ILA-PAG-0001 v02.01)

> El frontend de InnovaByte (ORG-0003) aplica la matematica de negocio (IGV, descuento, validacion de S/50). El backend ejecuta persistencia atomica y notifica al modulo clinico.

```mermaid
flowchart TD
    A([Inicio]) --> B[Cajera ACT-0002 inicia sesion\nen Sistema Frontend ORG-0003]
    B --> C[Cajera abre formulario de\nGestion de Paquetes y Cobros IGU-0002]
    C --> D[Sistema despliega formulario con:\ncampo DNI paciente TXT-0002\nselector paquete CBO-0001]
    D --> E[Cajera ingresa DNI del paciente\ny selecciona paquete de salud]
    E --> F[Cajera marca casilla CHK-0002\nconfirmando que paciente firmo\nConsentimiento Informado fisicamente]

    F --> G{Cajera selecciona\ntipo de comprobante\nRDO-0001}
    G -- Factura --> H[Frontend calcula y suma\n18% de IGV al precio base LBL-0001]
    G -- Boleta --> I[Sin IGV aplicado]
    H --> J[Continua con precio final con IGV]
    I --> J

    J --> K{Fecha de evaluacion\ncoinicide con dia de compra?}
    K -- Si --> L[Frontend aplica descuento\nautomatico de S/25 al total]
    K -- No --> M[Sin descuento aplicado]
    L --> N[Continua con precio descontado]
    M --> N

    N --> O[Cajera ingresa monto del abono inicial\nTXT-0003]
    O --> P{Frontend valida:\nAbono inicial >= S/50\nmonto minimo de apertura?}
    P -- No --> Q[Frontend interrumpe flujo\ny muestra alerta MSG-0005:\nmonto menor al minimo permitido]
    Q --> O
    P -- Si --> R[Cajera presiona Registrar Venta BTN-0005]
    R --> S[Frontend envia HTTP POST\na ENDPOINT-PAG-0001 del backend\ncon payload: DNI, precio base,\nabono, indicadores IGV/descuento\ny derivador opcional]

    S --> T[Backend conecta a payments_db\nabre tablas: Patient, PackageSale,\nInstallment, CashTransaction\ny CommissionRecord si hay derivador]
    T --> U{Backend verifica\nintegridad estructural:\nmontos numericos y DNI presente?}
    U -- No --> V[Backend retorna HTTP 400\nMSG-PAG-0001:\nDatos inconsistentes]
    V --> W([Fin con error])

    U -- Si --> X{Backend valida:\nDNI existe en tabla Patient?}
    X -- No --> Y[Backend retorna HTTP 400\nMSG-PAG-0001:\nEl DNI no pertenece a\nun paciente registrado]
    Y --> W

    X -- Si --> Z[Backend recalcula internamente:\nIGV segun indicador booleano\nDescuento segun indicador booleano\nMonto total resultante]
    Z --> AA{Abono recibido\n>= S/50?}
    AA -- No --> AB[Backend retorna error:\nAbono menor al minimo permitido]
    AB --> W

    AA -- Si --> AC[Backend persiste atomicamente:]
    AC --> AD[1. Datos de venta en PackageSale]
    AD --> AE[2. Abono inicial en Installment\ncon is_initial_payment = true]
    AE --> AF[3. Ingreso financiero en CashTransaction]
    AF --> AG{Existe identificador\nde derivador en payload?}
    AG -- Si --> AH[4. Registra deuda de comision\nen CommissionRecord]
    AG -- No --> AI[Omite CommissionRecord]
    AH --> AJ[Backend notifica via API_InnovaByte:\npaciente tiene paquete pagado\nhabilitar control de asistencias]
    AI --> AJ
    AJ --> AK[Backend retorna HTTP 200\nMSG-PAG-0002:\nEntrada de dinero y abono inicial\ncalculados y registrados exitosamente]
    AK --> AL[Frontend muestra confirmacion MSG-0006\na la cajera]
    AL --> AM[Frontend limpia formulario IGU-0002]
    AM --> AN[Backend cierra tablas y\ndesconecta payments_db]
    AN --> AO([Fin exitoso])
```

---

## Consultar historial de paquetes y deuda por DNI (ILA-PAG-0006 v02.05)

```mermaid
flowchart TD
    A([Inicio]) --> B[Cajera ACT-0002 inicia sesion\nen Sistema Frontend ORG-0003]
    B --> C[Cajera solicita busqueda de historial\npor DNI en interfaz de compra de paquetes]
    C --> D[Frontend envia HTTP GET\na ENDPOINT-PAG-0006 con DNI como parametro]
    D --> E[Backend conecta a payments_db\nabre tablas: Patient, PackageSale, Installment]
    E --> F[Backend verifica integridad\nestructural del parametro DNI]
    F --> G{Backend valida:\nDNI existe en tabla Patient?}
    G -- No --> H[Backend retorna HTTP 404\nMSG-PAG-0003: Paciente no encontrado\nSin alterar base de datos]
    H --> I([Fin con error])
    G -- Si --> J[Backend consulta en PackageSale\nel historial de paquetes\nvinculados a ese paciente]
    J --> K[Backend calcula dinamicamente\nla deuda actual por cada paquete:\nTotal paquete MENOS suma de abonos\nen tabla Installment\nNota: la deuda NO se almacena\ncomo valor estatico]
    K --> L[Backend estructura en JSON:\ndatos del paciente, historial\nde compras y deuda calculada]
    L --> M[Backend retorna HTTP 200\nMSG-PAG-0004 con JSON]
    M --> N[Frontend renderiza historial\ny aviso de deuda en pantalla]
    N --> O[Backend cierra tablas y\ndesconecta payments_db]
    O --> P([Fin — solo lectura])
```

---

## Registrar pago de cuota (ILA-PAG-0007 v02.01)

```mermaid
flowchart TD
    A([Inicio]) --> B[Cajera ACT-0002 inicia sesion\nen Sistema Frontend ORG-0003]
    B --> C[Cajera confirma cobro de nueva cuota\npara paquete existente]
    C --> D[Frontend envia HTTP PUT/POST\na ENDPOINT-PAG-0007 con:\nID de venta y monto de cuota ej. S/40]
    D --> E[Backend conecta a payments_db\nabre tablas: PackageSale e Installment]
    E --> F{Backend verifica:\nMonto numerico\ny ID de venta presente?}
    F -- No --> G[Backend retorna error:\nDatos invalidos o ID ausente]
    G --> H([Fin con error])
    F -- Si --> I{Backend busca en PackageSale:\nLa venta existe y\nno esta anulada?}
    I -- No --> J[Backend retorna HTTP 404/400\nMSG-PAG-0005:\nVenta no encontrada\no deuda previamente cancelada]
    J --> H
    I -- Si --> K{La deuda ya estaba\ntotalmente cancelada?}
    K -- Si --> J
    K -- No --> L[Backend persiste nuevo registro\nde cuota en tabla Installment\nvinculado al ID de venta]
    L --> M[Backend calcula matematicamente\nel saldo restante de la deuda]
    M --> N{La cuota regulariza\ntotal o parcialmente\nla deuda requerida?}
    N -- Si --> O[Backend notifica via API_InnovaByte:\ndesbloquear citas futuras\ndel paciente]
    N -- No --> P[Sin notificacion al modulo clinico]
    O --> Q[Backend retorna HTTP 200\nMSG-PAG-0006:\nCuota registrada exitosamente]
    P --> Q
    Q --> R[Frontend muestra confirmacion a la cajera]
    R --> S[Backend cierra tablas y\ndesconecta payments_db]
    S --> T([Fin exitoso])
```

---

## Anular venta de paquete (ILA-PAG-0008 v02.00)

```mermaid
flowchart TD
    A([Inicio]) --> B[Cajera ACT-0002 inicia sesion\nen Sistema Frontend ORG-0003]
    B --> C[Cajera acepta ventana de confirmacion\npara anular una venta en la interfaz\nNota: la ventana de advertencia es\nresponsabilidad del frontend]
    C --> D[Frontend envia HTTP DELETE o PATCH\na ENDPOINT-PAG-0008 con\nID unico de la venta a anular]
    D --> E[Backend conecta a payments_db\nabre tablas: PackageSale e Installment]
    E --> F[Backend verifica integridad\nestructural del ID entrante]
    F --> G{Backend busca en PackageSale:\nLa venta existe y\nno esta ya anulada?}
    G -- No --> H[Backend retorna HTTP 400/404\nMSG-PAG-0007:\nVenta no encontrada\no previamente anulada\nSin alterar base de datos]
    H --> I([Fin con error])
    G -- Si --> J[Backend ejecuta borrado logico:\nActualiza estado de la venta\na Anulado en PackageSale]
    J --> K[Backend actualiza estado de\ntodos los abonos asociados\na Anulado en Installment]
    K --> L[Backend retorna HTTP 200\nMSG-PAG-0008:\nRegistro de entrada de dinero\nanulado exitosamente]
    L --> M[Frontend muestra confirmacion a la cajera]
    M --> N[Backend cierra tablas y\ndesconecta payments_db]
    N --> O([Fin exitoso])
```
