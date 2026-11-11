"""Fixed-size, big-endian DEBUG_UNIT wire format (no delimiter scanning)."""

from dataclasses import dataclass
import time

from .initial import validate_initial_registers


class ProtocolError(Exception):
    """Synchronization is no longer trustworthy; reconnect after checking board."""


class CommandRejected(Exception):
    """A complete, known NACK: the command failed but framing remains intact."""


INITIAL_NACKS = {
    0xE1: "Initial register index rejected (only x1..x31 are writable)",
    0xE2: "Initial state locked: RESET required before initialization; STEP/RUN closes the window",
}


@dataclass(frozen=True)
class Snapshot:
    pcs: tuple[int, ...]
    instruction: int
    operand_a: int
    operand_b: int
    rd_ex: int
    alu_mem: int
    rd_mem: int
    alu_wb: int
    rd_wb: int
    registers: tuple[int, ...]


def parse_dump(frame: bytes) -> Snapshot:
    if len(frame) != 337 or frame[0] != 0xDD or frame[-1] != 0xFF:
        raise ProtocolError("Invalid dump: expected exactly 337 bytes with DD/FF markers")
    if any(frame[offset] > 31 for offset in (61, 70, 79)):
        raise ProtocolError("Invalid destination register in dump")

    def integer(offset: int, size: int = 8) -> int:
        return int.from_bytes(frame[offset:offset + size], "big")

    return Snapshot(
        tuple(integer(offset) for offset in (1, 9, 17, 25, 33)),
        integer(41, 4), integer(45), integer(53), frame[61],
        integer(62), frame[70], integer(71), frame[79],
        tuple(integer(80 + index * 8) for index in range(32)),
    )


class UART:
    """Blocking operations; caller serializes transactions off the UI thread."""

    def __init__(self, port, timeout: float = 2.0):
        self.port = port
        self.timeout = timeout

    def read_exact(self, size: int, timeout: float | None = None) -> bytes:
        deadline = time.monotonic() + (self.timeout if timeout is None else timeout)
        data = bytearray()
        while len(data) < size:
            if time.monotonic() >= deadline:
                raise ProtocolError(f"UART timeout: received {len(data)}/{size} bytes")
            data.extend(self.port.read(size - len(data)))
        return bytes(data)

    def write(self, data: bytes) -> None:
        if self.port.write(data) != len(data):
            raise ProtocolError("Incomplete UART write")

    def command(self, command: int, payload: bytes = b"", ack: int | None = None) -> None:
        self.write(bytes([command]) + payload)
        expected = command if ack is None else ack
        actual = self.read_exact(1)[0]
        if command == 6 and actual in INITIAL_NACKS:
            raise CommandRejected(INITIAL_NACKS[actual])
        if actual != expected:
            raise ProtocolError(f"Unexpected ACK {actual:02X}; expected {expected:02X}")

    def initialize_register(self, index: int, value: int) -> None:
        value = validate_initial_registers({index: value})[index]
        self.command(6, bytes([index]) + value.to_bytes(8, "big"))

    def dump(self) -> Snapshot:
        self.write(b"\x05")
        # 337 bytes take ~0.35s at 9600 8N1; allow a bounded USB margin.
        return parse_dump(self.read_exact(337, max(4.0, self.timeout)))
