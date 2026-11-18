#!/usr/bin/env bash
# SmartCityCE - Configuración local de HDFS en modo pseudodistribuido.
# No descarga Hadoop, no inicia servicios y nunca formatea el NameNode.
set -Eeuo pipefail

HADOOP_HOME="${HADOOP_HOME:-$HOME/hadoop}"
JAVA_HOME="${HADOOP_JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}"
HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
HDFS_DATA_DIR="${SMARTCITYCE_HDFS_DATA_DIR:-$HOME/hadoop_data}"
NAMENODE_DIR="$HDFS_DATA_DIR/namenode"
DATANODE_DIR="$HDFS_DATA_DIR/datanode"

if [[ ! -x "$HADOOP_HOME/bin/hdfs" ]]; then
  echo "ERROR: Hadoop no se encontró en $HADOOP_HOME" >&2
  echo "Instálalo allí o define HADOOP_HOME antes de ejecutar este script." >&2
  exit 1
fi
if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "ERROR: Java no se encontró en $JAVA_HOME" >&2
  echo "Define HADOOP_JAVA_HOME con la ruta correcta de Java 11." >&2
  exit 1
fi
if ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -q 'version "11\.'; then
  echo "ERROR: Este script está configurado para Java 11; revisa HADOOP_JAVA_HOME." >&2
  exit 1
fi
if [[ ! -d "$HADOOP_CONF_DIR" ]]; then
  echo "ERROR: No existe el directorio de configuración $HADOOP_CONF_DIR" >&2
  exit 1
fi

mkdir -p "$NAMENODE_DIR" "$DATANODE_DIR"

# El XML solo cambia si no coincide; respalda las configuraciones anteriores.
backup_and_write() {
  local target="$1"
  local content="$2"
  local tmp
  tmp=$(mktemp)
  printf '%s\n' "$content" > "$tmp"
  if [[ -f "$target" ]] && cmp -s "$tmp" "$target"; then
    echo "Sin cambios: $target"
    rm -f "$tmp"
    return
  fi
  if [[ -f "$target" ]]; then
    cp -p "$target" "$target.bak.$(date +%Y%m%d_%H%M%S)"
  fi
  cat "$tmp" > "$target"
  rm -f "$tmp"
  echo "Configurado: $target"
}

CORE_XML='<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:9000</value>
  </property>
</configuration>'
HDFS_XML="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file://${NAMENODE_DIR}</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file://${DATANODE_DIR}</value>
  </property>
</configuration>"
backup_and_write "$HADOOP_CONF_DIR/core-site.xml" "$CORE_XML"
backup_and_write "$HADOOP_CONF_DIR/hdfs-site.xml" "$HDFS_XML"

ENV_FILE="$HADOOP_CONF_DIR/hadoop-env.sh"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: No se encontró $ENV_FILE" >&2
  exit 1
fi
# Elimina líneas activas previas de JAVA_HOME y escribe una sola configuración.
if ! grep -Fxq "export JAVA_HOME=\"$JAVA_HOME\"" "$ENV_FILE"; then
  cp -p "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d_%H%M%S)"
  sed -i '/^[[:space:]]*export[[:space:]]\+JAVA_HOME=/d' "$ENV_FILE"
  printf '\nexport JAVA_HOME="%s"\n' "$JAVA_HOME" >> "$ENV_FILE"
  echo "Configurado JAVA_HOME en $ENV_FILE"
fi

echo
echo "Hadoop: $HADOOP_HOME"
echo "Java:   $JAVA_HOME"
echo "HDFS:   $HDFS_DATA_DIR"
if [[ -f "$NAMENODE_DIR/current/VERSION" ]]; then
  echo 'NameNode: YA inicializado (no se formateó).'
else
  echo 'NameNode: no se encontró la marca de inicialización.'
  echo 'Solo para una instalación NUEVA, y tras verificar las rutas, ejecuta:'
  echo "  JAVA_HOME=\"$JAVA_HOME\" \"$HADOOP_HOME/bin/hdfs\" namenode -format"
  echo 'NO ejecutes ese comando si ya existen datos de HDFS.'
fi
printf '\nPara iniciar HDFS: ./Hadoop/scripts/start_hadoop.sh\n'
printf 'Comprueba: hdfs dfsadmin -report\n'
