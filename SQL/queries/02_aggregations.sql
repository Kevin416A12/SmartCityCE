
-- =====================================================
-- AGREGACIONES Y CONSULTAS ANALITICAS
-- Consulta 1: estadisticas por sensor y unidad.
--
-- GROUP BY: agrupa por sensor, edificio y unidad.
-- HAVING: conserva grupos con al menos 24 lecturas.
-- COUNT: cantidad de mediciones.
-- SUM: suma de los valores registrados.
-- AVG: promedio de las mediciones.
-- MIN / MAX: valor minimo y maximo.
-- =====================================================

SELECT
    s.id_sensor,
    s.nombre AS nombre_sensor,
    e.id_edificio,
    e.uso_principal,
    l.unidad,
    COUNT(l.id_lectura) AS cantidad_lecturas,
    SUM(l.valor) AS suma_valores,
    ROUND(AVG(l.valor), 4) AS promedio,
    MIN(l.valor) AS minimo,
    MAX(l.valor) AS maximo
FROM lectura_sql AS l
INNER JOIN sensor AS s
    ON s.id_sensor = l.id_sensor
LEFT JOIN edificio AS e
    ON e.id_edificio = s.id_edificio
GROUP BY
    s.id_sensor,
    s.nombre,
    e.id_edificio,
    e.uso_principal,
    l.unidad
HAVING COUNT(l.id_lectura) >= 24
ORDER BY promedio DESC
LIMIT 100;


-- Consulta 2: resumen diario por unidad.
-- Se agrupa por fecha y unidad de medida.

SELECT
    fecha_hora::date AS dia,
    unidad,
    COUNT(*) AS cantidad_lecturas,
    ROUND(AVG(valor), 4) AS promedio_diario,
    MIN(valor) AS minimo_diario,
    MAX(valor) AS maximo_diario
FROM lectura_sql
GROUP BY
    fecha_hora::date,
    unidad
HAVING COUNT(*) >= 24
ORDER BY dia DESC, unidad;
