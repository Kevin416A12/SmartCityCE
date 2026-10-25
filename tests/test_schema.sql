-- SmartCityCE - Issue #4: pruebas del esquema PostgreSQL
-- Ejecutar desde la raíz del repositorio:
-- psql -h localhost -U smartcity -d smartcityce -X -v ON_ERROR_STOP=1 -f tests/test_schema.sql
-- Todas las inserciones se revierten al terminar.

BEGIN;

DO $test$
DECLARE
    missing_tables text[];
    num_constraints integer;
    location_id integer;
    category_id integer;
    org_id integer;
    sensor_id integer;
    rejected boolean;
BEGIN
    SELECT array_agg(t.table_name) INTO missing_tables
    FROM (VALUES
        ('ubicacion'), ('edificio'), ('categoria_sensor'),
        ('organismo_responsable'), ('sensor'), ('usuario_sistema'),
        ('lectura_sql'), ('registro_meteorologico')
    ) AS t(table_name)
    WHERE to_regclass(format('public.%I', t.table_name)) IS NULL;

    IF missing_tables IS NOT NULL THEN
        RAISE EXCEPTION 'Faltan tablas: %', missing_tables;
    END IF;
    RAISE NOTICE 'OK: existen las 8 tablas.';

    SELECT count(*) INTO num_constraints
    FROM pg_constraint
    WHERE conrelid = 'public.sensor'::regclass AND contype = 'f';
    IF num_constraints < 3 THEN
        RAISE EXCEPTION 'sensor debe tener 3 FK; tiene %', num_constraints;
    END IF;
    RAISE NOTICE 'OK: sensor tiene sus 3 claves foráneas.';

    -- Referencia inexistente: debe rechazarse.
    rejected := false;
    BEGIN
        INSERT INTO edificio (id_edificio, id_ubicacion, uso_principal)
        VALUES ('__TEST_FK_INVALIDA__', -999, 'office');
    EXCEPTION WHEN foreign_key_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'FALLO: se permitió edificio con ubicación inexistente';
    END IF;
    RAISE NOTICE 'OK: FK edificio -> ubicacion rechaza referencias inválidas.';

    -- Coordenadas inválidas: deben rechazarse.
    rejected := false;
    BEGIN
        INSERT INTO ubicacion (nombre_zona, distrito, latitud, longitud)
        VALUES ('__TEST_COORD_INVALIDA__', 'Pruebas', 150, -200);
    EXCEPTION WHEN check_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'FALLO: se permitieron coordenadas inválidas';
    END IF;
    RAISE NOTICE 'OK: CHECK de coordenadas funciona.';

    -- Inserciones válidas de ejemplo (revertidas al final).
    INSERT INTO ubicacion (nombre_zona, distrito, latitud, longitud)
    VALUES ('__TEST_ZONA__', 'Pruebas', 28.517689, -81.379039)
    RETURNING id_ubicacion INTO location_id;

    INSERT INTO edificio (id_edificio, id_ubicacion, uso_principal)
    VALUES ('__TEST_EDIFICIO__', location_id, 'office');

    INSERT INTO categoria_sensor (nombre_categoria, descripcion)
    VALUES ('__TEST_CATEGORIA__', 'Temporal')
    RETURNING id_categoria INTO category_id;

    INSERT INTO organismo_responsable (nombre, responsable)
    VALUES ('__TEST_ORGANISMO__', 'Temporal')
    RETURNING id_organismo INTO org_id;

    INSERT INTO sensor (nombre, id_categoria, id_organismo, id_edificio, estado)
    VALUES ('__TEST_SENSOR__', category_id, org_id, '__TEST_EDIFICIO__', 'activo')
    RETURNING id_sensor INTO sensor_id;

    INSERT INTO lectura_sql (id_sensor, fecha_hora, valor, unidad)
    VALUES (sensor_id, TIMESTAMP '2016-01-01 00:00:00', 12.5, 'kWh');

    INSERT INTO registro_meteorologico (id_ubicacion, fecha_hora, temperatura, humedad_relativa)
    VALUES (location_id, TIMESTAMP '2016-01-01 00:00:00', 21.5, 50);

    INSERT INTO usuario_sistema (nombre, correo)
    VALUES ('__TEST_USUARIO__', '__test_smartcityce__@example.invalid');
    RAISE NOTICE 'OK: inserciones válidas y relaciones entre tablas.';

    -- Estado inválido de sensor.
    rejected := false;
    BEGIN
        INSERT INTO sensor (nombre, id_categoria, estado)
        VALUES ('__TEST_SENSOR_INVALIDO__', category_id, 'imposible');
    EXCEPTION WHEN check_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'FALLO: sensor aceptó un estado no permitido';
    END IF;
    RAISE NOTICE 'OK: CHECK del estado del sensor.';

    -- La misma lectura del sensor a la misma hora debe ser única.
    rejected := false;
    BEGIN
        INSERT INTO lectura_sql (id_sensor, fecha_hora, valor, unidad)
        VALUES (sensor_id, TIMESTAMP '2016-01-01 00:00:00', 99, 'kWh');
    EXCEPTION WHEN unique_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'FALLO: se permitió una lectura duplicada';
    END IF;
    RAISE NOTICE 'OK: UNIQUE de lectura por sensor y fecha.';

    rejected := false;
    BEGIN
        INSERT INTO registro_meteorologico (id_ubicacion, fecha_hora, humedad_relativa)
        VALUES (location_id, TIMESTAMP '2016-01-01 01:00:00', 120);
    EXCEPTION WHEN check_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'FALLO: humedad relativa fuera de rango';
    END IF;
    RAISE NOTICE 'OK: CHECK de humedad relativa.';

    RAISE NOTICE 'TODAS LAS PRUEBAS TERMINARON CORRECTAMENTE.';
END
$test$;

ROLLBACK;
