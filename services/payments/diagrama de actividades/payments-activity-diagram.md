# Diagrama de Actividades – Servicio de Pagos

Cubre los cuatro módulos operativos: egresos operativos, entradas por venta de paquetes, comisiones externas y egresos fijos mensuales.

---

## A. Egresos Operativos Diarios (CashTransaction)

### A1. Crear Egreso Operativo

```mermaid
flowchart TD
    A([Inicio]) --> B[Usuario inicia sesión]
    B --> C[Abre formulario de registro de salidas]
    C --> D[Selecciona categoría y método de pago]
    D --> E[Ingresa monto y descripción]
    E --> F[Presiona 'Registrar Salida']
    F --> G{¿Monto válido,\ncategoría y\nmétodo seleccionados?}
    G -- No --> H[Muestra error:\n'Faltan datos obligatorios\no monto inválido']
    H --> E
    G -- Sí --> I[Persiste en CashTransaction\ntype='salida']
    I --> J[Limpia campos del formulario]
    J --> K[Muestra: 'Salida de dinero\nregistrada correctamente']
    K --> L([Fin])
```

### A2. Consultar Historial de Egresos

```mermaid
flowchart TD
    A([Inicio]) --> B[Abre historial de salidas]
    B --> C[Selecciona fecha y presiona 'Buscar']
    C --> D{¿Fecha válida?}
    D -- No --> E[Muestra error:\n'Debe seleccionar\nuna fecha válida']
    E --> C
    D -- Sí --> F[Consulta CashTransaction\ntype='salida' y fecha coincidente]
    F --> G{¿Existen registros?}
    G -- No --> H[Muestra:\n'No hay salidas registradas\nen esta fecha']
    G -- Sí --> I[Renderiza lista:\nmonto, concepto, método de pago]
    H --> J([Fin])
    I --> J
```

### A3. Actualizar Egreso Operativo

```mermaid
flowchart TD
    A([Inicio]) --> B[Selecciona egreso del historial]
    B --> C[Formulario carga datos actuales]
    C --> D[Modifica categoría / método / monto / descripción]
    D --> E[Presiona 'Actualizar Salida']
    E --> F{¿Monto y campos válidos?}
    F -- No --> G[Muestra error:\n'Faltan datos o monto inválido']
    G --> D
    F -- Sí --> H[Sobreescribe registro en CashTransaction]
    H --> I[Muestra: 'Egreso operativo\nactualizado correctamente']
    I --> J[Redirige al historial]
    J --> K([Fin])
```

### A4. Anular Egreso Operativo

```mermaid
flowchart TD
    A([Inicio]) --> B[Selecciona egreso del historial]
    B --> C[Despliega ventana de advertencia]
    C --> D{¿Usuario confirma?}
    D -- No --> E([Fin sin cambios])
    D -- Sí --> F{¿El registro existe\ny no está anulado?}
    F -- No --> G[Muestra error:\n'Registro no encontrado\no ya anulado']
    G --> E
    F -- Sí --> H[Borrado lógico:\ncambia estado a 'anulado'\nen CashTransaction]
    H --> I[Muestra: 'Egreso operativo\nanulado correctamente']
    I --> J[Actualiza historial]
    J --> K([Fin])
```

---

## B. Entradas por Venta de Paquetes (PackageSale / Installment)

### B1. Crear Registro de Entrada de Dinero

```mermaid
flowchart TD
    A([Inicio]) --> B[Cajera registra venta en sistema clínico]
    B --> C[Backend recibe: DNI, precio, abono,\nindicadores IGV/descuento, derivador opcional]
    C --> D[Abre tablas: Patient, PackageSale,\nInstallment, CashTransaction, CommissionRecord]
    D --> E{¿Integridad\nestructural OK?}
    E -- No --> F[Devuelve error de validación]
    F --> Z([Fin con error])
    E -- Sí --> G{¿DNI existe\nen Patient?}
    G -- No --> H[Devuelve error:\n'DNI no pertenece a\npaciente registrado']
    H --> Z
    G -- Sí --> I[Calcula IGV, descuento\ny monto total internamente]
    I --> J{¿Abono inicial\n>= S/ 50?}
    J -- No --> K[Devuelve error:\n'Abono menor al mínimo permitido']
    K --> Z
    J -- Sí --> L[Persiste atómicamente:\n1. PackageSale\n2. Installment is_initial_payment=true\n3. CashTransaction\n4. CommissionRecord si hay derivador]
    L --> M[Notifica a InnovaByte:\npaquete habilitado para atención]
    M --> N[Devuelve: 'Entrada de dinero\ny abono inicial registrados']
    N --> O([Fin exitoso])
```

### B2. Registrar Pago de Cuota

```mermaid
flowchart TD
    A([Inicio]) --> B[Cajera confirma cobro de cuota]
    B --> C[Backend recibe: ID de venta y monto de cuota]
    C --> D[Abre PackageSale e Installment]
    D --> E{¿Monto numérico\ny ID venta existe?}
    E -- No --> F[Devuelve error:\n'Venta no encontrada\no datos inválidos']
    F --> Z([Fin con error])
    E -- Sí --> G{¿Deuda\nya cancelada?}
    G -- Sí --> H[Devuelve error:\n'Deuda previamente cancelada']
    H --> Z
    G -- No --> I[Persiste nueva cuota en Installment\nvinculada a la venta]
    I --> J[Calcula saldo restante]
    J --> K{¿Deuda\nregularizada?}
    K -- Sí --> L[Notifica a InnovaByte:\ndesbloquear citas futuras del paciente]
    K -- No --> M[No notifica]
    L --> N[Devuelve: 'Cuota registrada exitosamente']
    M --> N
    N --> O([Fin exitoso])
```

### B3. Anular Registro de Venta

