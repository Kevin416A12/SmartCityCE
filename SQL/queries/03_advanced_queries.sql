
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
