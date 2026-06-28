import errno
import fcntl
import os
import pty
import shlex
import select
import signal
import subprocess
import sys
import termios


USAGE = """Usage:
  nixos-deploy <flake> <target-host>
  nixos-deploy <flake> <build-host> <target-host>

Notes:
  - Remaining nixos-rebuild arguments are fixed by this wrapper.
  - Provide sudo password via stdin if you want non-interactive execution.
"""


def build_command(args: list[str]) -> list[str]:
    if len(args) == 2:
        flake, target_host = args
        build_host = None
    elif len(args) == 3:
        flake, build_host, target_host = args
    else:
        sys.stderr.write(USAGE)
        raise SystemExit(1)

    command = ["nixos-rebuild", "switch", "--flake", flake]
    if build_host:
        command.extend(["--build-host", build_host])
    command.extend(
        [
            "--target-host",
            target_host,
            "--sudo",
            "--ask-sudo-password",
            "--use-substitutes",
            "--no-reexec",
        ]
    )
    return command


def run_command(command: list[str]) -> int:
    print(f"Running: {shlex.join(command)}", flush=True)

    if sys.stdin.isatty():
        os.execvp(command[0], command)

    return run_with_piped_password(command)


def run_with_piped_password(command: list[str]) -> int:
    password = sys.stdin.buffer.readline()
    if not password:
        sys.stderr.write("Error: expected sudo password on stdin.\n")
        return 1

    master_fd, slave_fd = pty.openpty()

    def child_setup():
        os.setsid()
        if hasattr(termios, "TIOCSCTTY"):
            fcntl.ioctl(slave_fd, termios.TIOCSCTTY, 0)

    proc = subprocess.Popen(
        command,
        stdin=slave_fd,
        close_fds=True,
        preexec_fn=child_setup,
    )
    os.close(slave_fd)
    signal.signal(signal.SIGINT, lambda sig, _frame: os.killpg(proc.pid, sig))
    signal.signal(signal.SIGTERM, lambda sig, _frame: os.killpg(proc.pid, sig))

    sent_password = False
    output = b""

    while True:
        ready, _, _ = select.select([master_fd], [], [], 0.1)
        if master_fd in ready:
            try:
                data = os.read(master_fd, 4096)
            except OSError as err:
                if err.errno != errno.EIO:
                    raise
                data = b""
            if not data:
                break

            if not sent_password:
                output = (output + data)[-4096:]
                if b"password" in output.lower():
                    os.write(sys.stdout.fileno(), output)
                    os.write(master_fd, password)
                    os.write(sys.stdout.fileno(), b"\n")
                    sent_password = True
        elif proc.poll() is not None:
            break

    os.close(master_fd)
    return proc.wait()


def main() -> int:
    return run_command(build_command(sys.argv[1:]))


if __name__ == "__main__":
    sys.exit(main())
