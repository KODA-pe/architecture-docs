# Resumen del servicio de pagos

El servicio de pagos administra ingresos y egresos de dinero sobre la base de datos **payments_db**. Su operación cubre registros operativos diarios, ventas de paquetes con pagos fraccionados, comisiones externas y egresos fijos mensuales. Trabaja con las tablas **CashTransaction**, **Patient**, **PackageSale**, **Installment**, **CommissionRecord** y **FixedExpense**.

La lógica general se apoya en cuatro principios:

- **Atomicidad:** cada operación realiza una sola función principal: crear, leer, actualizar o anular.
- **Validación estricta:** se verifican campos obligatorios, montos numéricos, montos no negativos, fechas válidas, existencia de registros y estados no duplicados.
- **Borrado lógico:** las anulaciones no eliminan físicamente la información; cambian el estado a “anulado”.
- **Confirmación previa:** antes de actualizar o anular registros sensibles se solicita confirmación al usuario.
- **Cierre ordenado:** al finalizar cada operación se cierran las tablas y la conexión a **payments_db**.
- **Control de acceso:** algunas operaciones son exclusivas del Gerente General; otras las puede realizar la Cajera o el Gerente General, siempre con sesión iniciada.

---

## 1. Egresos operativos diarios

Se registran en **CashTransaction** con el atributo **type** igual a “salida”.

### Crear egreso operativo

- El usuario inicia sesión y abre el formulario de registro de salidas.
- Selecciona la categoría del egreso desde opciones fijas: “Egresos operativos diarios” o “Pago de comisiones externas”.
- Selecciona el método de pago.
- Digita el monto exacto y una justificación o descripción.
- Presiona “Registrar Salida”.
- Validaciones:
  - Si el monto está vacío, es negativo o no se seleccionó categoría/método, se muestra el error: “Faltan datos obligatorios o el monto ingresado es inválido”.
  - El formulario permanece activo y no borra los datos ingresados.
- Si todo es válido:
  - Se persiste el registro en **CashTransaction**.
  - El atributo **type** se registra automáticamente como “salida”.
  - Se limpian los campos.
  - Se muestra confirmación: “Salida de dinero registrada correctamente”.
- Postcondición: el egreso queda guardado permanentemente y la interfaz queda lista para una nueva transacción.

### Leer historial de egresos operativos diarios

- El usuario abre el historial de salidas.
- Selecciona una fecha y presiona “Buscar”.
- Validaciones:
  - Si la fecha está vacía o tiene formato incorrecto, se muestra: “Debe seleccionar una fecha válida”.
  - No se altera la base de datos.
- Si la fecha es válida:
  - Se consulta **CashTransaction** para obtener solo registros con **type** “salida” y fecha coincidente.
  - Si no hay registros, se muestra: “No hay salidas de dinero registradas en esta fecha”.
  - Si existen, se renderiza una lista con monto, concepto y método de pago.
- Postcondición: operación de solo lectura; no se modifica **payments_db**.

### Actualizar egreso operativo

- El usuario selecciona un egreso previamente registrado.
- El formulario carga automáticamente los datos actuales.
- Puede modificar categoría, método de pago, monto y descripción.
- Presiona “Actualizar Salida”.
- Validaciones:
  - Si el monto queda vacío, es negativo o falta una opción obligatoria, se muestra: “Faltan datos obligatorios o el monto modificado es inválido”.
  - El formulario permanece activo sin alterar ni limpiar los datos.
- Si todo es válido:
  - Se sobreescribe el registro correspondiente en **CashTransaction**.
  - Se muestra: “Egreso operativo actualizado correctamente”.
  - Se redirige al historial.
- Postcondición: los datos quedan modificados y persistidos permanentemente.

### Anular egreso operativo

- El usuario selecciona un egreso desde el historial.
- Se despliega una ventana de advertencia para confirmar la anulación.
- El usuario confirma.
- Validaciones:
  - Si el registro ya no existe o ya está “anulado”, se muestra: “El registro de salida no fue encontrado o ya se encuentra anulado”.
  - No se altera la base de datos.
- Si es válido:
  - Se ejecuta borrado lógico.
  - El estado del registro cambia a “anulado” en **CashTransaction**.
  - Se muestra: “Egreso operativo anulado correctamente”.
  - Se actualiza la lista del historial.
- Postcondición: el estado “anulado” queda persistido permanentemente.

---

## 2. Entradas de dinero por venta de paquetes

Estas operaciones se gestionan desde el sistema clínico externo hacia el backend de pagos. Involucran **Patient**, **PackageSale**, **Installment**, **CashTransaction** y, si existe derivador, **CommissionRecord**.

### Crear registro de entrada de dinero

