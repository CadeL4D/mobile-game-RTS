#!/usr/bin/env python3
"""Restore unsupported evidence promotions without reverting implementation data.

For records that existed at HEAD, evidence-like fields are restored to their
committed values. New evidence fields and new records are never allowed to
start as CONFIRMED_OFFICIAL without a separate evidence review; they are
demoted to VERIFY_RUNTIME. Formatting and non-evidence values are preserved.
"""

from __future__ import annotations

import re
import subprocess
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "content" / "data"
EVIDENCE_VALUES = (
    "VERIFY_RUNTIME",
    "CONFIRMED_RUNTIME",
    "CONFIRMED_OFFICIAL",
    "WIKI_SUPPORTED",
    "LEGACY_REMOVED",
    "MOBILE_ADAPTATION",
)
VALUE_PATTERN = "(?:" + "|".join(EVIDENCE_VALUES) + ")"
ID_RE = re.compile(r'"id"\s*:\s*"([^"]+)"')
FIELD_RE = re.compile(
    rf'"(?P<key>(?:[A-Za-z0-9_]+_)?evidence|status)"\s*:\s*"(?P<value>{VALUE_PATTERN})"'
)


def git_head_text(relative_path: str) -> str | None:
    result = subprocess.run(
        ["git", "show", f"HEAD:{relative_path}"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    return result.stdout if result.returncode == 0 else None


def evidence_fields(line: str) -> dict[str, str]:
    return {match.group("key"): match.group("value") for match in FIELD_RE.finditer(line)}


def replace_field(line: str, key: str, value: str) -> str:
    pattern = re.compile(rf'("{re.escape(key)}"\s*:\s*")({VALUE_PATTERN})(")')
    return pattern.sub(rf"\g<1>{value}\g<3>", line)


def restore_file(path: Path) -> int:
    relative = path.relative_to(ROOT).as_posix()
    baseline_text = git_head_text(relative)
    baseline_records: dict[str, list[dict[str, str]]] = defaultdict(list)
    if baseline_text is not None:
        active_baseline_fields: dict[str, str] | None = None
        for line in baseline_text.splitlines():
            identifier = ID_RE.search(line)
            if identifier:
                active_baseline_fields = {}
                baseline_records[identifier.group(1)].append(active_baseline_fields)
            fields = evidence_fields(line)
            if active_baseline_fields is not None and fields:
                active_baseline_fields.update(fields)

    occurrence: dict[str, int] = defaultdict(int)
    changes = 0
    output: list[str] = []
    original = path.read_text(encoding="utf-8")
    active_baseline_fields: dict[str, str] = {}
    for line in original.splitlines(keepends=True):
        identifier = ID_RE.search(line)
        if identifier:
            record_id = identifier.group(1)
            record_index = occurrence[record_id]
            occurrence[record_id] += 1
            records = baseline_records.get(record_id, [])
            active_baseline_fields = records[record_index] if record_index < len(records) else {}
        current_fields = evidence_fields(line)
        if not current_fields:
            output.append(line)
            continue

        updated = line
        for key, current_value in current_fields.items():
            if key in active_baseline_fields:
                desired = active_baseline_fields[key]
            elif current_value == "CONFIRMED_OFFICIAL":
                desired = "VERIFY_RUNTIME"
            else:
                desired = current_value
            if desired != current_value:
                updated = replace_field(updated, key, desired)
                changes += 1
        output.append(updated)

    if changes:
        path.write_text("".join(output), encoding="utf-8", newline="")
    return changes


def main() -> int:
    total = 0
    for path in sorted(DATA_DIR.glob("*.json")):
        changed = restore_file(path)
        if changed:
            print(f"{path.relative_to(ROOT)}: restored {changed} evidence field(s)")
            total += changed
    print(f"Restored {total} unsupported evidence promotion(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
