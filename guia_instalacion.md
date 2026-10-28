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

Este script crea, si es necesario, el usuario y la base de datos utilizados por el proyecto. La configuración se obtiene desde el archivo `.env`.

### 5.1. Configurar las variables de entorno

La configuración de PostgreSQL se obtiene desde el archivo `.env` ubicado en la raíz del repositorio.

Si el archivo todavía no existe, crearlo a partir del ejemplo:

```bash
cp .env.example .env
```

Las variables utilizadas por PostgreSQL son:

```dotenv
DB_HOST=localhost
DB_PORT=5432
DB_NAME=smartcityce
DB_USER=smartcity
DB_PASSWORD=ZXCV1234
```

El script `scripts/setup_database.sh` carga automáticamente estas variables, por lo que no es necesario modificar las credenciales directamente dentro del script.

**Seguridad:** las credenciales incluidas en `.env.example` están destinadas únicamente al entorno local de desarrollo. El archivo `.env` no debe subirse al repositorio.

### 5.2. Ejecutar el script

Desde la raíz del repositorio:

```bash
bash scripts/setup_database.sh
```

El script configura:

- Base de datos: la definida mediante `DB_NAME`.
- Usuario: el definido mediante `DB_USER`.
- Contraseña: la definida mediante `DB_PASSWORD`.
- Permisos necesarios sobre la base de datos.

El script requiere que PostgreSQL y el cliente `psql` estén instalados en el entorno donde se ejecuta.

En sistemas Ubuntu o WSL puede solicitar la contraseña del usuario administrador mediante `sudo`.

### 5.3. Verificar la conexión

Ejecutar:

```bash
psql -h localhost -U smartcity -d smartcityce
```

Introducir la contraseña configurada en `.env`.

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

El proceso ETL utiliza las variables definidas en el archivo `.env` de la raíz del repositorio.

Si todavía no se creó el archivo durante la configuración de PostgreSQL, ejecutar:

```bash
cp .env.example .env
```

La configuración esperada para PostgreSQL es:

```dotenv
DB_HOST=localhost
DB_PORT=5432
DB_NAME=smartcityce
DB_USER=smartcity
DB_PASSWORD=ZXCV1234
```

El archivo `.env` contiene la configuración local utilizada por los scripts de carga y no debe subirse a GitHub.

El cargador `scripts/load_postgresql.py` utiliza estas variables para establecer la conexión con PostgreSQL mediante `psycopg2`.

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

## 13. Resumen de comandos para PostgreSQL

Una vez instaladas las herramientas necesarias, este es el orden para configurar PostgreSQL desde cero.

```bash
# 1. Crear y activar el entorno virtual
python3 -m venv .venv
source .venv/bin/activate

# 2. Instalar dependencias
pip install -r requirements.txt

# 3. Crear la configuración local
cp .env.example .env

# 4. Descargar los datasets
python scripts/download_datasets.py

# 5. Crear la base de datos y el usuario
# La configuración se obtiene desde .env
bash scripts/setup_database.sh

# 6. Crear las tablas
psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f SQL/01_schema.sql

# 7. Probar el esquema
psql -h localhost -U smartcity -d smartcityce \
    -X -v ON_ERROR_STOP=1 \
    -f tests/test_schema.sql

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

La carga completa puede requerir varios minutos debido al volumen de registros procesados.


## 14. Configurar MongoDB

SmartCityCE utiliza MongoDB para almacenar información semiestructurada y de alta frecuencia, incluyendo las lecturas eléctricas utilizadas por el proyecto.

MongoDB se ejecuta mediante Docker Compose, por lo que es necesario tener Docker y Docker Compose disponibles antes de continuar.

### 14.1. Configurar las variables de entorno

Las variables necesarias para MongoDB están documentadas en `.env.example`.

El archivo `.env` debe incluir:

```dotenv
MONGO_ROOT_USER=smartcity
MONGO_ROOT_PASSWORD=smartcity_dev
MONGO_DATABASE=smartcityce
MONGO_PORT=27017
```

Estas credenciales corresponden únicamente al entorno local de desarrollo.

### 14.2. Inicializar MongoDB

Desde la raíz del repositorio, ejecutar:

```bash
bash scripts/init_mongodb.sh
```

El script realiza las siguientes operaciones:

- Lee la configuración desde `.env`.
- Comprueba que Docker esté disponible.
- Levanta el servicio `mongodb` definido en `docker-compose.yml`.
- Espera hasta que MongoDB responda correctamente.
- Deja la base disponible para realizar la carga de datos.

El script puede ejecutarse nuevamente si el contenedor ya existe. En ese caso, Docker Compose reutiliza el servicio configurado.

### 14.3. Cargar las lecturas

Para realizar una carga reproducible de 500 000 documentos:

```bash
python MongoDB/cargar_lecturas.py \
    --limite 500000 \
    --reiniciar
