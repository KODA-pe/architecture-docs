# Diagrama de Actividades — Comisiones Externas

**Educcion:** EDU-0005  
**Tabla afectada:** CommissionRecord (payments_db), integracion lectura con Subsistema de Personal  
**Actores:** ACT-0001 (Gerente General), ACT-0002 (Cajera)  
**Tipos de derivador:** Promotor Externo (coloquialmente jaladora) y Medico Traumatologo Aliado

---

## Crear registro de pago o deuda de comision (ILA-PAG-0009 v03.00)

```mermaid
flowchart TD
    A([Inicio]) --> B[Usuario inicia sesion\nACT-0001 o ACT-0002]
    B --> C[Abre interfaz de registro\nde comisiones IGU-PAG-0005]
    C --> D[Sistema conecta a payments_db\nabre tabla CommissionRecord\ne integra lectura con Subsistema de Personal]
    D --> E[Sistema despliega formulario con:\nBuscador de derivador SEL-0001\nCampo Yape o banco solo lectura TXT-0001\nCampo monto TXT-0002\nSelector estado SEL-0002: Pagado o Pendiente]
    E --> F[Usuario busca y selecciona derivador\ndesde SEL-0001 que carga\nregistros activos del Subsistema de Personal]
    F --> G[Sistema identifica automaticamente\ncategoria del derivador seleccionado]
    G --> H{Cual es la\ncategoria?}
    H -- Promotor Externo --> I[Sistema obtiene telefono Yape\ndel derivador desde Personal\ny lo muestra bloqueado en TXT-0001]
    H -- Medico Traumatologo --> J[Sistema obtiene cuenta bancaria\ndel derivador desde Personal\ny la muestra bloqueada en TXT-0001]
    I --> K[Usuario digita monto a comisionar\nen TXT-0002 ej. S/25]
    J --> K
    K --> L[Usuario establece estado del registro\nen SEL-0002: Pagado o Pendiente]
    L --> M[Usuario presiona Registrar Comision\nBTN-0001]
    M --> N{Validacion logica:\nDerivador seleccionado?\nMonto valido y no vacio?\nEstado definido?}
    N -- No --> O[Sistema despliega error MSG-0001:\nFaltan datos obligatorios\no el monto ingresado es invalido]
    O --> P[Formulario permanece activo\nsin borrar seleccion previa]
    P --> K
    N -- Si --> Q[Sistema persiste datos\nde la nueva comision en CommissionRecord\nvinculada al ID del derivador]
    Q --> R[Sistema limpia campos del formulario]
    R --> S[Sistema lanza MSG-0002:\nRegistro de comision creado exitosamente]
    S --> T[Sistema cierra tabla CommissionRecord]
    T --> U[Sistema cierra conexion a payments_db]
    U --> V[Interfaz permanece en IGU-PAG-0005\nlista para nueva transaccion]
    V --> W([Fin])
```

---

## Consultar historial de comisiones y exportar reporte a Excel (ILA-PAG-0010 v02.00)

```mermaid
flowchart TD
    A([Inicio]) --> B[Usuario inicia sesion\nACT-0001 o ACT-0002]
    B --> C[Abre interfaz de historial\nde comisiones IGU-PAG-0006]
    C --> D[Sistema conecta a payments_db\nabre tabla CommissionRecord\ne integra lectura con Subsistema de Personal]
    D --> E[Sistema despliega:\nMenu desplegable de meses SEL-0001\nMenu Medico Traumatologo SEL-0002\ny cuadricula vacia TBL-0001]
    E --> F[Usuario selecciona mes en SEL-0001]
    F --> G[Usuario selecciona Medico Traumatologo Aliado\nen SEL-0002 que carga solo\nprofesionales desde Subsistema de Personal]
    G --> H[Usuario presiona Filtrar Historial\nBTN-0001]
    H --> I{Sistema busca en CommissionRecord:\nExisten registros de comisiones\npara ese medico y mes?}
    I -- No --> J[Sistema muestra MSG-0001:\nNo se encontraron comisiones\nen el periodo seleccionado]
    J --> K[Cuadricula TBL-0001 permanece vacia]
    K --> L([Fin — solo lectura])
    I -- Si --> M[Sistema procesa datos encontrados]
    M --> N[Sistema calcula total acumulado\nde comisiones del periodo]
    N --> O[Sistema renderiza en TBL-0001:\nlista de pacientes derivados\ny monto final a pagar a fin de mes]
    O --> P{Usuario presiona\nExportar a Excel\nBTN-0002?}
    P -- No --> Q([Fin — solo lectura])
    P -- Si --> R[Sistema procesa data visualizada\nen la cuadricula TBL-0001]
    R --> S[Sistema genera archivo .xlsx\nestructurado para cuadre contable]
    S --> T[Sistema dispara descarga\ndel archivo en el navegador]
    T --> U[Sistema muestra MSG-0002:\nReporte exportado correctamente\nSin alterar base de datos]
    U --> V[Sistema cierra tabla CommissionRecord]
    V --> W[Sistema cierra conexion a payments_db]
    W --> X[Interfaz permanece en IGU-PAG-0006\nlista para nuevo filtro]
    X --> Y([Fin — solo lectura])
```

