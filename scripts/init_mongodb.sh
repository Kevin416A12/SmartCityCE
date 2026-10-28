#!/usr/bin/env bash
set -Eeuo pipefail

# SmartCityCE - Inicialización local de MongoDB
# Ejecutar desde la raíz del repositorio:
#   bash scripts/init_mongodb.sh

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

: "${MONGO_ROOT_USER:?Falta MONGO_ROOT_USER en .env}"
: "${MONGO_ROOT_PASSWORD:?Falta MONGO_ROOT_PASSWORD en .env}"
: "${MONGO_DATABASE:?Falta MONGO_DATABASE en .env}"

# Validar dependencias
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: Docker no está instalado o no está disponible." >&2
  exit 1
fi

if [[ ! -f "docker-compose.yml" ]]; then
  echo "Error: no se encontró docker-compose.yml." >&2
  exit 1
fi


# Levantar MongoDB
echo "Iniciando MongoDB..."

docker compose up -d mongodb

echo "Esperando a que MongoDB esté disponible..."

until docker exec smartcity_mongodb mongosh \
  -u "$MONGO_ROOT_USER" \
  -p "$MONGO_ROOT_PASSWORD" \
  --authenticationDatabase admin \
  --quiet \
  --eval "db.adminCommand('ping').ok" 2>/dev/null | grep -q "1"; do
  sleep 2
done

echo
echo "MongoDB configurado correctamente."
echo "Base de datos: $MONGO_DATABASE"
echo
echo "Siguiente paso:"
echo "  python MongoDB/cargar_lecturas.py --reiniciar"