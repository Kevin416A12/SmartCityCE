# SmartCityCE — Dominio y fuentes de datos

> **Issue #1:** Definir dominio SmartCity y seleccionar datasets  
> **Estado:** Selección inicial documentada; pendiente validación técnica de descarga, campos y cobertura.  
> **Ubicación en el repositorio:** `/docs/datasets.md`

## 1. Dominio seleccionado

**Energía: monitoreo y análisis del consumo energético urbano.**

SmartCityCE plantea un sistema de análisis de lecturas de medidores energéticos de edificios, complementadas con información meteorológica histórica. El objetivo es estudiar el consumo en distintas instalaciones, caracterizar patrones temporales, comparar grupos de edificios y explorar la relación entre las condiciones climáticas y la demanda energética.

**Alcance geográfico:** Los datos originales de Building Data Genome 2 (BDG2) proceden de edificios de diferentes sitios; **no se asumirán como zonas reales de una única ciudad**. Para el caso de estudio SmartCity se podrán definir zonas lógicas o utilizar los sitios existentes, indicando explícitamente cómo se construyó esa representación. No se inventarán coordenadas reales.

## 2. Problema a resolver

Los medidores inteligentes producen secuencias de lecturas que deben almacenarse y analizarse junto con metadatos de las instalaciones y variables externas, como la temperatura. El problema es organizar datos estructurados y series temporales de gran volumen para responder preguntas útiles para la planificación energética:

- ¿Cómo varía el consumo por hora, día, mes y tipo de edificio?
- ¿Cuáles instalaciones o agrupaciones registran mayor consumo?
- ¿En qué períodos aparecen picos de demanda?
- ¿Existe correlación entre temperatura exterior y consumo?
- ¿Qué lecturas parecen anómalas respecto al comportamiento histórico?
- ¿Qué sensores dejan de reportar durante un intervalo establecido?

Estas preguntas **son objetivos de análisis**, no resultados ya obtenidos.

## 3. Fuentes de datos seleccionadas

### Fuente principal — Building Data Genome Project 2 (BDG2)

| Característica | Información |
|---|---|
| Nombre | Building Data Genome Project 2 (BDG2) |
| Publicación / referencia | *Scientific Data* (2020), DOI: `10.1038/s41597-020-00712-x` |
| Repositorio | https://github.com/buds-lab/building-data-genome-project-2 |
| Registro del dataset | https://openenergyhub.ornl.gov/explore/dataset/the-building-data-genome-2-bdg2-data-set/ |
| Licencia publicada en catálogo | CC BY 4.0; verificar condiciones de los archivos descargados antes de redistribuirlos |
| Cobertura temporal | 2016–2017 |
| Granularidad | Horaria |
| Alcance publicado | 3.053 medidores y 1.636 edificios |
| Tipos de medición | Electricidad y otros medidores energéticos (calefacción, refrigeración, vapor y riego) |

El repositorio describe datos de medidores, metadatos de edificios y datos de clima. La ruta publicada incluye `data/metadata/`, `data/weather/` y `data/meters/` (con archivos crudos y limpiados). Las columnas exactas, formatos y cardinalidad de cada archivo se verificarán después de la descarga.

**Uso propuesto:** seleccionar principalmente lecturas eléctricas, preservar los identificadores originales de medidores/edificios, construir catálogos de referencia y analizar sus series temporales.

### Fuente complementaria — Open-Meteo Historical Weather API

| Característica | Información |
|---|---|
| Nombre | Open-Meteo Historical Weather API |
| Documentación | https://open-meteo.com/en/docs/historical-weather-api |
| Servicio de datos | `https://archive-api.open-meteo.com/v1/archive` |
| Cobertura histórica | Modelos históricos con datos desde 1940 o 1950, según el producto; permite consultar 2016–2017 |
| Variables previstas | `temperature_2m`, `relative_humidity_2m` y, si se necesitan, precipitación y otras variables |
| Resolución | Puede proporcionar datos horarios según modelo y parámetros |
| Licencia de datos indicada por el proveedor | CC BY 4.0 con atribución; revisar límites y condiciones del servicio para uso académico |

**Uso propuesto:** consultar clima de 2016–2017 para ubicaciones de BDG2 **solo cuando se disponga de localización suficientemente fiable** y un criterio trazable de asociación espacial. La API provee reanálisis/modelos meteorológicos, no necesariamente mediciones directas de una estación concreta.