---

## Actualizar estado o monto de comision (ILA-PAG-0011)

```mermaid
flowchart TD
    A([Inicio]) --> B[Usuario inicia sesion\nACT-0001 o ACT-0002]
    B --> C[Abre historial de comisiones\ny visualiza cuadricula]
    C --> D[Sistema conecta a payments_db\nabre tabla CommissionRecord]
    D --> E[Usuario selecciona registro especifico\nen la cuadricula y presiona Editar Comision]
    E --> F[Sistema despliega formulario modal\ncon datos actuales del registro]
    F --> G[Usuario modifica uno o ambos campos:\nEstado: cambia a Pagado\nMonto: corrige cifra]
    G --> H[Usuario presiona Actualizar]
    H --> I[Sistema muestra ventana de confirmacion:\nEsta seguro de guardar\nlos cambios en esta comision?]
    I --> J{Usuario confirma?}
    J -- No --> K[Sistema cierra ventana\nFormulario modal permanece activo]
    K --> G
    J -- Si --> L{Validacion logica:\nMonto vacio o\nno numerico?}
    L -- Si --> M[Sistema muestra error:\nDatos invalidos\nVentana de confirmacion se cierra\npero formulario modal permanece activo]
    M --> G
    L -- No --> N[Sistema sobreescribe registro\ncorrespondiente en CommissionRecord]
    N --> O[Sistema cierra ventana de confirmacion\ny formulario modal]
    O --> P[Sistema muestra exito:\nComision actualizada exitosamente]
    P --> Q[Sistema renderiza nueva informacion\nen la cuadricula]
    Q --> R[Sistema cierra tabla CommissionRecord]
    R --> S[Sistema cierra conexion a payments_db]
    S --> T([Fin])
```

---

## Anular registro de comision (ILA-PAG-0012)

```mermaid
flowchart TD
    A([Inicio]) --> B[Usuario inicia sesion\nACT-0001 o ACT-0002]
    B --> C[Abre historial de comisiones\ny visualiza cuadricula]
    C --> D[Sistema conecta a payments_db\nabre tabla CommissionRecord]
    D --> E[Usuario selecciona registro especifico\ny presiona Eliminar Comision]
    E --> F[Sistema despliega ventana de advertencia:\nEsta seguro de anular esta comision?\nEsta accion no se puede deshacer]
    F --> G{Usuario confirma\nanulacion?}
    G -- No --> H[Ventana se cierra\nsin alterar base de datos]
    H --> I([Fin sin cambios])
    G -- Si --> J{Validacion logica:\nEl registro existe y\nno esta ya en estado Anulado?}
    J -- No --> K[Sistema muestra error:\nLa comision ya fue anulada previamente]
    K --> L[Ventana de advertencia se cierra\nsin alterar base de datos]
    L --> I
    J -- Si --> M[Sistema ejecuta borrado logico:\ncambia estado del registro\na Anulado en CommissionRecord]
    M --> N[Sistema muestra exito:\nComision anulada exitosamente]
    N --> O[Sistema actualiza cuadricula\ncon datos actualizados]
    O --> P[Sistema cierra tabla CommissionRecord]
    P --> Q[Sistema cierra conexion a payments_db]
    Q --> R([Fin])
```
