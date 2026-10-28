
/*
 * SmartCityCE - Issue #14
 * CRUD sobre la colección real de lecturas de BDG2.
 *
 * Compatible con mongosh.
 *
 * IMPORTANTE:
 * - No crea ni utiliza lecturas_prueba.
 * - Las operaciones de escritura se ejecutan cuando se llaman
 *   las funciones correspondientes.
 * - Para actualizar o eliminar, se exige un filtro específico.
 */

db = db.getSiblingDB("smartcityce");

const lecturas = db.getCollection("lecturas");

print("\n=== SMARTCITYCE: CRUD DE LECTURAS ===");
print("Base de datos: " + db.getName());
print("Colección: lecturas");
print("Documentos existentes: " + lecturas.countDocuments({}));

// Validar que el documento tenga la estructura básica de una lectura.
function validarLectura(documento) {
    if (!documento || typeof documento !== "object") {
        throw new Error("Debe proporcionar un documento válido.");
    }

    const camposObligatorios = [
        "id_sensor",
        "fecha_hora",
        "medicion",
        "ubicacion",
        "sensor",
        "metadatos"
    ];

    camposObligatorios.forEach(campo => {
        if (documento[campo] === undefined || documento[campo] === null) {
            throw new Error("Falta el campo obligatorio: " + campo);
        }
    });
}

// Evitar actualizaciones o eliminaciones sin un filtro específico.
function validarFiltro(filtro) {
    if (
        !filtro ||
        typeof filtro !== "object" ||
        Object.keys(filtro).length === 0
    ) {
        throw new Error(
            "Debe proporcionar un filtro específico para esta operación."
        );
    }
}

// 1. CREATE: insertar una lectura.
function crearLectura(documento) {
    validarLectura(documento);

    const resultado = lecturas.insertOne(documento);

    print("\n=== CREATE: INSERT ONE ===");
    printjson(resultado);

    return resultado;
}

// 2. CREATE: insertar varias lecturas.
function crearMuchasLecturas(documentos) {
    if (!Array.isArray(documentos) || documentos.length === 0) {
        throw new Error("Debe proporcionar una lista de lecturas.");
    }

    documentos.forEach(validarLectura);

    const resultado = lecturas.insertMany(documentos);

    print("\n=== CREATE: INSERT MANY ===");
    printjson(resultado);

    return resultado;
}

// 3. READ: consultar lecturas usando un filtro.
function consultarLecturas(filtro = {}, limite = 20) {
    const resultado = lecturas
        .find(filtro)
        .sort({ fecha_hora: -1 })
        .limit(limite)
        .toArray();

    print("\n=== READ: FIND ===");
    print("Resultados encontrados: " + resultado.length);
    printjson(resultado);

    return resultado;
}

// 4. READ: consultar una lectura específica.
function consultarUnaLectura(filtro) {
    validarFiltro(filtro);

    const resultado = lecturas.findOne(filtro);

    print("\n=== READ: FIND ONE ===");
    printjson(resultado);

    return resultado;
}

// 5. UPDATE: actualizar una lectura.
function actualizarUnaLectura(filtro, cambios) {
    validarFiltro(filtro);

    if (!cambios || Object.keys(cambios).length === 0) {
        throw new Error("Debe proporcionar los cambios que desea aplicar.");
    }

    const resultado = lecturas.updateOne(filtro, { $set: cambios });

    print("\n=== UPDATE: UPDATE ONE ===");
    printjson(resultado);

    return resultado;
}

// 6. UPDATE: actualizar varias lecturas que coincidan con el filtro.
function actualizarMuchasLecturas(filtro, cambios) {
    validarFiltro(filtro);

    if (!cambios || Object.keys(cambios).length === 0) {
        throw new Error("Debe proporcionar los cambios que desea aplicar.");
    }

    const resultado = lecturas.updateMany(filtro, { $set: cambios });

    print("\n=== UPDATE: UPDATE MANY ===");
    printjson(resultado);

    return resultado;
}

// 7. DELETE: eliminar una lectura específica.
function eliminarUnaLectura(filtro) {
    validarFiltro(filtro);

    const resultado = lecturas.deleteOne(filtro);

    print("\n=== DELETE: DELETE ONE ===");
    printjson(resultado);

    return resultado;
}

// EJEMPLOS DE USO
// Se ejecutan manualmente desde mongosh después de cargar este archivo.

// Consultar las últimas 10 lecturas:
// consultarLecturas({}, 10);

// Consultar lecturas de un sensor específico:
// consultarLecturas({ id_sensor: 123 }, 10);

// Consultar una lectura por su identificador MongoDB:
// consultarUnaLectura({ _id: ObjectId("REEMPLAZAR_POR_ID_VALIDO") });

// Actualizar una lectura específica:
// actualizarUnaLectura(
//     { _id: ObjectId("REEMPLAZAR_POR_ID_VALIDO") },
//     { "metadatos.calidad": "revisado" }
// );

// Actualizar varias lecturas que coincidan con un criterio:
// actualizarMuchasLecturas(
//     { id_sensor: 123 },
//     { "metadatos.calidad": "revisado" }
// );

// Eliminar una lectura específica:
// eliminarUnaLectura({ _id: ObjectId("REEMPLAZAR_POR_ID_VALIDO") });

// Insertar una lectura nueva:
// crearLectura({
//     id_sensor: 123,
//     fecha_hora: new Date(),
//     medicion: { valor: 12.5, unidad: "kWh_sum" },
//     ubicacion: {
//         id_ubicacion: 1,
//         zona: "Zona de ejemplo",
//         coordenadas: { latitud: 0, longitud: 0 }
//     },
//     sensor: {
//         tipo: "energia",
//         categoria: "consumo_electrico",
//         uso_primario: "Unknown"
//     },
//     metadatos: {
//         fuente: "BDG2",
//         calidad: "limpio",
//         zona_horaria_origen: "UTC"
//     }
// });

print("\n=== CRUD LISTO PARA UTILIZARSE ===");
