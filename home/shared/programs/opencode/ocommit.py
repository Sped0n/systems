#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import shutil
import signal
import subprocess
import sys
from collections import deque
from typing import NoReturn

CLEAR_LINE = "\x1b[2K"
HIDE_CURSOR = "\x1b[?25l"
SHOW_CURSOR = "\x1b[?25h"
YELLOW = "\x1b[33m"
RESET = "\x1b[0m"
DEFAULT_MAX_LINES = 15


class InlineRenderer:
    def __init__(self, max_lines: int) -> None:
        self._enabled = sys.stdout.isatty()
        self._max_lines = max_lines
        self._active = False

    def enter(self) -> None:
        if not self._enabled or self._active:
            return

        sys.stdout.write(HIDE_CURSOR)
        if self._max_lines > 1:
            sys.stdout.write("\n" * (self._max_lines - 1))
        sys.stdout.flush()
        self._active = True

    @property
    def enabled(self) -> bool:
        return self._enabled

    @property
    def max_lines(self) -> int:
        return self._max_lines

    def _move_to_top(self) -> None:
        sys.stdout.write("\r")
        if self._max_lines > 1:
            sys.stdout.write(f"\x1b[{self._max_lines - 1}A")

    def _terminal_width(self) -> int:
        return max(shutil.get_terminal_size(fallback=(80, 24)).columns, 1)

    def _format_line(self, line: str) -> str:
        width = self._terminal_width()
        if len(line) <= width:
            return line
        if width <= 3:
            return line[:width]
        return f"{line[: width - 3]}..."

    def _clear_reserved_region(self) -> None:
        self._move_to_top()
        for index in range(self._max_lines):
            sys.stdout.write(CLEAR_LINE)
            if index < self._max_lines - 1:
                sys.stdout.write("\n")
        self._move_to_top()

    def render(self, lines: deque[str]) -> None:
        if not self._active:
            return

        visible_lines = list(lines)
        padded_lines = visible_lines + [""] * (self._max_lines - len(visible_lines))

        self._clear_reserved_region()
        for index, line in enumerate(padded_lines):
            sys.stdout.write(CLEAR_LINE)
            sys.stdout.write(YELLOW)
            sys.stdout.write(self._format_line(line))
            sys.stdout.write(RESET)
            if index < self._max_lines - 1:
                sys.stdout.write("\n")
        sys.stdout.flush()

    def finish(self, *, preserve_output: bool) -> None:
        if not self._active:
            return

        if not preserve_output:
            self._clear_reserved_region()
        else:
            sys.stdout.write("\n\n")

        sys.stdout.write(SHOW_CURSOR)
        sys.stdout.flush()
        self._active = False


renderer = InlineRenderer(DEFAULT_MAX_LINES)
child_process: subprocess.Popen[str] | None = None


def build_prompt(argv: list[str]) -> str:
    prompt = "STAGED CHANGE ONLY"
    if not argv:
        return prompt
    return f"{prompt}\nHint: {' '.join(argv)}"


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("--max-lines must be greater than 0")
    return parsed


def parse_args(argv: list[str]) -> tuple[int, list[str]]:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--max-lines", type=positive_int, default=DEFAULT_MAX_LINES)
    parser.add_argument("hint", nargs="*")
    args = parser.parse_args(argv)
    return args.max_lines, args.hint


def exit_with_signal(signum: int) -> NoReturn:
    raise SystemExit(128 + signum)


def handle_signal(signum: int, _frame: object) -> None:
    global child_process

    process = child_process
    if process is not None and process.poll() is None:
        process.send_signal(signum)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()

    renderer.finish(preserve_output=True)
    exit_with_signal(signum)


def run_oc(prompt: str) -> int:
    global child_process

    recent_lines: deque[str] = deque(maxlen=renderer.max_lines)
    child_process = subprocess.Popen(
        ["oc-ephemeral-run", "--agent", "commit-message-writer", prompt],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    stdout = child_process.stdout
    if stdout is None:
        raise RuntimeError("oc-ephemeral-run stdout is unavailable")

    renderer.enter()
    if renderer.enabled:
        renderer.render(recent_lines)

    for line in stdout:
        if renderer.enabled:
            recent_lines.append(line.rstrip("\r\n"))
            renderer.render(recent_lines)
            continue

        sys.stdout.write(line)
        sys.stdout.flush()

    return_code = child_process.wait()
    child_process = None
    return return_code


def run_git_commit() -> NoReturn:
    result = subprocess.run(
        ["git", "rev-parse", "--git-path", "COMMIT_EDITMSG"],
        check=True,
        capture_output=True,
        text=True,
    )
    commit_message_path = result.stdout.strip()
    try:
        os.execvp(
            "git",
            ["git", "commit", "-s", "-e", "-F", commit_message_path],
        )
    except OSError as exc:
        raise RuntimeError("failed to exec git commit") from exc


def main(argv: list[str]) -> int:
    global renderer

    max_lines, hint_args = parse_args(argv)
    renderer = InlineRenderer(max_lines)
    prompt = build_prompt(hint_args)

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    return_code = 1
    try:
        return_code = run_oc(prompt)
    finally:
        renderer.finish(preserve_output=True)

    if return_code != 0:
        return return_code

    run_git_commit()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
