# Diagrama de Actividades — Egresos Operativos Diarios

**Educcion:** EDU-0001  
**Tabla afectada:** CashTransaction (payments_db)  
**Actores:** ACT-0001 (Gerente General), ACT-0002 (Cajera)

---

## Crear egreso operativo (ILA-PAG-0001 v02.05)

```mermaid
flowchart TD
    A([Inicio]) --> B[Usuario inicia sesion con credenciales\nACT-0001 o ACT-0002]
    B --> C[Abre interfaz IGU-PAG-0001\nFormulario de registro de salidas]
    C --> D[Sistema conecta a payments_db\ny abre tabla CashTransaction]
    D --> E[Sistema despliega formulario interactivo]
    E --> F[Usuario selecciona categoria del egreso\nSEL-0001: Egresos operativos diarios\no Pago de comisiones externas]
    F --> G[Usuario selecciona metodo de pago\nSEL-0002: Efectivo o Yape]
    G --> H[Usuario digita monto exacto\nTXT-0001 campo numerico]
    H --> I[Usuario ingresa descripcion o justificacion\nTXT-0002]
    I --> J[Usuario presiona Registrar Salida\nBTN-0001]
    J --> K{Validacion logica:\nMonto vacio, negativo\no falta categoria o metodo?}
    K -- Si --> L[Sistema despliega error MSG-0001:\nFaltan datos obligatorios\no el monto ingresado es invalido]
    L --> M[Formulario permanece activo\nSin borrar datos ingresados]
    M --> F
    K -- No --> N[Sistema persiste registro en CashTransaction\ncon atributo type = salida automaticamente]
    N --> O[Sistema limpia campos del formulario]
    O --> P[Sistema lanza MSG-0002:\nSalida de dinero registrada correctamente]
    P --> Q[Sistema cierra tabla CashTransaction]
    Q --> R[Sistema cierra conexion a payments_db]
    R --> S[Interfaz permanece en IGU-PAG-0001\nlista para nueva transaccion]
    S --> T([Fin])
```

---

## Consultar historial de egresos operativos por fecha (ILA-PAG-0002 v03.00)

```mermaid
flowchart TD
    A([Inicio]) --> B[Usuario inicia sesion\nACT-0001 o ACT-0002]
    B --> C[Abre interfaz IGU-PAG-0002\nHistorial de salidas de dinero]
    C --> D[Sistema conecta a payments_db\ny abre tabla CashTransaction]
    D --> E[Sistema despliega selector de fecha DAT-0001\ny lista de resultados vacia SEL-0001]
    E --> F[Usuario selecciona fecha a consultar\nDAT-0001]
    F --> G[Usuario presiona Buscar\nBTN-0001]
    G --> H{Validacion:\nFecha vacia o formato\nincorrecto?}
    H -- Si --> I[Sistema despliega error MSG-0001:\nDebe seleccionar una fecha valida]
    I --> J[Interfaz permanece activa\nsin alterar base de datos]
    J --> F
    H -- No --> K[Sistema consulta CashTransaction\nfiltro: type=salida y fecha coincidente]
    K --> L{La consulta\ndevuelve registros?}
    L -- No --> M[Sistema muestra MSG-0002:\nNo hay salidas de dinero\nregistradas en esta fecha]
    M --> N[Lista de resultados permanece vacia]
    N --> O([Fin — solo lectura])
    L -- Si --> P[Sistema renderiza lista SEL-0001\ncon monto, concepto y metodo de pago\nde cada egreso encontrado]
    P --> Q[Sistema cierra tabla CashTransaction]
    Q --> R[Sistema cierra conexion a payments_db]
    R --> S[Interfaz permanece en IGU-PAG-0002\nlista para nueva consulta]
    S --> T([Fin — solo lectura])
```

---

## Actualizar egreso operativo

```mermaid
flowchart TD
    A([Inicio]) --> B[Usuario inicia sesion\nACT-0001 o ACT-0002]
    B --> C[Abre interfaz IGU-PAG-0002\ny selecciona un egreso del historial]
    C --> D[Sistema conecta a payments_db\ny abre tabla CashTransaction]
    D --> E[Sistema carga datos actuales del egreso\nen el formulario de edicion]
    E --> F[Usuario modifica uno o varios campos:\ncategoria, metodo, monto o descripcion]
    F --> G[Usuario presiona Actualizar Salida]
    G --> H{Validacion:\nMonto vacio, negativo\no falta opcion obligatoria?}
    H -- Si --> I[Sistema muestra error:\nFaltan datos obligatorios\no el monto modificado es invalido]
    I --> J[Formulario permanece activo\nsin limpiar datos]
    J --> F
    H -- No --> K[Sistema sobreescribe registro\ncorrespondiente en CashTransaction]
    K --> L[Sistema muestra exito:\nEgreso operativo actualizado correctamente]
    L --> M[Sistema redirige al historial IGU-PAG-0002]
    M --> N[Sistema cierra tabla CashTransaction]
    N --> O[Sistema cierra conexion a payments_db]
    O --> P([Fin])
```

---

## Anular egreso operativo (ILA-PAG-0004 v03.01)

```mermaid
flowchart TD
    A([Inicio]) --> B[Usuario inicia sesion\nACT-0001 o ACT-0002]
    B --> C[Abre interfaz IGU-PAG-0002\nHistorial de egresos]
    C --> D[Usuario selecciona egreso y presiona\nVer mas BTN-0002]
    D --> E[Sistema redirige a IGU-PAG-0004\ncon detalle del registro]
    E --> F[Sistema conecta a payments_db\ny abre tabla CashTransaction]
    F --> G[Sistema despliega ventana de advertencia modal\nIGU-PAG-0004-MOD-0001:\nConfirmacion definitiva de anulacion\nsegun plan de mitigacion de riesgos]
    G --> H{Usuario presiona\nConfirmar Anulacion\nBTN-0016?}
    H -- No / Cancelar --> I[Ventana se cierra\nsin alterar base de datos]
    I --> J([Fin sin cambios])
    H -- Si --> K{Validacion logica:\nEl registro ya no existe\no ya posee estado Anulado?}
    K -- Si --> L[Sistema despliega error MSG-0001:\nEl registro de salida no fue encontrado\no ya se encuentra anulado]
    L --> M[Ventana permanece activa\nsin alterar base de datos]
    M --> J
    K -- No --> N[Sistema ejecuta borrado logico:\ncambia atributo estado a anulado\nen tabla CashTransaction]
    N --> O[Sistema cierra ventana de advertencia]
    O --> P[Sistema lanza MSG-0003:\nEgreso operativo anulado correctamente]
    P --> Q[Sistema actualiza automaticamente\nlista de resultados del historial]
    Q --> R[Sistema cierra tabla CashTransaction]
    R --> S[Sistema cierra conexion a payments_db]
    S --> T[Interfaz retorna al historial IGU-PAG-0002\nactualizado]
    T --> U([Fin])
```