- La Cajera inicia sesión en el sistema clínico y registra una venta.
- El backend recibe los datos: DNI del paciente, precio base, monto de abono inicial, indicadores de IGV/descuento y, opcionalmente, identificador de derivación.
- Se abren las tablas **Patient**, **PackageSale**, **Installment**, **CashTransaction** y, si hay derivador, **CommissionRecord**.
- Validaciones:
  - Se verifica integridad estructural: montos numéricos y DNI obligatorio.
  - Si el DNI no existe en **Patient**, se devuelve error: “El DNI ingresado no pertenece a un paciente registrado”.
  - No se altera la base de datos.
- Si el DNI existe:
  - El backend calcula internamente IGV y descuento según los indicadores booleanos.
  - Obtiene matemáticamente el monto total.
  - Valida que el abono inicial sea igual o mayor al mínimo permitido: **S/ 50**.
  - Persiste de forma atómica:
    - Datos de venta en **PackageSale**.
    - Abono inicial en **Installment**, marcando **is_initial_payment** como verdadero.
    - Ingreso financiero final en **CashTransaction**.
    - Si hubo derivador, registra la deuda de comisión en **CommissionRecord**.
  - Notifica automáticamente al módulo clínico que el paciente tiene un paquete pagado para habilitar el control de asistencias.
  - Devuelve confirmación: “Entrada de dinero y abono inicial calculados y registrados exitosamente”.
- Postcondición: los datos quedan persistidos en **PackageSale**, **Installment**, **CashTransaction** y, de corresponder, **CommissionRecord**. El módulo clínico queda notificado.

### Leer historial de paquetes y deuda por DNI

- La Cajera solicita la búsqueda del historial de un paciente por DNI.
- El backend recibe el DNI como parámetro.
- Se abren **Patient**, **PackageSale** e **Installment**.
- Validaciones:
  - Se verifica la integridad estructural del DNI.
  - Si el DNI no existe en **Patient**, se devuelve: “Paciente no encontrado”.
  - No se altera ninguna información.
- Si el paciente existe:
  - Se consulta en **PackageSale** el historial de paquetes comprados.
  - Se calcula dinámicamente la deuda actual: por cada paquete, se resta la sumatoria de abonos registrados en **Installment** al monto total a pagar.
  - Se estructura la información del paciente, historial de compras y deuda calculada.
  - Se devuelve respuesta exitosa.
- Postcondición: operación de solo lectura. El backend no guarda la deuda como valor estático; la calcula al vuelo desde **Installment**.

### Actualizar registro de entrada de dinero: pago de cuota

- La Cajera confirma el cobro de una nueva cuota para un paquete existente.
- El backend recibe el identificador de venta y el monto de la cuota, por ejemplo, **S/ 40**.
- Se abren **PackageSale** e **Installment**.
- Validaciones:
  - Se verifica que el monto sea numérico y que exista el identificador de venta.
  - Se busca la venta en **PackageSale**.
  - Si la venta no existe o la deuda ya estaba totalmente cancelada, se devuelve: “Venta no encontrada o deuda previamente cancelada”.
  - No se alteran los datos.
- Si la venta es válida:
  - Se persiste el nuevo pago parcial en **Installment**, vinculado a esa venta.
  - Se verifica matemáticamente el saldo restante.
  - Si corresponde regularización total o parcial, se notifica al módulo de agendamiento clínico para desbloquear reservas de citas futuras del paciente.
  - Se devuelve: “Cuota registrada exitosamente”.
- Postcondición: la nueva cuota queda persistida en **Installment** y el módulo clínico queda notificado.

### Anular registro de entrada de dinero

- La Cajera acepta una ventana de confirmación para anular una venta.
- El backend recibe el identificador único de la venta.
- Se abren **PackageSale** e **Installment**.
- Validaciones:
  - Se verifica la integridad del identificador.
  - Se busca la venta en **PackageSale**.
  - Si la venta no existe o ya estaba anulada, se devuelve: “Venta no encontrada o previamente anulada”.
  - No se altera la base de datos.
- Si la venta es válida:
  - Se ejecuta borrado lógico.
  - Se actualiza el estado de la venta en **PackageSale** y de todos sus abonos asociados en **Installment** a “anulado”.
  - Se devuelve: “Registro de entrada de dinero anulado exitosamente”.
- Postcondición: la venta y sus abonos quedan con estado “anulado” persistido permanentemente.

---

## 3. Comisiones externas

Se gestionan en **CommissionRecord**. Están asociadas a derivadores como “Promotor Externo” o “Médico Traumatólogo”.

### Crear registro de pago o deuda de comisión

