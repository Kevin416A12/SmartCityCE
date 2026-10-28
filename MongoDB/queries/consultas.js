
/*
 * Issue #15 - Implementar consultas y filtros MongoDB
 * Proyecto SmartCityCE
 *
 * Incluye:
 * - Filtros simples y múltiples
 * - Operadores de comparación
 * - Operadores lógicos
 * - Proyecciones
 * - Ordenamientos
 * - Rangos de fechas
 */

db = db.getSiblingDB("smartcityce");

const lecturas = db.getCollection("lecturas");

// ============================================================
// 1. FILTROS SIMPLES
// ============================================================

// Buscar lecturas de un sensor específico.
print("\n1. Filtro simple: sensor específico");
printjson(
    lecturas.find({
        id_sensor: "Panther_parking_Lorriane"
    }).limit(5).toArray()
);

// Buscar lecturas de una zona específica.
print("\n2. Filtro simple: zona Panther");
printjson(
    lecturas.find({
        "ubicacion.zona": "Panther"
    }).limit(5).toArray()
);

// ============================================================
// 2. FILTROS MÚLTIPLES
// ============================================================

// Buscar lecturas que cumplan ambas condiciones.
print("\n3. Filtros múltiples: zona y tipo de sensor");
printjson(
    lecturas.find({
        "ubicacion.zona": "Panther",
        "sensor.tipo": "energia"
    }).limit(5).toArray()
);

// ============================================================
// 3. OPERADORES DE COMPARACIÓN
// ============================================================

// $gt: mayor que.
print("\n4. Consumo mayor que cero");
printjson(
    lecturas.find({
        "medicion.valor": { $gt: 0 }
    }).limit(5).toArray()
);

// $gte y $lte: entre dos valores, inclusive.
print("\n5. Consumo entre 0 y 10");
printjson(
    lecturas.find({
        "medicion.valor": {
            $gte: 0,
            $lte: 10
        }
    }).limit(5).toArray()
);

// $lt: menor que.
print("\n6. Consumo menor que 5");
printjson(
    lecturas.find({
        "medicion.valor": { $lt: 5 }
    }).limit(5).toArray()
);

// $ne: diferente de.
print("\n7. Lecturas cuya fuente no sea BDG2");
printjson(
    lecturas.find({
        "metadatos.fuente": { $ne: "BDG2" }
    }).limit(5).toArray()
);

// ============================================================
// 4. OPERADORES LÓGICOS
// ============================================================

// $and: deben cumplirse ambas condiciones.
print("\n8. Operador lógico AND");
printjson(
    lecturas.find({
        $and: [
            { "ubicacion.zona": "Panther" },
            { "medicion.valor": { $gt: 0 } }
        ]
    }).limit(5).toArray()
);

// $or: debe cumplirse al menos una condición.
print("\n9. Operador lógico OR");
printjson(
    lecturas.find({
        $or: [
            { "ubicacion.zona": "Panther" },
            { "metadatos.fuente": "BDG2" }
        ]
    }).limit(5).toArray()
);

// ============================================================
// 5. PROYECCIONES
// ============================================================

// Mostrar únicamente los campos seleccionados.
// _id: 0 excluye el identificador de MongoDB.
print("\n10. Proyección de campos");
printjson(
    lecturas.find(
        {},
        {
            _id: 0,
            id_sensor: 1,
            fecha_hora: 1,
            "medicion.valor": 1,
            "medicion.unidad": 1,
            "ubicacion.zona": 1
        }
    ).limit(5).toArray()
);

// ============================================================
// 6. ORDENAMIENTO
// ============================================================

// Orden ascendente: fecha más antigua primero.
print("\n11. Orden ascendente por fecha");
printjson(
    lecturas.find({})
        .sort({ fecha_hora: 1 })
        .limit(5)
        .toArray()
);

// Orden descendente: fecha más reciente primero.
print("\n12. Orden descendente por fecha");
printjson(
    lecturas.find({})
        .sort({ fecha_hora: -1 })
        .limit(5)
        .toArray()
);

// ============================================================
// 7. RANGOS DE FECHAS
// ============================================================

// Buscar lecturas dentro del 1 de enero de 2016 (UTC).
// Incluye el inicio y excluye el inicio del día siguiente.
print("\n13. Lecturas del 1 de enero de 2016");
printjson(
    lecturas.find({
        fecha_hora: {
            $gte: ISODate("2016-01-01T00:00:00.000Z"),
            $lt: ISODate("2016-01-02T00:00:00.000Z")
        }
    }).sort({ fecha_hora: 1 }).limit(10).toArray()
);


