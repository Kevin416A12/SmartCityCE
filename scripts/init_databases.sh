#!/usr/bin/env bash
set -Eeuo pipefail

# SmartCityCE - Inicialización reproducible de las bases de datos
#
# Uso:
#   bash scripts/init_databases.sh --postgres
#   bash scripts/init_databases.sh --mongo
#   bash scripts/init_databases.sh --all

ENV_FILE=".env"
MODO="${1:-}"


# Ayuda


mostrar_ayuda() {
  echo "Uso:"
  echo "  bash scripts/init_databases.sh --postgres"
  echo "  bash scripts/init_databases.sh --mongo"
  echo "  bash scripts/init_databases.sh --all"
}

if [[ "$MODO" != "--postgres" &&
      "$MODO" != "--mongo" &&
      "$MODO" != "--all" ]]; then
  mostrar_ayuda
  exit 1
fi


# Configuración general


if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: no existe el archivo $ENV_FILE." >&2
  echo "Créalo con:" >&2
  echo "  cp .env.example .env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if ! command -v python >/dev/null 2>&1; then
  echo "Error: Python no está disponible." >&2
  exit 1
fi


# Datasets


descargar_datasets() {
  echo
  echo " Preparando datasets"

  python scripts/download_datasets.py --dataset all
}


# PostgreSQL


inicializar_postgresql() {
  echo
  echo " Inicializando PostgreSQL"

  if ! command -v psql >/dev/null 2>&1; then
    echo "Error: PostgreSQL/psql no está disponible en este entorno." >&2
    echo "Consulta guia_instalacion.md para instalar PostgreSQL." >&2
    return 1
  fi

  bash scripts/setup_database.sh

  echo "Creando esquema PostgreSQL..."

  PGPASSWORD="$DB_PASSWORD" psql \
    -h "${DB_HOST:-localhost}" \
    -p "${DB_PORT:-5432}" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -X -v ON_ERROR_STOP=1 \
    -f SQL/01_schema.sql

  echo "Cargando datos PostgreSQL..."

  python scripts/load_postgresql.py \
    --phase all \
    --meters-file data/raw/bdg2/meters/cleaned/electricity_cleaned.csv

  echo "PostgreSQL inicializado correctamente."
}


# MongoDB


inicializar_mongodb() {
  echo
  echo " Inicializando MongoDB"

  bash scripts/init_mongodb.sh

  echo
  echo "Cargando lecturas MongoDB..."

  python MongoDB/cargar_lecturas.py \
    --limite 500000 \
    --reiniciar

  echo
  echo "Creando índices MongoDB..."

  docker exec -i smartcity_mongodb mongosh \
    -u "$MONGO_ROOT_USER" \
    -p "$MONGO_ROOT_PASSWORD" \
    --authenticationDatabase admin \
    --quiet \
    < MongoDB/indexes.js

  echo
  echo "MongoDB inicializado correctamente."
}


# Ejecución


descargar_datasets

case "$MODO" in
  --postgres)
    inicializar_postgresql
    ;;

  --mongo)
    inicializar_mongodb
    ;;

  --all)
    inicializar_postgresql
    inicializar_mongodb
    ;;
esac

echo
echo " Inicialización finalizada"
echo
