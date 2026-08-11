#!/usr/bin/env python3
"""Report on the published leaderboard, and flag rows nothing can clean up.

    python3 tools/leaderboard_audit.py

Read-only: every request is a GET, and nothing local is written.

This exists because the client can only ever delete its own row. A row whose
owning account is gone - an install that lost user://, or one still running a
build without the orphan reaper - is unreachable by any code we ship, and a
Firestore TTL policy would need a billing-enabled project. So the sweep stays
manual, and this is the broom.

Two identical names is the signature to look for: one player counted twice, the
second row published after their identity changed underneath them. It is not
proof - two people can pick the same name - which is why this prints the
evidence rather than just a verdict.
"""

import json
import re
import sys
import urllib.error
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

CONFIG_PATH = Path(__file__).resolve().parent.parent / "resources" / "leaderboard_config.tres"
PAGE_SIZE = 300
REQUEST_TIMEOUT_SECONDS = 30

# Beyond this a row has outlived the client that wrote it, in all likelihood.
STALE_DAYS = 400


def read_config() -> dict[str, str]:
    """Pull the Firestore coordinates out of the Godot resource.

    Parsed rather than duplicated, so the audit cannot drift away from what the
    game actually talks to. The api_key is a public project identifier that
    ships inside every client binary - see leaderboard_config.gd.
    """
    text = CONFIG_PATH.read_text(encoding="utf-8")
    config = {}
    for key in ("project_id", "api_key", "collection"):
        match = re.search(rf'^{key}\s*=\s*"([^"]*)"', text, re.MULTILINE)
        if not match:
            sys.exit(f"could not find {key} in {CONFIG_PATH}")
        config[key] = match.group(1)
    return config


def fetch_documents(config: dict[str, str]) -> list[dict]:
    """Every document in the collection, following pagination to the end."""
    base = (
        f"https://firestore.googleapis.com/v1/projects/{config['project_id']}"
        f"/databases/(default)/documents/{config['collection']}"
    )
    documents: list[dict] = []
    page_token = ""

    while True:
        url = f"{base}?key={config['api_key']}&pageSize={PAGE_SIZE}"
        if page_token:
            url += f"&pageToken={page_token}"

        try:
            with urllib.request.urlopen(url, timeout=REQUEST_TIMEOUT_SECONDS) as response:
                payload = json.load(response)
        except urllib.error.HTTPError as error:
            body = error.read().decode(errors="replace")
            sys.exit(f"Firestore returned HTTP {error.code}: {body}")
        except urllib.error.URLError as error:
            sys.exit(f"could not reach Firestore: {error.reason}")

        documents.extend(payload.get("documents", []))
        page_token = payload.get("nextPageToken", "")
        if not page_token:
            return documents


def string_field(fields: dict, key: str) -> str:
    return fields.get(key, {}).get("stringValue", "")


def int_field(fields: dict, key: str) -> int:
    # Firestore hands integerValue back as a JSON string.
    return int(fields.get(key, {}).get("integerValue", 0))


def timestamp_field(fields: dict, key: str) -> str:
    return fields.get(key, {}).get("timestampValue", "")


def days_since(timestamp: str) -> float | None:
    if not timestamp:
        return None
    parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    return (datetime.now(timezone.utc) - parsed).total_seconds() / 86400


def main() -> int:
    config = read_config()
    documents = fetch_documents(config)

    rows = []
    for document in documents:
        fields = document.get("fields", {})
        rows.append(
            {
                "name": string_field(fields, "name"),
                "score": int_field(fields, "score"),
                "updated_at": timestamp_field(fields, "updated_at"),
                "expires_at": timestamp_field(fields, "expires_at"),
                "uid": document["name"].rsplit("/", 1)[-1],
            }
        )

    print(f"{len(rows)} row(s) in {config['project_id']}/{config['collection']}\n")
    print(f"{'name':<18}{'score':>7}  {'updated_at':<22}{'age':>6}  uid")
    for row in sorted(rows, key=lambda r: r["score"], reverse=True):
        age = days_since(row["updated_at"])
        age_text = f"{age:.0f}d" if age is not None else "-"
        print(
            f"{row['name']:<18}{row['score']:>7}  {row['updated_at']:<22}"
            f"{age_text:>6}  {row['uid']}"
        )

    stale = [
        row
        for row in rows
        if (age := days_since(row["updated_at"])) is not None and age > STALE_DAYS
    ]
    duplicates = {
        name: count
        for name, count in Counter(row["name"] for row in rows).items()
        if count > 1
    }

    print()
    if stale:
        print(f"stale - untouched for over {STALE_DAYS} days:")
        for row in stale:
            print(f"  {row['name']} -> {row['uid']}")

    if not duplicates:
        print("no duplicate names")
        return 0

    print("DUPLICATE NAMES - likely one player counted twice:")
    for name, count in duplicates.items():
        print(f"  {name} x{count}")
        for row in [r for r in rows if r["name"] == name]:
            print(f"    {row['score']:>7}  {row['updated_at']}  {row['uid']}")

    print(
        "\nKeep the newest row of each pair and delete the rest in the Firestore"
        "\nconsole. Two players choosing the same name looks identical to this,"
        "\nso check the scores and timestamps before removing anything."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
