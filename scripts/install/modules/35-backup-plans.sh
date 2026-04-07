trim_string() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}


normalize_csv_list() {
  local raw="${1:-}"
  local normalized=()
  local item

  raw="${raw//|/,}"
  IFS=',' read -r -a items <<< "${raw}"
  for item in "${items[@]}"; do
    item="$(trim_string "${item}")"
    [[ -n "${item}" ]] || continue
    normalized+=("${item}")
  done

  (IFS=,; printf '%s' "${normalized[*]}")
}


backup_plan_parser_python() {
  if command -v python3 >/dev/null 2>&1; then
    echo "python3"
    return 0
  fi

  if command -v python >/dev/null 2>&1; then
    echo "python"
    return 0
  fi

  return 1
}


backup_plan_file_parse_lines() {
  local config_path="$1"
  local python_cmd

  python_cmd="$(backup_plan_parser_python)" || die "使用 --backup-plan-file 需要 python3 或 python"
  "${python_cmd}" - "${config_path}" <<'PY'
from __future__ import annotations

import json
import pathlib
import re
import sys


def strip_comments(line: str) -> str:
    in_single = False
    in_double = False
    escaped = False
    result = []

    for ch in line:
        if escaped:
            result.append(ch)
            escaped = False
            continue
        if ch == "\\":
            result.append(ch)
            escaped = True
            continue
        if ch == "'" and not in_double:
            in_single = not in_single
            result.append(ch)
            continue
        if ch == '"' and not in_single:
            in_double = not in_double
            result.append(ch)
            continue
        if ch == "#" and not in_single and not in_double:
            break
        result.append(ch)

    return "".join(result).rstrip()


def parse_scalar(value: str):
    raw = value.strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in ("'", '"'):
        raw = raw[1:-1]
    lowered = raw.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if lowered in ("null", "none"):
        return None
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    return raw


def parse_key_value(text: str):
    if ":" not in text:
        raise ValueError(f"invalid line: {text}")
    key, value = text.split(":", 1)
    return key.strip(), value.strip()


def parse_yaml(text: str):
    prepared = []
    for raw in text.splitlines():
        cleaned = strip_comments(raw)
        if not cleaned.strip():
            continue
        indent = len(cleaned) - len(cleaned.lstrip(" "))
        if indent % 2:
            raise ValueError("YAML indentation must use multiples of 2 spaces")
        prepared.append((indent, cleaned.lstrip()))

    def parse_scalar_map(start_index: int, indent: int):
        mapping = {}
        index = start_index
        while index < len(prepared):
            current_indent, content = prepared[index]
            if current_indent < indent:
                break
            if current_indent != indent or content.startswith("- "):
                raise ValueError(f"invalid map entry near: {content}")

            key, rest = parse_key_value(content)
            index += 1
            if rest:
              mapping[key] = parse_scalar(rest)
              continue

            items = []
            while index < len(prepared):
                child_indent, child_content = prepared[index]
                if child_indent < indent + 2:
                    break
                if child_indent != indent + 2 or not child_content.startswith("- "):
                    raise ValueError(f"expected list item for {key}")
                items.append(parse_scalar(child_content[2:].strip()))
                index += 1
            mapping[key] = items

        return mapping, index

    def parse_plan_list(start_index: int, indent: int):
        plans = []
        index = start_index
        while index < len(prepared):
            current_indent, content = prepared[index]
            if current_indent < indent:
                break
            if current_indent != indent or not content.startswith("- "):
                raise ValueError(f"invalid plan entry near: {content}")

            item = {}
            inline = content[2:].strip()
            if inline:
                key, rest = parse_key_value(inline)
                item[key] = parse_scalar(rest)
            index += 1

            while index < len(prepared):
                child_indent, child_content = prepared[index]
                if child_indent <= indent:
                    break
                if child_indent != indent + 2:
                    raise ValueError(f"invalid plan child near: {child_content}")

                key, rest = parse_key_value(child_content)
                index += 1
                if rest:
                    item[key] = parse_scalar(rest)
                    continue

                values = []
                while index < len(prepared):
                    list_indent, list_content = prepared[index]
                    if list_indent < indent + 4:
                        break
                    if list_indent != indent + 4 or not list_content.startswith("- "):
                        raise ValueError(f"expected list entry for {key}")
                    values.append(parse_scalar(list_content[2:].strip()))
                    index += 1
                item[key] = values

            plans.append(item)

        return plans, index

    data = {}
    index = 0
    while index < len(prepared):
        indent, content = prepared[index]
        if indent != 0:
            raise ValueError(f"invalid top-level entry near: {content}")
        key, rest = parse_key_value(content)
        index += 1
        if rest:
            data[key] = parse_scalar(rest)
            continue

        if key in ("plans", "backupPlans"):
            plans, index = parse_plan_list(index, 2)
            data["plans"] = plans
        elif key == "defaults":
            defaults, index = parse_scalar_map(index, 2)
            data["defaults"] = defaults
        elif key == "defaultPlan":
            default_plan, index = parse_scalar_map(index, 2)
            data["defaultPlan"] = default_plan
        else:
            raise ValueError(f"unsupported YAML section: {key}")

    return data


def ensure_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def normalize_scalar(value):
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def normalize_list(value):
    items = []
    for item in ensure_list(value):
        item_text = normalize_scalar(item).strip()
        if item_text:
            items.append(item_text)
    return ",".join(items)


def load_config(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    suffix = path.suffix.lower()

    if suffix == ".json":
        return json.loads(text)

    if suffix in (".yaml", ".yml"):
        return parse_yaml(text)

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return parse_yaml(text)


def serialize_plan(plan: dict) -> str:
    field_order = [
        "name",
        "storeName",
        "backend",
        "rootDir",
        "schedule",
        "retention",
        "nfsServer",
        "nfsPath",
        "s3Endpoint",
        "s3Bucket",
        "s3Prefix",
        "s3AccessKey",
        "s3SecretKey",
        "s3Insecure",
        "databases",
        "tables",
    ]

    encoded = []
    for key in field_order:
        value = plan.get(key)
        if key in ("databases", "tables"):
            encoded.append(f"{key}={normalize_list(value)}")
        else:
            encoded.append(f"{key}={normalize_scalar(value)}")
    return ";".join(encoded)


config_path = pathlib.Path(sys.argv[1])
config = load_config(config_path)
if not isinstance(config, dict):
    raise SystemExit("backup plan file root must be an object")

defaults = config.get("defaults") or {}
if defaults and not isinstance(defaults, dict):
    raise SystemExit("defaults must be an object")

default_plan = config.get("defaultPlan") or {}
if default_plan and not isinstance(default_plan, dict):
    raise SystemExit("defaultPlan must be an object")

default_plan_enabled = config.get("defaultPlanEnabled")
if default_plan_enabled is None and "enabled" in default_plan:
    default_plan_enabled = default_plan.get("enabled")

restore_source = config.get("restoreSource")
plans = config.get("plans") or config.get("backupPlans") or []
if not isinstance(plans, list):
    raise SystemExit("plans must be a list")

if default_plan_enabled is not None:
    print(f"meta defaultPlanEnabled {normalize_scalar(default_plan_enabled)}")
if restore_source is not None:
    print(f"meta restoreSource {normalize_scalar(restore_source)}")

for raw_plan in plans:
    if not isinstance(raw_plan, dict):
        raise SystemExit("each plan must be an object")
    merged = dict(defaults)
    merged.update(raw_plan)
    print("spec " + serialize_plan(merged))
PY
}


load_backup_plan_file_if_requested() {
  local config_path line
  local -a cli_specs=()
  local -a loaded_specs=()

  [[ -n "${BACKUP_PLAN_FILE}" ]] || return 0
  [[ -f "${BACKUP_PLAN_FILE}" ]] || die "backup plan file 不存在: ${BACKUP_PLAN_FILE}"

  config_path="${BACKUP_PLAN_FILE}"
  cli_specs=("${BACKUP_PLAN_EXTRA_SPECS[@]}")
  BACKUP_PLAN_EXTRA_SPECS=()

  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -n "${line}" ]] || continue
    case "${line}" in
      meta\ defaultPlanEnabled\ *)
        if [[ "${BACKUP_DEFAULT_PLAN_ENABLED_EXPLICIT}" != "true" ]]; then
          BACKUP_DEFAULT_PLAN_ENABLED="${line#meta defaultPlanEnabled }"
        fi
        ;;
      meta\ restoreSource\ *)
        if [[ "${BACKUP_RESTORE_SOURCE_EXPLICIT}" != "true" ]]; then
          BACKUP_RESTORE_SOURCE="${line#meta restoreSource }"
        fi
        ;;
      spec\ *)
        loaded_specs+=("${line#spec }")
        ;;
      *)
        die "无法识别 backup plan file 输出: ${line}"
        ;;
    esac
  done < <(backup_plan_file_parse_lines "${config_path}")

  BACKUP_PLAN_EXTRA_SPECS=("${loaded_specs[@]}" "${cli_specs[@]}")
}


