# SmartCityCE — Guía de instalación y configuración

Esta guía explica cómo preparar el entorno de desarrollo de **SmartCityCE** en Ubuntu, configurar PostgreSQL y cargar los datasets utilizados en el proyecto.

Al finalizar, tendremos una base de datos PostgreSQL con aproximadamente **1,8 millones de lecturas eléctricas**, además de información de edificios, sensores y registros meteorológicos.

## 1. Requisitos previos

Es necesario tener instalados:

- Git
- Python 3
- PostgreSQL
- pip
- Soporte para entornos virtuales de Python

En Ubuntu, podemos instalar estas herramientas mediante:

```bash
sudo apt update
sudo apt install -y git python3 python3-pip python3-venv postgresql postgresql-client
```

Comprobar las instalaciones:

```bash
python3 --version
psql --version
git --version
```

Verificar que PostgreSQL esté funcionando:

```bash
sudo systemctl status postgresql
```

Si PostgreSQL no está iniciado:

```bash
sudo systemctl start postgresql
```

## 2. Clonar el repositorio

Clonar SmartCityCE desde GitHub:

```bash
git clone <URL_DEL_REPOSITORIO>
cd SmartCityCE
```

**Importante:** Todos los comandos de esta guía deben ejecutarse desde la raíz del repositorio, salvo que se indique lo contrario.

## 3. Configurar el entorno de Python

Crear un entorno virtual:

```bash
python3 -m venv .venv
```

Activarlo:

```bash
source .venv/bin/activate
```

Instalar las dependencias del proyecto:

```bash
pip install -r requirements.txt
```

Cuando el entorno virtual esté activado, la terminal debería mostrar `(.venv)`.

## 4. Descargar los datasets

El proyecto utiliza dos fuentes de información:

1. **Building Data Genome 2 (BDG2):** información de edificios y consumo energético.
2. **Open-Meteo:** datos meteorológicos históricos de Orlando, Florida.

Para descargar los datasets, ejecutar:

```bash
python scripts/download_datasets.py
```

Una vez finalizada la descarga, comprobar que existan los directorios correspondientes:

```bash
ls data/raw/bdg2/
ls data/raw/open_meteo/
```

La estructura esperada es similar a:

```text
data/
└── raw/
    ├── bdg2/
    │   ├── metadata/
    │   │   └── metadata.csv
    │   └── meters/
    │       └── cleaned/
    │           └── electricity_cleaned.csv
    └── open_meteo/
        └── orlando_weather_2016_2017.csv
```

Los nombres y rutas definitivos deben coincidir con los archivos descargados.

## 5. Crear la base de datos PostgreSQL

SmartCityCE incluye un script que automatiza la configuración inicial de PostgreSQL.

El archivo utilizado es:

```text
scripts/setup_database.sh
```

### 5.1. Configurar la contraseña

Antes de ejecutarlo, abrir el script:

```bash
nano scripts/setup_database.sh
```

Comprobar la contraseña configurada para el usuario de PostgreSQL.

Para el entorno local del proyecto se ha utilizado:

```text
ZXCV1234
```

Si se modifica, debe utilizarse la misma contraseña en la configuración del ETL.

**Seguridad:** Esta contraseña es únicamente para desarrollo local. No debe reutilizarse en servidores públicos o entornos de producción.

### 5.2. Ejecutar el script

Desde la raíz del repositorio:

```bash
bash scripts/setup_database.sh
```

El script configura:

- Base de datos: `smartcityce`
- Usuario: `smartcity`
- Contraseña: la definida en el script
- Permisos necesarios sobre la base de datos

Es posible que Ubuntu solicite la contraseña del usuario administrador.

### 5.3. Verificar la conexión

Ejecutar:

```bash
psql -h localhost -U smartcity -d smartcityce
```

Introducir la contraseña configurada.

Si la conexión funciona, aparecerá:

```text
smartcityce=>
```

Para salir:

```sql
\q
```

## 6. Crear las tablas PostgreSQL

El esquema relacional está definido en:

