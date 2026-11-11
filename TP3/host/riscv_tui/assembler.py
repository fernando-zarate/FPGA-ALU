"""Strict ADD assembler. Unsupported words are never silently accepted."""

from dataclasses import dataclass
import re


@dataclass(frozen=True)
class Instruction:
    line: int
    address: int
    word: int
    text: str


def decode(word: int) -> tuple[int, int, int] | None:
    if word & 0xFE00707F != 0x33:
        return None
    return (word >> 7 & 31, word >> 15 & 31, word >> 20 & 31)


def assemble(source: str) -> list[Instruction]:
    result = []
    for number, line in enumerate(source.splitlines(), 1):
        text = re.split(r"#|;|//", line, maxsplit=1)[0].strip()
        if not text:
            continue
        match = re.fullmatch(r"add\s+x(\d+)\s*,\s*x(\d+)\s*,\s*x(\d+)", text, re.I)
        if not match or any(int(reg) > 31 for reg in match.groups()):
            raise ValueError(f"Line {number}: expected ADD x0..x31, x0..x31, x0..x31")
        if len(result) == 64:
            raise ValueError(f"Line {number}: IMEM holds at most 64 instructions")
        rd, rs1, rs2 = map(int, match.groups())
        word = rs2 << 20 | rs1 << 15 | rd << 7 | 0x33
        result.append(Instruction(number, len(result) * 4, word, f"ADD x{rd}, x{rs1}, x{rs2}"))
    if not result:
        raise ValueError("Program is empty; enter at least one ADD instruction")
    return result
