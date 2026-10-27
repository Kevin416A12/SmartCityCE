# Preparación y carga masiva de datos en MongoDB

## 1. Objetivo

El objetivo de esta etapa es preparar, transformar y cargar los datos seleccionados para el componente documental de MongoDB del proyecto **SmartCityCE**.

Para la colección `lecturas` se utiliza como fuente principal el **Building Data Genome Project 2 (BDG2)**. Los datos originales se encuentran en formato CSV y son transformados mediante un script desarrollado en Python a documentos compatibles con BSON para posteriormente almacenarlos en MongoDB.

La carga se realiza en la base de datos `smartcityce` y se prepara para cumplir con el requisito de almacenar al menos **500 000 documentos**.

---

## 2. Fuente de datos

Para las lecturas de consumo eléctrico se utiliza el archivo:

`data/raw/bdg2/meters/cleaned/electricity_cleaned.csv`

Los metadatos asociados a los edificios y series de medición se obtienen de:

`data/raw/bdg2/metadata/metadata.csv`

El archivo `electricity_cleaned.csv` está organizado de forma que la primera columna corresponde al timestamp y las columnas restantes representan las diferentes series de medición.

Durante la inspección del dataset se identificaron:

- **1 578** series de medición de electricidad.
- **17 544** filas temporales.
- Correspondencia de las **1 578** series eléctricas con registros presentes en `metadata.csv`.

Para relacionar ambos archivos se utiliza el identificador `building_id`.

Se seleccionó la versión `cleaned` de las mediciones eléctricas de BDG2 con el propósito de trabajar con los datos previamente depurados proporcionados por el dataset, sin modificar los archivos originales.

---

## 3. Script de transformación y carga

La transformación y carga de las lecturas se realiza mediante el archivo:

`MongoDB/cargar_lecturas.py`

El script realiza las siguientes tareas:

1. Lee los metadatos disponibles en `metadata.csv`.
2. Lee progresivamente las mediciones de `electricity_cleaned.csv`.
3. Relaciona cada serie de medición con su `building_id`.
4. Omite las celdas que no contienen una medición válida.
5. Convierte los valores numéricos a `float`.
6. Interpreta la fecha de acuerdo con la zona horaria indicada en los metadatos.
7. Convierte la fecha a UTC para su almacenamiento en MongoDB.
8. Incorpora la información disponible de ubicación, sensor y procedencia.
9. Construye un documento por cada lectura válida.
10. Inserta los documentos en MongoDB mediante lotes.

De esta forma, el proceso de transformación se realiza directamente desde los archivos CSV hacia documentos BSON a través de PyMongo, sin necesidad de generar manualmente un archivo intermedio.

---

## 4. Estructura de los documentos

Cada medición válida genera un documento independiente dentro de la colección `lecturas`.

La estructura utilizada es similar a la siguiente:

```javascript
{
    id_sensor: "Panther_parking_Lorriane",

    fecha_hora: ISODate("2016-01-01T05:00:00.000Z"),

    medicion: {
        valor: 0.0,
        unidad: "kWh_sum"
    },

    ubicacion: {
        id_ubicacion: "Panther",
        zona: "Panther",
        coordenadas: {
            latitud: 28.5176885788321,
            longitud: -81.3790387999998
        }
    },

    sensor: {
        tipo: "energia",
        categoria: "consumo_electrico",
        uso_primario: "Parking"
    },

    metadatos: {
        fuente: "BDG2",
        calidad: "limpio",
        zona_horaria_origen: "US/Eastern"
    }
}
```

Esta estructura sigue el modelo documental definido previamente para la colección `lecturas`.

---

## 5. Manejo de valores faltantes

El dataset contiene celdas en las que no existe una medición disponible.

Durante la transformación, estas celdas no se convierten en documentos. El script verifica cada valor antes de construir la lectura y omite aquellos que se encuentren vacíos o que no puedan convertirse correctamente a un valor numérico.