capture_default_backup_plan_settings() {
  [[ "${BACKUP_PLAN_DEFAULTS_CAPTURED}" == "true" ]] && return 0

  BACKUP_PLAN_DEFAULT_NAME="${BACKUP_PLAN_NAME:-primary}"
  BACKUP_PLAN_DEFAULT_STORE_NAME="${BACKUP_STORE_NAME:-${BACKUP_PLAN_DEFAULT_NAME}}"
  BACKUP_PLAN_DEFAULT_BACKEND="${BACKUP_BACKEND}"
  BACKUP_PLAN_DEFAULT_NFS_SERVER="${BACKUP_NFS_SERVER}"
  BACKUP_PLAN_DEFAULT_NFS_PATH="${BACKUP_NFS_PATH}"
  BACKUP_PLAN_DEFAULT_ROOT_DIR="${BACKUP_ROOT_DIR}"
  BACKUP_PLAN_DEFAULT_SCHEDULE="${BACKUP_SCHEDULE}"
  BACKUP_PLAN_DEFAULT_RETENTION="${BACKUP_RETENTION}"
  BACKUP_PLAN_DEFAULT_S3_ENDPOINT="${S3_ENDPOINT}"
  BACKUP_PLAN_DEFAULT_S3_BUCKET="${S3_BUCKET}"
  BACKUP_PLAN_DEFAULT_S3_PREFIX="${S3_PREFIX}"
  BACKUP_PLAN_DEFAULT_S3_ACCESS_KEY="${S3_ACCESS_KEY}"
  BACKUP_PLAN_DEFAULT_S3_SECRET_KEY="${S3_SECRET_KEY}"
  BACKUP_PLAN_DEFAULT_S3_INSECURE="${S3_INSECURE}"
  BACKUP_PLAN_DEFAULT_CRONJOB_NAME="${BACKUP_CRONJOB_NAME}"
  BACKUP_PLAN_DEFAULT_STORAGE_SECRET="${BACKUP_STORAGE_SECRET}"
  BACKUP_PLAN_DEFAULT_DATABASES="${BACKUP_DATABASES}"
  BACKUP_PLAN_DEFAULT_TABLES="${BACKUP_TABLES}"
  BACKUP_PLAN_DEFAULTS_CAPTURED="true"
}


