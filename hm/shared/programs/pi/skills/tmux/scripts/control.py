#!/usr/bin/env python3
"""Operate native tmux panes on explicit Pi-owned sockets."""

import argparse
import json
import os
import re
import shlex
import signal
import stat
import subprocess
import sys
import time
import uuid
from pathlib import Path


class ControlError(Exception):
    def __init__(self, kind, message, status=1):
        super().__init__(message)
        self.kind = kind
        self.status = status


def duration(value):
    match = re.fullmatch(r"(\d+(?:\.\d+)?)(ms|s|m|h)", value)
    if not match:
        raise argparse.ArgumentTypeError("use a duration such as 500ms, 10s, or 2m")
    seconds = float(match[1]) * {"ms": 0.001, "s": 1, "m": 60, "h": 3600}[match[2]]
    if not 0 < seconds <= 2_147_483:
        raise argparse.ArgumentTypeError("duration is outside the supported range")
    return seconds


def positive_integer(value):
    try:
        number = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("expected an integer") from error
    if number < 1:
        raise argparse.ArgumentTypeError("expected a positive integer")
    return number


def native_name(value):
    if not value or any(character in value for character in "\t\r\n:"):
        raise argparse.ArgumentTypeError(
            "names must be nonempty and contain no colon or control characters"
        )
    return value


def socket_directory():
    # Darwin's TMPDIR can exceed Unix socket path limits. Keep the default short.
    root = Path(os.environ.get("PI_TMUX_SOCKET_DIR", f"/tmp/pi-tmux-{os.getuid()}"))
    root = root.expanduser().absolute()
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = root.lstat()
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.getuid()
        or stat.S_IMODE(info.st_mode) != 0o700
    ):
        raise ControlError(
            "unsafe_directory", f"expected an owned mode-0700 directory: {root}"
        )
    return root


def selected_socket(root, name):
    if name is None:
        session_id = os.environ.get("PI_SESSION_ID")
        if not session_id:
            raise ControlError(
                "usage", "supply --socket NAME when PI_SESSION_ID is unavailable", 2
            )
        name = "pi-" + session_id
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", name):
        raise ControlError(
            "usage", "socket names use 1–64 letters, digits, underscores, or hyphens", 2
        )
    path = root / (name + ".sock")
    if len(os.fsencode(path)) > 103:
        raise ControlError(
            "usage", "socket path is too long; use a shorter PI_TMUX_SOCKET_DIR", 2
        )
    try:
        info = path.lstat()
    except FileNotFoundError:
        return path
    if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
        raise ControlError(
            "unsafe_socket",
            "refusing a socket symlink, non-socket file, or another user's socket",
        )
    return path


PANE_FIELDS = {
    "sessionId": "#{session_id}",
    "session": "#{session_name}",
    "windowId": "#{window_id}",
    "window": "#{window_name}",
    "pane": "#{pane_id}",
    "index": "#{pane_index}",
    "dead": "#{pane_dead}",
    "status": "#{pane_dead_status}",
    "signal": "#{pane_dead_signal}",
    "cwd": "#{?pane_current_path,#{pane_current_path},#{pane_start_path}}",
    "command": "#{pane_current_command}",
    "serverPid": "#{pid}",
    "startCommand": "#{@pi_command_json}",
}
PANE_FORMAT = "\t".join(PANE_FIELDS.values())


def parse_pane(row):
    values = row.split("\t")
    if len(values) != len(PANE_FIELDS):
        raise ControlError(
            "invalid_response", "tmux returned an invalid pane description", 3
        )
    pane = dict(zip(PANE_FIELDS, values, strict=True))
    if (
        not re.fullmatch(r"%\d+", pane["pane"])
        or pane["dead"] not in ("0", "1")
        or not pane["serverPid"].isdigit()
    ):
        raise ControlError("unavailable", "pane is unavailable", 3)
    pane["state"] = "exited" if pane.pop("dead") == "1" else "running"
    pane["serverPid"] = int(pane["serverPid"])
    pane["index"] = int(pane["index"])
    status = pane.pop("status")
    pane["exitCode"] = int(status) if status else None
    encoded = pane.pop("startCommand")
    if encoded:
        try:
            command = json.loads(encoded)
        except ValueError as error:
            raise ControlError(
                "invalid_response", "invalid pane command annotation", 3
            ) from error
        if not isinstance(command, str):
            raise ControlError("invalid_response", "invalid pane command annotation", 3)
        pane["startCommand"] = command
        if pane["state"] == "exited":
            pane["command"] = command
    return pane


