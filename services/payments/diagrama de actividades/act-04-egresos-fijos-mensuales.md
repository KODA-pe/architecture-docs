# Diagrama de Actividades — Egresos Fijos Mensuales

**Educcion:** EDU-0021  
**Tabla afectada:** FixedExpense (payments_db)  
**Actor:** ACT-0001 (Gerente General) — acceso exclusivo y confidencial  
**Categorias disponibles:** Alquileres de locales, Honorarios profesionales, Sueldos fijos de personal, Servicios externos

---

## Crear egreso fijo mensual (ILA-PAG-0013)

```mermaid
flowchart TD
    A([Inicio]) --> B[Gerente General ACT-0001\ninicia sesion con credenciales\npropias y exclusivas]
    B --> C[Abre interfaz confidencial\nde gestion de egresos fijos IGU-PAG-0009]
    C --> D[Sistema conecta a payments_db\nabre tabla maestra FixedExpense]
    D --> E[Sistema despliega formulario con:\nSelector de categoria\nCampo de concepto detallado\nCampo de monto]
    E --> F[Gerente selecciona categoria\ndesde opciones fijas:\nAlquileres de locales\nHonorarios profesionales\nSueldos fijos de personal\nServicios externos]
    F --> G[Gerente ingresa concepto detallado\ndel gasto]
    G --> H[Gerente ingresa monto del pago]
    H --> I[Gerente presiona Guardar Egreso]
    I --> J{Validacion logica:\nCategoria no seleccionada?\nMonto vacio o formato invalido?}
    J -- Si --> K[Sistema despliega error:\nFaltan datos obligatorios\no formato invalido]
    K --> L[Formulario permanece activo\nsin borrar datos ingresados]
    L --> F
    J -- No --> M[Sistema persiste nuevo egreso fijo\ncon su categoria en FixedExpense]
    M --> N[Sistema limpia el formulario]
    N --> O[Sistema muestra exito:\nEgreso fijo registrado correctamente]
    O --> P[Sistema cierra tabla FixedExpense]
    P --> Q[Sistema cierra conexion a payments_db]
    Q --> R[Interfaz permanece lista\npara nuevo registro]
    R --> S([Fin])
```

---

## Consultar historial de egresos fijos por mes (ILA-PAG-0014)

```mermaid
flowchart TD
    A([Inicio]) --> B[Gerente General ACT-0001\ninicia sesion]
    B --> C[Abre interfaz de historial\nde egresos fijos IGU-PAG-0011]
    C --> D[Sistema conecta a payments_db\nabre tabla FixedExpense]
    D --> E[Sistema despliega:\nMenu desplegable de meses\ny cuadricula vacia TBL-0001]
    E --> F[Gerente selecciona el mes\na consultar]
    F --> G[Gerente presiona Filtrar Historial]
    G --> H{Sistema busca en FixedExpense:\nExisten registros para\nel mes seleccionado?}
    H -- No --> I[Sistema muestra:\nNo se encontraron egresos\nregistrados en el periodo seleccionado]
    I --> J[Cuadricula permanece vacia\nsin alterar base de datos]
    J --> K([Fin — solo lectura])
    H -- Si --> L[Sistema renderiza lista detallada\nde gastos fijos del mes\nen la cuadricula TBL-0001]
    L --> M[Sistema calcula automaticamente\nla sumatoria total de egresos fijos]
    M --> N[Sistema muestra total en campo\nde solo lectura en la parte inferior]
    N --> O[Sistema cierra tabla FixedExpense]
    O --> P[Sistema cierra conexion a payments_db]
    P --> Q([Fin — solo lectura])
```

---

## Actualizar egreso fijo (ILA-PAG-0015)

```mermaid
flowchart TD
    A([Inicio]) --> B[Gerente General ACT-0001\ninicia sesion]
    B --> C[Abre historial de egresos fijos\nIGU-PAG-0011 y visualiza cuadricula]
    C --> D[Sistema conecta a payments_db\nabre tabla FixedExpense]
    D --> E[Gerente selecciona registro especifico\nen la cuadricula y presiona\nEditar Egreso BTN-0002]
    E --> F[Sistema despliega formulario modal\nIGU-PAG-0012 con datos actuales\ndel egreso fijo]
    F --> G[Gerente modifica uno o ambos campos:\nConcepto: ajustes o correcciones\nMonto: ajustes salariales o error de digitacion]
    G --> H[Gerente presiona Actualizar Egreso\nBTN-0001 del modal]
    H --> I[Sistema despliega ventana de confirmacion\nIGU-PAG-0013:\nEsta seguro de guardar los cambios\nen este registro de egreso fijo?]
    I --> J{Gerente confirma\nen BTN-0001 Confirmar?}
    J -- No / Cancelar BTN-0002 --> K[Sistema cierra ventana de confirmacion\nFormulario modal permanece activo]
    K --> G
    J -- Si --> L{Validacion logica:\nMonto vacio o\nformato no numerico?}
    L -- Si --> M[Sistema muestra error MSG-0001:\nDatos de monto invalidos\nFormulario modal permanece activo\nsin borrar datos ingresados]
    M --> G
    L -- No --> N[Sistema sobreescribe registro\ncorrespondiente en FixedExpense]
    N --> O[Sistema cierra ventana de confirmacion\ny formulario modal]
    O --> P[Sistema muestra exito MSG-0002:\nEgreso fijo actualizado exitosamente]
    P --> Q[Sistema actualiza cuadricula TBL-0001\ncon nueva informacion]
    Q --> R[Sistema cierra tabla FixedExpense]
    R --> S[Sistema cierra conexion a payments_db]
    S --> T([Fin])
```

---

## Anular egreso fijo (ILA-PAG-0016 v02.00)

```mermaid
flowchart TD
    A([Inicio]) --> B[Gerente General ACT-0001\ninicia sesion con credenciales exclusivas]
    B --> C[Abre interfaz de historial\nde egresos fijos IGU-PAG-0011]
    C --> D[Sistema conecta a payments_db\nabre tabla maestra FixedExpense]
    D --> E[Gerente selecciona registro especifico\nen cuadricula TBL-0001\ny presiona Eliminar Egreso BTN-0003]
    E --> F[Sistema despliega ventana emergente\nde advertencia IGU-PAG-0014:\nEsta seguro de anular este egreso fijo?\nEsta accion afectara los reportes contables]
    F --> G{Gerente presiona\nConfirmar Anulacion\nBTN-0001?}
    G -- No --> H[Ventana de advertencia se cierra\nsin alterar base de datos]
    H --> I([Fin sin cambios])
    G -- Si --> J{Validacion logica:\nEl registro ya no existe\no ya posee estado Anulado?}
    J -- Si --> K[Sistema muestra error MSG-0002:\nEl egreso ya fue anulado previamente]
    K --> L[Ventana de advertencia se cierra\nsin alterar base de datos]
    L --> I
    J -- No --> M[Sistema ejecuta borrado logico:\ncambia atributo estado del registro\na Anulado en tabla FixedExpense]
    M --> N[Sistema cierra ventana de advertencia]
    N --> O[Sistema lanza exito MSG-0001:\nEgreso fijo anulado exitosamente]
    O --> P[Sistema actualiza automaticamente\nla cuadricula TBL-0001]
    P --> Q[Sistema cierra tabla FixedExpense]
    Q --> R[Sistema cierra conexion a payments_db]
    R --> S[Interfaz permanece en IGU-PAG-0011\nlista para nuevas consultas]
    S --> T([Fin])
```
