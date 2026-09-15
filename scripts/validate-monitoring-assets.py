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
HEADER_MODULE = ROOT / "scripts" / "install" / "modules" / "00-header.sh"
BASE_HELP_MODULE = ROOT / "scripts" / "install" / "modules" / "20-help.sh"
HELP_MODULE = ROOT / "scripts" / "install" / "modules" / "22-help-mysql84.sh"
RESOURCE_PROFILE_MODULE = ROOT / "scripts" / "install" / "modules" / "45-resource-profiles.sh"
STORAGE_RECONCILE_MODULE = ROOT / "scripts" / "install" / "modules" / "57-storage-reconcile.sh"
BOOTSTRAP_MODULE = ROOT / "scripts" / "install" / "modules" / "65-monitoring-bootstrap.sh"
LIFECYCLE_MODULE = ROOT / "scripts" / "install" / "modules" / "75-mysql84-install.sh"
RENDER_MODULE = ROOT / "scripts" / "install" / "modules" / "55-delivery-render.sh"
ARGS_MODULE = ROOT / "scripts" / "install" / "modules" / "30-args.sh"
README = ROOT / "README.md"
BASELINE_DOC = ROOT / "docs" / "MYSQL-8.4-BASELINE.md"


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


def require_text(path: pathlib.Path, required_items: tuple[str, ...], label: str) -> None:
    text = path.read_text(encoding="utf-8")
    for required in required_items:
        if required not in text:
            raise SystemExit(f"{path}: missing {label}: {required}")