- El usuario inicia sesión y abre el formulario de registro de comisiones.
- Busca y selecciona al derivador desde un menú desplegable interconectado con los datos del personal.
- El sistema identifica automáticamente si el perfil es “Promotor Externo” o “Médico Traumatólogo”.
- Obtiene desde la base de datos el número de teléfono/Yape o cuenta bancaria del derivador y lo muestra en un campo bloqueado de solo lectura.
- El usuario digita el monto a comisionar, por ejemplo, **S/ 25**.
- Establece el estado del registro: “Pagado” o “Pendiente”.
- Presiona “Registrar Comisión”.
- Validaciones:
  - Si no se seleccionó derivador, el monto está vacío o es inválido, se muestra: “Faltan datos obligatorios o el monto ingresado es inválido”.
  - El formulario permanece activo sin borrar la selección previa.
- Si todo es válido:
  - Se persiste la nueva comisión en **CommissionRecord**.
  - Se limpian los campos.
  - Se muestra: “Registro de comisión creado exitosamente”.
- Postcondición: el pago o deuda de comisión queda guardado permanentemente y la interfaz queda lista para una nueva transacción.

### Leer historial de comisiones y exportar reporte

- El usuario abre el historial de comisiones.
- Se muestra un menú desplegable de meses, un menú desplegable de médico tratante y una cuadrícula vacía.
- El usuario selecciona el mes y al “Médico Traumatólogo Aliado”.
- Presiona “Filtrar Historial”.
- Validaciones:
  - Si no existen registros de comisiones para ese médico en el periodo seleccionado, se muestra: “No se encontraron comisiones en el periodo seleccionado”.
  - La cuadrícula permanece vacía.
- Si existen registros:
  - Se procesan los datos.
  - Se calcula el total acumulado.
  - Se renderiza en la cuadrícula la lista de pacientes derivados y el monto final a pagar a fin de mes.
- El usuario puede presionar “Exportar a Excel”.
- El sistema genera y descarga un archivo **.xlsx** estructurado para el cuadre contable.
- Se muestra: “Reporte exportado correctamente”.
- Postcondición: operación de solo lectura. No se altera, crea ni elimina información en **payments_db**.

### Actualizar estado o monto de la comisión externa

- El usuario selecciona un registro específico en la cuadrícula y presiona “Editar Comisión”.
- Se despliega un formulario modal con los datos actuales del registro.
- El usuario puede:
  - Cambiar el estado a “Pagado”.
  - Corregir la cifra del monto.
- Presiona “Actualizar”.
- Se muestra una ventana de confirmación: “¿Está seguro de guardar los cambios en esta comisión?”.
- El usuario confirma.
- Validaciones:
  - Si el monto está vacío o no es numérico, se muestra: “Datos inválidos”.
  - Se cierra la advertencia, pero el formulario modal permanece activo sin borrar los datos ingresados.
- Si todo es válido:
  - Se sobreescribe el registro correspondiente en **CommissionRecord**.
  - Se cierra la ventana de confirmación y el formulario modal.
  - Se muestra: “Comisión actualizada exitosamente”.
  - Se renderiza la nueva información en la cuadrícula.
- Postcondición: el nuevo estado o monto queda persistido permanentemente en **CommissionRecord**.

### Anular registro de comisión externa

- El usuario selecciona un registro en la cuadrícula y presiona “Eliminar Comisión”.
- Se despliega una ventana de advertencia: “¿Está seguro de anular esta comisión? Esta acción no se puede deshacer”.
- El usuario confirma la anulación.
- Validaciones:
  - Si el registro ya no existe o ya está “Anulado”, se muestra: “La comisión ya fue anulada previamente”.
  - Se cierra la ventana de advertencia sin alterar la base de datos.
- Si es válido:
  - Se ejecuta borrado lógico.
  - El estado del registro cambia a “Anulado” en **CommissionRecord**.
  - Se muestra: “Comisión anulada exitosamente”.
  - Se actualiza la cuadrícula.
- Postcondición: el estado “Anulado” queda persistido permanentemente, protegiendo el historial de auditoría financiera.

---

## 4. Egresos fijos mensuales

Se gestionan en **FixedExpense**. Esta operación es confidencial y exclusiva del Gerente General.

### Crear egreso fijo

- El Gerente General inicia sesión y entra a la gestión de egresos fijos.
- Selecciona la categoría del gasto desde opciones fijas:
  - “Alquileres de locales”
  - “Honorarios profesionales”
  - “Sueldos fijos de personal”
  - “Servicios externos”
- Ingresa el concepto detallado y el monto del pago.
- Presiona “Guardar Egreso”.
- Validaciones:
  - Si no se seleccionó categoría, el monto está vacío o tiene formato inválido, se muestra: “Faltan datos obligatorios o formato inválido”.
  - El formulario permanece activo sin borrar los datos.
- Si todo es válido:
  - Se persiste el nuevo egreso fijo y su categoría en **FixedExpense**.
  - Se limpia el formulario.
  - Se muestra: “Egreso fijo registrado correctamente”.
