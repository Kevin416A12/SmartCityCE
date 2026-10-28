
-- =====================================================
-- Las consultas 9 y 10 dependen de los objetos creados
-- mediante SQL/05_views.sql y SQL/06_functions.sql.
-- =====================================================


-- =====================================================
-- CONSULTA 1: Sensores por tipo.
-- Cuenta cuantos sensores existen por categoria.
-- =====================================================

SELECT
    cs.id_categoria,
    cs.nombre_categoria AS tipo_sensor,
    COUNT(s.id_sensor) AS cantidad_sensores
FROM public.categoria_sensor AS cs
LEFT JOIN public.sensor AS s
    ON s.id_categoria = cs.id_categoria
GROUP BY
    cs.id_categoria,
    cs.nombre_categoria
ORDER BY cantidad_sensores DESC, tipo_sensor;


-- =====================================================
-- CONSULTA 2: Sensores por ubicacion.
-- Lista los sensores y sus ubicaciones, incluyendo
-- sensores que no tengan un edificio asignado.
-- =====================================================

SELECT
    s.id_sensor,
    s.nombre AS nombre_sensor,
    cs.nombre_categoria AS tipo_sensor,
    e.id_edificio,
    COALESCE(u.nombre_zona, 'Sin ubicacion asignada') AS ubicacion,
    s.estado
FROM public.sensor AS s
INNER JOIN public.categoria_sensor AS cs
    ON cs.id_categoria = s.id_categoria
LEFT JOIN public.edificio AS e
    ON e.id_edificio = s.id_edificio
LEFT JOIN public.ubicacion AS u
    ON u.id_ubicacion = e.id_ubicacion
ORDER BY ubicacion, nombre_sensor;


-- =====================================================
-- CONSULTA 3: Cantidad de sensores activos e inactivos.
-- Tambien muestra mantenimiento y desconocido.
-- Los estados sin sensores muestran cantidad cero.
-- =====================================================

WITH estados(estado) AS (
    VALUES
        ('activo'::VARCHAR(20)),
        ('inactivo'::VARCHAR(20)),
        ('mantenimiento'::VARCHAR(20)),
        ('desconocido'::VARCHAR(20))
)
SELECT
    es.estado,
    COUNT(s.id_sensor) AS cantidad_sensores
FROM estados AS es
LEFT JOIN public.sensor AS s
    ON s.estado = es.estado
GROUP BY es.estado
ORDER BY es.estado;


-- =====================================================
-- CONSULTA 4: Sensores por organismo responsable.
-- Incluye sensores sin organismo asignado.
-- =====================================================

SELECT
    COALESCE(
        o.nombre,
        'Sin organismo asignado'
    ) AS organismo_responsable,
    COUNT(s.id_sensor) AS cantidad_sensores
FROM public.organismo_responsable AS o
RIGHT JOIN public.sensor AS s
    ON s.id_organismo = o.id_organismo
GROUP BY
    o.id_organismo,
    o.nombre
ORDER BY cantidad_sensores DESC, organismo_responsable;


-- =====================================================
-- CONSULTA 5: Ubicaciones con mayor cantidad de sensores.
-- Ordena desde la ubicacion con mas sensores.
-- =====================================================

SELECT
    u.id_ubicacion,
    u.nombre_zona,
    COUNT(DISTINCT s.id_sensor) AS cantidad_sensores
FROM public.ubicacion AS u
LEFT JOIN public.edificio AS e
    ON e.id_ubicacion = u.id_ubicacion
LEFT JOIN public.sensor AS s
    ON s.id_edificio = e.id_edificio
GROUP BY
    u.id_ubicacion,
    u.nombre_zona
HAVING COUNT(DISTINCT s.id_sensor) > 0
ORDER BY cantidad_sensores DESC, u.nombre_zona;


-- =====================================================
-- CONSULTA 6: Sensores instalados por año.
-- Limitacion: actualmente los sensores no tienen
-- fecha de instalacion registrada.
-- Se muestran los registros sin fecha de forma explicita.
-- =====================================================

SELECT
    COALESCE(
        EXTRACT(YEAR FROM fecha_instalacion)::INTEGER::TEXT,
        'Sin fecha registrada'
    ) AS anio_instalacion,
    COUNT(*) AS cantidad_sensores
FROM public.sensor
GROUP BY EXTRACT(YEAR FROM fecha_instalacion)
ORDER BY
    EXTRACT(YEAR FROM fecha_instalacion) NULLS LAST;


