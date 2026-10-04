#!/usr/bin/env python3
"""Run an isolated test command with terminal stderr and separately piped stdout."""

import argparse
import errno
import fcntl
import json
import os
import pty
import re
import selectors
import signal
import struct
import subprocess
import termios
import time
from pathlib import Path


class Screen:
    """Small fixture-only VT model: scrolling, reflow, CUP, EL and cursor save."""

    def __init__(self, rows, columns):
        self.rows, self.columns = rows, columns
        self.cells = [[" "] * columns for _ in range(rows)]
        self.history = []
        self.row = self.column = 0
        self.top, self.bottom = 0, rows - 1
        self.saved = (0, 0)

    def resize(self, rows, columns):
        # Reflow printable rows, retaining scrolled text for sentinel checks.
        lines = []
        for old in self.cells:
            text = "".join(old).rstrip()
            lines.extend([text[i:i + columns] for i in range(0, len(text), columns)] or [""])
        self.history.extend(lines[:-rows])
        lines = lines[-rows:]
        self.cells = [[" "] * columns for _ in range(rows - len(lines))]
        self.cells.extend([list(line.ljust(columns)) for line in lines])
        self.row = max(0, min(rows - 1, self.row + rows - self.rows))
        self.column = min(columns - 1, self.column)
        self.rows, self.columns = rows, columns
        self.top, self.bottom = 0, rows - 1

    def newline(self):
        if self.row == self.bottom:
            self.history.append("".join(self.cells.pop(self.top)).rstrip())
            self.cells.insert(self.bottom, [" "] * self.columns)
        else:
            self.row = min(self.rows - 1, self.row + 1)

    def feed(self, data):
        index = 0
        while index < len(data):
            if data[index:index + 2] in (b"\x1b7", b"\x1b8"):
                if data[index + 1] == ord("7"):
                    self.saved = self.row, self.column
                else:
                    self.row, self.column = self.saved
                    self.row = min(self.row, self.rows - 1)
                    self.column = min(self.column, self.columns - 1)
                index += 2
                continue
            match = re.match(rb"\x1b\[([0-9;?]*)([A-Za-z])", data[index:])
            if match:
                params = match.group(1).decode()
                numbers = [int(part or 0) for part in params.split(";")] if "?" not in params else []
                action = match.group(2)
                if action == b"r":
                    self.top = (numbers[0] or 1) - 1
                    self.bottom = (numbers[1] if len(numbers) > 1 else self.rows) - 1
                    self.row = self.column = 0
                elif action in (b"H", b"f"):
                    self.row = min(self.rows - 1, (numbers[0] or 1) - 1)
                    self.column = min(self.columns - 1, ((numbers[1] if len(numbers) > 1 else 1) or 1) - 1)
                elif action == b"K":
                    start = 0 if numbers[0] == 2 else self.column
                    self.cells[self.row][start:] = [" "] * (self.columns - start)
                index += match.end()
                continue
            character = data[index]
            if character == 13:
                self.column = 0
            elif character == 10:
                self.newline()
            elif 32 <= character < 127:
                if self.column == self.columns:
                    self.column = 0
                    self.newline()
                self.cells[self.row][self.column] = chr(character)
                self.column += 1
            index += 1

    def text(self):
        return "\n".join(self.history + ["".join(line).rstrip() for line in self.cells])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--rows", type=int, default=24)
    parser.add_argument("--columns", type=int, default=100)
    parser.add_argument("--stdout", required=True)
    parser.add_argument("--stderr", required=True)
    parser.add_argument("--screen")
    parser.add_argument("--reply", help="reply once to a NATIVE prompt on terminal stdin")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    master, slave = pty.openpty()

    def resize(rows, columns):
        fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))

    resize(args.rows, args.columns)

    def controlling_terminal():
        os.setsid()
        fcntl.ioctl(slave, termios.TIOCSCTTY, 0)

    process = subprocess.Popen(command, stdin=slave if args.reply is not None else subprocess.DEVNULL, stdout=subprocess.PIPE,
                               stderr=slave, preexec_fn=controlling_terminal)
    os.close(slave)
    selector = selectors.DefaultSelector()
    selector.register(master, selectors.EVENT_READ, "stderr")
    selector.register(process.stdout, selectors.EVENT_READ, "stdout")
    streams = {"stdout": bytearray(), "stderr": bytearray()}
    geometry_events = []
    handled = set()
    replied = False
    deadline = time.monotonic() + 20
    try:
        while selector.get_map():
            if time.monotonic() > deadline:
                raise TimeoutError("isolated terminal fixture exceeded 20 seconds")
            for key, _ in selector.select(0.1):
                try:
                    chunk = os.read(key.fd, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    chunk = b""
                if not chunk:
                    selector.unregister(key.fileobj)
                    continue
                streams[key.data].extend(chunk)
                if args.reply is not None and not replied and b"NATIVE prompt: " in streams["stderr"]:
                    os.write(master, args.reply.encode() + b"\n")
                    replied = True
                if key.data == "stdout":
                    for match in re.finditer(rb"RESIZE:(\d+):(\d+)\n|SIGNAL:(INT|TERM|HUP)\n", streams["stdout"]):
                        if match.start() in handled:
                            continue
                        handled.add(match.start())
                        if match.group(1):
                            # Drain pre-resize writes first: fixtures pause after
                            # the handshake, so each geometry has a byte boundary.
                            old_flags = fcntl.fcntl(master, fcntl.F_GETFL)
                            fcntl.fcntl(master, fcntl.F_SETFL, old_flags | os.O_NONBLOCK)
                            try:
                                while True:
                                    pending = os.read(master, 65536)
                                    if not pending:
                                        break
                                    streams["stderr"].extend(pending)
                            except OSError as error:
                                if error.errno not in (errno.EAGAIN, errno.EIO):
                                    raise
                            finally:
                                fcntl.fcntl(master, fcntl.F_SETFL, old_flags)
                            geometry_events.append((len(streams["stderr"]), int(match.group(1)), int(match.group(2))))
                            resize(int(match.group(1)), int(match.group(2)))
                            os.killpg(process.pid, signal.SIGWINCH)
                        else:
                            os.killpg(process.pid, getattr(signal, "SIG" + match.group(3).decode()))
        status = process.wait(timeout=2)
    finally:
        if process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        selector.close()
        process.stdout.close()
        os.close(master)
    for name in streams:
        Path(getattr(args, name)).write_bytes(streams[name])
    margins = list(re.finditer(rb"\x1b\[(?:(\d+);(\d+))?r", streams["stderr"]))
    last = margins[-1] if margins else None
    native = streams["stderr"].find(b"NATIVE")
    before_native = [match for match in margins if match.start() < native]
    frame_widths = [len(match.group(1)) for match in re.finditer(
        rb"\x1b\[\d+;1H\x1b\[2K([^\x1b]*)", streams["stderr"])]
    screen = Screen(args.rows, args.columns)
    offset = 0
    resize_erase_safe = True
    for boundary, rows, columns in geometry_events:
        next_region = re.search(rb"\x1b\[1;\d+r", streams["stderr"][boundary:])
        until = boundary + next_region.start() if next_region else len(streams["stderr"])
        resize_erase_safe = resize_erase_safe and b"\x1b[2K" not in streams["stderr"][boundary:until]
        screen.feed(streams["stderr"][offset:boundary])
        screen.resize(rows, columns)
        offset = boundary
    screen.feed(streams["stderr"][offset:])
    if args.screen:
        Path(args.screen).write_text(screen.text())
    print(json.dumps({"status": status,
                      "restored": last is None or last.group(1) is None,
                      "regions": len([match for match in margins if match.group(1)]),
                      "native_full": native < 0 or not before_native or before_native[-1].group(1) is None,
                      "max_frame_width": max(frame_widths, default=0),
                      "resize_erase_safe": resize_erase_safe,
                      "diagnostic_survived": "DIAGNOSTIC-SENTINEL" in screen.text()}))


if __name__ == "__main__":
    main()