backup_plan_reset_active() {
  capture_default_backup_plan_settings

  BACKUP_PLAN_NAME="${BACKUP_PLAN_DEFAULT_NAME}"
  BACKUP_STORE_NAME="${BACKUP_PLAN_DEFAULT_STORE_NAME}"
  BACKUP_BACKEND="${BACKUP_PLAN_DEFAULT_BACKEND}"
  BACKUP_NFS_SERVER="${BACKUP_PLAN_DEFAULT_NFS_SERVER}"
  BACKUP_NFS_PATH="${BACKUP_PLAN_DEFAULT_NFS_PATH}"
  BACKUP_ROOT_DIR="${BACKUP_PLAN_DEFAULT_ROOT_DIR}"
  BACKUP_SCHEDULE="${BACKUP_PLAN_DEFAULT_SCHEDULE}"
  BACKUP_RETENTION="${BACKUP_PLAN_DEFAULT_RETENTION}"
  S3_ENDPOINT="${BACKUP_PLAN_DEFAULT_S3_ENDPOINT}"
  S3_BUCKET="${BACKUP_PLAN_DEFAULT_S3_BUCKET}"
  S3_PREFIX="${BACKUP_PLAN_DEFAULT_S3_PREFIX}"
  S3_ACCESS_KEY="${BACKUP_PLAN_DEFAULT_S3_ACCESS_KEY}"
  S3_SECRET_KEY="${BACKUP_PLAN_DEFAULT_S3_SECRET_KEY}"
  S3_INSECURE="${BACKUP_PLAN_DEFAULT_S3_INSECURE}"
  BACKUP_CRONJOB_NAME="${BACKUP_PLAN_DEFAULT_CRONJOB_NAME}"
  BACKUP_STORAGE_SECRET="${BACKUP_PLAN_DEFAULT_STORAGE_SECRET}"
  BACKUP_DATABASES="${BACKUP_PLAN_DEFAULT_DATABASES}"
  BACKUP_TABLES="${BACKUP_PLAN_DEFAULT_TABLES}"
}