class Tmux:
    """Own socket selection, environment isolation, framing, and request deadlines."""

    def __init__(self, path, timeout=5):
        self.path = path
        self.timeout = timeout
        self.config = os.environ.get("PI_TMUX_CONFIG", "/dev/null")

    def command(self, *arguments, input_data=None, timeout=None):
        env = os.environ.copy()
        env.pop("TMUX", None)
        env.pop("TMUX_PANE", None)
        try:
            return subprocess.run(
                ["tmux", "-f", self.config, "-S", str(self.path), *arguments],
                input=input_data,
                capture_output=True,
                env=env,
                timeout=self.timeout if timeout is None else timeout,
                check=False,
            )
        except FileNotFoundError as error:
            raise ControlError("tmux_missing", "tmux is not installed", 3) from error
        except subprocess.TimeoutExpired as error:
            raise ControlError(
                "request_timeout", "tmux did not respond", 124
            ) from error

    def checked(self, *arguments, **options):
        result = self.command(*arguments, **options)
        if result.returncode:
            message = (
                result.stderr.decode(errors="replace").strip() or "tmux command failed"
            )
            unavailable = any(
                text in message
                for text in (
                    "no server running",
                    "error connecting",
                    "can't find",
                    "more than one",
                    "failed to connect",
                )
            )
            raise ControlError(
                "unavailable" if unavailable else "tmux_error",
                message,
                3 if unavailable else 4,
            )
        return result.stdout.decode(errors="replace")

    def pane(self, target, timeout=None):
        if not re.fullmatch(r"%\d+", target) and (
            ":" not in target or "." not in target
        ):
            raise ControlError(
                "usage", "target a pane ID (%3) or explicit session:window.pane", 2
            )
        text = self.checked(
            "display-message", "-p", "-t", target, PANE_FORMAT, timeout=timeout
        )
        return parse_pane(text.rstrip("\n"))

    def panes(self, session=None):
        arguments = (
            ["list-panes", "-s", "-t", "=" + session]
            if session
            else ["list-panes", "-a"]
        )
        return [
            parse_pane(row)
            for row in self.checked(*arguments, "-F", PANE_FORMAT).splitlines()
        ]


def sockets(root, timeout):
    found = []
    for file in sorted(root.glob("*.sock")):
        if (
            not stat.S_ISSOCK(file.lstat().st_mode)
            or file.lstat().st_uid != os.getuid()
        ):
            continue
        client = Tmux(selected_socket(root, file.stem), timeout)
        try:
            panes = client.panes()
        except ControlError as error:
            if error.kind == "unavailable":
                continue
            found.append(
                {
                    "socket": file.stem,
                    "socketPath": str(file),
                    "state": "unavailable",
                    "error": error.kind,
                }
            )
        else:
            found.append(
                {
                    "socket": file.stem,
                    "socketPath": str(file),
                    "state": "running",
                    "panes": len(panes),
                    "serverPid": panes[0]["serverPid"] if panes else None,
                }
            )
    return found


