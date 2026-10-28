# Comparación tecnológica: PostgreSQL vs. MongoDB

## 1. Objetivo y alcance

Este documento compara PostgreSQL y MongoDB en el contexto de SmartCityCE y justifica la asignación de datos realizada en las entregas del proyecto. Las conclusiones se apoyan en el esquema relacional, el modelo documental, las consultas, los índices y los datos integrados en las implementaciones existentes.

La comparación no significa que una tecnología sea superior en todos los casos. Ambas cumplen funciones complementarias:

- PostgreSQL almacena datos maestros, estructurados y altamente relacionados.
- MongoDB almacena lecturas temporales y datos semiestructurados que deben ser consultados y agregados con flexibilidad.

## 2. Resumen comparativo

| Criterio | PostgreSQL | MongoDB | Decisión en SmartCityCE |
|---|---|---|---|
| Datos estructurados | Excelente: esquema fijo, tipos definidos y relaciones explícitas | Bueno, pero mantiene estructuras flexibles | PostgreSQL |
| Datos semiestructurados | Puede representarlos con JSONB, aunque con menor naturalidad para documentos heterogéneos | Excelente: documentos BSON y campos embebidos | MongoDB |
| Relaciones complejas | Excelente mediante tablas normalizadas, claves e instrucciones `JOIN` | Adecuado mediante referencias o documentos desnormalizados; las relaciones complejas son menos naturales | PostgreSQL |
| Grandes volúmenes | Muy bueno con particionamiento, índices y optimización; requiere diseño cuidadoso para series temporales | Muy bueno mediante distribución horizontal y documentos independientes | MongoDB para series temporales, PostgreSQL para datos maestros y una muestra SQL |
| Flexibilidad del esquema | Esquema explícito y controlado; los cambios requieren migraciones | Esquema flexible por documento, con validación opcional o JSON Schema | MongoDB para estructuras variables, PostgreSQL para maestros |
| Integridad | Fuerte mediante PK, FK, `NOT NULL`, `UNIQUE` y `CHECK` | Integridad dentro del documento o mediante lógica de aplicación; no existen FK transaccionales entre colecciones | PostgreSQL |
| Capacidades analíticas | SQL, vistas, funciones, `JOIN`, ventanas y agregaciones | Aggregation Framework con tuberías de etapas | PostgreSQL para análisis relacionales; MongoDB para agregaciones sobre documentos temporales |
| Escalabilidad | Escala vertical con gran solidez y replicas; el reparto horizontal es más complejo o depende de extensiones/arquitecturas adicionales | Escala horizontal mediante sharding y replicas, adecuado para crecimiento por colección | Ambas según la carga; MongoDB ofrece un crecimiento más sencillo para grandes volúmenes |

## 3. Datos estructurados

### PostgreSQL

El modelo de PostgreSQL define explícitamente las tablas `ubicacion`, `edificio`, `categoria_sensor`, `organismo_responsable`, `sensor`, `usuario_sistema`, `lectura_sql` y `registro_meteorologico` en `SQL/01_schema.sql`. Cada columna tiene un tipo de dato fijo (`INTEGER`, `VARCHAR`, `NUMERIC`, `DATE`, `TIMESTAMP`, etc.), lo cual permite validar la forma esperada de cada entidad desde la creación de la tabla.

Ejemplo del proyecto:

```sql
CREATE TABLE lectura_sql (
    id_lectura BIGINT PRIMARY KEY,
    id_sensor INTEGER NOT NULL,
    fecha_hora TIMESTAMP NOT NULL,
    valor NUMERIC(15, 4) NOT NULL,
    unidad VARCHAR(20) NOT NULL
);
```

### MongoDB

MongoDB puede almacenar datos estructurados, pero no exige que todos los documentos tengan exactamente la misma forma. Cada documento de la colección `lecturas` incluye campos definidos por la aplicación, como `fecha_hora` y `medicion`, pero nuevos campos pueden añadirse sin alterar una colección completa.

Esta flexibilidad es útil para datos de monitoreo, pero hace que PostgreSQL sea la opción más adecuada para los maestros cuya estructura debe estar claramente especificada.

