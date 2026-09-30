#!/usr/bin/env python3

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlsplit


class ArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(1, f"{message}\n")


def parse_args(argv):
    parser = ArgumentParser(
        description="Convert documents to Markdown with MarkItDown."
    )
    parser.add_argument("input")
    output = parser.add_mutually_exclusive_group()
    output.add_argument("--out", type=Path)
    output.add_argument("--tmp", action="store_true")
    return parser.parse_args(argv)


def is_url(value):
    return value.lower().startswith(("http://", "https://"))


def convert(source):
    # Spool output so a large converter response cannot exhaust Python's heap.
    limit = 50 * 1024 * 1024
    with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
        try:
            result = subprocess.run(
                ["uvx", "--from", "markitdown[pdf]", "markitdown", source],
                stdout=stdout,
                stderr=stderr,
                check=False,
            )
        except OSError as error:
            raise ValueError(f"failed to run markitdown: {error}") from error
        if stdout.tell() > limit or stderr.tell() > limit:
            raise ValueError("failed to run markitdown: output exceeds 50 MiB")
        if result.returncode:
            stderr.seek(0)
            message = stderr.read().decode("utf-8", errors="replace").strip()
            raise ValueError(f"markitdown failed: {message}")
        stdout.seek(0)
        return stdout.read().decode("utf-8", errors="replace")


def main(argv=None):
    args = parse_args(argv)
    try:
        if not is_url(args.input) and not Path(args.input).exists():
            raise ValueError(f"file not found: {args.input}")
        markdown = convert(args.input)
        if args.out:
            args.out.write_text(markdown, encoding="utf-8")
        elif args.tmp:
            source_path = (
                urlsplit(args.input).path if is_url(args.input) else args.input
            )
            name = re.sub(
                r"[^a-zA-Z0-9._-]+", "_", Path(source_path).name or "document"
            )
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                prefix=f"pi-document-{name}-",
                suffix=".md",
                delete=False,
            ) as output:
                output.write(markdown)
            print(output.name)
        else:
            sys.stdout.write(markdown)
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