**Nota:** BDG2 ya incluye archivos meteorológicos. Open-Meteo se incorpora como **segunda fuente externa independiente**, no como si el clima incluido en BDG2 fuera otro repositorio independiente. Antes de mezclar las series se revisarán diferencias de cobertura, resolución, huso horario y variables.

## 4. Repartición de la información entre tecnologías

| Tecnología | Datos propuestos | Justificación |
|---|---|---|
| **PostgreSQL** | Catálogos de medidores/sensores, edificios, sitios o zonas lógicas, categorías, organismos y usuarios de referencia; posibles agregados tabulares | Estructuras relacionadas, claves y restricciones de integridad; consultas SQL y análisis relacional |
| **MongoDB** | Lecturas energéticas, mediciones meteorológicas asociadas, eventos y alertas de monitoreo | Documentos con diferentes tipos de medición, atributos variables y datos temporales |
| **Hadoop / HDFS** | Copias históricas masivas en formatos definidos (CSV, JSON o Parquet), registros crudos e intermedios | Almacenamiento distribuido para la segunda entrega |
| **Apache Spark** | Series de consumo y clima provenientes de los repositorios, transformaciones, cruces y resultados analíticos | Procesamiento distribuido, agregaciones temporales, correlaciones y detección de anomalías |

La estructura concreta de las tablas y colecciones se definirá en las Issues de modelado (`/SQL` y `/MongoDB`). Esta tabla establece **responsabilidades propuestas**, no una implementación terminada.

## 5. Campos necesarios y validación pendiente

| Necesidad | Datos requeridos | Situación |
|---|---|---|
| Identificar medidores | ID de medidor / vínculo con edificio | Verificar correspondencia de archivos BDG2 |
| Fechas y actividad | Timestamp y valor de lectura | Presentes como series temporales según descripción de BDG2; verificar formatos y faltantes |
| Tipos de sensor | Tipo de medidor / categoría | BDG2 describe tipos de medidor; las categorías del proyecto deberán normalizarse |
| Zonas | Sitio, agrupación o localización confiable | Definir qué significa «zona»; no asumir distritos o coordenadas inexistentes |
| Consumo | Valor, tipo de energía y unidad | Verificar unidades antes de sumar o comparar medidores distintos |
| Clima | Tiempo, ubicación, temperatura y humedad | Disponibles mediante Open-Meteo; requiere cruce geográfico/temporal válido |
| Alertas y eventos | ID de sensor, fecha, tipo, severidad y contexto | No confirmado como contenido nativo de BDG2/Open-Meteo; **generar eventos derivados** mediante reglas documentadas o incorporar tercera fuente |
| Incidentes urbanos | Categoría, fecha y vínculo con sensor/zona | No confirmados; requieren fuente adicional o **simulación claramente etiquetada** |
| Organismos y usuarios | Identificación y relaciones con sensores | No confirmados; datos de referencia a definir, marcando los sintéticos |
| Fecha de instalación y estado de sensores | Campos del esquema SQL obligatorio | No confirmados en fuentes; requerirán criterios explícitos para su representación |

**Regla de calidad:** los atributos derivados o sintéticos deben quedar marcados como tales y no presentarse como observaciones reales.

## 6. Requisitos de volumen

El enunciado define como escenario mínimo del proyecto completo:

- **100.000 registros en PostgreSQL.**
- **500.000 documentos en MongoDB.**
- **1.000.000 registros procesados mediante Spark.**

También establece una referencia de **100 MB mínimo** para el dataset del proyecto, y recomienda mayores volúmenes para demostrar procesamiento distribuido. El conjunto BDG2 es suficientemente amplio **en principio**, pero **aún no se ha ejecutado ni validado una carga** de esos tamaños.

### Estrategia preliminar

1. Descargar y examinar metadatos y lecturas de BDG2.
2. Seleccionar únicamente mediciones con identificadores, fechas y unidades interpretables.
3. Obtener clima de Open-Meteo para ubicaciones y períodos compatibles.
4. Diseñar una carga de PostgreSQL que cumpla el volumen exigido **sin forzar artificialmente tablas maestras pequeñas**; la selección exacta de tablas queda pendiente de modelado.
5. Cargar al menos 500.000 documentos de medición en MongoDB.
6. Reservar un volumen de al menos 1.000.000 de registros para la fase Hadoop/Spark.
7. En caso de ampliar registros mediante simulación, documentar método, semilla, proporciones, atributos modificados y límites de interpretación.