def reject_legacy_resource_profile_aliases() -> None:
    """Keep one delivery vocabulary: lite / standard / large only."""
    profile_source = RESOURCE_PROFILE_MODULE.read_text(encoding="utf-8")
    for legacy_case in (
        "lite|small",
        "compact|low",
        "standard|mid",
        "midd|middle",
        "medium)",
        "large|high",
    ):
        if legacy_case in profile_source:
            raise SystemExit(
                f"{RESOURCE_PROFILE_MODULE}: legacy resource-profile alias remains: {legacy_case}"
            )

    docs_and_help = {
        BASE_HELP_MODULE: BASE_HELP_MODULE.read_text(encoding="utf-8"),
        HELP_MODULE: HELP_MODULE.read_text(encoding="utf-8"),
        README: README.read_text(encoding="utf-8"),
        BASELINE_DOC: BASELINE_DOC.read_text(encoding="utf-8"),
    }
    forbidden_phrases = (
        "low -> lite",
        "low=lite",
        "mid / midd",
        "mid/midd",
        "high -> large",
        "high=large",
        "支持 low|mid",
        "兼容别名",
        "兼容旧参数",
    )
    for path, text in docs_and_help.items():
        for phrase in forbidden_phrases:
            if phrase in text:
                raise SystemExit(f"{path}: legacy resource-profile terminology remains: {phrase}")


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

    require_text(
        RUNTIME_CONFIG,
        (
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
        ),
        "required runtime setting",
    )

    require_text(
        CORE_MANIFEST,
        (
            "startupProbe:",
            "failureThreshold: 60",
            "terminationGracePeriodSeconds: 120",
            "automountServiceAccountToken: false",
            "enableServiceLinks: false",
            "sizeLimit: __MYSQL_LOG_SIZE_LIMIT__",
            "cpu: __MYSQL_REQUEST_CPU__",
            "memory: __MYSQL_REQUEST_MEM__",
            "cpu: __MYSQL_LIMIT_CPU__",
            "memory: __MYSQL_LIMIT_MEM__",
            "storage: __STORAGE_SIZE__",
        ),
        "delivery hardening/resource setting",
    )

    all_manifest_text = "\n".join(
        p.read_text(encoding="utf-8") for p in (ROOT / "manifests").glob("*.yaml")
    )
    for legacy in ("mysqlhealthchecker", "localroot", "health@passw0rd", "local@paasw0rd", "local-infile=1"):
        if legacy in all_manifest_text:
            raise SystemExit(f"manifests: legacy artifact remains: {legacy}")
    if (ROOT / "manifests" / "innodb-mysql.yaml").exists():
        raise SystemExit("manifests/innodb-mysql.yaml: legacy combined manifest must be removed")

    require_text(
        HEADER_MODULE,
        (
            'RESOURCE_PROFILE="standard"',
            'STORAGE_CLASS=""',
            'STORAGE_SIZE=""',
            'STORAGE_CLASS_EXPLICIT="false"',
            'STORAGE_SIZE_EXPLICIT="false"',
        ),
        "resource profile default",
    )

    require_text(
        RESOURCE_PROFILE_MODULE,
        (
            "lite)",
            'RESOURCE_PROFILE="lite"',
            'MYSQL_LIMIT_CPU MYSQL_LIMIT_CPU_EXPLICIT "1"',
            'MYSQL_LIMIT_MEM MYSQL_LIMIT_MEM_EXPLICIT "2Gi"',
            'MYSQL_INNODB_BUFFER_POOL_SIZE="1G"',
            'STORAGE_SIZE="20Gi"',
            "standard)",
            'RESOURCE_PROFILE="standard"',
            'MYSQL_LIMIT_CPU MYSQL_LIMIT_CPU_EXPLICIT "2"',
            'MYSQL_LIMIT_MEM MYSQL_LIMIT_MEM_EXPLICIT "8Gi"',
            'MYSQL_INNODB_BUFFER_POOL_SIZE="5G"',
            'STORAGE_SIZE="100Gi"',
            "large)",
            'RESOURCE_PROFILE="large"',
            'MYSQL_LIMIT_CPU MYSQL_LIMIT_CPU_EXPLICIT "4"',
            'MYSQL_LIMIT_MEM MYSQL_LIMIT_MEM_EXPLICIT "16Gi"',
            'MYSQL_INNODB_BUFFER_POOL_SIZE="10G"',
            'STORAGE_SIZE="500Gi"',
            "resource-profile 仅支持 lite|standard|large",
            "不会因 resource-profile 自动改盘",
            "不能通过 reconcile 原地改为",
        ),
        "canonical resource profile invariant",
    )
    reject_legacy_resource_profile_aliases()

    require_text(
        STORAGE_RECONCILE_MODULE,
        (
            "volumeClaimTemplates is immutable",
            "kubectl patch pvc",
            "allowVolumeExpansion=true",
            "PVC 不支持缩容",
        ),
        "safe PVC resize behavior",
    )

    require_text(
        HELP_MODULE,
        (
            "lite      精简模式",
            "standard  标准模式",
            "large     大规格模式",
            "2C/8Gi",
            "1C/2Gi",
            "4C/16Gi",
            "PVC 默认 100Gi",
            "PVC 默认 20Gi",
            "PVC 默认 500Gi",
            "只接受 lite / standard / large",
        ),
        "resource profile help",
    )

    require_text(
        BOOTSTRAP_MODULE,
        (
            "reconcile_remote_root_user",
            "prune_remote_root_users",
            "host <> 'localhost'",
            "IDENTIFIED WITH mysql_native_password",
            "GRANT ALL PRIVILEGES ON *.*",
            "sync_install_root_secret",
            "sync_embedded_exporter_secret",
            "检测到现有 StatefulSet/${STS_NAME}",
        ),
        "remote-root/credential reconciliation logic",
    )

    require_text(
        LIFECYCLE_MODULE,
        (
            "sync_install_root_secret",
            "sync_embedded_exporter_secret",
            "apply_mysql_runtime_config",
            "apply_mysql_observability_manifests",
            'if [[ "${DELETE_PVC}" == "true" ]]',
            'Secret/${AUTH_SECRET} 已保留',
        ),
        "safe lifecycle behavior",
    )

    require_text(
        RENDER_MODULE,
        (
            "strip_embedded_exporter_secret",
            "__MYSQL_INNODB_BUFFER_POOL_SIZE__",
            "__MYSQL_LOG_SIZE_LIMIT__",
        ),
        "safe rendering behavior",
    )

    args = ARGS_MODULE.read_text(encoding="utf-8")
    if "mysql:8.0.46" in args or "mysql:8.0.45" in args:
        raise SystemExit(f"{ARGS_MODULE}: obsolete MySQL 8.0 registry rewrite remains")
    if 'MYSQL_IMAGE="${REGISTRY_REPO}/mysql:8.4.11"' not in args:
        raise SystemExit(f"{ARGS_MODULE}: --registry must resolve MySQL 8.4.11")
    for flag in (
        "--enable-remote-root",
        "--disable-remote-root",
        "--root-remote-host",
        "--enable-native-password",
        "--disable-native-password",
        "--resource-profile",
        "--storage-class",
        "--storage-size",
        "--innodb-buffer-pool-size",
        "--mysql-log-size-limit",
    ):
        if flag not in args:
            raise SystemExit(f"{ARGS_MODULE}: missing delivery flag {flag}")

    images = json.loads((ROOT / "images" / "image.json").read_text(encoding="utf-8"))
    for arch in ("amd64", "arm64"):
        expected_mysql = "sealos.hub:5000/kube4/mysql:8.4.11"
        expected_exporter = "sealos.hub:5000/kube4/mysqld-exporter:v0.19.0"
        arch_tags = {item["tag"] for item in images if item["arch"] == arch}
        if expected_mysql not in arch_tags or expected_exporter not in arch_tags:
            raise SystemExit(f"images/image.json: {arch} is missing MySQL 8.4.11 or exporter v0.19.0")

    print(
        f"validated {total} Grafana dashboard JSON block(s), MySQL 8.4 hardening, "
        "canonical resource profiles, storage reconcile, lifecycle safety and image BOM"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
