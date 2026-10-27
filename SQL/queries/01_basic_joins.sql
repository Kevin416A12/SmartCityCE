
-- =====================================================
-- 1. SELECT
-- Consultar edificios y sus atributos principales.
-- =====================================================
SELECT
    id_edificio,
    uso_principal,
    superficie,
    anio_construccion
FROM edificio
LIMIT 20;


-- =====================================================
-- 2. WHERE
-- Filtrar edificios con superficie de al menos 1000 m².
-- Se excluyen superficies desconocidas.
-- =====================================================
SELECT
    id_edificio,
    uso_principal,
    superficie
FROM edificio
WHERE superficie IS NOT NULL
  AND superficie >= 1000
ORDER BY superficie DESC;


-- =====================================================
-- 3. ORDER BY
-- Consultar las 25 lecturas más recientes.
-- =====================================================
SELECT
    fecha_hora,
    id_sensor,
    valor,
    unidad
FROM lectura_sql
ORDER BY fecha_hora DESC
LIMIT 25;


-- =====================================================
-- 4. DISTINCT
-- Obtener los usos principales diferentes de los edificios.
-- =====================================================
SELECT DISTINCT
    uso_principal
FROM edificio
WHERE uso_principal IS NOT NULL
ORDER BY uso_principal;


-- =====================================================
-- 5. JOIN
-- Relacionar los edificios con sus sensores.
-- JOIN sin calificador equivale a INNER JOIN.
-- =====================================================
SELECT
    e.id_edificio,
    e.uso_principal,
    s.id_sensor,
    s.nombre AS sensor,
    s.estado
FROM edificio AS e
JOIN sensor AS s
    ON s.id_edificio = e.id_edificio
ORDER BY e.id_edificio;


-- =====================================================
-- 6. INNER JOIN
-- Consultar las lecturas eléctricas junto con su edificio.
-- Solo aparecen lecturas que tienen relaciones coincidentes.
-- =====================================================
SELECT
    e.id_edificio,
    e.uso_principal,
    l.fecha_hora,
    l.valor,
    l.unidad
FROM edificio AS e
INNER JOIN sensor AS s
    ON s.id_edificio = e.id_edificio
INNER JOIN lectura_sql AS l
    ON l.id_sensor = s.id_sensor
WHERE l.fecha_hora >= TIMESTAMP '2016-01-01 00:00:00'
  AND l.fecha_hora <  TIMESTAMP '2016-01-02 00:00:00'
ORDER BY l.fecha_hora DESC
LIMIT 100;


-- =====================================================
-- 7. LEFT JOIN
-- Mostrar todos los edificios, incluso sin sensores
-- o sin lecturas durante el día seleccionado.
-- =====================================================
SELECT
    e.id_edificio,
    e.uso_principal,
    COUNT(DISTINCT s.id_sensor) AS cantidad_sensores,
    COUNT(l.id_lectura) AS cantidad_lecturas
FROM edificio AS e
LEFT JOIN sensor AS s
    ON s.id_edificio = e.id_edificio
LEFT JOIN lectura_sql AS l
    ON l.id_sensor = s.id_sensor
   AND l.fecha_hora >= TIMESTAMP '2016-01-01 00:00:00'
   AND l.fecha_hora <  TIMESTAMP '2016-01-02 00:00:00'
GROUP BY
    e.id_edificio,
    e.uso_principal
ORDER BY cantidad_lecturas DESC, e.id_edificio;


-- =====================================================
-- 8. INTEGRACIÓN BDG2 + OPEN-METEO
-- Relacionar consumo eléctrico y clima por ubicación
-- y fecha-hora exactas.
-- =====================================================
SELECT
    l.fecha_hora,
    e.id_edificio,
    e.uso_principal,
    l.valor AS consumo,
    l.unidad,
    rm.temperatura,
    rm.humedad_relativa,
    rm.precipitacion
FROM lectura_sql AS l
INNER JOIN sensor AS s
    ON s.id_sensor = l.id_sensor
INNER JOIN edificio AS e
    ON e.id_edificio = s.id_edificio
INNER JOIN registro_meteorologico AS rm
    ON rm.id_ubicacion = e.id_ubicacion
   AND rm.fecha_hora = l.fecha_hora
WHERE l.fecha_hora >= TIMESTAMP '2016-01-01 00:00:00'
  AND l.fecha_hora <  TIMESTAMP '2016-01-02 00:00:00'
ORDER BY l.fecha_hora, e.id_edificio
LIMIT 100;
