# Resource-profile examples loaded after the base help modules.

show_help_examples() {
  cat <<'EOF'
常见示例:

1. 标准交付（默认 2C/8Gi + 100Gi PVC）：
  ./mysql-installer-<arch>.run install \
    --namespace mysql-prod \
    --resource-profile standard \
    --storage-class ceph-rbd \
    --root-password 'StrongPassw0rd' \
    -y

2. 精简模式（1C/2Gi + 20Gi PVC）：
  ./mysql-installer-<arch>.run install \
    --namespace mysql-demo \
    --resource-profile lite \
    --storage-class nfs \
    --disable-data-protection \
    -y

3. 大规格模式（4C/16Gi + 500Gi PVC）：
  ./mysql-installer-<arch>.run install \
    --namespace mysql-large \
    --resource-profile large \
    --storage-class ceph-rbd \
    -y

4. 标准模式但项目要求 300Gi 数据盘：
  ./mysql-installer-<arch>.run install \
    --namespace mysql-prod \
    --resource-profile standard \
    --storage-class ceph-rbd \
    --storage-size 300Gi \
    -y

5. 已有 PVC 显式扩容到 500Gi：
  ./mysql-installer-<arch>.run install \
    --namespace mysql-prod \
    --resource-profile standard \
    --storage-size 500Gi \
    -y

   注意：PVC 不支持缩容；扩容要求 StorageClass.allowVolumeExpansion=true。

6. 标准规格但按压测结果调整 Buffer Pool：
  ./mysql-installer-<arch>.run install \
    --namespace mysql-prod \
    --resource-profile standard \
    --innodb-buffer-pool-size 6G \
    -y

7. 首次安装并显式打开文件慢日志 sidecar：
  ./mysql-installer-<arch>.run install \
    --namespace mysql-demo \
    --resource-profile lite \
    --enable-fluentbit \
    --mysql-slow-query-time 1 \
    -y

8. 给已有 MySQL 补监控：
  ./mysql-monitoring-<arch>.run addon-install \
    --namespace mysql-demo \
    --addons monitoring,service-monitor \
    --monitoring-target 10.0.0.20:3306 \
    -y

9. 独立压测：
  ./mysql-benchmark-<arch>.run benchmark \
    --namespace mysql-demo \
    --mysql-host 10.0.0.20 \
    --mysql-user root \
    --mysql-password '<MYSQL_PASSWORD>' \
    --benchmark-profile oltp-read-write \
    --benchmark-threads 64 \
    --benchmark-time 300 \
    --report-dir ./reports \
    -y
EOF
}
