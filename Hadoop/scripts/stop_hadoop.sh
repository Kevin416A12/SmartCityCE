#!/bin/bash

set -e

export HADOOP_HOME="${HADOOP_HOME:-$HOME/hadoop}"
export JAVA_HOME="${HADOOP_JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"

export PATH="$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"

echo "================================"
echo " SmartCityCE - Deteniendo Hadoop"
echo "================================"

if [ ! -x "$HADOOP_HOME/sbin/stop-dfs.sh" ]; then
    echo "ERROR: No se encontró Hadoop en $HADOOP_HOME"
    exit 1
fi

# Detener HDFS
"$HADOOP_HOME/sbin/stop-dfs.sh"

echo ""
echo "Procesos restantes:"
jps

