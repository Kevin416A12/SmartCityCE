#!/usr/bin/env bash
# SmartCityCE — Verifica presencia, tamaño, lectura, integridad y descarga HDFS.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HDFS_ROOT="${SMARTCITYCE_HDFS_ROOT:-/smartcityce}"

if ! command -v hdfs >/dev/null 2>&1; then
  echo 'ERROR: comando hdfs no encontrado.' >&2
  exit 1
fi

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

for i in "${!files[@]}"; do
  source="$ROOT/${files[$i]}"
  target="$HDFS_ROOT/${destinations[$i]}"
  [[ -f "$source" ]] || { echo "ERROR: falta archivo local: $source" >&2; exit 1; }
  hdfs dfs -test -f "$target" || { echo "ERROR: falta archivo HDFS: $target" >&2; exit 1; }

  local_bytes="$(stat -c '%s' "$source")"
  remote_bytes="$(hdfs dfs -stat '%b' "$target")"
  [[ "$local_bytes" == "$remote_bytes" ]] || {
    echo "ERROR: tamaños diferentes en $target: local=$local_bytes, HDFS=$remote_bytes" >&2
    exit 1
  }

  # Compara todos los bytes leyendo por HDFS en streaming (sin duplicar 170+ MB en disco).
  hdfs dfs -cat "$target" | cmp - "$source" || {
    echo "ERROR: contenido distinto en $target" >&2
    exit 1
  }
  echo "OK: $target ($remote_bytes bytes, contenido idéntico)"
done

# Prueba explícita de descarga con un archivo pequeño, usando un temporal seguro.
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
hdfs dfs -get "$HDFS_ROOT/processed/buildings.csv" "$tmp_dir/buildings.csv"
cmp "$ROOT/data/processed/hadoop/buildings.csv" "$tmp_dir/buildings.csv"
echo 'OK: descarga y comparación de buildings.csv'

# Se informa el tamaño lógico sin confundirlo con espacio físico replicado.
echo
hdfs dfs -du -s -h "$HDFS_ROOT"
echo 'Verificación HDFS completada: 6 archivos válidos.'
