#!/usr/bin/env python3
"""Validate Grafana JSON blocks, image BOM and MySQL 8.4 delivery invariants."""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
DASHBOARD_MANIFESTS = [
    ROOT / "manifests" / "mysql-observability.yaml",
    ROOT / "manifests" / "mysql-addon-monitoring.yaml",
]
EXPORTER_MANIFESTS = [
    ROOT / "manifests" / "mysql-core.yaml",
    ROOT / "manifests" / "mysql-addon-monitoring.yaml",
]
RUNTIME_CONFIG = ROOT / "manifests" / "mysql-runtime-config.yaml"
CORE_MANIFEST = ROOT / "manifests" / "mysql-core.yaml"
BOOTSTRAP_MODULE = ROOT / "scripts" / "install" / "modules" / "65-monitoring-bootstrap.sh"
ARGS_MODULE = ROOT / "scripts" / "install" / "modules" / "30-args.sh"


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

    for manifest in EXPORTER_MANIFESTS:
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

    for manifest in DASHBOARD_MANIFESTS:
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
        "mysql_native_password=ON",
        "character_set_server=utf8mb4",
        "collation_server=utf8mb4_0900_ai_ci",
        "default_time_zone='+00:00'",
        "log_timestamps=UTC",
        "innodb_flush_log_at_trx_commit=1",
        "sync_binlog=1",
        "innodb_buffer_pool_size=__MYSQL_INNODB_BUFFER_POOL_SIZE__",
        "innodb_redo_log_capacity=1G",
        "performance_schema=ON",
        "binlog_format=ROW",
    )
    for setting in required_runtime_settings:
        if setting not in runtime:
            raise SystemExit(f"{RUNTIME_CONFIG}: missing required setting {setting}")

    core = CORE_MANIFEST.read_text(encoding="utf-8")
    for required in (
        "startupProbe:",
        "failureThreshold: 60",
        "terminationGracePeriodSeconds: 120",
        "automountServiceAccountToken: false",
        "sizeLimit: __MYSQL_LOG_SIZE_LIMIT__",
    ):
        if required not in core:
            raise SystemExit(f"{CORE_MANIFEST}: missing delivery hardening setting {required}")

    all_manifest_text = "\n".join(
        p.read_text(encoding="utf-8") for p in (ROOT / "manifests").glob("*.yaml")
    )
    for legacy in ("mysqlhealthchecker", "localroot", "health@passw0rd", "local@paasw0rd"):
        if legacy in all_manifest_text:
            raise SystemExit(f"manifests: legacy static-password artifact remains: {legacy}")

    bootstrap = BOOTSTRAP_MODULE.read_text(encoding="utf-8")
    for required in (
        "reconcile_remote_root_user",
        "IDENTIFIED WITH mysql_native_password",
        "GRANT ALL PRIVILEGES ON *.*",
        "DROP USER IF EXISTS 'root'@'%'",
    ):
        if required not in bootstrap:
            raise SystemExit(f"{BOOTSTRAP_MODULE}: missing remote-root reconciliation logic: {required}")

    args = ARGS_MODULE.read_text(encoding="utf-8")
    if "mysql:8.0.46" in args or "mysql:8.0.45" in args:
        raise SystemExit(f"{ARGS_MODULE}: obsolete MySQL 8.0 registry rewrite remains")
    if 'MYSQL_IMAGE="${REGISTRY_REPO}/mysql:8.4.11"' not in args:
        raise SystemExit(f"{ARGS_MODULE}: --registry must resolve MySQL 8.4.11")

    images = json.loads((ROOT / "images" / "image.json").read_text(encoding="utf-8"))
    for arch in ("amd64", "arm64"):
        expected_mysql = "sealos.hub:5000/kube4/mysql:8.4.11"
        expected_exporter = "sealos.hub:5000/kube4/mysqld-exporter:v0.19.0"
        arch_tags = {item["tag"] for item in images if item["arch"] == arch}
        if expected_mysql not in arch_tags or expected_exporter not in arch_tags:
            raise SystemExit(f"images/image.json: {arch} is missing MySQL 8.4.11 or exporter v0.19.0")

    print(
        f"validated {total} Grafana dashboard JSON block(s), MySQL 8.4 hardening, "
        "remote-root reconciliation and image BOM"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
