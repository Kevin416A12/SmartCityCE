/* ============================================================
 * AGREGACIÓN 3
 * Análisis temporal del consumo por hora local
 * ============================================================
 *
 * Objetivo:
 * Analizar cómo varía el consumo eléctrico según la hora del día,
 * respetando la zona horaria original de cada medición.
 *
 * La fecha almacenada en MongoDB se encuentra normalizada a UTC.
 * Por esta razón, antes de agrupar se recupera la hora local
 * utilizando metadatos.zona_horaria_origen.
 *
 * Etapas utilizadas:
 *   $set     -> genera dinámicamente la hora local de la lectura.
 *   $group   -> agrupa las mediciones por hora del día.
 *   $project -> presenta y redondea las estadísticas calculadas.
 *   $sort    -> ordena cronológicamente las horas de 0 a 23.
 *
 * Esta consulta constituye una agregación avanzada porque deriva
 * información temporal a partir de un BSON Date considerando la
 * zona horaria particular de cada documento.
 */

db.lecturas.aggregate([
    {
        $set: {
            hora_local: {
                $hour: {
                    date: "$fecha_hora",
                    timezone: "$metadatos.zona_horaria_origen"
                }
            }
        }
    },
    {
        $group: {
            _id: "$hora_local",

            consumo_promedio: {
                $avg: "$medicion.valor"
            },

            consumo_total: {
                $sum: "$medicion.valor"
            },

            total_lecturas: {
                $sum: 1
            }
        }
    },
    {
        $project: {
            _id: 0,
            hora: "$_id",

            consumo_promedio: {
                $round: ["$consumo_promedio", 2]
            },

            consumo_total: {
                $round: ["$consumo_total", 2]
            },

            total_lecturas: 1
        }
    },
    {
        $sort: {
            hora: 1
        }
    }
]);