**Justificación:** Los datos maestros tienen atributos conocidos, tipos homogéneos y relaciones importantes. Por ello se mantienen en PostgreSQL y se evita depender de convenciones impuestas únicamente por la aplicación.

## 4. Datos semiestructurados

### PostgreSQL

PostgreSQL puede almacenar semiestructurados con `JSONB`, pero los datos que cambian frecuentemente según su origen pueden quedar fuera de las columnas normalizadas. Para esta entrega, PostgreSQL representa las variables meteorológicas conocidas como columnas independientes en `registro_meteorologico`, por ejemplo `temperatura`, `humedad_relativa`, y `precipitacion`.

### MongoDB

MongoDB representa este tipo de datos de manera natural mediante documentos BSON y objetos embebidos. En SmartCityCE, una lectura BDG2 integra información que pertenece a la medición, pero también contexto agregado:

```javascript
{
  id_sensor: "Panther_parking_Lorriane",
  fecha_hora: ISODate("2016-01-01T05:00:00.000Z"),
  medicion: { valor: 0, unidad: "kWh_sum" },
  ubicacion: { id_ubicacion: "Panther", zona: "Panther" },
  sensor: { tipo: "energia", categoria: "consumo_electrico" },
  metadatos: { fuente: "BDG2", calidad: "limpio" }
}
```

Además, el diseño contempla objetos como `datos` en los eventos y `datos_adicionales` en los incidentes, cuyos atributos pueden variar según el tipo de situación.

**Justificación:** Estas estructuras tienen anidados, metadatos procedentes de distintas fuentes y campos opcionales. MongoDB permite guardar el documento completo y consultar rutas como `medicion.valor`, `ubicacion.zona` o `metadatos.calidad` sin dividirlos artificialmente en muchas tablas.

## 5. Relaciones complejas

### PostgreSQL

PostgreSQL resuelve relaciones complejas mediante claves primarias, claves foráneas y consultas relacionales. En el proyecto, por ejemplo:

```text
ubicacion → edificio → sensor → lectura_sql
ubicacion → registro_meteorologico
categoria_sensor → sensor
organismo_responsable → sensor
```

Las claves foráneas de `SQL/01_schema.sql` impiden lecturas huérfanas respecto de un sensor y edificios huérfanos respecto de una ubicación. La vista `vw_sensor_resumen`, definida en `SQL/05_views.sql`, reúne sensor, categoría, organismo, edificio, ubicación y estadísticas de lecturas mediante varios `JOIN`.

### MongoDB

MongoDB permite referencias mediante identificadores, como `id_sensor`, pero normalmente incorpora datos que se consultan juntos dentro del mismo documento. El modelo lo demuestra con la ubicación y el resumen del sensor embebidos en cada lectura. También mantiene referencias lógicas de `evento` a `alerta` mediante `id_evento` e `id_sensor`.

Estas referencias deben estar protegidas por la aplicación, puesto que MongoDB no impone el equivalente a una clave foránea entre colecciones. En SmartCityCE, la integración usa además identificadores compartidos con PostgreSQL, como el `building_id` almacenado en `edificio.id_edificio` y `lecturas.id_sensor`.

**Justificación:** Las relaciones entre entidades maestras y sus restricciones son más naturales en PostgreSQL. MongoDB evita dependencias excesivas de consultas entre colecciones desnormalizando contexto dentro de cada documento y conserva solo las referencias necesarias entre eventos, alertas e incidentes.

## 6. Grandes volúmenes de datos

### PostgreSQL

PostgreSQL maneja grandes conjuntos mediante tablas, índices, particionamiento, replicas y herramientas como vistas materializadas. En SmartCityCE se crean índices en `fecha_hora`, `sensor.id_edificio` y `edificio.id_ubicacion`, además de índices sobre lecturas y meteorología de acuerdo con las consultas. Esto es adecuado para datos maestros y para una colección de lecturas SQL utilizada como muestra relacional.

Sin embargo, almacenar millones de series temporales puede hacer crecer mucho la tabla y requiere particionamiento, mantenimiento y proyección cuidadosa de consultas.

### MongoDB

