import serial


def read_value(prompt, maximum):
    while True:
        try:
            value = int(input(prompt), 0)
        except ValueError:
            print("Ingrese un numero entero valido.")
            continue

        if 0 <= value <= maximum:
            return value

        print(f"El valor debe estar entre 0 y {maximum}.")


data_a = read_value("Ingrese el dato A (0-255): ", 255)
data_b = read_value("Ingrese el dato B (0-255): ", 255)
opcode = read_value("Ingrese el opcode (0-63): ", 63)

with serial.Serial(
    "/dev/ttyUSB1",
    9600,
    bytesize=8,
    parity="N",
    stopbits=1,
    timeout=2
) as port:
    port.write(bytes([data_a, data_b, opcode]))
    result = port.read(1)
    if result:
        print(f"Resultado recibido: {result.hex()}")
    else:
        print("No se recibio respuesta dentro del tiempo de espera.")
