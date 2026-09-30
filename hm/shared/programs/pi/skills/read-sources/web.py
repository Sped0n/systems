#!/usr/bin/env python3

import argparse
import json
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPException
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote, urlencode, urlsplit, urlunsplit
from urllib.request import Request, urlopen


class ArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(1, f"{message}\n")


def parse_args(argv):
    parser = ArgumentParser(description="Search and read web pages through Jina.")
    parser.add_argument("command", choices=("search", "read"))
    parser.add_argument("target")
    parser.add_argument("--purpose", default="general research")
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--read", action="store_true")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args(argv)
    if not 1 <= args.limit <= 10:
        parser.error("--limit must be an integer from 1 through 10")
    if args.command == "read" and args.read:
        parser.error("--read is only valid with search")
    return args


def http_url(value):
    url = urlsplit(value)
    if url.scheme not in ("http", "https") or not url.hostname:
        raise ValueError("only HTTP(S) URLs are supported")
    # Validate malformed ports before handing the URL to the HTTP client.
    url.port
    return urlunsplit(
        (
            url.scheme,
            url.netloc,
            quote(url.path or "/", safe="/:@!$&'()*+,;=-._~%"),
            quote(url.query, safe="/?@:!$&'()*+,;=-._~%"),
            quote(url.fragment, safe="/?@:!$&'()*+,;=-._~%"),
        )
    )


def jina_base(name):
    value = os.environ.get(name)
    if not value:
        raise ValueError(f"{name} is required")
    return http_url(value).rstrip("/")


def request(url, accept):
    key = os.environ.get("JINA_API_KEY")
    if not key:
        raise ValueError("JINA_API_KEY is required")
    headers = {
        "Authorization": f"Bearer {key}",
        "Accept": accept,
        "User-Agent": "pi-coding-agent",
        "X-Return-Format": "json" if "json" in accept else "markdown",
    }
    try:
        with urlopen(Request(url, headers=headers), timeout=60) as response:
            return response.read().decode("utf-8")
    except HTTPError as error:
        with error:
            body = error.read().decode("utf-8", errors="replace")
        raise ValueError(f"Jina request failed ({error.code}): {body}") from error


def search(query, limit):
    base = jina_base("JINA_SEARCH_SVIP_BASE")
    body = request(f"{base}/?{urlencode({'q': query})}", "application/json")
    try:
        parsed = json.loads(body)
    except json.JSONDecodeError as error:
        raise ValueError("Jina Search returned non-JSON output") from error
    if not isinstance(parsed, dict):
        raise ValueError("Jina Search returned an invalid response")
    candidates = parsed.get("data")
    if not isinstance(candidates, list):
        candidates = parsed.get("results", [])
    if not isinstance(candidates, list):
        raise ValueError("Jina Search returned invalid results")
    results = []
    for item in candidates[:limit]:
        if not isinstance(item, dict):
            raise ValueError("Jina Search returned an invalid result")
        url = item.get("url") or item.get("link")
        if url:
            result = {
                "title": item.get("title") or "Untitled",
                "url": url,
                "description": item.get("description") or item.get("snippet") or "",
                "content": item.get("content") or "",
            }
            if not all(isinstance(value, str) for value in result.values()):
                raise ValueError("Jina Search returned an invalid result")
            results.append(result)
    return results


def read_page(url):
    source = http_url(url)
    base = jina_base("JINA_READER_BASE")
    return {"url": source, "markdown": request(f"{base}/{source}", "text/plain")}


def format_search(results, pages):
    lines = [
        "\n".join(
            filter(
                None,
                (f"{index}. {result['title']}", result["url"], result["description"]),
            )
        )
        for index, result in enumerate(results, 1)
    ]
    lines.extend(f"\n## {page['url']}\n\n{page['markdown']}" for page in pages)
    return "\n\n".join(lines)


def main(argv=None):
    args = parse_args(argv)
    try:
        if args.command == "read":
            data = read_page(args.target)
        else:
            results = search(args.target, args.limit)
            pages = []
            if args.read and results:
                with ThreadPoolExecutor(max_workers=len(results)) as executor:
                    pages = list(
                        executor.map(read_page, (result["url"] for result in results))
                    )
            data = {
                "query": args.target,
                "purpose": args.purpose,
                "results": results,
                "pages": pages,
            }
        if args.json:
            output = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        elif args.command == "read":
            output = data["markdown"]
        else:
            output = format_search(data["results"], data["pages"]) + "\n"
        if args.out:
            args.out.write_text(output, encoding="utf-8")
        else:
            sys.stdout.write(output)
    except (OSError, ValueError, HTTPException) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