backup_plan_scope_type() {
  if [[ -n "${BACKUP_TABLES}" ]]; then
    echo "tables"
  elif [[ -n "${BACKUP_DATABASES}" ]]; then
    echo "databases"
  else
    echo "all"
  fi
}


backup_plan_apply_derived_names() {
  local normalized_name normalized_store

  normalized_name="$(sanitize_target_name "${BACKUP_PLAN_NAME}")"
  [[ -n "${normalized_name}" ]] || die "backup plan name 不能为空"
  BACKUP_PLAN_NAME="${normalized_name}"

  if [[ -n "${BACKUP_STORE_NAME}" ]]; then
    normalized_store="$(sanitize_target_name "${BACKUP_STORE_NAME}")"
  else
    normalized_store="${BACKUP_PLAN_NAME}"
  fi
  [[ -n "${normalized_store}" ]] || die "backup store name 不能为空"
  BACKUP_STORE_NAME="${normalized_store}"

  if [[ "${BACKUP_PLAN_NAME}" == "${BACKUP_PLAN_DEFAULT_NAME}" ]]; then
    BACKUP_CRONJOB_NAME="${BACKUP_PLAN_DEFAULT_CRONJOB_NAME}"
    BACKUP_STORAGE_SECRET="${BACKUP_PLAN_DEFAULT_STORAGE_SECRET}"
  else
    BACKUP_CRONJOB_NAME="${BACKUP_PLAN_DEFAULT_CRONJOB_NAME}-${BACKUP_PLAN_NAME}"
    BACKUP_STORAGE_SECRET="${BACKUP_PLAN_DEFAULT_STORAGE_SECRET}-${BACKUP_PLAN_NAME}"
  fi
}