- Postcondición: el egreso fijo queda persistido permanentemente y la interfaz queda lista para un nuevo registro.

### Leer historial de egresos fijos mensuales

- El Gerente General abre el historial de egresos fijos.
- Se muestra un menú desplegable de meses y una cuadrícula vacía.
- Selecciona el mes y presiona “Filtrar Historial”.
- Validaciones:
  - Si no existen registros para el mes seleccionado, se muestra: “No se encontraron egresos registrados en el periodo seleccionado”.
  - La cuadrícula permanece vacía sin alterar la base de datos.
- Si existen registros:
  - Se renderiza la lista detallada de los gastos fijos del mes.
  - Se calcula matemáticamente y se muestra automáticamente la sumatoria total de los egresos fijos en la parte inferior, en un campo de solo lectura.
- Postcondición: operación de solo lectura. No se altera la base de datos.

### Actualizar egreso fijo

- El usuario selecciona un registro en la cuadrícula y presiona “Editar Egreso”.
- Se despliega un formulario modal con los datos actuales del egreso fijo.
- El usuario puede modificar el concepto o corregir el monto por ajustes salariales o errores de digitación.
- Presiona “Actualizar Egreso”.
- Se muestra una ventana de confirmación: “¿Está seguro de guardar los cambios en este registro de egreso fijo?”.
- El usuario confirma.
- Validaciones:
  - Si el monto está vacío o tiene formato no numérico, se muestra: “Datos de monto inválidos”.
  - El formulario modal permanece activo sin borrar la información ingresada.
- Si todo es válido:
  - Se sobreescribe el registro correspondiente en **FixedExpense**.
  - Se cierra la ventana de confirmación y el formulario modal.
  - Se muestra: “Egreso fijo actualizado exitosamente”.
  - Se actualiza la cuadrícula.
- Postcondición: los datos quedan modificados y persistidos permanentemente en **FixedExpense**.

### Anular egreso fijo

- El usuario selecciona un registro en la cuadrícula y presiona “Eliminar Egreso”.
- Se despliega una ventana de advertencia: “¿Está seguro de anular este egreso fijo? Esta acción afectará los reportes contables”.
- El usuario confirma la anulación.
- Validaciones:
  - Si el registro ya no existe o ya está “Anulado”, se muestra: “El egreso ya fue anulado previamente”.
  - Se cierra la ventana de advertencia sin alterar la base de datos.
- Si es válido:
  - Se ejecuta borrado lógico.
  - El estado del registro cambia a “Anulado” en **FixedExpense**.
  - Se muestra: “Egreso fijo anulado exitosamente”.
  - Se actualiza la cuadrícula.
- Postcondición: el estado “Anulado” queda persistido permanentemente, protegiendo el historial de auditoría financiera.

---

## 5. Persistencia y efectos en la base de datos

Las operaciones afectan las siguientes tablas de **payments_db**:

- **CashTransaction:** registra egresos operativos diarios con **type** “salida” y también ingresos financieros finales por ventas de paquetes.
- **Patient:** valida la existencia del paciente por DNI.
- **PackageSale:** almacena las ventas de paquetes y su estado.
- **Installment:** registra abonos iniciales y cuotas posteriores. El abono inicial se marca con **is_initial_payment** verdadero.
- **CommissionRecord:** registra deudas o pagos de comisiones externas y su estado.
- **FixedExpense:** registra egresos fijos mensuales y su categoría.

Las operaciones de lectura no alteran **payments_db**. Las anulaciones siempre son borrado lógico: cambian el estado a “anulado” y conservan la información para auditoría.

---

## 6. Controles de seguridad y mitigación de riesgos

- Todas las operaciones requieren que el usuario haya iniciado sesión con credenciales válidas.
- Los egresos fijos son exclusivos del Gerente General.
- Los egresos operativos, entradas de dinero y comisiones pueden ser gestionados por la Cajera y/o el Gerente General según corresponda.
- Antes de actualizar o anular comisiones, egresos fijos y egresos operativos se muestran ventanas de confirmación para evitar cambios accidentales.
- Las anulaciones no eliminan físicamente registros; solo cambian su estado a “anulado”.
- Se validan montos, fechas, campos obligatorios, existencia de pacientes, ventas, comisiones y registros no anulados previamente.
- Se controla el abono mínimo de apertura de **S/ 50**.
- Se calculan internamente IGV, descuentos, totales y deudas para evitar manipulaciones desde el frontend.
- Se notifica automáticamente al módulo clínico cuando un paquete queda pagado o cuando una cuota regulariza la deuda, para habilitar o desbloquear citas.
- Se permite exportar el historial de comisiones a Excel para cuadre contable, sin alterar la base de datos.
