#!/usr/bin/env python3
"""Validate embedded Grafana JSON blocks, image BOM and MySQL runtime invariants."""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MONITORING_MANIFESTS = [
    ROOT / "manifests" / "innodb-mysql.yaml",
    ROOT / "manifests" / "mysql-addon-monitoring.yaml",
]
RUNTIME_CONFIG = ROOT / "manifests" / "mysql-runtime-config.yaml"


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
    for manifest in MONITORING_MANIFESTS:
        text = manifest.read_text(encoding="utf-8")
        if "user=root" in text and "mysqld-exporter" in text:
            raise SystemExit(f"{manifest}: exporter must not use root credentials")
        for collector in (
            "--collect.info_schema.innodb_metrics",
            "--collect.info_schema.processlist",
            "--collect.binlog_size",
        ):
            if collector not in text:
                raise SystemExit(f"{manifest}: missing collector {collector}")

        blocks = extract_json_blocks(manifest)
        if not blocks:
            raise SystemExit(f"{manifest}: no Grafana JSON blocks found")
        for name, raw in blocks.items():
            try:
                json.loads(raw)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"{manifest}:{name}: invalid JSON: {exc}") from exc
            total += 1

    runtime = RUNTIME_CONFIG.read_text(encoding="utf-8")
    required_runtime_settings = (
        "local_infile=OFF",
        "skip_name_resolve=ON",
        "mysqlx=0",
        "innodb_flush_log_at_trx_commit=1",
        "sync_binlog=1",
        "innodb_redo_log_capacity=1G",
        "performance_schema=ON",
        "binlog_format=ROW",
    )
    for setting in required_runtime_settings:
        if setting not in runtime:
            raise SystemExit(f"{RUNTIME_CONFIG}: missing required setting {setting}")
    if "mysqlhealthchecker" in runtime or "localroot" in runtime:
        raise SystemExit(f"{RUNTIME_CONFIG}: legacy static-password users must not be present")

    images = json.loads((ROOT / "images" / "image.json").read_text(encoding="utf-8"))
    for arch in ("amd64", "arm64"):
        expected_mysql = "sealos.hub:5000/kube4/mysql:8.4.11"
        expected_exporter = "sealos.hub:5000/kube4/mysqld-exporter:v0.19.0"
        arch_tags = {item["tag"] for item in images if item["arch"] == arch}
        if expected_mysql not in arch_tags or expected_exporter not in arch_tags:
            raise SystemExit(f"images/image.json: {arch} is missing MySQL 8.4.11 or exporter v0.19.0")

    print(f"validated {total} Grafana dashboard JSON block(s), MySQL 8.4 runtime config and image BOM")
    return 0


if __name__ == "__main__":
    sys.exit(main())
