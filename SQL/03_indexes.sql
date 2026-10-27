-- 1. Consultas por intervalos temporales de lecturas eléctricas.
CREATE INDEX IF NOT EXISTS idx_lectura_fecha_hora
    ON lectura_sql (fecha_hora);

-- 2. Relación entre sensores y edificios.
CREATE INDEX IF NOT EXISTS idx_sensor_id_edificio
    ON sensor (id_edificio);

-- 3. Relación entre edificios y ubicaciones.
CREATE INDEX IF NOT EXISTS idx_edificio_id_ubicacion
    ON edificio (id_ubicacion);

-- Actualizar las estadísticas para ayudar al planificador
-- de consultas a decidir cuándo usar los índices.
ANALYZE lectura_sql;
ANALYZE sensor;
ANALYZE edificio;