backup_plan_validate_active() {
  local schedule_required="${1:-false}"
  local entry database_name table_name

  [[ "${BACKUP_BACKEND}" == "nfs" || "${BACKUP_BACKEND}" == "s3" ]] || die "backup plan ${BACKUP_PLAN_NAME} 的 backend 仅支持 nfs 或 s3"
  [[ "${BACKUP_RETENTION}" =~ ^[0-9]+$ ]] || die "backup plan ${BACKUP_PLAN_NAME} 的 retention 必须是数字"

  if [[ "${schedule_required}" == "true" && -z "${BACKUP_SCHEDULE}" ]]; then
    die "backup plan ${BACKUP_PLAN_NAME} 缺少 schedule"
  fi

  if [[ -n "${BACKUP_DATABASES}" && -n "${BACKUP_TABLES}" ]]; then
    die "backup plan ${BACKUP_PLAN_NAME} 不能同时指定 databases 和 tables"
  fi

  if [[ "${BACKUP_BACKEND}" == "nfs" ]]; then
    [[ -n "${BACKUP_NFS_SERVER}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 NFS 时必须提供 nfsServer"
    [[ -n "${BACKUP_NFS_PATH}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 NFS 时必须提供 nfsPath"
  fi

  if [[ "${BACKUP_BACKEND}" == "s3" ]]; then
    [[ -n "${S3_ENDPOINT}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 S3 时必须提供 s3Endpoint"
    [[ -n "${S3_BUCKET}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 S3 时必须提供 s3Bucket"
    [[ -n "${S3_ACCESS_KEY}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 S3 时必须提供 s3AccessKey"
    [[ -n "${S3_SECRET_KEY}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 S3 时必须提供 s3SecretKey"
  fi

  if [[ -n "${BACKUP_TABLES}" ]]; then
    IFS=',' read -r -a entries <<< "${BACKUP_TABLES}"
    for entry in "${entries[@]}"; do
      entry="$(trim_string "${entry}")"
      [[ -n "${entry}" ]] || continue
      database_name="${entry%%.*}"
      table_name="${entry#*.}"
      [[ -n "${database_name}" && -n "${table_name}" && "${database_name}" != "${entry}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 的 tables 需使用 db.table 形式: ${entry}"
    done
  fi
}


backup_plan_serialize_active() {
  printf 'name=%s;storeName=%s;backend=%s;rootDir=%s;schedule=%s;retention=%s;nfsServer=%s;nfsPath=%s;s3Endpoint=%s;s3Bucket=%s;s3Prefix=%s;s3AccessKey=%s;s3SecretKey=%s;s3Insecure=%s;databases=%s;tables=%s' \
    "${BACKUP_PLAN_NAME}" \
    "${BACKUP_STORE_NAME}" \
    "${BACKUP_BACKEND}" \
    "${BACKUP_ROOT_DIR}" \
    "${BACKUP_SCHEDULE}" \
    "${BACKUP_RETENTION}" \
    "${BACKUP_NFS_SERVER}" \
    "${BACKUP_NFS_PATH}" \
    "${S3_ENDPOINT}" \
    "${S3_BUCKET}" \
    "${S3_PREFIX}" \
    "${S3_ACCESS_KEY}" \
    "${S3_SECRET_KEY}" \
    "${S3_INSECURE}" \
    "${BACKUP_DATABASES}" \
    "${BACKUP_TABLES}"
}


backup_plan_activate_spec() {
  local raw_spec="$1"
  local part key value
  local store_name_explicit="false"

  backup_plan_reset_active
  [[ -n "${raw_spec}" ]] || {
    backup_plan_apply_derived_names
    return 0
  }

  IFS=';' read -r -a parts <<< "${raw_spec}"
  for part in "${parts[@]}"; do
    part="$(trim_string "${part}")"
    [[ -n "${part}" ]] || continue
    [[ "${part}" == *=* ]] || die "backup plan 配置格式错误: ${part}"
    key="$(trim_string "${part%%=*}")"
    value="$(trim_string "${part#*=}")"

    case "${key}" in
      name)
        BACKUP_PLAN_NAME="${value}"
        ;;
      storeName|store|store-name)
        BACKUP_STORE_NAME="${value}"
        store_name_explicit="true"
        ;;
      type|backend)
        BACKUP_BACKEND="${value}"
        ;;
      rootDir|root|root-dir)
        BACKUP_ROOT_DIR="${value}"
        ;;
      schedule)
        BACKUP_SCHEDULE="${value}"
        ;;
      retention)
        BACKUP_RETENTION="${value}"
        ;;
      nfsServer|nfs-server)
        BACKUP_NFS_SERVER="${value}"
        ;;
      nfsPath|nfs-path)
        BACKUP_NFS_PATH="${value}"
        ;;
      s3Endpoint|s3-endpoint)
        S3_ENDPOINT="${value}"
        ;;
      s3Bucket|s3-bucket)
        S3_BUCKET="${value}"
        ;;
      s3Prefix|s3-prefix)
        S3_PREFIX="${value}"
        ;;
      s3AccessKey|s3-access-key)
        S3_ACCESS_KEY="${value}"
        ;;
      s3SecretKey|s3-secret-key)
        S3_SECRET_KEY="${value}"
        ;;
      s3Insecure|s3-insecure)
        S3_INSECURE="${value}"
        ;;
      databases|dbs)
        BACKUP_DATABASES="$(normalize_csv_list "${value}")"
        ;;
      tables)
        BACKUP_TABLES="$(normalize_csv_list "${value}")"
        ;;
      *)
        die "backup plan ${raw_spec} 中存在未知字段: ${key}"
        ;;
    esac
  done

  BACKUP_DATABASES="$(normalize_csv_list "${BACKUP_DATABASES}")"
  BACKUP_TABLES="$(normalize_csv_list "${BACKUP_TABLES}")"
  if [[ -n "${raw_spec}" && "${store_name_explicit}" != "true" ]]; then
    BACKUP_STORE_NAME=""
  fi
  backup_plan_apply_derived_names
}


