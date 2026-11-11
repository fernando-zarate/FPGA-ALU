"""Board transactions and an explicitly synthetic, untimed pipeline demo."""

import time

import serial

from .assembler import assemble, decode
from .initial import MASK, validate_initial_registers
from .protocol import CommandRejected, INITIAL_NACKS, Snapshot, UART

SAMPLE = "# Independent ADDs; apply initial values x1=7, x2=5\nADD x3, x1, x2\nADD x4, x1, x1\nADD x5, x2, x2\n"


def validate_words(words: list[int]) -> None:
    if not 1 <= len(words) <= 64 or any(decode(word) is None or not 0 <= word <= 0xFFFFFFFF for word in words):
        raise ValueError("Upload requires 1..64 fully validated ADD words")


class Board:
    def __init__(self, port: str, baud: int = 9600, allow_upload: bool = False):
        self.port_name = port
        self.baud = baud
        self.allow_upload = allow_upload
        self.uart: UART | None = None
        self.running: bool | None = None

    def connect(self) -> None:
        self.uart = UART(serial.Serial(
            self.port_name, self.baud, bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE,
            timeout=0.1, write_timeout=2,
        ))
        self.running = None  # Opening a port sends no debug commands.

    def snapshot(self) -> Snapshot:
        self.uart.command(0)
        self.running = False
        return self.uart.dump()

    def step(self) -> Snapshot:
        self.uart.command(0)
        self.running = False
        self.uart.command(3)
        return self.uart.dump()

    def run(self) -> None:
        self.uart.command(4)
        self.running = True

    def reset(self) -> Snapshot:
        self.uart.command(1)
        self.running = False
        return self.snapshot()

    def require_hardware_writes(self) -> None:
        if not self.allow_upload:
            raise ValueError("Hardware writes blocked: physical board validation pending; experimental opt-in required")

    def initialize(self, initial: dict[int, int]) -> Snapshot:
        initial = validate_initial_registers(initial)
        self.require_hardware_writes()
        self.uart.command(0)
        self.running = False
        self.uart.command(1)
        for index, value in initial.items():
            self.uart.initialize_register(index, value)
        return self.snapshot()

    def upload(self, words: list[int], initial: dict[int, int] | None = None) -> Snapshot:
        validate_words(words)  # Entire program must pass before any command/write.
        initial = validate_initial_registers(initial)
        self.require_hardware_writes()
        self.uart.command(0)
        self.running = False
        self.uart.command(1)
        for index in range(64):
            word = words[index] if index < len(words) else 0
            self.uart.command(2, bytes([index * 4]) + word.to_bytes(4, "big"), ack=0xAA)
        self.uart.command(1)  # Last reset MUST precede every initial register write.
        for index, value in initial.items():
            self.uart.initialize_register(index, value)
        return self.snapshot()

    def close(self, pause: bool = True) -> None:
        if self.uart is not None:
            try:
                if pause:
                    self.uart.command(0)
            finally:
                self.uart.port.close()
                self.uart = None
                self.running = None


class Demo:
    """No forwarding; reads old registers before WB on each synthetic cycle."""

    allow_upload = True

    def __init__(self):
        self.running = False
        self.memory = [item.word for item in assemble(SAMPLE)] + [0] * 61
        self._reset()
        self.registers[1:3] = [7, 5]

    def connect(self) -> None:
        self.running = False

    def _reset(self) -> None:
        self.pc = 0
        self.pcs = [0] * 4
        self.instruction = 0
        self.a = self.b = self.rd_ex = 0
        self.mem = self.rd_mem = self.wb = self.rd_wb = 0
        self.ex_write = self.mem_write = self.wb_write = False
        self.registers = [0] * 32
        self.running = False
        self.initial_window = True

    def _cycle(self) -> None:
        self.initial_window = False
        fields = decode(self.instruction)
        rs1 = self.instruction >> 15 & 31
        rs2 = self.instruction >> 20 & 31
        a, b = self.registers[rs1], self.registers[rs2]
        if self.wb_write and self.rd_wb:
            self.registers[self.rd_wb] = self.wb
        self.registers[0] = 0
        self.wb, self.rd_wb, self.wb_write = self.mem, self.rd_mem, self.mem_write
        self.mem, self.rd_mem, self.mem_write = (self.a + self.b) & MASK, self.rd_ex, self.ex_write
        self.a, self.b = a, b
        self.rd_ex = self.instruction >> 7 & 31
        self.ex_write = fields is not None
        self.instruction = self.memory[(self.pc >> 2) & 63]
        self.pcs = [self.pc, *self.pcs[:3]]
        self.pc = (self.pc + 4) & MASK

    def _catch_up(self) -> None:
        if self.running:
            # 10 synthetic cycles/sec, deliberately unrelated to FPGA timing.
            count = int((time.monotonic() - self.started) * 10)
            for _ in range(count):
                self._cycle()
            self.started += count / 10

    def snapshot(self) -> Snapshot:
        self._catch_up()
        self.running = False
        return Snapshot((self.pc, *self.pcs), self.instruction, self.a, self.b,
                        self.rd_ex, self.mem, self.rd_mem, self.wb, self.rd_wb,
                        tuple(self.registers))

    def step(self) -> Snapshot:
        self.snapshot()
        self._cycle()
        return self.snapshot()

    def run(self) -> None:
        self.initial_window = False
        if not self.running:
            self.started = time.monotonic()
            self.running = True

    def reset(self) -> Snapshot:
        self._reset()
        return self.snapshot()

    def initialize_register(self, index: int, value: int) -> None:
        value = validate_initial_registers({index: value})[index]
        if self.running or not self.initial_window:
            raise CommandRejected(INITIAL_NACKS[0xE2])
        self.registers[index] = value

    def initialize(self, initial: dict[int, int]) -> Snapshot:
        initial = validate_initial_registers(initial)
        self._reset()
        for index, value in initial.items():
            self.initialize_register(index, value)
        return self.snapshot()

    def upload(self, words: list[int], initial: dict[int, int] | None = None) -> Snapshot:
        validate_words(words)
        initial = validate_initial_registers(initial)
        self._reset()
        self.memory = words + [0] * (64 - len(words))
        return self.initialize(initial)

    def close(self, pause: bool = True) -> None:
        self.snapshot()