MongoDB está diseñado para distribuir colecciones grandes mediante sharding y almacenar documentos independientes en las mismas unidades lógicas. El proyecto usa índices sobre `id_sensor`, `fecha_hora`, `ubicacion.zona` y la combinación `id_sensor + fecha_hora` en `MongoDB/indexes.js`, optimizando las búsquedas más frecuentes sobre la serie de lecturas.

**Justificación:** MongoDB resulta apropiado para el volumen y la frecuencia de las lecturas BDG2, que crecen por cada sensor y momento. PostgreSQL conserva los datos SQL agregados o de menor volumen necesarios para demostrar consultas relacionales. Ninguno de los dos modelos sustituyó al otro por completo, porque el volumen actual no necesita ser tratado con la misma estrategia que los datos maestros.

## 7. Flexibilidad del esquema

### PostgreSQL

PostgreSQL aplica un esquema explícito: agregar una variable meteorológica a todos los registros puede requerir modificar la tabla con una migración. Esta rigidez es una ventaja para campos esenciales, como los identificadores y las relaciones, porque detecta desde el diseño cuándo cambia el modelo.

### MongoDB

MongoDB permite que documentos del mismo dominio incorporen campos diferentes. El diseño de eventos puede almacenar atributos específicos en `datos`, y otros tipos de eventos pueden agregar medidas distintas sin volver a crear una colección. El código CRUD también aplica validación de aplicación para exigir los campos básicos de una lectura.

**Justificación:** El esquema flexible de MongoDB responde mejor a documentos de fuentes o tipos de eventos heterogéneos. PostgreSQL conserva flexibilidad controlada para datos maestros, en los que una evolución debe ser revisada y aplicada mediante migraciones. La flexibilidad no implica ausencia de reglas: SmartCityCE valida las lecturas obligatorias en `MongoDB/crud.js`.

## 8. Integridad de los datos

### PostgreSQL

PostgreSQL proporciona integridad declarativa. Las implementaciones de SmartCityCE usan:

- `PRIMARY KEY`, por ejemplo para `ubicacion`, `edificio`, `sensor` y lecturas.
- `FOREIGN KEY` para relacionar edificios, sensores y mediciones.
- `NOT NULL` para identificadores y campos indispensables.
- `UNIQUE` para nombres y la combinación sensor-fecha.
- `CHECK` para rangos, estados, superficies, humedad, precipitación y velocidad del viento.

Por ejemplo, se impide una latitud fuera de `[-90, 90]`, una humedad fuera de `[0, 100]` y estados diferentes de los definidos.

### MongoDB

MongoDB valida documentos mediante validadores de colección o mediante reglas implementadas en el código. La función `validarLectura()` exige `id_sensor`, `fecha_hora`, `medicion`, `ubicacion`, `sensor` y `metadatos`. Además, las operaciones de actualización y eliminación requieren filtros específicos para prevenir cambios masivos accidentales.

MongoDB permite mantener integridad interna del documento, pero referencias entre colecciones como `alertas.id_evento` o `incidentes.sensores_relacionados` no generan restricciones automáticas de clave foránea.

**Justificación:** PostgreSQL es más apropiado para identificar relaciones que deben ser inválidas si se eliminan sus referidos. MongoDB aporta integridad en el contenido y en las operaciones de CRUD, complementada por identificadores lógicos compartidos con PostgreSQL.

## 9. Capacidades analíticas

### PostgreSQL

PostgreSQL ofrece SQL estándar y extensiones de consulta relacional. `SQL/queries/02_aggregations.sql` agrupa lecturas por sensor, unidad y fecha, calcula `COUNT`, `SUM`, `AVG`, `MIN` y `MAX`, y usa `HAVING` para filtrar grupos con al menos 24 registros. Las vistas permiten reutilizar combinaciones complejas de tablas.

Ejemplo del proyecto:

```sql
SELECT s.id_sensor, l.unidad,
       COUNT(*) AS cantidad,
       AVG(l.valor) AS promedio
FROM lectura_sql l
JOIN sensor s ON s.id_sensor = l.id_sensor
GROUP BY s.id_sensor, l.unidad;
```

### MongoDB

MongoDB proporciona el Aggregation Framework, aplicado en `MongoDB/queries/aggregations.js` para calcular consumo promedio y total por hora local. El pipeline usa `$set`, `$group`, `$project` y `$sort`. Como las fechas se normalizan a UTC, `$hour` toma `metadatos.zona_horaria_origen`, por ejemplo `US/Eastern`, para reconstruir la hora local.