```mermaid
flowchart TD
    A([Inicio]) --> B[Cajera acepta ventana de confirmación]
    B --> C[Backend recibe ID único de venta]
    C --> D[Abre PackageSale e Installment]
    D --> E{¿ID válido y\nventa existe?}
    E -- No --> F[Devuelve error:\n'Venta no encontrada\no previamente anulada']
    F --> Z([Fin con error])
    E -- Sí --> G{¿Venta\nya anulada?}
    G -- Sí --> F
    G -- No --> H[Borrado lógico:\ncambia estado a 'anulado'\nen PackageSale e Installment]
    H --> I[Devuelve:\n'Registro de entrada\nanulado exitosamente']
    I --> J([Fin exitoso])
```

---

## C. Comisiones Externas (CommissionRecord)

### C1. Registrar Comisión

```mermaid
flowchart TD
    A([Inicio]) --> B[Abre formulario de comisiones]
    B --> C[Selecciona derivador del menú desplegable]
    C --> D[Sistema obtiene perfil del derivador\ny datos de contacto: Yape / cuenta]
    D --> E[Ingresa monto y estado:\nPagado o Pendiente]
    E --> F[Presiona 'Registrar Comisión']
    F --> G{¿Derivador seleccionado,\nmonto válido y estado?}
    G -- No --> H[Muestra error:\n'Faltan datos obligatorios\no monto inválido']
    H --> E
    G -- Sí --> I[Persiste en CommissionRecord]
    I --> J[Limpia campos del formulario]
    J --> K[Muestra: 'Registro de comisión\ncreado exitosamente']
    K --> L([Fin])
```

### C2. Actualizar Comisión

```mermaid
flowchart TD
    A([Inicio]) --> B[Selecciona registro en cuadrícula]
    B --> C[Presiona 'Editar Comisión']
    C --> D[Formulario modal muestra datos actuales]
    D --> E[Modifica estado y/o monto]
    E --> F[Presiona 'Actualizar']
    F --> G[Muestra ventana de confirmación]
    G --> H{¿Confirma cambios?}
    H -- No --> I([Fin sin cambios])
    H -- Sí --> J{¿Monto válido\ny numérico?}
    J -- No --> K[Muestra error: 'Datos inválidos'\nEl modal permanece activo]
    K --> E
    J -- Sí --> L[Sobreescribe en CommissionRecord]
    L --> M[Cierra modal y ventana de confirmación]
    M --> N[Muestra: 'Comisión\nactualizada exitosamente']
    N --> O[Renderiza nueva info en cuadrícula]
    O --> P([Fin])
```

### C3. Anular Comisión

```mermaid
flowchart TD
    A([Inicio]) --> B[Selecciona registro y presiona 'Eliminar Comisión']
    B --> C[Despliega advertencia:\n'Esta acción no se puede deshacer']
    C --> D{¿Confirma anulación?}
    D -- No --> E([Fin sin cambios])
    D -- Sí --> F{¿Registro existe\ny no está anulado?}
    F -- No --> G[Muestra: 'La comisión\nya fue anulada previamente']
    G --> E
    F -- Sí --> H[Borrado lógico:\nestado = 'Anulado' en CommissionRecord]
    H --> I[Muestra: 'Comisión\nanulada exitosamente']
    I --> J[Actualiza cuadrícula]
    J --> K([Fin])
```

---

## D. Egresos Fijos Mensuales (FixedExpense) — Solo Gerente General

### D1. Crear Egreso Fijo

```mermaid
flowchart TD
    A([Inicio]) --> B[Gerente General inicia sesión]
    B --> C[Abre gestión de egresos fijos]
    C --> D[Selecciona categoría:\nAlquiler / Honorario / Sueldo / Servicios]
    D --> E[Ingresa concepto detallado y monto]
    E --> F[Presiona 'Guardar Egreso']
    F --> G{¿Categoría seleccionada\ny monto válido?}
    G -- No --> H[Muestra error:\n'Faltan datos obligatorios\no formato inválido']
    H --> E
    G -- Sí --> I[Persiste en FixedExpense\ncon categoría]
    I --> J[Limpia el formulario]
    J --> K[Muestra: 'Egreso fijo\nregistrado correctamente']
    K --> L([Fin])
```

### D2. Actualizar / Anular Egreso Fijo

```mermaid
flowchart TD
    A([Inicio]) --> B[Gerente selecciona registro en cuadrícula]
    B --> C{¿Acción?}

    C -- Editar --> D[Presiona 'Editar Egreso']
    D --> E[Modal muestra datos actuales]
    E --> F[Modifica concepto y/o monto]
    F --> G[Presiona 'Actualizar Egreso']
    G --> H[Ventana de confirmación]
    H --> I{¿Confirma?}
    I -- No --> J([Fin sin cambios])
    I -- Sí --> K{¿Monto numérico válido?}
    K -- No --> L[Muestra error: 'Datos de monto inválidos'\nModal permanece activo]
    L --> F
    K -- Sí --> M[Sobreescribe en FixedExpense]
    M --> N[Muestra: 'Egreso fijo\nactualizado exitosamente']
    N --> O[Actualiza cuadrícula]
    O --> P([Fin])

    C -- Eliminar --> Q[Presiona 'Eliminar Egreso']
    Q --> R[Advertencia:\n'Afectará reportes contables']
    R --> S{¿Confirma anulación?}
    S -- No --> J
    S -- Sí --> T{¿Registro existe\ny no está anulado?}
    T -- No --> U[Muestra: 'El egreso\nya fue anulado previamente']
    U --> J
    T -- Sí --> V[Borrado lógico:\nestado = 'Anulado' en FixedExpense]
    V --> W[Muestra: 'Egreso fijo\nanulado exitosamente']
    W --> O
```