-- =====================================================
-- CONSULTA 7: Sensores sin actividad registrada.
-- Considera actividad una lectura electrica en
-- la tabla lectura_sql.
-- =====================================================

SELECT
    s.id_sensor,
    s.nombre AS nombre_sensor,
    s.estado,
    s.fecha_instalacion
FROM public.sensor AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM public.lectura_sql AS l
    WHERE l.id_sensor = s.id_sensor
)
ORDER BY s.nombre;


-- =====================================================
-- CONSULTA 8: Ranking de zonas monitoreadas.
-- Ordena las zonas por el total de registros electricos
-- y meteorologicos asociados a cada ubicacion.
-- Se calculan las fuentes por separado para evitar
-- multiplicar filas al unir lecturas con registros clima.
-- =====================================================

WITH sensores_por_zona AS (
    SELECT
        u.id_ubicacion,
        COUNT(DISTINCT s.id_sensor) AS cantidad_sensores
    FROM public.ubicacion AS u
    LEFT JOIN public.edificio AS e
        ON e.id_ubicacion = u.id_ubicacion
    LEFT JOIN public.sensor AS s
        ON s.id_edificio = e.id_edificio
    GROUP BY u.id_ubicacion
),
lecturas_por_zona AS (
    SELECT
        e.id_ubicacion,
        COUNT(l.id_lectura) AS lecturas_electricas
    FROM public.edificio AS e
    INNER JOIN public.sensor AS s
        ON s.id_edificio = e.id_edificio
    INNER JOIN public.lectura_sql AS l
        ON l.id_sensor = s.id_sensor
    GROUP BY e.id_ubicacion
),
clima_por_zona AS (
    SELECT
        rm.id_ubicacion,
        COUNT(rm.id_registro) AS registros_meteorologicos
    FROM public.registro_meteorologico AS rm
    GROUP BY rm.id_ubicacion
),
resumen AS (
    SELECT
        u.id_ubicacion,
        u.nombre_zona,
        COALESCE(sz.cantidad_sensores, 0) AS cantidad_sensores,
        COALESCE(lz.lecturas_electricas, 0) AS lecturas_electricas,
        COALESCE(cz.registros_meteorologicos, 0)
            AS registros_meteorologicos
    FROM public.ubicacion AS u
    LEFT JOIN sensores_por_zona AS sz
        ON sz.id_ubicacion = u.id_ubicacion
    LEFT JOIN lecturas_por_zona AS lz
        ON lz.id_ubicacion = u.id_ubicacion
    LEFT JOIN clima_por_zona AS cz
        ON cz.id_ubicacion = u.id_ubicacion
),
ranking AS (
    SELECT
        r.*,
        r.lecturas_electricas + r.registros_meteorologicos
            AS total_registros,
        RANK() OVER (
            ORDER BY
                r.lecturas_electricas
                + r.registros_meteorologicos DESC
        ) AS posicion
    FROM resumen AS r
)
SELECT
    posicion,
    id_ubicacion,
    nombre_zona,
    cantidad_sensores,
    lecturas_electricas,
    registros_meteorologicos,
    total_registros
FROM ranking
ORDER BY posicion, nombre_zona;


-- =====================================================
-- CONSULTA 9: Consulta utilizando la vista del Issue #11.
-- Presenta los sensores con mas lecturas registradas.
-- =====================================================

SELECT
    id_sensor,
    nombre_sensor,
    tipo_sensor,
    organismo_responsable,
    nombre_zona,
    estado,
    cantidad_lecturas,
    ultima_actividad
FROM public.vw_sensor_resumen
ORDER BY
    cantidad_lecturas DESC,
    ultima_actividad DESC NULLS LAST
LIMIT 50;


-- =====================================================
-- CONSULTA 10: Consulta utilizando la funcion del Issue #11.
-- Busca una ubicacion que tenga sensores asociados a
-- edificios y pasa su id como parametro a la funcion.
-- =====================================================

SELECT *
FROM public.fn_sensores_por_ubicacion(
    (
        SELECT u.id_ubicacion
        FROM public.ubicacion AS u
        INNER JOIN public.edificio AS e
            ON e.id_ubicacion = u.id_ubicacion
        INNER JOIN public.sensor AS s
            ON s.id_edificio = e.id_edificio
        ORDER BY u.id_ubicacion
        LIMIT 1
    )
);
