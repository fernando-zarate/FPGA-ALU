# Trabajo Práctico 2: Máquinas de Estado Finitas y UART

### Profesor: Martin Pereyra
### Alumnos: Agustín Álvarez y Fernando Zarate.

## Introducción

El trabajo consiste en implementar una comunicación UART entre una PC y una placa Basys 3, utilizando módulos desarrollados en Verilog y máquinas de estado finitas.

El objetivo principal es utilizar una FSM para controlar las distintas etapas de una comunicación serie asíncrona. Para esto se implementaron un **receptor UART**, un **transmisor UART** y un **generador de baud rate**.

La PC envía tres bytes correspondientes a los datos `A`, `B` y el `opcode`. La FPGA recibe estos datos, realiza la operación correspondiente mediante la ALU y devuelve un byte con el resultado.

El sistema utiliza:

* Clock de FPGA: `100 MHz`.
* Baud rate: `9600`.
* 1 bit de start.
* 8 bits de datos.
* 1 bit de stop.
* Oversampling de `16`.
* Comunicación bidireccional entre PC y FPGA.

---

## Implementación

El sistema está compuesto por los siguientes módulos principales:

* `BAUD_RATE_GENERATOR`: genera el pulso de sincronización utilizado por el transmisor y receptor UART.
* `UART_RX`: recibe los datos provenientes de la PC.
* `UART_TX`: transmite el resultado hacia la PC.
* `INTF_RX`: almacena temporalmente el byte recibido.
* `INTF_TX`: almacena el byte que debe transmitirse.
* `OP_CONTROLLER`: controla la recepción de `A`, `B` y `opcode`, y posteriormente solicita el envío del resultado.
* `ALU`: realiza la operación indicada por el opcode.
* `TOP`: conecta todos los módulos.

### Generador de baud rate

El generador utiliza el clock de `100 MHz` y un oversampling de `16`:

```text
TICK_RATE = 9600 × 16 = 153600 Hz
```

Por lo tanto:

```text
BAUD_COUNT = 100000000 / 153600 ≈ 651
```

Cada 651 ciclos del clock se genera un pulso `rate`, utilizado como referencia temporal por `UART_RX` y `UART_TX`.

---

## Recepción y Transmisión

El módulo `UART_RX` recibe cada byte y lo almacena en un registro de desplazamiento.
La FSM del receptor tiene cuatro estados:

```text
IDLE → START → DATA → STOP
  ↑                       │
  └───────────────────────┘
```
Cuando se detecta la caida a "0" en `i_rx` pasamos de IDLE a START. Dentro de START, a mitad del oversampling vefificamos nuevamente que `i_rx` este en "0" para pasar a DATA.
Al momento de pasar a DATA inicializamos un contador de 16 para muestrear los datos a la mitad del período del bit.

Una vez recibidos los 8 bits y el bit de stop, genera `o_done`, indicando que hay un nuevo dato disponible.
Ya listo el dato pasa a la interfaz `INTF_RX`.

El módulo `UART_TX` realiza el proceso inverso al receptor. Recibe un byte en paralelo desde la interfaz `INTF_TX` y lo convierte en una secuencia serie, utilizando los mismos estados que el receptor. Al finalizar tambien genera un `o_done`.

Las interfaces `INTF_RX` e `INTF_TX` funcionan como buffers de un byte para conectar los módulos UART con el controlador.

---

## Control de la operación

`OP_CONTROLLER` recibe los tres bytes en el siguiente orden:

```text
PC → A → B → OPCODE → FPGA
```

Luego de recibirlos, solicita a la ALU la operación correspondiente y espera que la interfaz de transmisión esté disponible para enviar el resultado.

---

## Comunicación con la PC 

Para probar el sistema se utilizó un script en Python.

El programa solicita al usuario los valores de `A`, `B` y `opcode`, establece la comunicación serie con la Basys 3 y envía los tres bytes.

La configuración utilizada en Python coincide con la configuración UART implementada en la FPGA:

```text
Puerto:    /dev/ttyUSB1
Baud rate: 9600
Datos:     8 bits
Paridad:   Ninguna
Stop bits: 1
```
---

## Módulo TOP

En `TOP` realizamos la conexión entre todos los módulos que forman el sistema UART y la unidad de procesamiento.
Utilizamos la misma forma de conexiones del enunciado, agregando solamente el módulo `OP_CONTROLLER`.

## Testbenches

Se desarrollaron cuatro testbenches para verificar el funcionamiento de los módulos.

#### `INTF_TB`

Verifica las interfaces de recepción y transmisión, incluyendo:

* Reset.
* Escritura y lectura.
* Estado lleno/vacío.
* Intentos de escritura cuando el buffer está ocupado.
* Lectura y escritura simultáneas.

#### `INTF_UART_TB`

Realiza pruebas de transmisión y recepción UART utilizando distintos valores.
Se verifica el envío, la recepción y la estructura de los datos transmitidos.

#### `OP_CONTROLLER_TB`

Prueba el controlador junto con la ALU utilizando operaciones y también verificando las señales de estado de la ALU.

#### `TOP_TB`

Prueba el sistema completo, incluyendo:


```text
UART RX → INTF_RX → OP_CONTROLLER → ALU → INTF_TX → UART TX
```
---

## Conclusión

Se implementó un sistema de comunicación UART entre una PC y una FPGA Basys 3. La implementación permite recibir dos operandos y un opcode, procesarlos mediante la ALU y devolver el resultado a la PC.

Los distintos testbenches permiten verificar individualmente las interfaces, la comunicación UART, el controlador y finalmente la integración de todo el sistema.

El trabajo permitió aplicar los conceptos de máquinas de estado, lógica secuencial y temporización al diseño de un sistema de comunicación serie asíncrono.