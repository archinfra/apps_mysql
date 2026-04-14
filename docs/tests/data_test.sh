#!/usr/bin/env bash
#
# k8s_mysql_test_data.sh - 在 K8s MySQL 容器中生成测试数据，并验证备份恢复后的完备性
#
# 用法:
#   ./k8s_mysql_test_data.sh [选项]
#
# 选项:
#   -n, --namespace NAMESPACE   K8s 命名空间 (默认: default)
#   -p, --pod POD               MySQL Pod 名称 (必填)
#   -c, --container CONTAINER   MySQL 容器名称 (可选，不指定则交互式选择)
#   -u, --user USER             MySQL 用户名 (默认: root)
#   --password PASSWORD         MySQL 密码 (默认: 空)
#   --port PORT                 MySQL 容器内部端口 (默认: 3306，通常无需修改)
#   --db-prefix PREFIX          测试库名前缀 (默认: test_backup_)
#   --cleanup                   验证完成后删除测试库 (默认: 不删除)
#   -h, --help                  显示帮助信息
#
# 手动备份/恢复流程:
#   1. 脚本创建测试库、表、数据，并记录数据指纹。
#   2. 用户手动执行备份 (例如使用 mysqldump)。
#   3. 脚本自动删除测试库，模拟数据丢失。
#   4. 用户手动执行恢复。
#   5. 脚本重新计算指纹并与备份前对比，输出验证结果。
#
# 校验逻辑:
#   对每张表计算 (行数, 指定列校验和)，恢复后重新计算，比对是否一致。
#

set -euo pipefail

# 默认参数
NAMESPACE="default"
POD=""
CONTAINER=""
MYSQL_USER="root"
MYSQL_PASSWORD=""
MYSQL_PORT="3306"
DB_PREFIX="test_backup_"
DO_CLEANUP=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 帮助函数
show_help() {
    cat << EOF
用法: $0 [选项]

必需参数:
  -p, --pod POD            MySQL Pod 名称 (例如: mysql-0)

可选参数:
  -n, --namespace NS       K8s 命名空间 (默认: default)
  -c, --container NAME     MySQL 容器名称 (默认自动交互选择)
  -u, --user USER          MySQL 用户名 (默认: root)
  --password PASSWORD      MySQL 密码 (默认: 空)
  --port PORT              MySQL 容器内部端口 (默认: 3306，通常无需修改)
  --db-prefix PREFIX       测试库名前缀 (默认: test_backup_)
  --cleanup                验证完成后自动删除测试库 (默认: 保留)
  -h, --help               显示此帮助信息

示例:
  $0 -n myns -p mysql-0 -c mysql --password secret123
  $0 -p mysql-0 --db-prefix verify_ --cleanup

备份与恢复步骤 (脚本会在合适时机暂停):
  1. 脚本创建测试库、表、数据，并记录数据指纹。
  2. 手动执行备份 (例如使用 mysqldump)。
  3. 脚本自动删除测试库 (模拟数据丢失)。
  4. 手动执行恢复 (例如使用 mysql 客户端)。
  5. 脚本重新计算指纹并与备份前对比，输出验证结果。
EOF
    exit 0
}

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -p|--pod)
            POD="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER="$2"
            shift 2
            ;;
        -u|--user)
            MYSQL_USER="$2"
            shift 2
            ;;
        --password)
            MYSQL_PASSWORD="$2"
            shift 2
            ;;
        --port)
            MYSQL_PORT="$2"
            shift 2
            ;;
        --db-prefix)
            DB_PREFIX="$2"
            shift 2
            ;;
        --cleanup)
            DO_CLEANUP=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo -e "${RED}错误: 未知参数 $1${NC}"
            show_help
            ;;
    esac
done

# 检查必需参数
if [[ -z "$POD" ]]; then
    echo -e "${RED}错误: 必须指定 MySQL Pod 名称 (-p 或 --pod)${NC}"
    show_help
fi

