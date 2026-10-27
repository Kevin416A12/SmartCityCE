/*
 * SmartCityCE
 * Issue #17 - Crear índices MongoDB
 */

db = db.getSiblingDB("smartcityce");


/*
 * ÍNDICE 1
 * Búsqueda de lecturas por sensor
 */

db.lecturas.createIndex(
    { id_sensor: 1 },
    { name: "idx_lecturas_sensor" }
);


/*
 * ÍNDICE 2
 * Búsqueda de lecturas por fecha
 */

db.lecturas.createIndex(
    { fecha_hora: 1 },
    { name: "idx_lecturas_fecha" }
);


/*
 * ÍNDICE 3
 * Búsqueda de lecturas por zona
 */

db.lecturas.createIndex(
    { "ubicacion.zona": 1 },
    { name: "idx_lecturas_zona" }
);


/*
 * ÍNDICE 4
 * Búsqueda combinada por sensor y fecha
 */

db.lecturas.createIndex(
    {
        id_sensor: 1,
        fecha_hora: 1
    },
    {
        name: "idx_lecturas_sensor_fecha"
    }
);