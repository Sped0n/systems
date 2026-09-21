#!/usr/bin/env python3
"""Measure local verbosity and structural erosion without executing source code."""

import hashlib
import json
import math
import os
import re
import signal
import stat
import sys
import time
from collections import defaultdict
from itertools import islice
from pathlib import Path

from ast_grep_py import SgRoot
from complexity import measure_complexity

SCRIPTS = Path(__file__).resolve().parent
RULES = SCRIPTS.parent / "rules/verbosity.json"
EXTENSIONS = {
    "C": "c h",
    "Cpp": "cc cpp cxx hpp hh hxx cu ino",
    "JavaScript": "js jsx cjs mjs",
    "TypeScript": "ts cts mts",
    "Tsx": "tsx",
    "Python": "py pyi",
    "Go": "go",
    "Rust": "rs",
    "Nix": "nix",
    "Java": "java",
}
EVALUATION_OPTIONS = {
    "language",
    "include",
    "exclude",
    "workers",
    "timeoutMs",
    "maxOutputBytes",
    "gitignore",
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def positive_integer(value, name):
    if type(value) is not int or value <= 0:
        raise ValueError(f"{name} must be a positive integer")

    return value


def run_command(
    argv,
    cwd,
    *,
    input=b"",
    timeout_ms=30000,
    max_output_bytes=128 * 1024 * 1024,
    env=None,
):
    """Bound combined output and runtime; kill the process group on interruption."""
    # Parser subprocesses do not need the command runner's imports.
    import selectors
    import subprocess
    import tempfile

    output = {"stdout": bytearray(), "stderr": bytearray()}
    error = None
    process = None
    completed = False

    with tempfile.TemporaryFile() as source, selectors.DefaultSelector() as selector:
        source.write(input)
        source.seek(0)

        try:
            process = subprocess.Popen(
                argv,
                cwd=cwd,
                env=env,
                stdin=source,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True,
            )
            deadline = time.monotonic() + timeout_ms / 1000

            for name in output:
                selector.register(getattr(process, name), selectors.EVENT_READ, name)

            size = 0

            while selector.get_map():
                remaining = deadline - time.monotonic()

                if remaining <= 0:
                    raise subprocess.TimeoutExpired(argv, timeout_ms / 1000)

                for key, _ in selector.select(remaining):
                    chunk = os.read(key.fd, 65536)

                    if not chunk:
                        selector.unregister(key.fileobj)
                        continue

                    available = max(0, max_output_bytes - size)
                    output[key.data].extend(chunk[:available])
                    size += len(chunk)

                    if size > max_output_bytes:
                        raise ValueError(
                            f"command output exceeded {max_output_bytes} bytes"
                        )

            process.wait(timeout=max(0, deadline - time.monotonic()))
            completed = True
        except (OSError, subprocess.TimeoutExpired, ValueError) as e:
            error = str(e)
        finally:
            if process is not None:
                if not completed:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass

                process.wait()
                process.stdout.close()
                process.stderr.close()

    code = process.returncode if process is not None else None

    return {
        "passed": error is None and code == 0,
        "status": code if code is not None and code >= 0 else None,
        "signal": signal.Signals(-code).name if code is not None and code < 0 else None,
        "error": error,
        **{
            name: bytes(data).decode("utf-8", "surrogateescape")
            for name, data in output.items()
        },
    }


def discover(root, exclusions, gitignore, inclusions=()):
    base = root if root.is_dir() else root.parent
    files, skipped, excluded, errors = [], [], [], []
    repositories = {base: []}

    def walk(file, repository):
        relative_path = file.relative_to(base)
        relative = str(relative_path)

        try:
            if ".git" in file.parts:
                excluded.append(relative)
                return

            mode = file.lstat().st_mode

            if any(
                relative_path.full_match(
                    pattern.removesuffix("/**") if stat.S_ISDIR(mode) else pattern,
                    case_sensitive=True,
                )
                for pattern in exclusions
            ):
                if stat.S_ISDIR(mode):
                    excluded.append(relative)

                return

            if stat.S_ISLNK(mode):
                skipped.append({"file": relative, "reason": "symlink", "loc": None})
            elif stat.S_ISDIR(mode):
                # Git cannot match paths inside another repository. Check its
                # boundary in the parent, then its contents against its own rules.
                if gitignore and file != root and (file / ".git").exists():
                    repositories[repository].append(file)
                    repository = file
                    repositories[repository] = []

                for child in sorted(file.iterdir()):
                    walk(child, repository)
            elif stat.S_ISREG(mode):
                if inclusions and not any(
                    relative_path.full_match(pattern, case_sensitive=True)
                    for pattern in inclusions
                ):
                    return

                files.append(file)
                repositories[repository].append(file)
        except OSError as e:
            errors.append({"file": relative, "message": str(e), "loc": None})

    root.stat()
    walk(root, base)

    ignored = set()
    policy = "disabled"

    if gitignore:

        def git(directory, *args, input=b""):
            result = run_command(
                ["git", *args],
                directory,
                input=input,
                env={**os.environ, "LC_ALL": "C"},
            )

            if result["error"] or result["signal"]:
                raise RuntimeError(
                    f"Git ignore check failed: {result['error'] or result['signal']}"
                )

            return result

        probe = git(base, "rev-parse", "--is-inside-work-tree")

        if (
            probe["status"] == 128
            and probe["stderr"].startswith("fatal: not a git repository")
        ) or (probe["status"] == 0 and probe["stdout"].strip() == "false"):
            policy = "outside-work-tree"
        elif probe["status"] != 0 or probe["stdout"].strip() != "true":
            raise RuntimeError(f"Git ignore check failed: {probe['stderr']}")
        else:
            policy = "respected"
            for repository, paths in repositories.items():
                if str(repository) in ignored:
                    ignored.update(map(str, paths))
                    continue

                result = git(
                    repository,
                    "check-ignore",
                    "--stdin",
                    "-z",
                    input=b"".join(os.fsencode(file) + b"\0" for file in paths),
                )

                if result["status"] not in (0, 1):
                    raise RuntimeError(f"Git ignore check failed: {result['stderr']}")

                ignored.update(result["stdout"].split("\0"))

    return (
        base,
        [file for file in files if str(file) not in ignored],
        {
            "skipped": skipped,
            "excludedDirectories": excluded,
            "analysisErrors": errors,
            "gitIgnoredFiles": [
                str(file.relative_to(base)) for file in files if str(file) in ignored
            ],
        },
        policy,
    )


def analyze(text, language):
    root = SgRoot(text, language).root()
    errors = root.find_all(kind="ERROR")
    functions, skipped = measure_complexity(text, root, language, errors)
    lines = text.split("\n")
    measured_functions = [
        {**function, "mass": function["cc"] * math.sqrt(function["sloc"])}
        for function in functions or []
    ]
    result = {
        "mass": sum(function["mass"] for function in measured_functions)
        if functions is not None and (not errors or functions)
        else None,
        "highCcMass": sum(
            function["mass"] for function in measured_functions if function["cc"] > 10
        ),
        "highComplexityFunctions": [
            function for function in measured_functions if function["cc"] > 10
        ],
        "functionCount": len(functions or []),
    }

    if errors:
        covered_lines = set()

        for function in functions or []:
            covered_lines.update(range(function["line"] - 1, function["endLine"]))

        return {
            **result,
            "complexityLoc": sum(bool(lines[line].strip()) for line in covered_lines),
            "parseErrors": {
                "lines": sorted({error.range().start.line + 1 for error in errors}),
                "skippedFunctions": skipped,
            },
        }

    clones, seen, flagged = [], set(), set()

    for node in root.find_all(pattern="$A", regex="(?s).{80}"):
        location = node.range()
        last = location.end.line - (location.end.column == 0)

        if last - location.start.line < 4:
            continue

        node_text = node.text()
        nonblank = re.finditer(r"(?m)^[^\S\n]*\S", node_text)

        if len(node_text.strip()) < 80 or sum(1 for _ in islice(nonblank, 5)) < 5:
            continue

        interval = (location.start.index, location.end.index)

        if interval in seen:
            continue

        seen.add(interval)
        clones.append(
            {
                "key": digest(node_text.replace("\r\n", "\n").encode()),
                "first": location.start.line,
                "last": last,
            }
        )

    for rule in json.loads(RULES.read_text()):
        if language not in rule["languages"]:
            continue

        for node in root.find_all(pattern=rule["pattern"]):
            location = node.range()
            end = location.end.line - (location.end.column == 0)
            flagged.update(
                line
                for line in range(location.start.line, end + 1)
                if lines[line].strip()
            )

    return {
        **result,
        "clones": clones,
        "flagged": sorted(flagged),
        "nonblankLines": [index for index, line in enumerate(lines) if line.strip()]
        if clones
        else [],
    }


def measure_file(file, base, language, limits):
    result = {"file": str(file.relative_to(base)), "loc": None, "digest": None}

    try:
        data = file.read_bytes()

        if b"\0" in data:
            return {**result, "reason": "binary"}

        text = data.decode("utf-8")
        result.update(
            loc=sum(bool(line.strip()) for line in text.split("\n")),
            digest=digest(data),
        )
        language = language or next(
            (
                name
                for name, extensions in EXTENSIONS.items()
                if file.suffix[1:] in extensions.split()
            ),
            None,
        )

        if language is None:
            return {**result, "reason": "unsupported language; LOC only"}

        result["language"] = language
        command = run_command(
            [sys.executable, str(SCRIPTS / "evaluate.py"), "--analyze", language],
            base,
            input=data,
            **limits,
        )

        if not command["passed"]:
            return {
                **result,
                "error": command["error"]
                or command["stderr"]
                or f"analyzer exited with {command['signal'] or command['status']}",
            }

        result.update(json.loads(command["stdout"]))

        if digest(file.read_bytes()) != result["digest"]:
            result["error"] = "source changed during analysis"
    except UnicodeDecodeError:
        result["reason"] = "non-UTF-8"
    except OSError as e:
        result["error"] = str(e)

    return result


def summarize(results, discovery, settings):
    groups, source_lines, clone_ranges = defaultdict(list), {}, defaultdict(list)
    sources, unsupported, files, high_complexity_functions = [], [], [], []
    flagged, clones = set(), set()
    loc = analyzed_loc = complexity_loc = ast_files = complexity_files = 0
    mass = high_cc_mass = function_count = skipped_functions = 0

    for result in results:
        file = result["file"]
        loc += result["loc"] or 0
        file_summary = {
            "file": file,
            "loc": result["loc"],
            "analyzedLoc": 0,
            "complexityLoc": 0,
            "functionCount": 0,
            "cloneLines": 0,
            "flaggedLines": 0,
            "unionLines": 0,
            "verbosity": None,
            "mass": None,
            "highCcMass": None,
            "erosion": None,
        }
        files.append(file_summary)

        if result["digest"]:
            sources.append([file, result["digest"]])

        if "error" in result:
            discovery["analysisErrors"].append(
                {"file": file, "loc": result["loc"], "message": result["error"]}
            )
            continue

        if "reason" in result:
            discovery["skipped"].append(
                {"file": file, "loc": result["loc"], "reason": result["reason"]}
            )

            if result["loc"] is not None:
                unsupported.append(file)

            continue

        if result["mass"] is None:
            unsupported.append(file)
        else:
            file_summary.update(
                {
                    "complexityLoc": result.get("complexityLoc", result["loc"]),
                    "functionCount": result["functionCount"],
                    "mass": result["mass"],
                    "highCcMass": result["highCcMass"],
                    "erosion": (
                        result["highCcMass"] / result["mass"]
                        if result["mass"]
                        else None
                    ),
                }
            )
            high_complexity_functions.extend(
                {"file": file, **function}
                for function in result["highComplexityFunctions"]
            )
            complexity_files += 1
            complexity_loc += result.get("complexityLoc", result["loc"])
            function_count += result["functionCount"]
            mass += result["mass"]
            high_cc_mass += result["highCcMass"]

        if "parseErrors" in result:
            skipped_functions += len(result["parseErrors"]["skippedFunctions"])
            discovery["analysisErrors"].append(
                {
                    "file": file,
                    "loc": result["loc"],
                    "message": "partial complexity coverage; verbosity omitted due to parser errors",
                    **result["parseErrors"],
                }
            )
            continue

        ast_files += 1
        analyzed_loc += result["loc"]
        file_summary["analyzedLoc"] = result["loc"]
        source_lines[file] = result["nonblankLines"]
        flagged.update((file, line) for line in result["flagged"])

        for candidate in result["clones"]:
            groups[(result["language"], candidate["key"])].append(
                {"file": file, **candidate}
            )

    # Equal AST text cannot strictly contain itself; equal spans were deduplicated.
    for occurrences in groups.values():
        if len(occurrences) >= 2:
            for item in occurrences:
                clone_ranges[item["file"]].append(item)

    for file, ranges in clone_ranges.items():
        lines = source_lines[file]
        index = 0

        for item in sorted(ranges, key=lambda item: item["first"]):
            while index < len(lines) and lines[index] < item["first"]:
                index += 1

            while index < len(lines) and lines[index] <= item["last"]:
                clones.add((file, lines[index]))
                index += 1

    clones_by_file = defaultdict(set)
    flagged_by_file = defaultdict(set)
    for file, line in clones:
        clones_by_file[file].add(line)
    for file, line in flagged:
        flagged_by_file[file].add(line)

    for item in files:
        if not item["analyzedLoc"]:
            continue
        file_clones = clones_by_file[item["file"]]
        file_flagged = flagged_by_file[item["file"]]
        union = file_clones | file_flagged
        item.update(
            {
                "cloneLines": len(file_clones),
                "flaggedLines": len(file_flagged),
                "unionLines": len(union),
                "verbosity": len(union) / item["analyzedLoc"],
            }
        )

    return {
        "sourceHash": digest(json.dumps(sources, separators=(",", ":")).encode()),
        "settings": settings,
        "complete": not discovery["analysisErrors"] and not unsupported,
        "coverage": {
            "astFiles": ast_files,
            "complexityFiles": complexity_files,
            "complexityLoc": complexity_loc,
            "complexityFunctions": function_count,
            "skippedFunctions": skipped_functions,
        },
        "loc": loc,
        "analyzedLoc": analyzed_loc,
        **discovery,
        "complexityUnsupported": unsupported,
        "files": files,
        "highComplexityFunctions": sorted(
            high_complexity_functions,
            key=lambda function: (
                -function["mass"],
                function["file"],
                function["line"],
            ),
        ),
        "cloneLines": len(clones),
        "flaggedLines": len(flagged),
        "unionLines": len(clones | flagged),
        "verbosity": len(clones | flagged) / analyzed_loc if analyzed_loc else None,
        "mass": mass,
        "highCcMass": high_cc_mass,
        "erosion": high_cc_mass / mass if mass else None,
    }


def evaluate(input, options=None):
    from concurrent.futures import ThreadPoolExecutor
    from importlib.metadata import version

    options = dict(options or {})

    if options.keys() - EVALUATION_OPTIONS:
        raise ValueError("unknown evaluation options")

    language = options.get("language")

    if language is not None:
        language = next(
            (name for name in EXTENSIONS if name.lower() == str(language).lower()), None
        )

        if language is None:
            raise ValueError(f"language must be one of: {', '.join(EXTENSIONS)}")

    if type(options.get("gitignore", True)) is not bool:
        raise ValueError("gitignore must be a boolean")

    filters = {}

    for name in ("include", "exclude"):
        patterns = options.get(name, [])
        patterns = [patterns] if isinstance(patterns, str) else patterns

        if not isinstance(patterns, list) or any(
            not isinstance(pattern, str)
            or not pattern
            or Path(pattern).is_absolute()
            or ".." in Path(pattern).parts
            for pattern in patterns
        ):
            raise ValueError(
                f"{name} requires relative path/glob patterns without '..'"
            )

        filters[name] = sorted(set(patterns))

    workers = positive_integer(
        options.get("workers", min(4, os.cpu_count() or 1)), "workers"
    )
    limits = {
        "timeout_ms": positive_integer(options.get("timeoutMs", 30000), "timeoutMs"),
        "max_output_bytes": positive_integer(
            options.get("maxOutputBytes", 128 * 1024 * 1024), "maxOutputBytes"
        ),
    }
    base, files, discovery, policy = discover(
        Path(input).absolute(),
        filters["exclude"],
        options.get("gitignore", True),
        filters["include"],
    )
    validation = run_command(
        [sys.executable, str(SCRIPTS / "evaluate.py"), "--validate"], base
    )

    if not validation["passed"]:
        raise RuntimeError(
            validation["error"]
            or validation["stderr"]
            or "analyzer initialization failed"
        )

    settings = {
        "language": language,
        **filters,
        "gitignore": policy,
        **limits,
        "analyzerHash": digest(
            b"\0".join(
                (SCRIPTS / name).read_bytes()
                for name in (
                    "evaluate.py",
                    "complexity.py",
                    "../rules/complexity.json",
                    "../rules/verbosity.json",
                )
            )
        ),
        "dependencies": {
            "python": sys.version,
            "ast-grep-py": version("ast-grep-py"),
        },
    }

    with ThreadPoolExecutor(max_workers=workers) as executor:
        try:
            results = executor.map(
                lambda file: measure_file(file, base, language, limits), files
            )

            return summarize(results, discovery, settings)
        except BaseException:
            executor.shutdown(wait=False, cancel_futures=True)
            raise


def main():
    # Internal subprocess modes isolate native parser faults from the scan.
    if len(sys.argv) == 2 and sys.argv[1] == "--validate":
        for language in EXTENSIONS:
            analyze("", language)

        return 0

    if len(sys.argv) == 3 and sys.argv[1] == "--analyze":
        try:
            result = analyze(sys.stdin.buffer.read().decode("utf-8"), sys.argv[2])
        except ValueError as e:
            result = {"error": str(e)}

        print(json.dumps(result))
        return 0

    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "path", help="File or directory to measure; emits JSON on stdout"
    )
    parser.add_argument(
        "--language",
        help=f"Force a parser ({', '.join(EXTENSIONS)}); default: by extension, with .h as C",
    )
    parser.add_argument(
        "--include",
        action="append",
        metavar="PATTERN",
        help="Relative file path/glob; repeat to combine selections (default: all files)",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        metavar="PATTERN",
        help="Relative path/glob to omit; repeat as needed; exclusions win over includes",
    )
    parser.add_argument(
        "--no-gitignore",
        dest="gitignore",
        action="store_false",
        help="Include Git-ignored files; explicit exclusions still apply",
    )
    parser.add_argument(
        "--workers", type=int, help="Concurrent parser processes (default: up to 4)"
    )
    parser.add_argument(
        "--timeout-ms",
        dest="timeoutMs",
        type=int,
        help="Per-file parser timeout, including startup (default: 30000 ms)",
    )
    parser.add_argument(
        "--max-output-bytes",
        dest="maxOutputBytes",
        type=int,
        help="Combined stdout/stderr limit per parser process (default: 134217728 bytes)",
    )
    args = vars(parser.parse_args())
    root = args.pop("path")

    try:
        report = evaluate(
            root, {key: value for key, value in args.items() if value is not None}
        )
        print(json.dumps(report, indent=2, allow_nan=False))

        if not report["complete"]:
            print(
                "Partial report: inspect analysisErrors and complexityUnsupported before interpreting scores.",
                file=sys.stderr,
            )

        return 0
    except (OSError, ValueError, TypeError, RuntimeError) as e:
        print(str(e), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