# 检查 kubectl 可用性
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}错误: 未找到 kubectl 命令，请确保已安装并配置好 kubeconfig${NC}"
    exit 1
fi

# 检查 Pod 是否存在
if ! kubectl -n "$NAMESPACE" get pod "$POD" &> /dev/null; then
    echo -e "${RED}错误: Pod '$POD' 在命名空间 '$NAMESPACE' 中不存在或无法访问${NC}"
    exit 1
fi

# 如果未指定容器，则交互式选择
if [[ -z "$CONTAINER" ]]; then
    echo -e "${YELLOW}未指定容器名称，正在获取 Pod '$POD' 中的容器列表...${NC}"
    mapfile -t containers < <(kubectl -n "$NAMESPACE" get pod "$POD" -o jsonpath='{.spec.containers[*].name}' | tr ' ' '\n')
    if [[ ${#containers[@]} -eq 0 ]]; then
        echo -e "${RED}错误: Pod 中没有找到任何容器${NC}"
        exit 1
    elif [[ ${#containers[@]} -eq 1 ]]; then
        CONTAINER="${containers[0]}"
        echo -e "${GREEN}仅有一个容器，自动选择: $CONTAINER${NC}"
    else
        echo "请选择 MySQL 容器:"
        for i in "${!containers[@]}"; do
            echo "  $((i+1))) ${containers[$i]}"
        done
        read -p "请输入数字 (1-${#containers[@]}): " choice
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#containers[@]} ]]; then
            echo -e "${RED}无效选择${NC}"
            exit 1
        fi
        CONTAINER="${containers[$((choice-1))]}"
        echo -e "${GREEN}已选择容器: $CONTAINER${NC}"
    fi
fi

# 密码转义：将单引号替换为 '\'' (用于在 sh -c 中安全传递)
# 注意：此转义仅针对 MYSQL_PWD 环境变量的值，确保在单引号字符串中可用。
escape_single_quote() {
    local str="$1"
    # 将每个 ' 替换为 '\''
    printf "%s" "$str" | sed "s/'/'\\\\''/g"
}

# 构建 mysql 命令行前缀 (通过 kubectl exec 进入指定容器，使用 MYSQL_PWD 环境变量避免警告)
mysql_exec() {
    local sql="$1"
    local escaped_sql="${sql//\'/\\\'}"  # 对 SQL 语句中的单引号转义
    local safe_password
    safe_password=$(escape_single_quote "$MYSQL_PASSWORD")
    kubectl -n "$NAMESPACE" exec "$POD" -c "$CONTAINER" -- \
        sh -c "MYSQL_PWD='$safe_password' mysql -h 127.0.0.1 -P $MYSQL_PORT -u $MYSQL_USER -e '$escaped_sql'"
}

# 执行 SQL 文件或多行语句（用于创建表等，此处保持使用相同方式）
mysql_exec_stdin() {
    local safe_password
    safe_password=$(escape_single_quote "$MYSQL_PASSWORD")
    kubectl -n "$NAMESPACE" exec "$POD" -c "$CONTAINER" -- \
        sh -c "MYSQL_PWD='$safe_password' mysql -h 127.0.0.1 -P $MYSQL_PORT -u $MYSQL_USER"
}

# 测试库名
DB1="${DB_PREFIX}db1"
DB2="${DB_PREFIX}db2"

# 临时文件存放数据指纹
FINGERPRINT_FILE=$(mktemp)
trap 'rm -f "$FINGERPRINT_FILE"' EXIT

# 函数: 记录一张表的指纹 (行数 + CHECKSUM)
capture_table_fingerprint() {
    local db=$1
    local table=$2
    local extra_cond=${3:-"1=1"}
    
    local row_count
    row_count=$(mysql_exec "SELECT COUNT(*) FROM \`$db\`.\`$table\` WHERE $extra_cond" | tail -n 1)
    
    local checksum
    checksum=$(mysql_exec "CHECKSUM TABLE \`$db\`.\`$table\`" | tail -n 1 | awk '{print $2}')
    
    echo "$db.$table:$row_count:$checksum" >> "$FINGERPRINT_FILE"
    echo -e "${GREEN}已记录指纹: $db.$table 行数=$row_count 校验和=$checksum${NC}"
}

# 函数: 创建数据库和表，插入测试数据
create_test_data() {
    echo -e "${YELLOW}[1/4] 创建测试数据库和表...${NC}"
    
    mysql_exec "DROP DATABASE IF EXISTS \`$DB1\`"
    mysql_exec "DROP DATABASE IF EXISTS \`$DB2\`"
    
    mysql_exec "CREATE DATABASE \`$DB1\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    mysql_exec "CREATE DATABASE \`$DB2\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    
    # 使用 heredoc 传递多行 SQL (通过 mysql_exec_stdin 或管道)
    # 这里由于 SQL 包含多行，直接通过 mysql_exec_stdin 传入
    cat <<EOF | mysql_exec_stdin
USE \`$DB1\`;
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    product_name VARCHAR(200),
    amount DECIMAL(10,2),
    order_date DATE,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
EOF

    cat <<EOF | mysql_exec_stdin
USE \`$DB2\`;
CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(200),
    price DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE
);
CREATE TABLE inventory (
    id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    warehouse VARCHAR(50),
    last_updated DATETIME,
    FOREIGN KEY (product_id) REFERENCES products(id)
);
EOF
    
    echo -e "${GREEN}数据库和表结构创建完成${NC}"
    
    echo -e "${YELLOW}插入测试数据...${NC}"
    
    # DB1.users: 10 个用户
    for i in {1..10}; do
        mysql_exec "INSERT INTO \`$DB1\`.users (username, email) VALUES ('user$i', 'user$i@example.com')"
    done
    
    # DB1.orders: 每个用户随机 1-3 条订单，共约 20 条
    for uid in {1..10}; do
        local order_count=$((RANDOM % 3 + 1))
        for ((j=1; j<=order_count; j++)); do
            local amount=$(echo "scale=2; $RANDOM/100 + 10" | bc)
            local date="2024-$(printf "%02d" $((RANDOM % 12 + 1)))-$(printf "%02d" $((RANDOM % 28 + 1)))"
            mysql_exec "INSERT INTO \`$DB1\`.orders (user_id, product_name, amount, order_date) VALUES ($uid, 'Product_$RANDOM', $amount, '$date')"
        done
    done
    
    # DB2.products: 15 个产品
    for i in {1..15}; do
        local sku="SKU$(printf "%04d" $i)"
        local price=$(echo "scale=2; $RANDOM/100 + 5" | bc)
        mysql_exec "INSERT INTO \`$DB2\`.products (sku, name, price, is_active) VALUES ('$sku', 'Product $i', $price, TRUE)"
    done
    
    # DB2.inventory: 每个产品一个库存记录
    for pid in {1..15}; do
        local qty=$((RANDOM % 500 + 1))
        local warehouse="WH_$((RANDOM % 3 + 1))"
        mysql_exec "INSERT INTO \`$DB2\`.inventory (product_id, quantity, warehouse, last_updated) VALUES ($pid, $qty, '$warehouse', NOW())"
    done
    
    echo -e "${GREEN}测试数据插入完成 (users:10, orders:~20, products:15, inventory:15)${NC}"
}

# 函数: 捕获所有表的指纹
capture_all_fingerprints() {
    echo -e "${YELLOW}[2/4] 记录当前数据指纹 (行数+CHECKSUM)...${NC}"
    > "$FINGERPRINT_FILE"
    
    capture_table_fingerprint "$DB1" "users"
    capture_table_fingerprint "$DB1" "orders"
    capture_table_fingerprint "$DB2" "products"
    capture_table_fingerprint "$DB2" "inventory"
    
    echo -e "${GREEN}指纹已保存至: $FINGERPRINT_FILE${NC}"
    echo "内容如下:"
    cat "$FINGERPRINT_FILE"
}

# 函数: 删除测试数据库 (模拟数据丢失)
delete_test_databases() {
    echo -e "${YELLOW}正在删除测试数据库，模拟数据丢失场景...${NC}"
    mysql_exec "DROP DATABASE IF EXISTS \`$DB1\`"
    mysql_exec "DROP DATABASE IF EXISTS \`$DB2\`"
    echo -e "${GREEN}测试库已删除，数据已清空。${NC}"
}

# 函数: 验证当前数据指纹是否与保存的一致
verify_fingerprints() {
    echo -e "${YELLOW}[4/4] 验证恢复后的数据完备性...${NC}"
    local failed=0
    
    while IFS=: read -r table row_count checksum; do
        local db_table="$table"
        local db="${db_table%.*}"
        local tbl="${db_table#*.}"
        
        local cur_row_count
        cur_row_count=$(mysql_exec "SELECT COUNT(*) FROM \`$db\`.\`$tbl\`" | tail -n 1)
        local cur_checksum
        cur_checksum=$(mysql_exec "CHECKSUM TABLE \`$db\`.\`$tbl\`" | tail -n 1 | awk '{print $2}')
        
        echo -n "  表 $db_table : 期望 (行=$row_count, 校验=$checksum) ; 当前 (行=$cur_row_count, 校验=$cur_checksum) -> "
        if [[ "$cur_row_count" == "$row_count" && "$cur_checksum" == "$checksum" ]]; then
            echo -e "${GREEN}一致${NC}"
        else
            echo -e "${RED}不一致！${NC}"
            failed=1
        fi
    done < "$FINGERPRINT_FILE"
    
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}✅ 所有表数据完备性验证通过！备份恢复成功。${NC}"
        return 0
    else
        echo -e "${RED}❌ 数据验证失败！请检查备份恢复操作。${NC}"
        return 1
    fi
}

# 函数: 清理测试库 (最终保留或删除)
cleanup() {
    if [[ "$DO_CLEANUP" == true ]]; then
        echo -e "${YELLOW}清理测试数据库...${NC}"
        mysql_exec "DROP DATABASE IF EXISTS \`$DB1\`"
        mysql_exec "DROP DATABASE IF EXISTS \`$DB2\`"
        echo -e "${GREEN}已删除测试库 $DB1 和 $DB2${NC}"
    else
        echo -e "${YELLOW}测试库已保留 (如需自动删除，请使用 --cleanup 选项)${NC}"
        echo "  库名: $DB1, $DB2"
    fi
}

# 主流程
main() {
    echo -e "${GREEN}=== K8s MySQL 备份恢复测试脚本 ===${NC}"
    echo "目标 Pod: $NAMESPACE/$POD"
    echo "目标容器: $CONTAINER"
    echo "MySQL 端口 (容器内): $MYSQL_PORT"
    echo "测试库前缀: $DB_PREFIX"
    echo
    
    create_test_data
    capture_all_fingerprints
    
    echo
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}请现在手动执行数据库备份操作！${NC}"
    echo "推荐命令 (需替换参数):"
    echo "  kubectl exec -n $NAMESPACE $POD -c $CONTAINER -- mysqldump -u $MYSQL_USER ${MYSQL_PASSWORD:+-p'$MYSQL_PASSWORD'} --all-databases > backup.sql"
    echo
    read -p "备份完成后，按 Enter 继续..."
    
    # 自动删除测试数据库，模拟数据丢失
    delete_test_databases
    
    echo
    echo -e "${YELLOW}请现在手动执行数据库恢复操作！${NC}"
    echo "恢复示例 (需将备份文件导入):"
    echo "  kubectl exec -n $NAMESPACE $POD -c $CONTAINER -i -- mysql -u $MYSQL_USER ${MYSQL_PASSWORD:+-p'$MYSQL_PASSWORD'} < backup.sql"
    echo
    read -p "恢复完成后，按 Enter 进行数据验证..."
    
    if verify_fingerprints; then
        cleanup
        exit 0
    else
        cleanup
        exit 1
    fi
}

main