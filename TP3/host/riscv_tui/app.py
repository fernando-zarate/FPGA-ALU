"""Textual dashboard. Exactly one bounded backend transaction runs at a time."""

import asyncio
from datetime import datetime

from rich.text import Text
from textual import events
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Grid, Horizontal, Vertical, VerticalScroll
from textual.screen import ModalScreen
from textual.widgets import Button, DataTable, Footer, RichLog, Static, TabbedContent, TabPane, TextArea

from .assembler import assemble, decode
from .backend import Demo, SAMPLE
from .initial import INITIAL_SAMPLE, parse_initial_registers
from .protocol import CommandRejected, Snapshot


class Confirm(ModalScreen[bool]):
    BINDINGS = [("escape", "cancel", "Cancel")]
    DEFAULT_CSS = """
    Confirm { align: center middle; background: #000000 65%; }
    Confirm > Vertical { width: 68; max-width: 95%; height: auto;
        border: thick #ffbd69; background: #142330; padding: 1 2; }
    Confirm Static { height: auto; margin-bottom: 1; }
    Confirm Horizontal { height: 3; align-horizontal: right; }
    Confirm Button { margin-left: 1; }
    """

    def __init__(self, message: str):
        super().__init__()
        self.message = message

    def compose(self) -> ComposeResult:
        with Vertical():
            yield Static(self.message)
            with Horizontal():
                yield Button("Cancel", id="cancel")
                yield Button("Confirm", variant="warning", id="confirm")

    def on_mount(self) -> None:
        self.query_one("#cancel", Button).focus()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        event.stop()
        self.dismiss(event.button.id == "confirm")

    def action_cancel(self) -> None:
        self.dismiss(False)