De esta manera, cada documento almacenado en `lecturas` corresponde a una medición válida.

El script también muestra al finalizar la cantidad de valores omitidos durante el procesamiento, facilitando la verificación de la carga.

---

## 6. Manejo de fechas y zonas horarias

Los timestamps de BDG2 deben interpretarse considerando la zona horaria correspondiente al sitio al que pertenece cada serie de medición.

El archivo `metadata.csv` contiene el campo `timezone`, el cual se utiliza durante la transformación.

El script emplea `ZoneInfo` para asociar el timestamp con su zona horaria de origen y posteriormente lo convierte a **UTC** antes de almacenarlo.

Por ejemplo, una lectura con:

```text
Timestamp original: 2016-01-01 00:00:00
Zona horaria: US/Eastern
```

se almacena en MongoDB como:

```javascript
ISODate("2016-01-01T05:00:00.000Z")
```

MongoDB conserva `fecha_hora` utilizando el tipo BSON `Date`.

Además, la zona horaria de origen se mantiene explícitamente dentro del documento:

```text
metadatos.zona_horaria_origen
```

Esto permite trabajar con fechas normalizadas en las consultas posteriores sin perder el contexto temporal proporcionado por la fuente original.

---

## 7. Unidades de las mediciones

Las lecturas eléctricas se almacenan utilizando la unidad:

```text
kWh_sum
```

Esta información se conserva dentro del subdocumento `medicion`:

```javascript
medicion: {
    valor: 0.0,
    unidad: "kWh_sum"
}
```

De esta manera, el valor de la lectura permanece acompañado por la información necesaria para interpretar correctamente la medición.

---

## 8. Manejo de coordenadas

Los metadatos de BDG2 incluyen información geográfica para los sitios cuando esta se encuentra disponible.

Durante la transformación se recuperan los campos de latitud y longitud asociados a cada serie. Cuando ambos valores son válidos, se incorporan dentro de:

```text
ubicacion.coordenadas
```

con la estructura:

```javascript
coordenadas: {
    latitud: 28.5176885788321,
    longitud: -81.3790387999998
}
```

No se generan coordenadas artificiales para completar información faltante. Las coordenadas almacenadas proceden directamente de los metadatos del dataset.

Asimismo, el `site_id` de BDG2 se conserva como identificador lógico de ubicación y zona. Por ejemplo:

```javascript
ubicacion: {
    id_ubicacion: "Panther",
    zona: "Panther"
}
```

Por lo tanto, nombres como `Panther` corresponden a identificadores propios de BDG2 y no representan zonas urbanas inventadas para el proyecto.

---

## 9. Inserción por lotes

La carga no realiza una operación individual contra MongoDB por cada lectura.

Para mejorar la eficiencia, los documentos se acumulan temporalmente y posteriormente se insertan utilizando:

```python
insert_many()
```

El tamaño predeterminado de cada lote es de:

```text
5 000 documentos
```

Este valor puede modificarse mediante el argumento:

```bash
--lote
```

Por ejemplo:

```bash
python MongoDB/cargar_lecturas.py --limite 100000 --lote 10000
```

Esto permite modificar el tamaño de las operaciones de inserción sin alterar el código fuente.

---

## 10. Parámetros del script

El cargador proporciona diferentes argumentos para facilitar las pruebas y la reproducción del proceso.

### `--limite`

Permite indicar la cantidad máxima de documentos que se desea insertar.

Ejemplo:

```bash
python MongoDB/cargar_lecturas.py --limite 100
```

Este parámetro fue utilizado inicialmente para validar la transformación con una cantidad pequeña de documentos antes de realizar la carga masiva.

### `--lote`

Permite modificar la cantidad de documentos enviados en cada operación `insert_many()`.

El valor predeterminado es de 5 000 documentos.

### `--reiniciar`

Elimina la colección `lecturas` antes de iniciar una nueva carga.

Ejemplo:

```bash
python MongoDB/cargar_lecturas.py --limite 100 --reiniciar
```