def launch(client, args):
    command = args.command
    if not command:
        command = shlex.split(
            os.environ.get("PI_TMUX_SHELL", "bash --noprofile --norc")
        )
    if not command:
        raise ControlError("usage", "PI_TMUX_SHELL must not be empty", 2)
    cwd = str(Path(args.cwd).resolve(strict=True))
    if not Path(cwd).is_dir():
        raise ControlError("usage", "working directory must be a directory", 2)
    anchor = client.pane(args.target) if args.operation == "split" else None
    bootstrap = "pi-bootstrap-" + uuid.uuid4().hex
    started = False
    try:
        client.checked("new-session", "-d", "-s", bootstrap, "/bin/sleep", "2147483647")
        client.checked("set-option", "-g", "remain-on-exit", "on")
        client.checked("set-option", "-g", "remain-on-exit-format", "")
        # tmux's argv parser treats a standalone semicolon as a command separator.
        # A JSON exec launcher preserves every command argument without shell evaluation.
        launcher = "import json, os, sys; argv=json.loads(sys.argv[1]); os.execvpe(argv[0], argv, os.environ)"
        child = [sys.executable, "-c", launcher, json.dumps(command)]
        options = [
            "-d",
            "-P",
            "-F",
            "#{pane_id}",
            "-c",
            cwd,
            "-e",
            "PATH=" + os.environ.get("PATH", os.defpath),
        ]
        if anchor:
            client.checked(
                "set-option", "-w", "-t", anchor["windowId"], "remain-on-exit", "on"
            )
            direction = ["-h"] if args.direction in ("right", "left") else ["-v"]
            if args.direction in ("left", "above"):
                direction.append("-b")
            pane_id = client.checked(
                "split-window", *options, "-t", anchor["pane"], *direction, *child
            ).strip()
        else:
            name = ["-n", args.window] if args.window else []
            exists = (
                client.command("has-session", "-t", "=" + args.session).returncode == 0
            )
            if exists:
                pane_id = client.checked(
                    "new-window",
                    *options,
                    "-t",
                    "=" + args.session + ":",
                    *name,
                    *child,
                ).strip()
            else:
                result = client.command(
                    "new-session", *options, "-s", args.session, *name, *child
                )
                if result.returncode and b"duplicate session:" in result.stderr:
                    pane_id = client.checked(
                        "new-window",
                        *options,
                        "-t",
                        "=" + args.session + ":",
                        *name,
                        *child,
                    ).strip()
                elif result.returncode:
                    raise ControlError(
                        "tmux_error", result.stderr.decode(errors="replace").strip(), 4
                    )
                else:
                    pane_id = result.stdout.decode().strip()
        started = True
        client.checked(
            "set-option",
            "-p",
            "-t",
            pane_id,
            "@pi_command_json",
            json.dumps(shlex.join(command)),
        )
        return client.pane(pane_id)
    except ControlError as error:
        if started or error.kind == "request_timeout":
            error.args = (
                str(error)
                + f"; creation may have started. Recover with --socket {client.path.stem} list; do not blindly rerun",
            )
        raise
    finally:
        client.command("kill-session", "-t", "=" + bootstrap)


def capture(client, pane, lines, all_history=False, ansi=False, timeout=None):
    arguments = [
        "capture-pane",
        "-p",
        "-J",
        "-t",
        pane["pane"],
        "-S",
        "-" if all_history else "-" + str(lines),
    ]
    if ansi:
        arguments.append("-e")
    rendered = client.checked(*arguments, timeout=timeout).splitlines()
    while rendered and not rendered[-1].strip():
        rendered.pop()
    truncated = not all_history and len(rendered) > lines
    if not all_history:
        rendered = rendered[-lines:]
    return {"pane": pane["pane"], "text": "\n".join(rendered), "truncated": truncated}


def send(client, pane, args):
    if pane["state"] == "exited":
        raise ControlError("pane_exited", "cannot send input to an exited pane", 3)
    text = sys.stdin.buffer.read() if args.stdin else args.text.encode()
    if text:
        # A buffer carries literal input, including semicolons and escape bytes, as data.
        buffer = "pi-" + uuid.uuid4().hex
        client.checked("load-buffer", "-b", buffer, "-", input_data=text)
        try:
            client.checked("paste-buffer", "-d", "-b", buffer, "-t", pane["pane"])
        finally:
            client.command("delete-buffer", "-b", buffer)
    if args.enter:
        client.checked("send-keys", "-t", pane["pane"], "Enter")
    return {"pane": pane["pane"], "accepted": True}


def send_keys(client, pane, keys):
    if pane["state"] == "exited":
        raise ControlError("pane_exited", "cannot send keys to an exited pane", 3)
    escaped = [r"\;" if key == ";" else key for key in keys]
    client.checked("send-keys", "-t", pane["pane"], "--", *escaped)
    return {"pane": pane["pane"], "accepted": True}


def validate_regex(pattern):
    if not pattern:
        raise argparse.ArgumentTypeError("regex must not be empty")
    result = subprocess.run(
        ["grep", "-E", "--", pattern], input=b"", capture_output=True, check=False
    )
    if result.returncode not in (0, 1):
        raise argparse.ArgumentTypeError(result.stderr.decode(errors="replace").strip())
    return pattern