class DebugApp(App):
    TITLE = "TP3 / ADD LAB"
    ENABLE_COMMAND_PALETTE = False
    CSS = """
    Screen { background: #09121d; color: #d6e4ef; }
    #brand { height: 1; background: #173044; color: #65e4eb; text-style: bold; padding: 0 1; }
    #status { height: 2; padding: 0 1; color: #ffbd69; }
    #toolbar { height: 6; grid-size: 3 2; grid-columns: 1fr 1fr 1fr; grid-rows: 3 3; }
    #toolbar Button { width: 100%; min-width: 12; height: 3; }
    TabbedContent { height: 1fr; }
    TabPane { padding: 0 1; }
    #stages { height: 9; grid-size: 5 1; grid-columns: 1fr 1fr 1fr 1fr 1fr; }
    .stage { border: round #258995; padding: 0 1; height: 9; color: #cceef1; }
    #mem, #wb { border: round #c59350; }
    #inspector { height: auto; min-height: 7; border: round #34516a; padding: 0 1; }
    .note { height: auto; color: #91a6b9; padding: 0 1; margin: 1 0; }
    #registers { height: 1fr; }
    #decimal { height: 3; width: 34; }
    #editor { height: 10; border: round #258995; }
    #initial-values { height: 6; border: round #c59350; }
    #listing { height: 10; }
    #program-actions, #initial-actions { height: 3; }
    #program-actions Button, #initial-actions Button { width: 1fr; }
    #upload-note { height: auto; color: #ffbd69; }
    #log { height: 5; border-top: solid #34516a; background: #0d1b28; padding: 0 1; }
    .compact #stages { height: 45; grid-size: 1 5; grid-columns: 1fr; grid-rows: 9 9 9 9 9; }
    """
    BINDINGS = [
        Binding("f9", "connect", "Connect"),
        Binding("f5", "step", "Step cycle"),
        Binding("f6", "run", "Run"),
        Binding("f7", "snapshot", "Pause/dump"),
        Binding("f8", "reset", "Reset"),
        Binding("ctrl+p", "assemble", "Preview", priority=True),
        Binding("ctrl+u", "upload", "Upload", show=False, priority=True),
        Binding("ctrl+q", "quit", "Quit", priority=True),
        Binding("ctrl+c", "quit", "Quit", show=False, priority=True),
    ]

    def __init__(self, backend):
        super().__init__()
        self.backend = backend
        self.demo = isinstance(backend, Demo)
        self.connected = False
        self.busy = False
        self.quitting = False
        self.stale = False
        self.snapshot: Snapshot | None = None
        self.previous: Snapshot | None = None
        self.signed = False
        self.steps = 0
        self._closing = False
        self._transaction_task: asyncio.Task | None = None

    def compose(self) -> ComposeResult:
        yield Static("TP3 / ADD LAB     RISC-V · 64-BIT · FIVE-STAGE PIPELINE", id="brand")
        yield Static(id="status")
        with Grid(id="toolbar"):
            yield Button("Connect · F9", id="connect", variant="primary")
            yield Button("Step cycle · F5", id="step")
            yield Button("Run · F6", id="run", variant="success")
            yield Button("Pause / dump · F7", id="snapshot", variant="primary")
            yield Button("Reset · F8", id="reset", variant="warning")
            yield Button("Quit · Ctrl+Q", id="quit")
        with TabbedContent():
            with TabPane("Pipeline", id="pipeline-tab"):
                with VerticalScroll():
                    with Grid(id="stages"):
                        for stage in ("IF", "ID", "EX", "MEM", "WB"):
                            yield Static(id=stage.lower(), classes="stage")
                    yield Static(id="inspector")
                    yield Static("Only exported latch data is shown. Stage valid/empty flags, control bits,\n"
                                 "IF/EX/MEM/WB instruction words and data memory are not exposed.\n"
                                 "STEP = one clock cycle, not one instruction. No FPGA cycle counter.", classes="note")
            with TabPane("Registers", id="register-tab"):
                yield Button("Decimal: unsigned (toggle)", id="decimal")
                yield DataTable(id="registers", cursor_type="row", zebra_stripes=True)
            with TabPane("Program", id="program-tab"):
                with VerticalScroll():
                    yield Static("ADD only · max 64 words · no forwarding/stalls: schedule dependencies.\n"
                                 "No HALT instruction, end detection or automatic pipeline drain.", classes="note")
                    yield TextArea(SAMPLE, id="editor", show_line_numbers=True, soft_wrap=False)
                    yield Static("Initial register values · x1..x31 = decimal / hex; empty = all zeros.\n"
                                 "Editing does nothing until confirmed. Unlisted registers reset to zero.", classes="note")
                    yield TextArea(INITIAL_SAMPLE, id="initial-values", show_line_numbers=True, soft_wrap=False)
                    with Horizontal(id="program-actions"):
                        yield Button("Assemble / preview · Ctrl+P", id="assemble", variant="primary")
                        yield Button("Replace IMEM + init · Ctrl+U", id="upload", variant="warning")
                    with Horizontal(id="initial-actions"):
                        yield Button("Reset + initialize (retain IMEM)", id="initialize", variant="warning")
                    yield Static(id="upload-note")
                    yield DataTable(id="listing", cursor_type="row", zebra_stripes=True)
            with TabPane("Guide", id="guide-tab"):
                with VerticalScroll():
                    yield Static(
                        "[bold cyan]SAFE LAB WORKFLOW[/]\n\n"
                        "1. Connect opens the port only; it never runs or resets the board.\n"
                        "2. Pause / dump sends HALT, waits for ACK, then reads a coherent snapshot.\n"
                        "3. STEP advances one cycle. RUN makes the displayed snapshot stale.\n"
                        "4. Pause / dump again to refresh; no dumps are sent while running.\n\n"
                        "[bold #ffbd69]DESTRUCTIVE OPERATIONS[/]\n"
                        "Reset clears registers, PC and pipeline latches; IMEM survives.\n"
                         "Replace IMEM + init resets before/after loading, then applies initial values.\n"
                         "Reset + initialize retains IMEM, clears all CPU state, then applies values.\n"
                         "Program-tab values default to x1=7, x2=5; nothing is applied by typing.\n"
                        "Uninitialized or old IMEM can execute; fetching wraps every 256 bytes.\n\n"
                        "[bold cyan]HONEST LIMITS[/]\n"
                         "ADD ISA unchanged: initial values use debug command 06, not instructions.\n"
                         "Initialization is allowed only after RESET and before any STEP/RUN.\n"
                         "HALT never reopens that window. Reset alone still clears every register.\n"
                         "DEMO startup seeds are synthetic; confirmed initial values also work on rebuilt RTL.\n"
                         "Demo is not timing/RTL validation. Old bitstreams require regeneration.\n"
                         "RX simulation passed; physical board validation is pending. Upload stays blocked by default.\n"
                          "--allow-hardware-upload gates both IMEM and initial-register writes; ACK is not IMEM readback.\n\n"
                        "After timeout/bad frame the host disconnects: synchronization is unknown.\n"
                        "A physical board reset/reconnect may be required. Upload may be partial.\n\n"
                        "Use Tab / Shift+Tab to focus, Enter to activate buttons, arrow keys to scroll.\n"
                        "Only function/Ctrl shortcuts control execution; typing ADD cannot step/run.",
                        classes="note",
                    )
        yield RichLog(id="log", wrap=True, highlight=False, markup=False, max_lines=300)
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#registers", DataTable)
        for key, label, width in (("reg", "Register", 8), ("hex", "Hex / 64-bit", 16),
                                  ("dec", "Decimal", 20), ("delta", "Δ", 2)):
            table.add_column(label, key=key, width=width)
        for index in range(32):
            table.add_row(f"x{index:02}", "—", "—", "", key=str(index))
        listing = self.query_one("#listing", DataTable)
        listing.add_columns("Line", "Byte addr", "Word", "Assembly")
        self.set_class(self.size.width < 120, "compact")
        self.event_log("DEMO: synthetic registers x1=7, x2=5; no hardware validation." if self.demo
                 else "FPGA disconnected. Connect sends no debug commands; use Pause / dump next.")
        self.render_state()

    def on_resize(self, event: events.Resize) -> None:
        self.set_class(event.size.width < 120, "compact")

    def event_log(self, message: str) -> None:
        if not self._closing:
            self.query_one("#log", RichLog).write(f"{datetime.now():%H:%M:%S}  {message}")

    def render_state(self) -> None:
        if self._closing:
            return
        mode = "DEMO · SYNTHETIC" if self.demo else f"FPGA · {self.backend.port_name} · {self.backend.baud} 8N1"
        if not self.connected:
            state = "DISCONNECTED · no live data"
        elif self.backend.running:
            state = "RUNNING · snapshot STALE · use Pause / dump"
        elif self.backend.running is None:
            state = "CONNECTED · execution state unknown · request Pause / dump"
        elif self.stale:
            state = "PAUSED · snapshot STALE · refresh with Pause / dump"
        else:
            state = "PAUSED · coherent snapshot" if self.snapshot else "PAUSED · snapshot unavailable"
        if self.busy:
            state = "BUSY · transaction in progress; controls locked"
        if self.quitting:
            state = "CLOSING · waiting for transaction, then best-effort pause"
        self.query_one("#status", Static).update(f"{mode}\n{state}  |  Host STEP requests: {self.steps} (not total cycles)")
        self.query_one("#connect", Button).label = "Disconnect · F9" if self.connected else "Connect · F9"
        for name in ("connect", "step", "run", "snapshot", "reset", "upload", "initialize"):
            disabled = self.busy or self.quitting or (name != "connect" and not self.connected)
            if name in ("upload", "initialize") and not self.backend.allow_upload:
                disabled = True
            if name in ("step", "run", "upload", "initialize") and self.backend.running:
                disabled = True
            self.query_one(f"#{name}", Button).disabled = disabled
        note = ("Replacement resets twice and zero-fills IMEM tail, THEN applies initial values. Both actions require confirmation."
                if self.backend.allow_upload else
                 "FPGA writes BLOCKED: board validation pending. Rebuild bitstream; experimental CLI opt-in required.")
        self.query_one("#upload-note", Static).update(note)
        self.render_snapshot()

    def render_snapshot(self) -> None:
        snap = self.snapshot
        label = "STALE" if self.stale else "SNAPSHOT"
        values = ["PC —\nNo snapshot"] * 5
        if snap:
            values = [f"PC {pc:016X}" for pc in snap.pcs]
            values[0] += "\nInstruction: not exposed"
            values[1] += f"\nInstruction {snap.instruction:08X}"
            values[2] += f"\nA  {snap.operand_a:016X}\nB  {snap.operand_b:016X}\nrd x{snap.rd_ex}"
            values[3] += f"\nALU {snap.alu_mem:016X}\nrd x{snap.rd_mem}"
            values[4] += f"\nALU {snap.alu_wb:016X}\nrd x{snap.rd_wb}\nCommit enable: not exposed"
        for stage, value in zip(("IF", "ID", "EX", "MEM", "WB"), values):
            self.query_one(f"#{stage.lower()}", Static).update(Text(f"{stage} / {label}\n{value}"))
        inspector = "ADD INSPECTOR / ID\nNo snapshot. Connect, then Pause / dump."
        if snap:
            word = snap.instruction
            fields = decode(word)
            decoded = f"ADD x{fields[0]}, x{fields[1]}, x{fields[2]}" if fields else "Not ADD (unsupported/inert word)"
            inspector = (f"ADD INSPECTOR / ID · {label}\n{decoded}   raw 0x{word:08X}\n"
                         f"funct7  {word >> 25:07b}   rs2  {word >> 20 & 31:05b}   rs1  {word >> 15 & 31:05b}\n"
                         f"funct3  {word >> 12 & 7:03b}       rd   {word >> 7 & 31:05b}   opcode {word & 127:07b}\n"
                         "Only ID instruction is exported; rd alone does not prove register write.")
        self.query_one("#inspector", Static).update(Text(inspector))
        table = self.query_one("#registers", DataTable)
        for index in range(32):
            value = snap.registers[index] if snap else None
            changed = bool(snap and self.previous and value != self.previous.registers[index])
            decimal = value - (1 << 64) if value is not None and self.signed and value & (1 << 63) else value
            table.update_cell(str(index), "hex", Text(f"{value:016X}" if value is not None else "—",
                                                    style="bold #ffbd69" if changed else "#65e4eb"))
            table.update_cell(str(index), "dec", str(decimal) if decimal is not None else "—")
            table.update_cell(str(index), "delta", "*" if changed else "")

    def ready(self, connected: bool = True) -> bool:
        return not self.busy and not self.quitting and len(self.screen_stack) == 1 and (self.connected or not connected)

    def start(self, operation: str, words: list[int] | None = None, initial: dict[int, int] | None = None) -> None:
        if self.busy:
            return
        self.busy = True
        if operation in ("step", "run", "reset", "upload", "initialize"):
            self.stale = self.snapshot is not None
        self.render_state()
        self._transaction_task = asyncio.create_task(self.transact(operation, words, initial))

    async def transact(self, operation: str, words: list[int] | None, initial: dict[int, int] | None) -> None:
        try:
            if operation in ("disconnect", "quit"):
                await asyncio.to_thread(self.backend.close)
                self.connected = False
                self.snapshot = self.previous = None
            elif operation == "connect":
                await asyncio.to_thread(self.backend.connect)
                self.connected = True
                self.snapshot = self.previous = None
                self.steps = 0
                self.stale = False
            else:
                method = getattr(self.backend, operation)
                args = (words, initial) if operation == "upload" else (initial,) if operation == "initialize" else ()
                result = await asyncio.to_thread(method, *args)
                if isinstance(result, Snapshot):
                    self.previous, self.snapshot = self.snapshot, result
                    self.stale = False
                if operation == "step":
                    self.steps += 1
                if operation in ("reset", "upload", "initialize"):
                    self.steps = 0
                if operation == "run":
                    self.stale = True
            self.event_log(f"{operation.upper()} complete" + (" · no snapshot requested" if operation == "connect" else ""))
        except CommandRejected as error:
            self.stale = self.snapshot is not None
            self.event_log(f"REJECTED: {error}. Link synchronized; state may be partially initialized. Pause / dump to inspect.")
        except Exception as error:
            self.event_log(f"ERROR: {error}")
            # Never try to resynchronize by scanning or reusing a partial frame.
            try:
                await asyncio.to_thread(self.backend.close, False)
            except Exception:
                pass
            self.connected = False
            self.stale = True
            self.event_log("Disconnected; state/sync unknown. Board reset/reconnect may be needed; upload may be partial.")
        finally:
            self.busy = False
            self.render_state()
            if self._closing:
                return
            if operation == "quit":
                self.exit()
            elif self.quitting:
                self.start("quit")

    def action_connect(self) -> None:
        if self.ready(False):
            self.start("disconnect" if self.connected else "connect")

    def action_step(self) -> None:
        if self.ready() and not self.backend.running:
            self.start("step")

    def action_run(self) -> None:
        if self.ready() and not self.backend.running:
            self.start("run")

    def action_snapshot(self) -> None:
        if self.ready():
            self.start("snapshot")

    def action_reset(self) -> None:
        if self.ready():
            self.push_screen(Confirm("RESET CPU?\n\nRegisters, PC and pipeline latches will be destroyed.\nProgram memory is retained. Demo seeds are also cleared."),
                             lambda yes: self.start("reset") if yes else None)

    def preview(self):
        listing = self.query_one("#listing", DataTable)
        listing.clear()
        try:
            instructions = assemble(self.query_one("#editor", TextArea).text)
        except ValueError as error:
            self.event_log(f"ASSEMBLY ERROR: {error}; no writes sent.")
            return None
        for item in instructions:
            listing.add_row(str(item.line), f"{item.address:02X}", f"{item.word:08X}", item.text)
        self.event_log(f"ASSEMBLED {len(instructions)} ADD words · preview only, no writes")
        return [item.word for item in instructions]

    def action_assemble(self) -> None:
        if len(self.screen_stack) == 1:
            self.preview()

    def action_upload(self) -> None:
        if not self.ready() or self.backend.running:
            return
        if not self.backend.allow_upload:
            self.event_log("WRITES BLOCKED: board validation pending; --allow-hardware-upload is experimental.")
            return
        words = self.preview()
        if words is not None:
            initial = self.initial_values()
            if initial is None:
                return
            warning = "\nEXPERIMENTAL FPGA upload: RX simulation passed; board validation pending. ACK does not verify stored data." if not self.demo else ""
            self.push_screen(Confirm(f"REPLACE IMEM + INITIALIZE?\n\nUpload {len(words)} words, zero-fill {64 - len(words)} unused words.\nReset before AND after: registers, PC and latches destroyed.\nThen apply {len(initial)} chosen initial values; all others zero.\nNo automatic run. Partial upload cannot be rolled back." + warning),
                             lambda yes: self.start("upload", words, initial) if yes else None)

    def initial_values(self) -> dict[int, int] | None:
        try:
            return parse_initial_registers(self.query_one("#initial-values", TextArea).text)
        except ValueError as error:
            self.event_log(f"INITIAL VALUES ERROR: {error}; no commands sent.")
            return None

    def action_initialize(self) -> None:
        if not self.ready() or self.backend.running:
            return
        if not self.backend.allow_upload:
            self.event_log("WRITES BLOCKED: experimental --allow-hardware-upload required on rebuilt hardware.")
            return
        initial = self.initial_values()
        if initial is not None:
            self.push_screen(Confirm(f"RESET + INITIALIZE?\n\nClear PC, pipeline latches and ALL registers; retain IMEM.\nThen apply {len(initial)} chosen initial values; all others zero.\nNo automatic run. Existing execution progress is destroyed."),
                             lambda yes: self.start("initialize", initial=initial) if yes else None)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        name = event.button.id
        if name == "decimal":
            self.signed = not self.signed
            event.button.label = f"Decimal: {'signed' if self.signed else 'unsigned'} (toggle)"
            self.render_snapshot()
        elif name:
            action = getattr(self, f"action_{name}", None)
            if action:
                action()

    def action_quit(self) -> None:
        if isinstance(self.screen, Confirm):
            self.screen.dismiss(False)
            self.call_after_refresh(self.action_quit)
            return
        self.quitting = True
        if self.busy:
            self.render_state()
        else:
            self.start("quit")

    async def on_unmount(self) -> None:
        # Test harness/external shutdown also waits for in-flight to_thread work.
        self._closing = True
        if self._transaction_task is not None and not self._transaction_task.done():
            await asyncio.shield(self._transaction_task)
        if self.connected:
            try:
                await asyncio.to_thread(self.backend.close)
            except Exception:
                pass