Esta opción permite realizar una carga controlada desde una colección limpia y evita acumular los documentos utilizados durante pruebas anteriores.

---

## 11. Validación previa

Antes de realizar la carga definitiva se ejecutó una prueba limitada a 100 documentos:

```bash
python MongoDB/cargar_lecturas.py --limite 100 --reiniciar
```

Posteriormente se verificó la cantidad almacenada mediante:

```javascript
db.lecturas.countDocuments()
```

obteniendo:

```text
100
```

También se inspeccionó un documento mediante:

```javascript
db.lecturas.findOne()
```

La prueba permitió comprobar que:

- `fecha_hora` se almacena como `ISODate`.
- Los valores de medición se almacenan numéricamente.
- Se conserva la unidad de la medición.
- Se incorporan los identificadores reales de BDG2.
- Las coordenadas disponibles se incorporan desde los metadatos.
- Se conserva la zona horaria de origen.
- La fecha local se convierte a UTC correctamente.

---

## 12. Carga masiva

Una vez validada la transformación, se realizó la carga definitiva mediante:

```bash
python MongoDB/cargar_lecturas.py --limite 500000 --reiniciar
```

La opción `--reiniciar` garantiza que la colección utilizada durante las pruebas se elimine antes de comenzar la carga definitiva.

El proceso finalizó con:

```text
Carga finalizada.
Documentos insertados: 500,000
```

Posteriormente se verificó directamente la cantidad de documentos almacenados en MongoDB:

```javascript
db.lecturas.countDocuments()
```

Resultado:

```text
500000
```

Por lo tanto, la colección `lecturas` cumple con el requisito de almacenar al menos **500 000 documentos**.

---

## 13. Datos sintéticos

No fue necesario utilizar generación sintética para alcanzar el volumen mínimo requerido.

BDG2 proporciona una cantidad suficiente de mediciones eléctricas reales para generar los 500 000 documentos utilizados en la carga.

Por lo tanto, los documentos de la colección `lecturas` utilizados para satisfacer el requisito de volumen provienen de las mediciones disponibles en el dataset seleccionado.

En caso de que posteriormente se requieran datos derivados o sintéticos para otras colecciones del modelo, estos deberán identificarse y documentarse explícitamente de acuerdo con su origen.

---

## 14. Reproducibilidad de la carga

Para reproducir la carga de las lecturas se deben cumplir los siguientes pasos:

1. Descargar previamente el dataset BDG2 mediante el mecanismo definido en el proyecto.
2. Tener el servicio de MongoDB en ejecución.
3. Configurar las variables correspondientes a MongoDB en el archivo local `.env`.
4. Crear y activar el entorno virtual de Python.
5. Instalar las dependencias de `requirements.txt`.
6. Ejecutar el script de carga.

La carga utilizada para satisfacer el requisito de volumen puede reproducirse mediante:

```bash
python MongoDB/cargar_lecturas.py --limite 500000 --reiniciar
```

El archivo `.env` no se almacena en el repositorio. Para documentar las variables requeridas se utiliza `.env.example`.

---

## 15. Resultado

La preparación y carga de las lecturas permite transformar los datos tabulares de BDG2 en documentos adecuados para el modelo documental de SmartCityCE.

Como resultado se dispone de una colección `lecturas` con:

- **500 000 documentos cargados**.
- Datos procedentes de BDG2.
- Mediciones almacenadas numéricamente.
- Fechas almacenadas mediante BSON `Date` y normalizadas a UTC.
- Zona horaria original conservada.
- Información del sensor incorporada.
- Ubicación y coordenadas incorporadas cuando están disponibles.
- Identificación explícita de la fuente y calidad de los datos.
- Un procedimiento de carga reproducible mediante Python y PyMongo.

La cantidad de documentos fue comprobada directamente en MongoDB mediante `countDocuments()`, confirmando el cumplimiento del volumen mínimo establecido para la carga documental.
