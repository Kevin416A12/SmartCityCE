
/*
 * Issue #18 - Las 10 consultas obligatorias MongoDB
 * Proyecto SmartCityCE
 *
 * Coleccion: smartcityce.lecturas
 *
 * IMPORTANTE:
 * El dataset actual contiene mediciones de sensores, pero no
 * registros independientes de alertas o incidentes.
 * Las consultas 4, 5 y 8 son aproximaciones basadas en un
 * umbral configurable, no alertas/incidentes reales.
 */

db = db.getSiblingDB("smartcityce");
const lecturas = db.getCollection("lecturas");

// Umbral ilustrativo: debe ajustarse a los criterios del proyecto.
const UMBRAL_CRITICO = 10;

// 1. Lecturas de un sensor específico
print("\n1. Lecturas de un sensor específico");
printjson(
    lecturas.find({
        id_sensor: "Panther_parking_Lorriane"
    }).sort({ fecha_hora: 1 }).limit(10).toArray()
);

// 2. Lecturas en un rango de fechas
print("\n2. Lecturas en un rango de fechas");
printjson(
    lecturas.find({
        fecha_hora: {
            $gte: ISODate("2016-01-01T00:00:00.000Z"),
            $lt: ISODate("2016-01-02T00:00:00.000Z")
        }
    }).sort({ fecha_hora: 1 }).toArray()
);

// 3. Valores máximos y mínimos registrados
print("\n3. Valores máximo y mínimo");
printjson(
    lecturas.aggregate([
        {
            $group: {
                _id: null,
                valor_maximo: { $max: "$medicion.valor" },
                valor_minimo: { $min: "$medicion.valor" },
                cantidad: { $sum: 1 }
            }
        },
        {
            $project: {
                _id: 0,
                valor_maximo: 1,
                valor_minimo: 1,
                cantidad: 1
            }
        }
    ]).toArray()
);

// 4. Mediciones críticas según un umbral ilustrativo
print("\n4. Mediciones que alcanzan el umbral crítico");
printjson(
    lecturas.find({
        "medicion.valor": { $gte: UMBRAL_CRITICO }
    }).sort({ "medicion.valor": -1 }).limit(20).toArray()
);

// 5. Posibles alertas agrupadas por zona
// Son mediciones sobre el umbral, no alertas almacenadas.
print("\n5. Mediciones sobre el umbral por zona");
printjson(
    lecturas.aggregate([
        {
            $match: {
                "medicion.valor": { $gte: UMBRAL_CRITICO }
            }
        },
        {
            $group: {
                _id: "$ubicacion.zona",
                cantidad_mediciones: { $sum: 1 },
                valor_maximo: { $max: "$medicion.valor" }
            }
        },
        {
            $sort: { cantidad_mediciones: -1 }
        }
    ]).toArray()
);

// 6. Promedio de mediciones por zona
print("\n6. Promedio por zona");
printjson(
    lecturas.aggregate([
        {
            $group: {
                _id: "$ubicacion.zona",
                promedio: { $avg: "$medicion.valor" },
                cantidad: { $sum: 1 }
            }
        },
        {
            $sort: { promedio: -1 }
        }
    ]).toArray()
);

// 7. Promedio por tipo de sensor
print("\n7. Promedio por tipo de sensor");
printjson(
    lecturas.aggregate([
        {
            $group: {
                _id: "$sensor.tipo",
                promedio: { $avg: "$medicion.valor" },
                cantidad: { $sum: 1 }
            }
        },
        {
            $sort: { promedio: -1 }
        }
    ]).toArray()
);

// 8. Mediciones sobre el umbral por categoría de sensor
// No representa incidentes reales: no existe ese registro en el dataset.
print("\n8. Mediciones sobre el umbral por categoría");
printjson(
    lecturas.aggregate([
        {
            $match: {
                "medicion.valor": { $gte: UMBRAL_CRITICO }
            }
        },
        {
            $group: {
                _id: "$sensor.categoria",
                cantidad: { $sum: 1 },
                valor_maximo: { $max: "$medicion.valor" }
            }
        },
        {
            $sort: { cantidad: -1 }
        }
    ]).toArray()
);

// 9. Consulta con agregaciones: resumen por zona y tipo
print("\n9. Resumen agregado por zona y tipo de sensor");
printjson(
    lecturas.aggregate([
        {
            $group: {
                _id: {
                    zona: "$ubicacion.zona",
                    tipo: "$sensor.tipo"
                },
                promedio: { $avg: "$medicion.valor" },
                minimo: { $min: "$medicion.valor" },
                maximo: { $max: "$medicion.valor" },
                cantidad: { $sum: 1 }
            }
        },
        {
            $sort: {
                "_id.zona": 1,
                "_id.tipo": 1
            }
        }
    ]).toArray()
);

// 10. Filtros múltiples
print("\n10. Filtros múltiples");
printjson(
    lecturas.find({
        "ubicacion.zona": "Panther",
        "sensor.tipo": "energia",
        "medicion.valor": { $gte: 0 }
    }).sort({ fecha_hora: 1 }).limit(20).toArray()
);

print("\nFin de las 10 consultas obligatorias.");
