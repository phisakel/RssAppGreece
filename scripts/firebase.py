#!/usr/bin/env python3
"""Render Firebase URLs and run Hosting with an explicit environment project."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "build/firebase"
PLACEHOLDER = "${FIREBASE_PROJECT_ID}"


def project_id():
    value = os.environ.get("FIREBASE_PROJECT_ID")
    if value is None:
        local = ROOT / "Config/firebase.env"
        if local.exists():
            for line in local.read_text().splitlines():
                line = line.strip()
                if line.startswith("FIREBASE_PROJECT_ID="):
                    value = line.split("=", 1)[1].strip()
    if not value:
        raise ValueError(
            "Set FIREBASE_PROJECT_ID in the environment or Config/firebase.env."
        )
    if not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", value):
        raise ValueError("FIREBASE_PROJECT_ID must be a valid Firebase project ID.")
    return value


def build(project):
    # Recreate generated directories so deleted source files cannot be deployed.
    for directory in ("web", "metadata"):
        destination = OUTPUT / directory
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(ROOT / directory, destination)
        for path in destination.rglob("*"):
            if path.suffix not in (".html", ".json"):
                continue
            path.write_text(path.read_text().replace(PLACEHOLDER, project))
            if path.suffix == ".json":
                json.loads(path.read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("build", "deploy", "emulate"))
    args = parser.parse_args()
    try:
        project = project_id()
        build(project)
    except (ValueError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print("Generated website and metadata in build/firebase.", flush=True)
    if args.action == "build":
        return 0
    command = "deploy" if args.action == "deploy" else "emulators:start"
    return subprocess.call(
        ["npx", "-y", "firebase-tools@latest", command,
         "--only", "hosting", "--project", project],
        cwd=ROOT,
    )


if __name__ == "__main__":
    sys.exit(main())
