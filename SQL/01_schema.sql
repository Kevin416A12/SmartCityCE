CREATE TABLE ubicacion (
    id_ubicacion INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_zona VARCHAR(100) NOT NULL,
    distrito VARCHAR(100),
    latitud NUMERIC(10, 7),
    longitud NUMERIC(10, 7),

    CONSTRAINT chk_latitud
        CHECK (latitud BETWEEN -90 AND 90),

    CONSTRAINT chk_longitud
        CHECK (longitud BETWEEN -180 AND 180)
);

-- ============================================
-- Tabla: edificio
-- ============================================

CREATE TABLE edificio (
    id_edificio VARCHAR(100) PRIMARY KEY,
    id_ubicacion INTEGER NOT NULL,

    uso_principal VARCHAR(100),
    superficie NUMERIC(12, 2),
    anio_construccion INTEGER,
    numero_pisos INTEGER,

    CONSTRAINT fk_edificio_ubicacion
        FOREIGN KEY (id_ubicacion)
        REFERENCES ubicacion(id_ubicacion),

    CONSTRAINT chk_superficie
        CHECK (superficie > 0),

    CONSTRAINT chk_anio_construccion
        CHECK (anio_construccion > 1800),

    CONSTRAINT chk_numero_pisos
        CHECK (numero_pisos > 0)
);

-- ============================================
-- Tabla: categoria_sensor
-- ============================================

CREATE TABLE IF NOT EXISTS categoria_sensor (
    id_categoria INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_categoria VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT
);

-- ============================================
-- Tabla: organismo_responsable
-- ============================================

CREATE TABLE IF NOT EXISTS organismo_responsable (
    id_organismo INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    responsable VARCHAR(150) NOT NULL
);

-- ============================================
-- Tabla: sensor
-- ============================================

CREATE TABLE IF NOT EXISTS sensor (
    id_sensor INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    nombre VARCHAR(150) NOT NULL UNIQUE,

    id_categoria INTEGER NOT NULL,
    id_organismo INTEGER,
    id_edificio VARCHAR(100),

    fecha_instalacion DATE,

    estado VARCHAR(20) NOT NULL DEFAULT 'desconocido',

    CONSTRAINT fk_sensor_categoria
        FOREIGN KEY (id_categoria)
        REFERENCES categoria_sensor(id_categoria),

    CONSTRAINT fk_sensor_organismo
        FOREIGN KEY (id_organismo)
        REFERENCES organismo_responsable(id_organismo),

    CONSTRAINT fk_sensor_edificio
        FOREIGN KEY (id_edificio)
        REFERENCES edificio(id_edificio),

    CONSTRAINT chk_sensor_estado
        CHECK (
            estado IN (
                'activo',
                'inactivo',
                'mantenimiento',
                'desconocido'
            )
        )
);

-- ============================================
-- Tabla: usuario_sistema
-- ============================================

CREATE TABLE IF NOT EXISTS usuario_sistema (
    id_usuario INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    nombre VARCHAR(150) NOT NULL,
    correo VARCHAR(255) NOT NULL UNIQUE,

    CONSTRAINT chk_usuario_correo
        CHECK (POSITION('@' IN correo) > 1)
);

-- ============================================
-- Tabla: lectura_sql
-- ============================================

CREATE TABLE IF NOT EXISTS lectura_sql (
    id_lectura BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    id_sensor INTEGER NOT NULL,
    fecha_hora TIMESTAMP NOT NULL,

    valor NUMERIC(15, 4) NOT NULL,
    unidad VARCHAR(20) NOT NULL,

    CONSTRAINT fk_lectura_sensor
        FOREIGN KEY (id_sensor)
        REFERENCES sensor(id_sensor),

    CONSTRAINT uq_lectura_sensor_fecha
        UNIQUE (id_sensor, fecha_hora),

    CONSTRAINT chk_lectura_unidad
        CHECK (TRIM(unidad) <> '')
);

-- ============================================
-- Tabla: registro_meteorologico
-- ============================================

CREATE TABLE IF NOT EXISTS registro_meteorologico (
    id_registro BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    id_ubicacion INTEGER NOT NULL,
    fecha_hora TIMESTAMP NOT NULL,

    temperatura NUMERIC(6, 2),
    humedad_relativa NUMERIC(5, 2),
    precipitacion NUMERIC(10, 2),
    nubosidad NUMERIC(5, 2),
    velocidad_viento NUMERIC(8, 2),

    CONSTRAINT fk_meteorologico_ubicacion
        FOREIGN KEY (id_ubicacion)
        REFERENCES ubicacion(id_ubicacion),

    CONSTRAINT uq_meteorologico_ubicacion_fecha
        UNIQUE (id_ubicacion, fecha_hora),

    CONSTRAINT chk_humedad
        CHECK (humedad_relativa BETWEEN 0 AND 100),

    CONSTRAINT chk_precipitacion
        CHECK (precipitacion >= 0),

    CONSTRAINT chk_nubosidad
        CHECK (nubosidad BETWEEN 0 AND 100),

    CONSTRAINT chk_velocidad_viento
        CHECK (velocidad_viento >= 0)
);