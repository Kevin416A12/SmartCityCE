#!/usr/bin/env bash
# SmartCityCE — Carga de datos originales y procesados en HDFS.
# Ejecutar desde cualquier directorio: bash Hadoop/scripts/load_hdfs.sh
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HDFS_ROOT="${SMARTCITYCE_HDFS_ROOT:-/smartcityce}"

if ! command -v hdfs >/dev/null 2>&1; then
  echo 'ERROR: comando hdfs no encontrado. Configura HADOOP_HOME y PATH.' >&2
  exit 1
fi

# Los seis CSV deben existir ANTES de iniciar la carga.
files=(
  'data/raw/bdg2/metadata/metadata.csv'
  'data/raw/bdg2/meters/cleaned/electricity_cleaned.csv'
  'data/raw/open_meteo/orlando_weather_2016_2017.csv'
  'data/processed/hadoop/buildings.csv'
  'data/processed/hadoop/electricity.csv'
  'data/processed/hadoop/weather.csv'
)
destinations=(
  'raw/bdg2/metadata.csv'
  'raw/bdg2/electricity_cleaned.csv'
  'raw/open_meteo/orlando_weather_2016_2017.csv'
  'processed/buildings.csv'
  'processed/electricity.csv'
  'processed/weather.csv'
)

for file in "${files[@]}"; do
  if [[ ! -f "$ROOT/$file" ]]; then
    echo "ERROR: no existe $ROOT/$file" >&2
    echo 'Descarga los originales y ejecuta prepare_datasets.py antes de cargar HDFS.' >&2
    exit 1
  fi
done

if ! hdfs dfs -ls / >/dev/null 2>&1; then
  echo 'ERROR: no se puede acceder a HDFS. Comprueba start_hadoop.sh y dfsadmin -report.' >&2
  exit 1
fi

printf 'SmartCityCE: cargando CSV en HDFS (%s)\n' "$HDFS_ROOT"
for i in "${!files[@]}"; do
  source="$ROOT/${files[$i]}"
  target="$HDFS_ROOT/${destinations[$i]}"
  parent="${target%/*}"
  hdfs dfs -mkdir -p "$parent"
  echo "Subiendo: ${files[$i]} -> $target"
  hdfs dfs -put -f "$source" "$target"
  local_bytes="$(stat -c '%s' "$source")"
  remote_bytes="$(hdfs dfs -stat '%b' "$target")"
  if [[ "$local_bytes" != "$remote_bytes" ]]; then
    echo "ERROR: tamaño distinto en $target (local=$local_bytes, HDFS=$remote_bytes)." >&2
    exit 1
  fi
  echo "  OK: $remote_bytes bytes"
done

printf '\nCarga completada. Tamaños lógicos en HDFS:\n'
hdfs dfs -du -s -h "$HDFS_ROOT"
printf '\nEjecuta la verificación: bash tests/test_hdfs.sh\n'
