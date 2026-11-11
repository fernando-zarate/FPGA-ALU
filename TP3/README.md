# TUI para interactuar con la Debug Unit

## como usarla

desde TP3/host/ y con la placa ya programada

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -e
python3 -m riscv_tui --board /dev/ttyUSB1 --allow-hardware-upload
```

## interactuar con la TUI 

primero es necesario conectar la placa, apretar el boton de Connect o F9.

En la seccion "program" podemos escribir el programa que vamos a ejecutar en el pipeline e inicializar los registros. 

Luego con Replace IMEM + Init o Crtl+U reprogramamos la instruccion memory sin re sintetizar el pipeline.

Despues de ejecutar 5 steps vemos que se ejecuto el WB y se actualizo el registro.
