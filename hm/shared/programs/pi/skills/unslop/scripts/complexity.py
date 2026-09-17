"""Local complexity conventions; each decision belongs to its innermost function."""

import json
from pathlib import Path

PROFILE_FILE = Path(__file__).resolve().parent.parent / "rules/complexity.json"
PROFILES = {
    language: profile
    for profile in json.loads(PROFILE_FILE.read_text())
    for language in profile["languages"]
}


def kinds(names):
    return {"any": [{"kind": name} for name in names]}


def complexity_rules(language):
    profile = PROFILES.get(language)

    if profile is None:
        return {}

    decisions = [kinds(profile["decisions"])]
    decisions.extend({"pattern": pattern} for pattern in profile["logical"])

    if "cases" in profile:
        decisions.append(profile["cases"])

    return {
        "functions": kinds(profile["functions"]),
        "decisions": {"any": decisions},
        "comments": kinds(profile["comments"]),
    }


def span(node):
    location = node.range()

    # The Python binding reports Unicode code-point indices, not UTF-8 bytes.
    return location.start.index, location.end.index


def measure_complexity(text, root, language, errors):
    rules = complexity_rules(language)

    if not rules:
        return None, []

    functions = sorted(
        root.find_all(**rules["functions"]),
        key=lambda node: (span(node)[0], -span(node)[1]),
    )
    ranges = [span(node) for node in functions]
    locations = [node.range() for node in functions]
    error_ranges = [span(error) for error in errors]
    accepted, skipped = [], []

    for index, (start, end) in enumerate(ranges):
        if any(
            start < error_end
            and error_start < end
            or error_start == error_end
            and start <= error_start <= end
            for error_start, error_end in error_ranges
        ):
            location = locations[index]
            skipped.append(
                {
                    "line": location.start.line + 1,
                    "endLine": location.end.line + (location.end.column != 0),
                }
            )
        else:
            accepted.append(index)

    if not accepted:
        return [], skipped

    # Keep every function in the ownership stack, including rejected ones.
    # Filtering first could charge a nested function's decisions to its parent.
    counts = [set() for _ in functions]
    active = []
    next_function = 0

    for decision in sorted(
        root.find_all(**rules["decisions"]), key=lambda node: span(node)[0]
    ):
        start, end = span(decision)

        while next_function < len(functions) and ranges[next_function][0] <= start:
            while active and ranges[active[-1]][1] <= ranges[next_function][0]:
                active.pop()

            active.append(next_function)
            next_function += 1

        while active and ranges[active[-1]][1] <= start:
            active.pop()

        owner = next(
            (index for index in reversed(active) if ranges[index][1] >= end), None
        )

        if owner is not None:
            counts[owner].add((start, end))

    # Preserve indices and line breaks; strings that resemble comments remain code.
    code = list(text)

    for comment in root.find_all(**rules["comments"]):
        start, end = span(comment)

        for index in range(start, end):
            if code[index] not in "\r\n":
                code[index] = " "

    code = "".join(code)

    return [
        {
            "sloc": sum(
                bool(line.strip())
                for line in code[ranges[index][0] : ranges[index][1]].split("\n")
            ),
            "cc": 1 + len(counts[index]),
            "line": locations[index].start.line + 1,
            "endLine": locations[index].end.line + (locations[index].end.column != 0),
        }
        for index in accepted
    ], skipped
