-- SmartCityCE - Issue #5
-- Pruebas de integridad y volumen posteriores a la carga ETL.
-- Solo consultas de lectura: no altera datos ni estructuras.
\set ON_ERROR_STOP on

\echo '=== SmartCityCE: validacion de datos PostgreSQL ==='

SELECT 'ubicacion' AS tabla, COUNT(*) AS registros FROM ubicacion
UNION ALL SELECT 'edificio', COUNT(*) FROM edificio
UNION ALL SELECT 'categoria_sensor', COUNT(*) FROM categoria_sensor
UNION ALL SELECT 'organismo_responsable', COUNT(*) FROM organismo_responsable
UNION ALL SELECT 'sensor', COUNT(*) FROM sensor
UNION ALL SELECT 'usuario_sistema', COUNT(*) FROM usuario_sistema
UNION ALL SELECT 'lectura_sql', COUNT(*) FROM lectura_sql
UNION ALL SELECT 'registro_meteorologico', COUNT(*) FROM registro_meteorologico
ORDER BY tabla;

DO $$
DECLARE
    lecturas BIGINT;
    clima BIGINT;
    sensores BIGINT;
    edificios BIGINT;
    sensores_con_lecturas BIGINT;
    huerfanas BIGINT;
    duplicados BIGINT;
    negativos BIGINT;
    lecturas_sin_unidad BIGINT;
    clima_invalido BIGINT;
BEGIN
    SELECT COUNT(*) INTO lecturas FROM lectura_sql;
    IF lecturas < 100000 THEN
        RAISE EXCEPTION 'FALLO: solo % lecturas; se esperan al menos 100000.', lecturas;
    END IF;
    RAISE NOTICE 'OK: % lecturas electricas (minimo 100000).', lecturas;

    SELECT COUNT(*) INTO clima FROM registro_meteorologico;
    IF clima = 0 THEN
        RAISE EXCEPTION 'FALLO: no hay registros meteorologicos.';
    END IF;
    RAISE NOTICE 'OK: % registros meteorologicos.', clima;

    SELECT COUNT(*) INTO edificios FROM edificio;
    SELECT COUNT(*) INTO sensores FROM sensor;
    IF edificios = 0 OR sensores = 0 THEN
        RAISE EXCEPTION 'FALLO: edificios (%) o sensores (%) vacios.', edificios, sensores;
    END IF;
    RAISE NOTICE 'OK: % edificios y % sensores.', edificios, sensores;

    SELECT COUNT(DISTINCT id_sensor) INTO sensores_con_lecturas FROM lectura_sql;
    RAISE NOTICE 'OK: % sensores distintos con lecturas.', sensores_con_lecturas;

    SELECT COUNT(*) INTO huerfanas
    FROM lectura_sql l LEFT JOIN sensor s ON s.id_sensor = l.id_sensor
    WHERE s.id_sensor IS NULL;
    IF huerfanas <> 0 THEN
        RAISE EXCEPTION 'FALLO: % lecturas sin sensor asociado.', huerfanas;
    END IF;
    RAISE NOTICE 'OK: no hay lecturas huerfanas.';

    SELECT COUNT(*) INTO duplicados FROM (
        SELECT id_sensor, fecha_hora FROM lectura_sql
        GROUP BY id_sensor, fecha_hora HAVING COUNT(*) > 1
    ) d;
    IF duplicados <> 0 THEN
        RAISE EXCEPTION 'FALLO: % combinaciones duplicadas de sensor y fecha.', duplicados;
    END IF;
    RAISE NOTICE 'OK: no hay lecturas duplicadas por sensor y fecha.';

    SELECT COUNT(*) INTO negativos FROM lectura_sql WHERE valor < 0;
    IF negativos <> 0 THEN
        RAISE EXCEPTION 'FALLO: % lecturas electricas negativas; revisar unidades y origen.', negativos;
    END IF;
    RAISE NOTICE 'OK: no hay lecturas negativas.';

    SELECT COUNT(*) INTO lecturas_sin_unidad FROM lectura_sql
    WHERE unidad IS NULL OR BTRIM(unidad) = '';
    IF lecturas_sin_unidad <> 0 THEN
        RAISE EXCEPTION 'FALLO: % lecturas sin unidad.', lecturas_sin_unidad;
    END IF;
    RAISE NOTICE 'OK: todas las lecturas tienen unidad.';

    SELECT COUNT(*) INTO clima_invalido FROM registro_meteorologico
    WHERE (humedad_relativa IS NOT NULL AND NOT (humedad_relativa BETWEEN 0 AND 100))
       OR (nubosidad IS NOT NULL AND NOT (nubosidad BETWEEN 0 AND 100))
       OR (precipitacion IS NOT NULL AND precipitacion < 0)
       OR (velocidad_viento IS NOT NULL AND velocidad_viento < 0);
    IF clima_invalido <> 0 THEN
        RAISE EXCEPTION 'FALLO: % registros meteorologicos invalidos.', clima_invalido;
    END IF;
    RAISE NOTICE 'OK: rangos meteorologicos validos.';

    RAISE NOTICE 'TODAS LAS PRUEBAS DE DATOS PASARON.';
END $$;

SELECT COUNT(*) AS total_lecturas,
       COUNT(DISTINCT id_sensor) AS sensores_con_lecturas,
       MIN(fecha_hora) AS primera_lectura,
       MAX(fecha_hora) AS ultima_lectura,
       COUNT(*) FILTER (WHERE valor = 0) AS lecturas_cero,
       COUNT(*) FILTER (WHERE valor < 0) AS lecturas_negativas
FROM lectura_sql;
