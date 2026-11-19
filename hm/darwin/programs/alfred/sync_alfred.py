from __future__ import annotations

import argparse
import json
import os
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import uuid
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

MAX_DOWNLOAD_BYTES = 10 * 1024 * 1024
MAX_UNPACKED_BYTES = 32 * 1024 * 1024


def read_plist(path: Path) -> dict[str, Any]:
    try:
        value = plistlib.loads(path.read_bytes())
    except (plistlib.InvalidFileException, ValueError) as error:
        raise ValueError(f"invalid plist: {path}") from error
    if not isinstance(value, dict):
        raise TypeError(f"expected a dictionary in {path}")
    return value


def installed_workflow(workflows: Path, bundle_id: str) -> Path | None:
    matches = [
        path.parent
        for path in workflows.glob("[!.]*/info.plist")
        if read_plist(path).get("bundleid") == bundle_id
    ]
    if len(matches) > 1:
        raise ValueError(f"multiple installed workflows use bundle ID {bundle_id}")
    return next(iter(matches), None)


def publish_workflow(staged: Path, workflows: Path) -> None:
    bundle_id = read_plist(staged / "info.plist")["bundleid"]
    if installed_workflow(workflows, bundle_id) is None:
        staged.rename(workflows / f"user.workflow.{str(uuid.uuid4()).upper()}")


def replace_file(path: Path, contents: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as staged:
        staged_path = Path(staged.name)
        try:
            staged.write(contents)
            staged.close()
            staged_path.replace(path)
        finally:
            staged_path.unlink(missing_ok=True)


def unpack_gallery_workflow(archive: Path, destination: Path) -> None:
    with zipfile.ZipFile(archive) as package:
        entries = package.infolist()
        if sum(entry.file_size for entry in entries) > MAX_UNPACKED_BYTES:
            raise ValueError("Gallery workflow exceeds unpacked size limit")
        for entry in entries:
            name = PurePosixPath(entry.filename)
            if name.is_absolute() or ".." in name.parts:
                raise ValueError(f"unsafe path in Gallery workflow: {entry.filename}")
            if not name.parts or name.parts[0] == "__MACOSX":
                continue
            mode = entry.external_attr >> 16
            if stat.S_IFMT(mode) not in (0, stat.S_IFDIR, stat.S_IFREG):
                raise ValueError(
                    f"unsupported entry in Gallery workflow: {entry.filename}"
                )
            target = destination / name
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with package.open(entry) as source, target.open("xb") as output:
                shutil.copyfileobj(source, output)
            target.chmod(0o644 | (mode & 0o111))


def install_gallery_workflow(workflows: Path, bundle_id: str, url: str) -> None:
    if installed_workflow(workflows, bundle_id) is not None:
        return
    # Stage on the same disk as the destination so a download failure cannot publish a partial workflow.
    with tempfile.TemporaryDirectory(
        prefix=".hm-alfred-", dir=workflows.parent
    ) as stage:
        archive = Path(stage) / "download.alfredworkflow"
        subprocess.run(
            [
                "/usr/bin/curl",
                "--disable",
                "--fail",
                "--silent",
                "--show-error",
                "--location",
                "--proto",
                "=https",
                "--proto-redir",
                "=https",
                "--max-time",
                "30",
                "--max-filesize",
                str(MAX_DOWNLOAD_BYTES),
                "--output",
                str(archive),
                url,
            ],
            check=True,
        )
        staged = Path(stage) / "workflow"
        unpack_gallery_workflow(archive, staged)
        if read_plist(staged / "info.plist").get("bundleid") != bundle_id:
            raise ValueError("downloaded workflow has a different bundle ID")
        publish_workflow(staged, workflows)


def sync_preferences(
    preferences: dict[str, Any], bundle: Path, local_hash: str
) -> None:
    changes = {}
    for root, sections in (
        (bundle / "preferences", preferences["sharedPreferences"]),
        (
            bundle / "preferences" / "local" / local_hash,
            preferences["localPreferences"],
        ),
    ):
        for section, keys in sections.items():
            path = root / section / "prefs.plist"
            current = read_plist(path) if path.exists() else {}
            merged = current | keys
            if merged != current:
                changes[path] = merged
    if not changes:
        return

    # Alfred caches settings in memory and may overwrite an out-of-band edit when it quits.
    running = subprocess.run(
        [
            "/usr/bin/pgrep",
            "-q",
            "-x",
            "-u",
            str(os.getuid()),
            "Alfred|Alfred Preferences",
        ],
        check=False,
    )
    if running.returncode == 0:
        print(
            "Alfred: quit Alfred and Alfred Preferences, then switch again to apply managed preferences.",
            file=sys.stderr,
        )
        return
    if running.returncode != 1:
        running.check_returncode()
    for path, contents in changes.items():
        replace_file(path, plistlib.dumps(contents))


def sync_alfred(settings_path: Path, home: Path) -> None:
    settings = json.loads(settings_path.read_bytes())
    profile_path = home / "Library/Application Support/Alfred/prefs.json"
    if not profile_path.is_file():
        print(
            "Alfred: open Alfred once, then switch again to install workflows and settings.",
            file=sys.stderr,
        )
        return
    profile = json.loads(profile_path.read_bytes())
    bundle = Path(profile["current"]).expanduser()
    local_hash = profile["localhash"]
    if (
        not bundle.is_absolute()
        or not bundle.is_dir()
        or not re.fullmatch(r"[a-f0-9]+", local_hash)
    ):
        raise ValueError(f"invalid Alfred profile in {profile_path}")

    workflows = bundle / "workflows"
    workflows.mkdir(exist_ok=True)
    sync_preferences(settings, bundle, local_hash)
    for bundle_id, url in settings["gallery"].items():
        try:
            install_gallery_workflow(workflows, bundle_id, url)
        except (
            OSError,
            TypeError,
            ValueError,
            subprocess.CalledProcessError,
            zipfile.BadZipFile,
        ) as error:
            print(
                f"Alfred: could not install {bundle_id}; will retry on the next switch: {error}",
                file=sys.stderr,
            )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Sync workflows and settings to the active Alfred profile."
    )
    parser.add_argument("settings", type=Path, help="Home Manager settings JSON")
    args = parser.parse_args()
    try:
        sync_alfred(args.settings, Path.home())
    except (
        OSError,
        TypeError,
        ValueError,
        KeyError,
        subprocess.CalledProcessError,
    ) as error:
        sys.exit(f"Alfred: {error}")