```

La opción `--reiniciar` elimina la colección `lecturas` existente antes de comenzar la nueva carga.

Durante la validación del proceso se obtuvo una carga de:

```text
Documentos insertados: 500,000
```

El script utiliza los datos eléctricos de BDG2 y sus metadatos asociados.

### 14.4. Crear los índices

Los índices deben crearse después de finalizar la carga masiva.

Primero cargar las variables del archivo `.env` en la terminal:

```bash
set -a
source .env
set +a
```

Luego ejecutar:

```bash
docker exec -i smartcity_mongodb mongosh \
    -u "$MONGO_ROOT_USER" \
    -p "$MONGO_ROOT_PASSWORD" \
    --authenticationDatabase admin \
    --quiet \
    < MongoDB/indexes.js
```

El archivo `MongoDB/indexes.js` crea los índices utilizados para las consultas por sensor, fecha, zona y la combinación sensor-fecha.

Los índices se aplican después de la carga masiva para evitar el costo de mantenerlos durante la inserción inicial de los documentos.

### 14.5. Verificar MongoDB

Para comprobar que el contenedor se encuentra en ejecución:

```bash
docker compose ps
```

También puede abrirse una sesión de MongoDB mediante:

```bash
docker exec -it smartcity_mongodb mongosh \
    -u "$MONGO_ROOT_USER" \
    -p "$MONGO_ROOT_PASSWORD" \
    --authenticationDatabase admin
```

Una vez dentro:

```javascript
use smartcityce
db.lecturas.countDocuments()
db.lecturas.getIndexes()
```

Para la carga reproducible utilizada por el proyecto, `countDocuments()` debe devolver 500 000 documentos.

## 15. Inicialización automatizada de las bases de datos

Además de los procedimientos manuales, SmartCityCE incluye el script:

```text
scripts/init_databases.sh
```

Este script coordina la preparación de los datasets y la inicialización de PostgreSQL y MongoDB utilizando los scripts existentes del proyecto.

### 15.1. Modos de ejecución

El script admite tres modos.

Inicializar solamente PostgreSQL:

```bash
bash scripts/init_databases.sh --postgres
```

Inicializar solamente MongoDB:

```bash
bash scripts/init_databases.sh --mongo
```

Inicializar ambas bases:

```bash
bash scripts/init_databases.sh --all
```

Si se ejecuta sin indicar un modo, el script muestra las opciones disponibles y no modifica ninguna base de datos.

### 15.2. Flujo de PostgreSQL

Al utilizar `--postgres`, el proceso realiza:

1. Preparación de los datasets.
2. Validación de la disponibilidad de PostgreSQL y `psql`.
3. Creación/configuración del usuario y la base mediante `scripts/setup_database.sh`.
4. Ejecución de `SQL/01_schema.sql`.
5. Carga de los datos mediante `scripts/load_postgresql.py`.

PostgreSQL debe estar instalado en el entorno desde el cual se ejecuta el script.

Si `psql` no está disponible, la inicialización se detiene y muestra un mensaje de error sin continuar con la carga.

### 15.3. Flujo de MongoDB

Al utilizar `--mongo`, el proceso realiza:

1. Preparación de los datasets.
2. Inicialización del contenedor mediante `scripts/init_mongodb.sh`.
3. Reinicio de la colección `lecturas`.
4. Carga reproducible de 500 000 documentos.
5. Creación de los índices definidos en `MongoDB/indexes.js`.

**Importante:** el modo `--mongo` utiliza la opción `--reiniciar`, por lo que reemplaza el contenido existente de la colección `lecturas`.

### 15.4. Flujo completo

El modo:

```bash
bash scripts/init_databases.sh --all
```

ejecuta primero PostgreSQL y posteriormente MongoDB.

El orden completo es:

```text
Preparar datasets
        |
        v
Configurar PostgreSQL
        |
        v
Crear esquema PostgreSQL
        |
        v
Cargar PostgreSQL
        |
        v
Levantar MongoDB
        |
        v
Cargar 500 000 documentos
        |
        v
Crear índices MongoDB
```

El script utiliza `set -Eeuo pipefail`, por lo que si una etapa falla el proceso se detiene y no continúa con las siguientes etapas.

### 15.5. Requisitos

Antes de utilizar la inicialización automatizada se requiere:

- Python 3 y las dependencias de `requirements.txt`.
- Archivo `.env` creado a partir de `.env.example`.
- PostgreSQL y `psql` para los modos `--postgres` y `--all`.
- Docker y Docker Compose para los modos `--mongo` y `--all`.
- Acceso a Internet para descargar datasets que todavía no estén disponibles localmente.

La carga completa puede tardar debido al volumen de información procesada.

## Resultado final

Si todos los pasos se ejecutan correctamente, el entorno de bases de datos de SmartCityCE estará listo para utilizarse en el desarrollo del proyecto.

PostgreSQL contendrá la información estructurada del sistema, incluyendo edificios, sensores, ubicaciones, lecturas seleccionadas y registros meteorológicos.

MongoDB contendrá la información documental y de alta frecuencia utilizada por el proyecto, incluyendo la colección de lecturas eléctricas y los índices necesarios para realizar consultas eficientes.

Los scripts de inicialización permiten reproducir la configuración de ambas bases a partir de los archivos y datasets definidos en el repositorio.
