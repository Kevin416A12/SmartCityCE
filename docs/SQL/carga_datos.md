# Carga de datos en PostgreSQL — SmartCityCE

## Objetivo

Cargar en PostgreSQL los datos del sitio **Panther** de Building Data Genome 2 (BDG2) y la serie histórica meteorológica de **Open-Meteo (Orlando, 2016–2017)**. El requisito mínimo de volumen de la entrega es **100 000 registros en PostgreSQL**.

## Requisitos previos

- PostgreSQL instalado, con la base `smartcityce`, el usuario `smartcity` y el esquema definido en `SQL/01_schema.sql`.
- Python 3 con entorno virtual y dependencias instaladas desde `requirements.txt`.
- Variables de conexión definidas en un archivo `.env` local **no versionado** (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`). No incluir contraseñas reales en Git.
- Datasets en las rutas indicadas a continuación; consultar `docs/datasets.md` para su procedencia.

## Archivos de entrada

| Fuente | Ruta esperada | Uso |
|---|---|---|
| BDG2 | `data/raw/bdg2/metadata/metadata.csv` | Edificios y sensores del sitio Panther |
| BDG2 | `data/raw/bdg2/meters/cleaned/electricity_cleaned.csv` | Mediciones eléctricas horarias; verificar el nombre real en disco |
| Open-Meteo | `data/raw/open_meteo/orlando_weather_2016_2017.csv` | Registros meteorológicos horarios |

Los datos originales no se deben modificar durante el ETL. El script de carga es `scripts/load_postgresql.py`.

## Procedimiento reproducible

Ejecutar desde la **raíz del repositorio**:

```bash
source .venv/bin/activate
# Preparar las tablas en una base recién creada:
psql -h localhost -U smartcity -d smartcityce -X -v ON_ERROR_STOP=1 -f SQL/01_schema.sql

# Cargar entidades de referencia primero:
python scripts/load_postgresql.py --phase metadata
python scripts/load_postgresql.py --phase weather

# Prueba acotada opcional de lecturas:
python scripts/load_postgresql.py --phase meters \
  --meters-file data/raw/bdg2/meters/cleaned/electricity_cleaned.csv \
  --max-meter-rows 100

# Carga completa:
python scripts/load_postgresql.py --phase meters \
  --meters-file data/raw/bdg2/meters/cleaned/electricity_cleaned.csv
```

**Atención:** el comando para crear las tablas corresponde a una base nueva. Si ya existen, no es necesario volver a ejecutar la creación del esquema. La carga de prueba es opcional. Verificar la implementación del ETL antes de repetir cargas, para asegurar que maneje adecuadamente los registros ya existentes.

## Validación

```bash
psql -h localhost -U smartcity -d smartcityce -X -v ON_ERROR_STOP=1 -f tests/test_schema.sql
psql -h localhost -U smartcity -d smartcityce -X -v ON_ERROR_STOP=1 -f tests/test_data.sql
```

La ejecución reportada de `tests/test_data.sql` terminó con **«TODAS LAS PRUEBAS DE DATOS PASARON»**. Verificó el volumen de lecturas, la presencia de registros meteorológicos y edificios, sensores con lecturas, ausencia de lecturas huérfanas o duplicadas por sensor/fecha, ausencia de lecturas negativas, unidades completas y rangos meteorológicos válidos.

## Resultado observado de la carga

Valores registrados en PostgreSQL según la ejecución de validación del **24 de octubre de 2026**:

| Tabla | Registros |
|---|---:|
| `ubicacion` | 1 |
| `edificio` | 136 |
| `categoria_sensor` | 1 |
| `sensor` | 105 |
| `organismo_responsable` | 0 |
| `usuario_sistema` | 0 |
| `registro_meteorologico` | 17 544 |
| `lectura_sql` | 1 817 156 |
| **Total** | **1 834 943** |

- Sensores distintos con lecturas: **105**.
- Período de las lecturas eléctricas: **2016-01-01 00:00:00** a **2017-12-31 23:00:00**.
- Lecturas con valor `0`: **341 994**. No se consideran inválidas automáticamente; requieren interpretación según el dataset.
- Lecturas negativas: **0**.
- Se supera el mínimo de **100 000 registros** exigido para PostgreSQL.

## Consideraciones y limitaciones

- `usuario_sistema` y `organismo_responsable` permanecen vacías: las fuentes usadas no aportan necesariamente estos datos administrativos. No generar registros ficticios sin documentarlo claramente.
- La meteorología representa la localización consultada en Open-Meteo; no constituye una medición individual en cada edificio.
- Las fechas horarias deben conservar una interpretación consistente de zona horaria entre ambas fuentes antes de hacer uniones temporales o análisis de correlación.
- Verificar las unidades físicas de la descarga de Open-Meteo y las de consumo energético de BDG2 antes de publicar estadísticas; la tabla `lectura_sql` registra las lecturas como `kWh`.
- Las pruebas confirman integridad y restricciones específicas; no demuestran que todos los campos hayan sido mapeados semánticamente sin error. Se recomienda contrastar muestras del CSV con su correspondiente fila en la base.