```text
SQL/01_schema.sql
```

Para crear las tablas, ejecutar:

```bash
psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f SQL/01_schema.sql
```

El script crea las ocho tablas del proyecto:

1. `ubicacion`
2. `edificio`
3. `categoria_sensor`
4. `organismo_responsable`
5. `sensor`
6. `usuario_sistema`
7. `lectura_sql`
8. `registro_meteorologico`

### 6.1. Verificar las tablas

Ejecutar:

```bash
psql -h localhost -U smartcity -d smartcityce -c "\dt"
```

Deben aparecer las ocho tablas.

## 7. Ejecutar las pruebas del esquema

Antes de cargar los datos, debemos verificar que las tablas y restricciones funcionen correctamente.

El archivo de pruebas es:

```text
tests/test_schema.sql
```

Ejecutarlo mediante:

```bash
psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f tests/test_schema.sql
```

Estas pruebas validan aspectos como:

- Existencia de las tablas.
- Claves primarias y foráneas.
- Integridad referencial.
- Restricciones `CHECK`.
- Restricciones `UNIQUE`.
- Rechazo de inserciones inválidas.

**Resultado esperado:** Todas las pruebas deben finalizar correctamente.

Si alguna falla, revisar el error antes de continuar con la carga.

## 8. Configurar la conexión del ETL

En la raíz del repositorio, crear un archivo llamado `.env`:

```bash
nano .env
```

Agregar:

```dotenv
DB_HOST=localhost
DB_PORT=5432
DB_NAME=smartcityce
DB_USER=smartcity
DB_PASSWORD=ZXCV1234
```

Guardar el archivo.

**Importante:** `.env` contiene credenciales y no debe subirse a GitHub. Debe estar incluido en `.gitignore`.

## 9. Cargar los datos en PostgreSQL

El proceso ETL está implementado en:

```text
scripts/load_postgresql.py
```

La carga debe realizarse en el orden indicado para respetar las relaciones entre las tablas.

### 9.1. Cargar metadatos BDG2

Ejecutar:

```bash
python scripts/load_postgresql.py --phase metadata
```

Esta etapa carga:

- Ubicaciones.
- Edificios.
- Categorías de sensores.
- Sensores eléctricos.

Resultado obtenido durante el desarrollo:

```text
INFO: Metadatos: 136 edificios procesados, 105 sensores nuevos.
INFO: ETL completado.
```

### 9.2. Cargar datos meteorológicos

Ejecutar:

```bash
python scripts/load_postgresql.py --phase weather
```

Esta etapa importa los registros de Open-Meteo.

Resultado obtenido durante el desarrollo:

```text
INFO: Clima: 17544 nuevos registros.
INFO: ETL completado.
```

### 9.3. Cargar lecturas eléctricas

Ejecutar:

```bash
python scripts/load_postgresql.py \
    --phase meters \
    --meters-file data/raw/bdg2/meters/cleaned/electricity_cleaned.csv
```

Este proceso transforma las mediciones eléctricas de BDG2 y las almacena en `lectura_sql`.

La carga completa puede requerir más tiempo debido al volumen de registros.

**Nota:** Si el CSV tiene otro nombre, sustituir la ruta indicada por la ubicación real del archivo.

## 10. Ejecutar las pruebas de los datos

Una vez completada la carga, ejecutar:

```bash
psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f tests/test_data.sql
```

Estas pruebas comprueban:

- Al menos 100.000 lecturas eléctricas.
- Existencia de registros meteorológicos.
- Existencia de edificios y sensores.
- Integridad referencial.
- Ausencia de lecturas duplicadas por sensor y fecha.
- Ausencia de lecturas negativas.
- Unidades de medición presentes.
- Rangos meteorológicos válidos.

El resultado esperado es:

```text
NOTICE: TODAS LAS PRUEBAS DE DATOS PASARON.
```

## 11. Verificar la cantidad de registros

Para consultar el número de registros de cada tabla:

