"""Explicit initial state, separate from ADD assembly and never evaluated as code."""

import re

MASK = (1 << 64) - 1
INITIAL_SAMPLE = "x1=7\nx2=5\n"


def validate_initial_registers(values: dict[int, int] | None) -> dict[int, int]:
    result = {}
    for index, value in (values if values is not None else {}).items():
        if type(index) is not int or not 1 <= index <= 31:
            raise ValueError("Initial register index must be x1..x31; x0 is immutable")
        if type(value) is not int or not -(1 << 63) <= value <= MASK:
            raise ValueError("Initial value must be in [-2^63, 2^64-1]")
        result[index] = value & MASK
    return result


def parse_initial_registers(source: str) -> dict[int, int]:
    result = {}
    for number, line in enumerate(source.splitlines(), 1):
        text = re.split(r"#|;|//", line, maxsplit=1)[0].strip()
        if not text:
            continue
        try:
            match = re.fullmatch(r"x(\d+)\s*=\s*([+-]?(?:0[xX][0-9a-fA-F]+|[0-9]+))", text, re.I)
            if not match:
                raise ValueError("expected x1..x31 = signed decimal or hexadecimal")
            index = int(match[1])
            if index in result:
                raise ValueError(f"duplicate x{index}")
            value = int(match[2], 16 if "x" in match[2].lower() else 10)
            result.update(validate_initial_registers({index: value}))
        except ValueError as error:
            raise ValueError(f"Line {number}: {error}") from error
    return result
