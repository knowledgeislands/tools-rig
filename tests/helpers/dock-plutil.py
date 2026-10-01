#!/usr/bin/env python3
"""Portable fixture-only implementation of the typed plutil calls Dock uses."""

import json
import os
import plistlib
import sys


def main():
    args = sys.argv[1:]
    if args and args[0] == "--fixture":
        spec = json.load(sys.stdin)
        fmt = plistlib.FMT_BINARY if "--binary" in args else plistlib.FMT_XML
        sys.stdout.buffer.write(plistlib.dumps(spec, fmt=fmt))
        return
    log = os.environ.get("DOCK_PLUTIL_LOG")
    if log:
        with open(log, "a", encoding="utf-8") as stream:
            stream.write(" ".join(args) + "\n")
    data = plistlib.loads(sys.stdin.buffer.read())
    if args == ["-convert", "xml1", "-o", "-", "-"]:
        sys.stdout.buffer.write(plistlib.dumps(data, fmt=plistlib.FMT_XML))
        return
    if len(args) != 9 or args[0] != "-extract" or args[2:4] != ["raw", "-expect"] or args[5:] != ["-n", "-o", "-", "-"]:
        raise ValueError("unexpected plutil invocation")
    value = data
    for part in args[1].split("."):
        value = value[int(part)] if isinstance(value, list) else value[part]
    expected = {"string": str, "integer": int, "array": list}[args[4]]
    if type(value) is not expected:
        raise ValueError("unexpected plist type")
    sys.stdout.write(str(len(value) if expected is list else value))


try:
    main()
except (ValueError, KeyError, IndexError, TypeError, plistlib.InvalidFileException):
    sys.exit(1)
