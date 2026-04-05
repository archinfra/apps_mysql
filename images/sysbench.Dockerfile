FROM registry.cn-beijing.aliyuncs.com/kube4/mysql:8.0.45

RUN microdnf install -y oracle-epel-release-el9 \
    && microdnf install -y sysbench gawk \
    && microdnf clean all
