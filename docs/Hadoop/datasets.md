# SmartCityCE — Preparación de datasets para Hadoop (Issue #41)

## Objetivo

Preparar copias CSV de BDG2 (sitio `Panther`) y Open-Meteo para su posterior carga a HDFS (Issue #42). El proceso no modifica archivos fuente ni depende de PostgreSQL.

## Entradas

| Fuente | Ruta local | Identificación |
|---|---|---|
| BDG2: metadatos | `data/raw/bdg2/metadata/metadata.csv` | `building_id`, `site_id`, `electricity`, `primaryspaceusage`, `sub_primaryspaceusage`, `sqm`, `timezone` |
| BDG2: electricidad | `data/raw/bdg2/meters/cleaned/electricity_cleaned.csv` | `timestamp` + columnas de medidores identificados por edificio |
| Open-Meteo | `data/raw/open_meteo/orlando_weather_2016_2017.csv` | `time` y variables meteorológicas con unidades en el encabezado |

Estos son archivos locales previamente descargados; están excluidos de Git. Para obtenerlos, consultar `scripts/download_datasets.py` y `docs/datasets.md`.

## Selección y transformación

1. **Edificios:** seleccionar `site_id = Panther`, descartar identificadores vacíos o duplicados y preservar las siete columnas indicadas arriba. No se descartan edificios con `electricity` vacío del catálogo.
2. **Medidores:** seleccionar únicamente columnas de `electricity_cleaned.csv` cuyo `building_id` corresponde a un edificio Panther marcado exactamente `electricity = Yes` (sin distinguir mayúsculas); es el mismo criterio de `scripts/load_postgresql.py`.
3. **Electricidad:** convertir CSV ancho a largo: `timestamp,building_id,value`. Conservar ceros; omitir valores vacíos, no numéricos o no finitos. Se registra el número de valores omitidos. No se inventan valores.
4. **Meteorología:** conservar temperatura, humedad relativa, precipitación, nubosidad alta/media/baja/total y velocidad del viento. Se validan las unidades explícitas del encabezado; se omiten registros con fechas inválidas o valores incompletos.
5. **Fechas:** validar y normalizar texto de fecha a `YYYY-MM-DD HH:MM:SS`; no convertir automáticamente a UTC ni afirmar correspondencia horaria entre fuentes. BDG2 indica `US/Eastern` en los ejemplos de metadatos y la descarga configurada de Open-Meteo usa `America/New_York`; la alineación temporal debe validarse antes de cruzar series, especialmente en cambios de horario de verano.
6. **Unidades eléctricas:** se conserva el valor original bajo la columna neutral `value`. La unidad exacta de las lecturas BDG2 debe confirmarse con documentación de la fuente antes de etiquetar valores `kWh` o hacer interpretaciones energéticas.

## Salidas

Todos los archivos se generan en `data/processed/hadoop/` (directorio ignorado por Git):

| Archivo | Esquema |
|---|---|
| `buildings.csv` | `building_id,site_id,primaryspaceusage,sub_primaryspaceusage,sqm,timezone,electricity` |
| `electricity.csv` | `timestamp,building_id,value` |
| `weather.csv` | `timestamp,temperature_c,humidity_pct,precipitation_mm,cloud_cover_high_pct,cloud_cover_mid_pct,cloud_cover_low_pct,cloud_cover_pct,wind_speed_kmh` |

La organización prevista en HDFS para la Issue #42 es `/smartcityce/raw/` para fuentes originales, si se decide conservarlas allí, y `/smartcityce/processed/{buildings,electricity,weather}/` para los archivos resultantes. Es una **convención propuesta**, todavía no una carga realizada.

## Ejecución

Desde la raíz del repositorio:

```bash
python3 Hadoop/scripts/prepare_datasets.py --max-hours 24  # prueba pequeña
python3 Hadoop/scripts/prepare_datasets.py                 # proceso completo
ls -lh data/processed/hadoop/
wc -l data/processed/hadoop/*.csv
```

`--max-hours` limita únicamente el número de filas temporales de BDG2, no los registros meteorológicos. El proceso completo sobrescribe las salidas procesadas, pero **no** los archivos originales. Se utilizan archivos temporales para evitar dejar salidas parcialmente actualizadas ante un error ordinario (no es una transacción atómica entre los tres archivos).

## Validaciones y límites

- Se comprueba que existan entradas, columnas requeridas y medidores coincidentes con los metadatos.
- Se imprimen recuentos de edificios, medidores, lecturas, horas y registros descartados por ausencia o invalidez.
- El procesamiento eléctrico usa `csv.DictReader` de forma secuencial y no requiere cargar el archivo completo en memoria.
- El script **no identifica duplicados temporales en electricidad ni clima**. Debe comprobarse ese aspecto antes de efectuar agregaciones que presupongan claves únicas.
- La validación de unidades climáticas depende de encabezados explícitos como `temperature_2m (°C)`; si el archivo cambia a encabezados sin unidades, el script detiene la ejecución en vez de suponerlas.
- El hecho de que el script termine correctamente **no demuestra todavía** que los CSV superen 100 MB ni que Spark procese 1.000.000 de filas; verificar los tamaños y recuentos reales después de ejecutarlo.
- Open-Meteo se descargó para coordenadas aproximadas de Orlando, no para cada edificio individual. No se deben presentar los valores como mediciones particulares de cada edificio ni unir sin verificar el criterio espacial y temporal.

## Fuentes de referencia

- `docs/datasets.md` (origen, limitaciones y atribución).
- `scripts/download_datasets.py` (descarga de datos).
- `scripts/load_postgresql.py` (criterios ya utilizados para los edificios y sensores Panther).