backup_plan_catalog_required() {
  case "${ACTION}" in
    install)
      [[ "${BACKUP_ENABLED}" == "true" ]]
      ;;
    addon-install)
      addon_selected backup
      ;;
    backup|restore|verify-backup-restore)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}


backup_plan_default_requested() {
  [[ "${BACKUP_DEFAULT_PLAN_ENABLED}" == "true" || ${#BACKUP_PLAN_EXTRA_SPECS[@]} -eq 0 ]]
}


backup_plan_default_spec() {
  backup_plan_activate_spec ""
  printf '%s' "$(backup_plan_serialize_active)"
}


backup_plan_build_catalog() {
  local spec normalized_spec
  local existing_name

  BACKUP_PLAN_CATALOG=()
  BACKUP_PLAN_NAMES=()

  backup_plan_catalog_required || return 0

  if [[ "${BACKUP_DEFAULT_PLAN_ENABLED}" == "true" || ${#BACKUP_PLAN_EXTRA_SPECS[@]} -eq 0 ]]; then
    normalized_spec="$(backup_plan_default_spec)"
    BACKUP_PLAN_CATALOG+=("${normalized_spec}")
    BACKUP_PLAN_NAMES+=("${BACKUP_PLAN_NAME}")
  fi

  for spec in "${BACKUP_PLAN_EXTRA_SPECS[@]}"; do
    backup_plan_activate_spec "${spec}"
    normalized_spec="$(backup_plan_serialize_active)"

    for existing_name in "${BACKUP_PLAN_NAMES[@]}"; do
      [[ "${existing_name}" != "${BACKUP_PLAN_NAME}" ]] || die "backup plan name 重复: ${BACKUP_PLAN_NAME}"
    done

    BACKUP_PLAN_CATALOG+=("${normalized_spec}")
    BACKUP_PLAN_NAMES+=("${BACKUP_PLAN_NAME}")
  done

  (( ${#BACKUP_PLAN_CATALOG[@]} > 0 )) || die "未找到可用的 backup plan，请提供默认备份配置，或通过 --backup-plan 显式定义"
  backup_plan_activate_spec "${BACKUP_PLAN_CATALOG[0]}"
}


backup_plan_validate_catalog() {
  local spec
  local schedule_required="false"

  backup_schedule_required && schedule_required="true"
  backup_plan_build_catalog

  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    backup_plan_validate_active "${schedule_required}"
  done

  if [[ "${ACTION}" == "restore" || "${ACTION}" == "verify-backup-restore" ]]; then
    if [[ "${BACKUP_RESTORE_SOURCE}" != "auto" ]]; then
      backup_plan_spec_by_name "${BACKUP_RESTORE_SOURCE}" >/dev/null || die "未找到 restore-source=${BACKUP_RESTORE_SOURCE} 对应的 backup plan"
    fi
  fi

  if (( ${#BACKUP_PLAN_CATALOG[@]} > 0 )); then
    backup_plan_activate_spec "${BACKUP_PLAN_CATALOG[0]}"
  fi
}


backup_plan_spec_by_name() {
  local plan_name="$1"
  local index

  backup_plan_build_catalog
  for ((index=0; index<${#BACKUP_PLAN_NAMES[@]}; index++)); do
    if [[ "${BACKUP_PLAN_NAMES[$index]}" == "${plan_name}" ]]; then
      printf '%s' "${BACKUP_PLAN_CATALOG[$index]}"
      return 0
    fi
  done

  return 1
}


backup_plan_specs_for_restore() {
  local spec

  backup_plan_build_catalog
  if [[ "${BACKUP_RESTORE_SOURCE}" == "auto" ]]; then
    printf '%s\n' "${BACKUP_PLAN_CATALOG[@]}"
    return 0
  fi

  spec="$(backup_plan_spec_by_name "${BACKUP_RESTORE_SOURCE}")" || return 1
  printf '%s\n' "${spec}"
}


backup_plan_any_uses_backend() {
  local backend_name="$1"
  local spec

  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    if [[ "${BACKUP_BACKEND}" == "${backend_name}" ]]; then
      return 0
    fi
  done

  return 1
}


csv_list_contains() {
  local csv_list="$1"
  local expected="$2"
  local item

  IFS=',' read -r -a items <<< "${csv_list}"
  for item in "${items[@]}"; do
    item="$(trim_string "${item}")"
    [[ -n "${item}" ]] || continue
    [[ "${item}" == "${expected}" ]] && return 0
  done

  return 1
}


backup_plan_supports_wipe_restore() {
  [[ "$(backup_plan_scope_type)" == "all" ]]
}


backup_plan_contains_database() {
  local database_name="$1"
  local scope_type

  scope_type="$(backup_plan_scope_type)"
  case "${scope_type}" in
    all)
      return 0
      ;;
    databases)
      csv_list_contains "${BACKUP_DATABASES}" "${database_name}"
      return
      ;;
    tables)
      local item
      IFS=',' read -r -a items <<< "${BACKUP_TABLES}"
      for item in "${items[@]}"; do
        item="$(trim_string "${item}")"
        [[ -n "${item}" ]] || continue
        [[ "${item}" == "${database_name}."* ]] && return 0
      done
      ;;
  esac

  return 1
}


backup_plan_contains_table() {
  local table_selector="$1"
  local database_name="${table_selector%%.*}"

  if [[ "$(backup_plan_scope_type)" == "all" ]]; then
    return 0
  fi

  if [[ "$(backup_plan_scope_type)" == "databases" ]]; then
    csv_list_contains "${BACKUP_DATABASES}" "${database_name}"
    return
  fi

  csv_list_contains "${BACKUP_TABLES}" "${table_selector}"
}


backup_plan_supports_verify_marker() {
  backup_plan_contains_table "offline_validation.backup_restore_check" && return 0
  backup_plan_contains_database "offline_validation"
}


backup_plan_scope_summary() {
  case "$(backup_plan_scope_type)" in
    all)
      echo "all"
      ;;
    databases)
      echo "databases:${BACKUP_DATABASES}"
      ;;
    tables)
      echo "tables:${BACKUP_TABLES}"
      ;;
  esac
}


backup_plan_summary_lines() {
  local spec
  local index=1

  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    printf '  %s. %s | backend=%s | store=%s | schedule=%s | scope=%s\n' \
      "${index}" \
      "${BACKUP_PLAN_NAME}" \
      "${BACKUP_BACKEND}" \
      "${BACKUP_STORE_NAME}" \
      "${BACKUP_SCHEDULE:-manual-only}" \
      "$(backup_plan_scope_summary)"
    index=$((index + 1))
  done
}
