

#!/usr/bin/env bash
set -Eeuo pipefail

# SmartCityCE - Inicialización local de PostgreSQL (Ubuntu/Debian)
# Ejecutar: bash scripts/setup_database.sh
# Requiere sudo y un servidor PostgreSQL instalado.

DB_NAME="smartcityce"
DB_USER="smartcity"
DB_PASSWORD="ZXCV1234"  # Cambiar a una contraseña segura antes de ejecutar

if ! command -v psql >/dev/null 2>&1; then
  echo "Error: psql no está instalado. Instala PostgreSQL primero." >&2
  exit 1
fi
if ! command -v sudo >/dev/null 2>&1; then
  echo "Error: este script requiere sudo." >&2
  exit 1
fi

# La contraseña se envía por stdin a psql, no se imprime ni se incluye en el SQL del log.
# Se exige una ejecución local con privilegios del usuario postgres.
echo "Configurando PostgreSQL para SmartCityCE..."
sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d postgres \
  -v db_name="$DB_NAME" -v db_user="$DB_USER" -v db_password="$DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user')
\gexec

-- Establecer o actualizar la contraseña sin mostrarla en salida.
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'db_user', :'db_password')
\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name')
\gexec
SQL

sudo -u postgres psql -X -v ON_ERROR_STOP=1 -d "$DB_NAME" -v db_user="$DB_USER" <<'SQL'
SELECT format('ALTER SCHEMA public OWNER TO %I', :'db_user')
\gexec
SQL

echo "Base '$DB_NAME' y usuario '$DB_USER' configurados."
echo "Para conectarte: psql -h localhost -U $DB_USER -d $DB_NAME -W"