def wait(client, pane, args):
    deadline = time.monotonic() + args.wait_for if args.wait_for is not None else None
    identity = (client.path.stat().st_ino, pane["serverPid"]) if pane else None

    def request_timeout():
        remaining = (
            deadline - time.monotonic() if deadline is not None else client.timeout
        )
        if remaining <= 0:
            raise ControlError(
                "wait_timeout", "wait deadline expired; process was not cancelled", 124
            )
        return min(client.timeout, remaining)

    while True:
        try:
            current = client.pane(
                pane["pane"] if pane else args.target, timeout=request_timeout()
            )
            if identity is None:
                identity = (client.path.stat().st_ino, current["serverPid"])
                pane = current
            if (client.path.stat().st_ino, current["serverPid"]) != identity:
                raise ControlError(
                    "server_replaced", "server was replaced; rediscover targets", 3
                )
            if args.text is not None or args.regex is not None:
                text = capture(client, current, args.lines, timeout=request_timeout())[
                    "text"
                ]
                if args.regex is not None:
                    match = subprocess.run(
                        ["grep", "-E", "--", args.regex],
                        input=text.encode(),
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.PIPE,
                        timeout=request_timeout(),
                        check=False,
                    )
                    if match.returncode not in (0, 1):
                        raise ControlError(
                            "regex_error",
                            match.stderr.decode(errors="replace").strip(),
                            2,
                        )
                    matched = match.returncode == 0
                else:
                    matched = args.text in text
                if matched:
                    return {"pane": current["pane"], "kind": "ready"}, 0
                if current["state"] == "exited":
                    raise ControlError(
                        "text_not_found", "pane exited before requested output appeared"
                    )
            elif current["state"] == "exited":
                status = current["exitCode"]
                if status is None and current["signal"]:
                    try:
                        number = (
                            int(current["signal"])
                            if current["signal"].isdigit()
                            else signal.Signals[
                                "SIG" + current["signal"].upper().removeprefix("SIG")
                            ].value
                        )
                    except KeyError as error:
                        raise ControlError(
                            "unknown_exit", "tmux returned an unknown exit signal"
                        ) from error
                    status = 128 + number
                if status is None:
                    raise ControlError(
                        "unknown_exit", "tmux did not retain the process exit status"
                    )
                return {
                    "pane": current["pane"],
                    "kind": "exited",
                    "exitCode": status % 256,
                }, status % 256
        except (ControlError, subprocess.TimeoutExpired) as error:
            if (
                deadline is not None
                and time.monotonic() >= deadline
                and (
                    isinstance(error, subprocess.TimeoutExpired)
                    or error.kind == "request_timeout"
                )
            ):
                raise ControlError(
                    "wait_timeout",
                    "wait deadline expired; process was not cancelled",
                    124,
                ) from error
            raise
        time.sleep(min(args.interval, request_timeout()))


def pane_info(client, pane):
    command = [
        "env",
        "-u",
        "TMUX",
        "-u",
        "TMUX_PANE",
        "tmux",
        "-f",
        client.config,
        "-S",
        str(client.path),
        "attach-session",
        "-t",
        pane["sessionId"],
        ";",
        "select-window",
        "-t",
        pane["windowId"],
        ";",
        "select-pane",
        "-t",
        pane["pane"],
    ]
    return {
        **pane,
        "socket": client.path.stem,
        "socketPath": str(client.path),
        "attachCommand": shlex.join(command),
    }


def parse_args():
    options = argparse.ArgumentParser(
        add_help=False, argument_default=argparse.SUPPRESS
    )
    options.add_argument("--socket", help="Pi-owned socket name, not a path")
    options.add_argument(
        "--timeout", type=duration, help="per-request timeout, default 5s"
    )
    options.add_argument("--json", action="store_true")
    parser = argparse.ArgumentParser(description=__doc__, parents=[options])
    subcommands = parser.add_subparsers(dest="operation", required=True)
    for name in ("sockets", "list"):
        sub = subcommands.add_parser(name, parents=[options])
        if name == "list":
            sub.add_argument("--session", type=native_name)
    for name in ("run", "split"):
        sub = subcommands.add_parser(name, parents=[options])
        if name == "split":
            sub.add_argument("target")
            sub.add_argument(
                "--direction",
                choices=("right", "left", "above", "below"),
                default="below",
            )
        else:
            sub.add_argument("--session", type=native_name, default="main")
            sub.add_argument("--window", type=native_name)
        sub.add_argument("--cwd", default=os.getcwd())
        sub.add_argument("--wait", action="store_true")
        sub.add_argument("--for", dest="wait_for", type=duration)
        sub.description = (
            "Append -- COMMAND...; omit the command for a clean Bash shell."
        )
    for name in ("capture", "send", "send-key", "wait", "info", "close"):
        sub = subcommands.add_parser(name, parents=[options])
        sub.add_argument("target")
        match name:
            case "capture":
                scope = sub.add_mutually_exclusive_group()
                scope.add_argument("--lines", type=positive_integer)
                scope.add_argument("--all", action="store_true")
                sub.add_argument("--ansi", action="store_true")
            case "send":
                sub.add_argument("text", nargs="?")
                sub.add_argument("--stdin", action="store_true")
                sub.add_argument("--enter", action="store_true")
            case "send-key":
                sub.add_argument("keys", nargs="+")
            case "wait":
                sub.add_argument("--for", dest="wait_for", type=duration)
                sub.add_argument("--interval", type=duration, default=0.5)
                sub.add_argument("--lines", type=positive_integer, default=1000)
                mode = sub.add_mutually_exclusive_group()
                mode.add_argument("--text")
                mode.add_argument("--regex", type=validate_regex)
            case "close":
                sub.add_argument("--force", action="store_true")
    tokens = sys.argv[1:]
    separator = tokens.index("--") if "--" in tokens else len(tokens)
    _, remaining = options.parse_known_args(tokens[:separator])
    command = []
    if remaining and remaining[0] in ("run", "split"):
        tokens, command = tokens[:separator], tokens[separator + 1 :]
    args = parser.parse_args(
        tokens, namespace=argparse.Namespace(socket=None, timeout=5, json=False)
    )
    if args.operation in ("run", "split"):
        args.command = command
    if args.operation == "send" and (args.stdin == (args.text is not None)):
        parser.error("supply one text argument or --stdin, not both")
    if args.operation == "wait" and args.text == "":
        parser.error("--text must not be empty")
    if (
        args.operation in ("run", "split")
        and args.wait_for is not None
        and not args.wait
    ):
        parser.error("--for requires --wait")
    return args


