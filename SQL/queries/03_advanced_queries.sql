
-- =====================================================
-- CONSULTAS AVANZADAS
-- Consulta 1: subconsulta en FROM.
--
-- La subconsulta calcula el promedio historico por unidad.
-- La consulta principal devuelve lecturas superiores
-- al promedio correspondiente a su unidad.
-- =====================================================

SELECT
    l.id_sensor,
    s.nombre AS nombre_sensor,
    l.fecha_hora,
    l.valor,
    l.unidad,
    ROUND(p.promedio_unidad, 4) AS promedio_unidad
FROM lectura_sql AS l
INNER JOIN sensor AS s
    ON s.id_sensor = l.id_sensor
INNER JOIN (
    SELECT
        unidad,
        AVG(valor) AS promedio_unidad
    FROM lectura_sql
    GROUP BY unidad
) AS p
    ON p.unidad = l.unidad
WHERE l.valor > p.promedio_unidad
ORDER BY l.fecha_hora DESC
LIMIT 100;


-- Consulta 2: CTE y agregacion diaria.
--
-- El CTE fecha_limite encuentra la ultima fecha disponible.
-- El CTE resumen agrupa las lecturas de los siete dias
-- anteriores a esa ultima fecha.
-- No depende de que la fecha actual coincida con los datos.

WITH fecha_limite AS (
    SELECT
        MAX(fecha_hora) - INTERVAL '7 days' AS desde
    FROM lectura_sql
),
resumen AS (
    SELECT
        l.fecha_hora::date AS dia,
        l.id_sensor,
        l.unidad,
        COUNT(*) AS cantidad_lecturas,
        ROUND(AVG(l.valor), 4) AS promedio,
        MIN(l.valor) AS minimo,
        MAX(l.valor) AS maximo
    FROM lectura_sql AS l
    CROSS JOIN fecha_limite AS f
    WHERE l.fecha_hora >= f.desde
    GROUP BY
        l.fecha_hora::date,
        l.id_sensor,
        l.unidad
)
SELECT
    dia,
    id_sensor,
    unidad,
    cantidad_lecturas,
    promedio,
    minimo,
    maximo
FROM resumen
ORDER BY dia DESC, id_sensor
LIMIT 100;


-- Consulta 3: funcion de ventana.
--
-- ROW_NUMBER asigna una posicion a cada lectura dentro
-- de su sensor, desde la mas reciente hasta la mas antigua.
-- Se limita el analisis a los ultimos siete dias disponibles.

WITH fecha_limite AS (
    SELECT
        MAX(fecha_hora) - INTERVAL '7 days' AS desde
    FROM lectura_sql
),
lecturas_recientes AS (
    SELECT
        l.id_lectura,
        l.id_sensor,
        l.fecha_hora,
        l.valor,
        l.unidad
    FROM lectura_sql AS l
    CROSS JOIN fecha_limite AS f
    WHERE l.fecha_hora >= f.desde
),
ranking AS (
    SELECT
        id_lectura,
        id_sensor,
        fecha_hora,
        valor,
        unidad,
        ROW_NUMBER() OVER (
            PARTITION BY id_sensor
            ORDER BY fecha_hora DESC, id_lectura DESC
        ) AS posicion_reciente,
        ROUND(
            AVG(valor) OVER (
                PARTITION BY id_sensor, unidad
            ),
            4
        ) AS promedio_sensor
    FROM lecturas_recientes
)
SELECT
    id_sensor,
    fecha_hora,
    valor,
    unidad,
    posicion_reciente,
    promedio_sensor
FROM ranking
WHERE posicion_reciente <= 3
ORDER BY id_sensor, fecha_hora DESC
LIMIT 100;


-- Consulta 4: filtrado por fecha y resumen diario.
-- Se seleccionan los siete dias calendario que terminan
-- en la ultima fecha disponible en la tabla.

WITH rango_fechas AS (
    SELECT
        MAX(fecha_hora)::date - 6 AS desde,
        MAX(fecha_hora)::date + 1 AS hasta
    FROM lectura_sql
)
SELECT
    l.fecha_hora::date AS dia,
    l.unidad,
    COUNT(*) AS cantidad_lecturas,
    ROUND(AVG(l.valor), 4) AS promedio,
    MIN(l.valor) AS minimo,
    MAX(l.valor) AS maximo
FROM lectura_sql AS l
CROSS JOIN rango_fechas AS r
WHERE l.fecha_hora >= r.desde::timestamp
  AND l.fecha_hora < r.hasta::timestamp
GROUP BY
    l.fecha_hora::date,
    l.unidad
ORDER BY dia DESC, l.unidad;

-- Consulta 5. Comprobar el uso de índices 
-- Comprobar que el índice existe
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'lectura_sql'
ORDER BY indexname;

-- Crear idx_lectura_fecha_hora si no existe
CREATE INDEX IF NOT EXISTS idx_lectura_fecha_hora
    ON lectura_sql (fecha_hora);

ANALYZE lectura_sql;

SELECT
    MIN(fecha_hora) AS primera_lectura,
    MAX(fecha_hora) AS ultima_lectura
FROM lectura_sql;


-- EXPLAIN ANALYZE permite observar el plan, el tiempo
-- real y los bloques leidos por PostgreSQL.

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    id_lectura,
    id_sensor,
    fecha_hora,
    valor,
    unidad
FROM lectura_sql
WHERE fecha_hora >= TIMESTAMP '2016-01-01 00:00:00'
  AND fecha_hora <  TIMESTAMP '2016-01-01 01:00:00'
ORDER BY fecha_hora
LIMIT 100;