```bash
psql -h localhost -U smartcity -d smartcityce -c "
SELECT 'ubicacion' AS tabla, COUNT(*) FROM ubicacion
UNION ALL
SELECT 'edificio', COUNT(*) FROM edificio
UNION ALL
SELECT 'categoria_sensor', COUNT(*) FROM categoria_sensor
UNION ALL
SELECT 'organismo_responsable', COUNT(*) FROM organismo_responsable
UNION ALL
SELECT 'sensor', COUNT(*) FROM sensor
UNION ALL
SELECT 'usuario_sistema', COUNT(*) FROM usuario_sistema
UNION ALL
SELECT 'lectura_sql', COUNT(*) FROM lectura_sql
UNION ALL
SELECT 'registro_meteorologico', COUNT(*) FROM registro_meteorologico;
"
```

Durante el desarrollo se obtuvieron estos resultados:

| Tabla | Registros |
|---|---:|
| `ubicacion` | 1 |
| `edificio` | 136 |
| `categoria_sensor` | 1 |
| `organismo_responsable` | 0 |
| `sensor` | 105 |
| `usuario_sistema` | 0 |
| `lectura_sql` | 1.817.156 |
| `registro_meteorologico` | 17.544 |
| **Total** | **1.834.943** |

Los resultados pueden variar según los datos disponibles y las cargas realizadas previamente.

## 12. Solución de problemas comunes

### Error: `Permission denied`

Si no puedes ejecutar un archivo `.sh` directamente:

```bash
chmod +x scripts/setup_database.sh
```

También puedes ejecutarlo con:

```bash
bash scripts/setup_database.sh
```

### Error: `password authentication failed`

Verificar que la contraseña del usuario `smartcity` coincida con la configurada en `.env`.

Si es necesario, restablecerla desde PostgreSQL:

```bash
sudo -u postgres psql
```

Luego:

```sql
\password smartcity
```

Introducir la nueva contraseña dos veces y salir:

```sql
\q
```

### Error: `relation does not exist`

Comprobar que las tablas estén creadas:

```bash
psql -h localhost -U smartcity -d smartcityce -c "\dt"
```

Si faltan tablas, ejecutar nuevamente el esquema:

```bash
psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f SQL/01_schema.sql
```

### Error: archivo CSV no encontrado

Verificar la ubicación de los datasets:

```bash
ls data/raw/bdg2/metadata/
ls data/raw/bdg2/meters/cleaned/
ls data/raw/open_meteo/
```

Si falta algún archivo, ejecutar el descargador de datasets o revisar su salida:

```bash
python scripts/download_datasets.py
```

## 13. Resumen de comandos

Una vez instaladas las herramientas necesarias, este es el orden para configurar SmartCityCE desde cero:

```bash
# 1. Crear y activar el entorno virtual
python3 -m venv .venv
source .venv/bin/activate

# 2. Instalar dependencias
pip install -r requirements.txt

# 3. Descargar datasets
python scripts/download_datasets.py

# 4. Crear la base de datos y el usuario
# Antes, revisar la contraseña en setup_database.sh
bash scripts/setup_database.sh

# 5. Crear tablas
psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f SQL/01_schema.sql

# 6. Probar el esquema
psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f tests/test_schema.sql

# 7. Configurar el archivo .env antes de ejecutar el ETL

# 8. Cargar metadatos
python scripts/load_postgresql.py --phase metadata

# 9. Cargar clima
python scripts/load_postgresql.py --phase weather

# 10. Cargar electricidad
python scripts/load_postgresql.py \
    --phase meters \
    --meters-file data/raw/bdg2/meters/cleaned/electricity_cleaned.csv

# 11. Validar los datos
psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f tests/test_data.sql
```

---

## Resultado final

Si todos los pasos se ejecutan correctamente, el entorno PostgreSQL de SmartCityCE estará listo para utilizarse en el desarrollo del proyecto.

La base de datos contendrá información de edificios, sensores, consumo energético y condiciones meteorológicas, con las restricciones e integridad referencial verificadas mediante pruebas automatizadas.