def main():
    args = parse_args()
    creation_printed = False
    try:
        root = socket_directory()
        status = 0
        if args.operation != "sockets":
            client = Tmux(selected_socket(root, args.socket), args.timeout)
        match args.operation:
            case "sockets":
                result = sockets(root, args.timeout)
            case "list":
                result = client.panes(args.session)
            case "run" | "split":
                pane = launch(client, args)
                result = pane_info(client, pane)
                print(json.dumps(result) if args.json else pane["pane"], flush=True)
                creation_printed = True
                if args.wait:
                    args.text = args.regex = None
                    args.interval, args.lines = 0.5, 1000
                    _, status = wait(client, pane, args)
                return status
            case "wait":
                result, status = wait(client, None, args)
            case "capture":
                result = capture(
                    client,
                    client.pane(args.target),
                    args.lines or 200,
                    args.all,
                    args.ansi,
                )
            case "send":
                result = send(client, client.pane(args.target), args)
            case "send-key":
                result = send_keys(client, client.pane(args.target), args.keys)
            case "info":
                result = pane_info(client, client.pane(args.target))
            case "close":
                pane = client.pane(args.target)
                if pane["state"] == "running" and not args.force:
                    raise ControlError(
                        "pane_running",
                        "pane is running; use close --force to close its terminal",
                    )
                client.checked("kill-pane", "-t", pane["pane"])
                result = {"pane": pane["pane"], "closed": True}
        if args.json:
            print(json.dumps(result))
            return status
        match args.operation:
            case "capture":
                print(result["text"])
            case "info":
                print(result["attachCommand"])
            case "sockets":
                print("SOCKET\tSTATE\tPATH")
                for item in result:
                    print(f"{item['socket']}\t{item['state']}\t{item['socketPath']}")
            case "list":
                print("PANE\tTARGET\tSTATE\tCOMMAND\tCWD")
                for item in result:
                    print(
                        f"{item['pane']}\t{item['session']}:{item['window']}.{item['index']}\t{item['state']}\t{item.get('startCommand', item['command'])}\t{item['cwd']}"
                    )
        return status
    except KeyboardInterrupt:
        error = {
            "kind": "interrupted",
            "message": "interrupted; waiting does not cancel the process",
        }
        if args.json:
            print(
                json.dumps({"error": error}),
                file=sys.stderr if creation_printed else sys.stdout,
            )
        else:
            print("control.py: " + error["message"], file=sys.stderr)
        return 130
    except (ControlError, OSError, subprocess.TimeoutExpired) as error:
        kind = error.kind if isinstance(error, ControlError) else "io_error"
        if args.json:
            print(
                json.dumps({"error": {"kind": kind, "message": str(error)}}),
                file=sys.stderr if creation_printed else sys.stdout,
            )
        else:
            print(f"control.py: {error}", file=sys.stderr)
        return error.status if isinstance(error, ControlError) else 1


if __name__ == "__main__":
    sys.exit(main())
