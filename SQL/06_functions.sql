
-- =====================================================
-- Funcion: fn_sensores_por_ubicacion
-- Parametro: id de la ubicacion deseada.
--
-- Devuelve los sensores asociados a edificios de esa
-- ubicacion. Los sensores sin edificio asignado no
-- pueden asociarse a una ubicacion mediante el esquema
-- actual.
-- =====================================================

CREATE OR REPLACE FUNCTION public.fn_sensores_por_ubicacion(
    p_id_ubicacion INTEGER
)
RETURNS TABLE (
    id_sensor INTEGER,
    nombre_sensor VARCHAR(150),
    tipo_sensor VARCHAR(100),
    organismo_responsable VARCHAR(150),
    id_edificio VARCHAR(100),
    nombre_zona VARCHAR(100),
    estado VARCHAR(20),
    fecha_instalacion DATE
)
LANGUAGE sql
STABLE
AS $func$
    SELECT
        s.id_sensor,
        s.nombre,
        cs.nombre_categoria,
        o.nombre,
        e.id_edificio,
        u.nombre_zona,
        s.estado,
        s.fecha_instalacion
    FROM public.sensor AS s

    INNER JOIN public.categoria_sensor AS cs
        ON cs.id_categoria = s.id_categoria

    LEFT JOIN public.organismo_responsable AS o
        ON o.id_organismo = s.id_organismo

    INNER JOIN public.edificio AS e
        ON e.id_edificio = s.id_edificio

    INNER JOIN public.ubicacion AS u
        ON u.id_ubicacion = e.id_ubicacion

    WHERE u.id_ubicacion = p_id_ubicacion

    ORDER BY s.nombre;
$func$;

COMMENT ON FUNCTION public.fn_sensores_por_ubicacion(INTEGER) IS
'Devuelve los sensores asignados a edificios de una ubicacion';

-- Ejemplo de uso: se selecciona una ubicacion que tenga
-- al menos un sensor asociado a un edificio.
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
