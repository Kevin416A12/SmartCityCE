
-- =====================================================
-- Vista: resumen de sensores.
-- Incluye informacion del sensor y un resumen de sus
-- lecturas electricas.
-- Los sensores sin lecturas tambien aparecen.
-- =====================================================

CREATE OR REPLACE VIEW public.vw_sensor_resumen AS
SELECT
    s.id_sensor,
    s.nombre AS nombre_sensor,
    cs.nombre_categoria AS tipo_sensor,

    o.nombre AS organismo_responsable,

    e.id_edificio,
    e.uso_principal,

    u.id_ubicacion,
    u.nombre_zona,

    s.fecha_instalacion,
    s.estado,

    COUNT(l.id_lectura) AS cantidad_lecturas,
    MAX(l.fecha_hora) AS ultima_actividad

FROM public.sensor AS s

INNER JOIN public.categoria_sensor AS cs
    ON cs.id_categoria = s.id_categoria

LEFT JOIN public.organismo_responsable AS o
    ON o.id_organismo = s.id_organismo

LEFT JOIN public.edificio AS e
    ON e.id_edificio = s.id_edificio

LEFT JOIN public.ubicacion AS u
    ON u.id_ubicacion = e.id_ubicacion

LEFT JOIN public.lectura_sql AS l
    ON l.id_sensor = s.id_sensor

GROUP BY
    s.id_sensor,
    s.nombre,
    cs.nombre_categoria,
    o.nombre,
    e.id_edificio,
    e.uso_principal,
    u.id_ubicacion,
    u.nombre_zona,
    s.fecha_instalacion,
    s.estado;

-- Documentar el proposito de la vista.
COMMENT ON VIEW public.vw_sensor_resumen IS
'Resumen de sensores con categoria, organismo, ubicacion,
estado y cantidad y fecha de la ultima lectura electrica';

-- Ejemplo de uso de la vista.
SELECT
    id_sensor,
    nombre_sensor,
    tipo_sensor,
    nombre_zona,
    estado,
    cantidad_lecturas,
    ultima_actividad
FROM public.vw_sensor_resumen
ORDER BY cantidad_lecturas DESC, nombre_sensor
LIMIT 50;