No se declara ningún umbral como cumplido hasta verificar recuentos tras la carga.

## 7. Consultas y análisis esperados

**PostgreSQL:** sensores por tipo/ubicación, activos e inactivos, sensores por organismo, ubicaciones con más sensores, instalaciones por año, sensores sin actividad, ranking de zonas, vistas y funciones/procedimientos. También deben demostrarse JOINs, agregaciones, subconsultas, CTEs, funciones de ventana, consultas de fechas e índices.

**MongoDB:** lecturas por sensor y fecha, máximos/mínimos, eventos críticos, alertas por zona, promedios por zona y tipo, incidentes por categoría, agregaciones y filtros múltiples; también CRUD e índices.

**Hadoop y Spark (segunda entrega):** conservar históricos, operaciones HDFS y procesamiento distribuido; análisis temporal, correlacional, tendencias, anomalías, comparaciones y reportes.

**Restricción importante del enunciado:** aunque el dominio principal sea Energía, la rúbrica y los requisitos generales de interfaz incluyen KPIs de movilidad, ambiente, energía e IoT, además de consultas de cuatro motores. **Estas exigencias no quedan resueltas automáticamente con BDG2 + Open-Meteo**; debe acordarse cómo cubrirlas en las Issues posteriores sin afirmar datos que no existan.

## 8. Decisiones y supuestos por confirmar

- [ ] Descargar BDG2 y verificar el esquema real, el tamaño y las unidades de sus archivos.
- [ ] Determinar qué medidores son de electricidad y cuáles de otras fuentes energéticas.
- [ ] Definir qué identificadores serán sensores, edificios, ubicaciones y categorías.
- [ ] Confirmar si las ubicaciones disponibles permiten asociar clima de Open-Meteo con suficiente precisión.
- [ ] Confirmar husos horarios, valores faltantes y duplicados.
- [ ] Diseñar una representación transparente de zonas si no existen zonas urbanas reales.
- [ ] Establecer criterios para «sensor activo/inactivo» y «sin actividad».
- [ ] Decidir origen y generación reproducible de alertas, eventos e incidentes.
- [ ] Planificar cómo cubrir los KPI ajenos al dominio Energía que exige la interfaz.
- [ ] Validar cobertura de las 10 consultas obligatorias de PostgreSQL y las 10 de MongoDB antes de cerrar el modelado.
- [ ] Registrar recuentos y tamaños **reales** después de la carga.

## 9. Referencias y atribución

1. BDG2 — repositorio oficial: https://github.com/buds-lab/building-data-genome-project-2
2. BDG2 — publicación científica: https://doi.org/10.1038/s41597-020-00712-x
3. BDG2 — catálogo y licencia: https://openenergyhub.ornl.gov/explore/dataset/the-building-data-genome-2-bdg2-data-set/
4. Open-Meteo — Historical Weather API: https://open-meteo.com/en/docs/historical-weather-api
5. Open-Meteo — licencia y atribución: https://github.com/open-meteo/open-meteo
6. Enunciado del curso — *SmartCity Analytics*, CE-3191 Bases de Datos, II semestre 2026 (documento proporcionado por el curso).

Al publicar datos o visualizaciones derivados de Open-Meteo, incluir la atribución correspondiente. Para BDG2, respetar la atribución de autores y la licencia aplicable a los datos efectivamente usados.

---

## 10. Checklist de la Issue #1

- [x] Dominio principal seleccionado: Energía.
- [x] Problema del proyecto definido.
- [x] Dos fuentes de datos independientes identificadas y documentadas.
- [x] URLs y condiciones de licencia de referencia documentadas.
- [x] Distribución preliminar PostgreSQL / MongoDB definida.
- [x] Proyección de responsabilidades Hadoop / Spark documentada.
- [ ] Descarga e inspección local de ambos conjuntos de datos.
- [ ] Confirmación de todos los atributos necesarios para consultas obligatorias.
- [ ] Validación de cobertura geográfica y temporal para integración.

**Conclusión:** Se cumple la parte de **selección y documentación inicial** de la Issue #1. La **validación de suficiencia de los datasets** permanece abierta hasta inspeccionarlos y verificar su cobertura frente a las consultas obligatorias.
