#!/usr/bin/env python3
"""Validate embedded Grafana JSON blocks and monitoring invariants without PyYAML."""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFESTS = [
    ROOT / "manifests" / "innodb-mysql.yaml",
    ROOT / "manifests" / "mysql-addon-monitoring.yaml",
]


def extract_json_blocks(path: pathlib.Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    blocks: dict[str, str] = {}
    current_name: str | None = None
    current: list[str] = []

    def flush() -> None:
        nonlocal current_name, current
        if current_name is not None:
            blocks[current_name] = "\n".join(current)
        current_name = None
        current = []

    for line in lines:
        match = re.match(r"^  ([A-Za-z0-9_.-]+\.json): \|-?$", line)
        if match:
            flush()
            current_name = match.group(1)
            continue

        if current_name is not None:
            if line.startswith("    "):
                current.append(line[4:])
                continue
            if not line.strip():
                current.append("")
                continue
            flush()

    flush()
    return blocks


def main() -> int:
    total = 0
    for manifest in MANIFESTS:
        text = manifest.read_text(encoding="utf-8")
        if "user=root" in text and "mysqld-exporter" in text:
            raise SystemExit(f"{manifest}: embedded exporter must not use root credentials")
        if "--collect.info_schema.innodb_metrics" not in text:
            raise SystemExit(f"{manifest}: missing InnoDB collector")
        if "--collect.info_schema.processlist" not in text:
            raise SystemExit(f"{manifest}: missing processlist collector")
        if "--collect.binlog_size" not in text:
            raise SystemExit(f"{manifest}: missing binlog_size collector")

        blocks = extract_json_blocks(manifest)
        if not blocks:
            raise SystemExit(f"{manifest}: no Grafana JSON blocks found")
        for name, raw in blocks.items():
            try:
                json.loads(raw)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"{manifest}:{name}: invalid JSON: {exc}") from exc
            total += 1

    images = json.loads((ROOT / "images" / "image.json").read_text(encoding="utf-8"))
    image_refs = {item["tag"] for item in images}
    for arch in ("amd64", "arm64"):
        expected_mysql = "sealos.hub:5000/kube4/mysql:8.0.46"
        expected_exporter = "sealos.hub:5000/kube4/mysqld-exporter:v0.19.0"
        arch_tags = {item["tag"] for item in images if item["arch"] == arch}
        if expected_mysql not in arch_tags or expected_exporter not in arch_tags:
            raise SystemExit(f"images/image.json: {arch} is missing MySQL 8.0.46 or exporter v0.19.0")

    print(f"validated {total} Grafana dashboard JSON block(s) and monitoring invariants")
    return 0


if __name__ == "__main__":
    sys.exit(main())
