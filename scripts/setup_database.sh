#!/usr/bin/env bash
set -Eeuo pipefail

# SmartCityCE - Inicialización local de PostgreSQL
# Ejecutar desde la raíz del repositorio:
#   bash scripts/setup_database.sh

ENV_FILE=".env"

# Cargar configuración
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: no existe el archivo $ENV_FILE." >&2
  echo "Créalo a partir de .env.example:" >&2
  echo "  cp .env.example .env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

: "${DB_NAME:?Falta DB_NAME en .env}"
: "${DB_USER:?Falta DB_USER en .env}"
: "${DB_PASSWORD:?Falta DB_PASSWORD en .env}"

# Validar dependencias

if ! command -v psql >/dev/null 2>&1; then
  echo "Error: psql no está instalado. Instala PostgreSQL primero." >&2
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "Error: este script requiere sudo." >&2
  exit 1
fi

# Crear usuario y base de datos
echo "Configurando PostgreSQL para SmartCityCE..."

sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d postgres \
  -v db_name="$DB_NAME" \
  -v db_user="$DB_USER" \
  -v db_password="$DB_PASSWORD" <<'SQL'

SELECT format('CREATE ROLE %I LOGIN', :'db_user')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_roles
    WHERE rolname = :'db_user'
)
\gexec

SELECT format(
    'ALTER ROLE %I WITH LOGIN PASSWORD %L',
    :'db_user',
    :'db_password'
)
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_database
    WHERE datname = :'db_name'
)
\gexec

SQL

# Configurar permisos
sudo -u postgres psql -X -v ON_ERROR_STOP=1 \
  -d "$DB_NAME" \
  -v db_user="$DB_USER" <<'SQL'

SELECT format('ALTER SCHEMA public OWNER TO %I', :'db_user')
\gexec

SQL

echo
echo "PostgreSQL configurado correctamente."
echo "Base de datos: $DB_NAME"
echo "Usuario:       $DB_USER"
echo
echo "Conexión:"
echo "  psql -h ${DB_HOST:-localhost} -p ${DB_PORT:-5432} -U $DB_USER -d $DB_NAME -W"