MongoDB también agrupa mediciones por zona y calcula mínimos, máximos y promedios en las consultas obligatorias.

**Justificación:** PostgreSQL destaca en análisis relacionales que requieren combinar maestros normalizados. MongoDB destaca al analizar documentos en una colección, derivar campos temporales y ejecutar varias etapas sobre los datos leídos en la misma tubería.

## 10. Escalabilidad

### PostgreSQL

PostgreSQL ofrece escalabilidad vertical sólida y, con un diseño adecuado, escalado por lecturas mediante réplicas. El particionamiento de tablas temporales puede permitir administrar volúmenes mayores de lecturas. Las operaciones de escritura entre muchas entidades requieren considerar transacciones, índices y la capacidad de coordinación del servidor principal.

En SmartCityCE los maestros están separados de las series temporales, lo que permite que el crecimiento de ubicaciones, edificios o sensores no reproduzca de forma innecesaria la información en cada registro.

### MongoDB

MongoDB ofrece escalabilidad horizontal mediante sharding, distribuye documentos por una clave de partición seleccionada y admite replicas para alta disponibilidad. Su modelo independiente es apropiado para admitir más sensores y lecturas sin requerir una consulta de unión a tablas grandes durante cada carga.

**Justificación:** En la arquitectura actual, MongoDB tiene mejores condiciones para crecer horizontalmente con la colección de lecturas. PostgreSQL escala de forma suficiente para datos maestros y relaciones críticas, pero su integridad referencial hace más importante mantener una estrategia de partición y mantenimiento. La elección no se basa exclusivamente en escalabilidad teórica, sino en el tipo de crecimiento observado en los datasets del proyecto.

## 11. Integración implementada y decisión global

SmartCityCE usa relaciones lógicas entre tecnologías, no claves foráneas físicas que atraviesen sistemas. El vínculo se mantiene mediante valores compartidos procedentes de las fuentes:

- `lecturas.id_sensor` ↔ `sensor.nombre` y `edificio.id_edificio`, según el `building_id` de BDG2.
- `ubicacion.zona` o `ubicacion.id_ubicacion` en MongoDB ↔ `ubicacion.nombre_zona` en PostgreSQL, usando el sitio `Panther`.
- `sensor.tipo/categoria` embebido en MongoDB ↔ `categoria_sensor.nombre_categoria` en PostgreSQL.

Esta separación evita duplicar relaciones críticas en MongoDB y evita obligar a PostgreSQL a conservar documentos heterogéneos de cada sensor.

## 12. Conclusión

PostgreSQL es la tecnología adecuada para el núcleo consistente de SmartCityCE: ubicaciones, edificios, sensores, organismos, categorías, usuarios y sus relaciones. Sus restricciones, tipos y claves permiten que esos datos sean administrados con integridad referencial.

MongoDB es la tecnología adecuada para lecturas, observaciones, eventos, alertas e incidentes cuando la estructura puede variar, el contexto debe consultarse junto con la medición y el volumen crece por registros temporales. Su Aggregation Framework también permite análisis directamente sobre las colecciones.

En consecuencia, la selección implementada es una arquitectura híbrida: PostgreSQL como fuente de verdad estructural y MongoDB como almacén documental orientado a datos temporales y semiestructurados. La combinación permite aprovechar las fortalezas de ambos sistemas sin utilizar claves, esquemas o modelos que sean artificiales para los datos del proyecto.

## 13. Referencias internas del proyecto

- Modelo relacional: `SQL/01_schema.sql` y `SQL/03_indexes.sql`.
- Consultas y análisis SQL: `SQL/queries/02_aggregations.sql` y `SQL/05_views.sql`.
- Modelo documental: `docs/MongoDB/modelo_documental.md`.
- Validación y CRUD: `MongoDB/crud.js`.
- Índices MongoDB: `MongoDB/indexes.js`.
- Agregaciones MongoDB: `MongoDB/queries/aggregations.js`.
- Integración lógica: `docs/integracion_postgresql_mongodb.md`.
