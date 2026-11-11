import argparse

from .app import DebugApp
from .backend import Board, Demo


def main() -> None:
    parser = argparse.ArgumentParser(description="TP3 ADD-only pipeline lab console")
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--demo", action="store_true", help="synthetic model; no board required")
    target.add_argument("--port", help="FPGA serial device, e.g. /dev/ttyUSB0")
    parser.add_argument("--baud", type=int, default=9600)
    parser.add_argument("--allow-hardware-upload", action="store_true",
                        help="EXPERIMENTAL hardware writes (IMEM + initial registers); rebuild bitstream; board validation pending")
    args = parser.parse_args()
    if args.baud <= 0:
        parser.error("--baud must be positive")
    backend = Demo() if args.demo else Board(args.port, args.baud, args.allow_hardware_upload)
    DebugApp(backend).run()


if __name__ == "__main__":
    main()
