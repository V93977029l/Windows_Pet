#!/usr/bin/env python3
"""Convert Godot Coverage addon's coverage.json to standard lcov.info format.

Usage:
    python tools/coverage_to_lcov.py <coverage.json> [--project-dir transparent-pet] [--out lcov.info]

The Godot Coverage addon stores:
    { "res://path/to/script.gd": { "5": 2, "7": 1, ... }, ... }
where each key is a line-number-string and the value is hit count.

LCOV format:
    TN:test_name
    SF:/filesystem/path/to/script.gd
    DA:5,2
    DA:7,1
    ...
    LF:<total instrumented lines>
    LH:<hit lines>
    end_of_record
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def res_to_filesystem(res_path: str, project_dir: Path) -> Path:
    if res_path.startswith("res://"):
        rel = res_path[len("res://") :]
    else:
        rel = res_path
    rel = rel.replace("\\", "/")
    return project_dir / rel


def convert(
    coverage_json_path: Path,
    project_dir: Path,
    out_path: Path,
    test_name: str = "godot-unit",
) -> None:
    with open(coverage_json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    lines = []
    total_lf = 0
    total_lh = 0

    for res_path in sorted(data.keys()):
        file_path = res_to_filesystem(res_path, project_dir)
        line_map = data[res_path]
        if not isinstance(line_map, dict) or not line_map:
            continue

        try:
            abs_path = file_path.resolve()
        except OSError:
            abs_path = file_path.absolute()

        lines.append("TN:" + test_name)
        lines.append("SF:" + abs_path.as_posix())

        lf = 0
        lh = 0
        for line_no_str in sorted(line_map.keys(), key=lambda s: int(s)):
            try:
                line_no = int(line_no_str)
            except ValueError:
                continue
            count = line_map[line_no_str]
            try:
                count = int(count)
            except (TypeError, ValueError):
                count = 0
            lines.append("DA:" + str(line_no) + "," + str(count))
            lf += 1
            if count > 0:
                lh += 1
        lines.append("LF:" + str(lf))
        lines.append("LH:" + str(lh))
        lines.append("end_of_record")

        total_lf += lf
        total_lh += lh

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    pct = (total_lh / total_lf * 100.0) if total_lf else 100.0
    print(
        "[coverage_to_lcov] wrote",
        out_path,
        "(" + str(len(data)) + " files,",
        str(total_lh) + "/" + str(total_lf) + " lines = " + ("%.2f" % pct) + "%)",
    )


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("coverage_json")
    p.add_argument("--project-dir", default="transparent-pet")
    p.add_argument("--out", default=None)
    p.add_argument("--test-name", default="godot-unit")
    args = p.parse_args()

    coverage_json = Path(args.coverage_json)
    if not coverage_json.is_file():
        print("ERROR: coverage.json not found at", coverage_json, file=sys.stderr)
        return 2

    project_dir = Path(args.project_dir)
    if not project_dir.is_dir():
        print("ERROR: project-dir not found at", project_dir, file=sys.stderr)
        return 2

    out = Path(args.out) if args.out else coverage_json.with_name("lcov.info")
    convert(coverage_json, project_dir, out, test_name=args.test_name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
