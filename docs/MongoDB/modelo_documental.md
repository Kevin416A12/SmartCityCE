# Modelo documental MongoDB

## 1. Objetivo

MongoDB se utiliza en SmartCityCE para almacenar información semiestructurada y de alta frecuencia asociada con el monitoreo energético y ambiental de la ciudad inteligente.

Mientras PostgreSQL mantiene los datos maestros y estructurados del sistema, como sensores, ubicaciones, edificios, categorías y organismos responsables, MongoDB se utiliza para almacenar información que puede crecer rápidamente y cuya estructura puede variar entre distintos tipos de registros.

## Colecciones del modelo

El diseño documental contempla las siguientes colecciones:

- `lecturas`: colección utilizada para almacenar las mediciones de sensores.
- `meteorologia`: colección propuesta para observaciones meteorológicas.
- `eventos`: colección propuesta para eventos detectados a partir de mediciones.
- `alertas`: colección propuesta para notificaciones generadas por reglas o eventos.
- `incidentes`: colección propuesta para incidentes urbanos.

La colección `lecturas` ha sido verificada en la base de datos
`smartcityce`. Las demás colecciones forman parte del diseño
documental descrito en este documento y su implementación debe
verificarse por separado.

---

## 2. Colección `lecturas`

La colección `lecturas` almacena las mediciones energéticas generadas por los sensores.

Cada documento representa una lectura realizada por un sensor en un instante determinado.

### Ejemplo de documento


{
    _id: ObjectId("..."),
    id_sensor: "Panther_parking_Lorriane",
    fecha_hora: ISODate("2016-01-01T05:00:00.000Z"),

    medicion: {
        valor: 0,
        unidad: "kWh_sum"
    },

    ubicacion: {
        id_ubicacion: "Panther",
        zona: "Panther",
        coordenadas: {
            latitud: 28.5176885788321,
            longitud: -81.3790387999998
        }
    },

    sensor: {
        tipo: "energia",
        categoria: "consumo_electrico",
        uso_primario: "Parking"
    },

    metadatos: {
        fuente: "BDG2",
        calidad: "limpio",
        zona_horaria_origen: "US/Eastern"
    }
}

### Justificación

El campo `id_sensor` mantiene una referencia lógica con el sensor almacenado en PostgreSQL.

Se incluye además un resumen de la ubicación y del tipo de sensor dentro del documento. Esta desnormalización controlada permite realizar consultas y agregaciones directamente en MongoDB por zona o tipo de sensor sin consultar constantemente la base relacional.

El campo `fecha_hora` se almacena utilizando el tipo `Date` de MongoDB para permitir búsquedas eficientes por rangos temporales.

---

## 3. Colección `meteorologia`

La colección `meteorologia` almacena las observaciones meteorológicas utilizadas para complementar el análisis energético.

Los datos meteorológicos provienen de Open-Meteo y pueden contener distintas variables ambientales para una ubicación y momento determinados.

### Ejemplo de documento

```javascript
{
    _id: ObjectId(),

    fecha_hora: ISODate("2016-01-01T08:00:00Z"),

    ubicacion: {
        id_ubicacion: 18,
        zona: "Zona Norte",
        coordenadas: {
            latitud: 9.93,
            longitud: -84.08
        }
    },

    mediciones: {
        temperatura: 24.5,
        humedad: 72,
        precipitacion: 0.0
    },

    metadatos: {
        fuente: "Open-Meteo"
    }
}
```

### Justificación

Las variables meteorológicas se almacenan dentro del objeto `mediciones` debido a que corresponden a una misma observación temporal.

La estructura documental permite incorporar posteriormente otras variables, como velocidad del viento u otras mediciones ambientales, sin modificar el resto de los documentos existentes.

Las coordenadas podrán representarse posteriormente mediante GeoJSON si se requieren consultas geoespaciales.

---

## 4. Colección `eventos`

La colección `eventos` representa situaciones relevantes detectadas a partir de las mediciones, como consumos anormales, picos de demanda u otras condiciones identificadas durante el análisis de los datos.

### Ejemplo de documento

```javascript
{
    _id: ObjectId(),

    id_sensor: 125,
    fecha_hora: ISODate("2016-01-01T18:35:00Z"),

    tipo_evento: "pico_consumo",
    categoria: "energia",
    severidad: "alta",

    descripcion: "Consumo energético superior al comportamiento esperado.",

    ubicacion: {
        id_ubicacion: 18,
        zona: "Zona Norte"
    },

    datos: {
        valor_detectado: 98.4,
        unidad: "kWh",
        umbral: 80.0
    },

    metadatos: {
        fuente: "analisis_automatico",
        estado: "detectado"
    }
}
```

### Justificación

El objeto `datos` permite almacenar información diferente según el tipo de evento detectado.

Por ejemplo, un evento energético puede almacenar un valor y un umbral, mientras que otro evento puede requerir duración, cantidad de lecturas afectadas u otros atributos.

Esta flexibilidad evita imponer una estructura rígida a todos los tipos de eventos.

---

## 5. Colección `alertas`

La colección `alertas` representa notificaciones generadas a partir de eventos o reglas definidas sobre los datos.

Una alerta puede mantener una referencia al evento que la originó.

### Ejemplo de documento

```javascript
{
    _id: ObjectId(),

    id_evento: ObjectId("..."),
    id_sensor: 125,

    fecha_hora: ISODate("2016-01-01T18:35:05Z"),

    tipo_alerta: "consumo_critico",
    nivel: "critico",

    mensaje: "Se detectó un consumo energético crítico.",

    ubicacion: {
        id_ubicacion: 18,
        zona: "Zona Norte"
    },

    estado: "activa",

    metadatos: {
        generada_automaticamente: true,
        regla: "consumo > 80 kWh"
    }
}
```

### Justificación

El evento completo no se embebe dentro de la alerta. En su lugar se utiliza `id_evento` como referencia.

Esto permite que eventos y alertas tengan ciclos de vida independientes. Por ejemplo, una alerta puede pasar de `activa` a `resuelta` sin modificar el registro histórico del evento que la generó.

La ubicación se mantiene embebida para facilitar consultas de alertas por zona geográfica.

---

## 6. Colección `incidentes`

La colección `incidentes` almacena incidentes urbanos relacionados con el contexto de SmartCity.

Los datasets principales seleccionados para el proyecto no proporcionan directamente este tipo de información. Por esta razón, los incidentes podrán generarse de forma sintética o incorporarse posteriormente desde una fuente externa.

La procedencia de cada incidente debe mantenerse explícitamente en sus metadatos.

### Ejemplo de documento

```javascript
{
    _id: ObjectId(),

    fecha_hora: ISODate("2016-01-01T19:10:00Z"),

    categoria: "falla_electrica",
    tipo_incidente: "interrupcion_suministro",
    severidad: "alta",

    descripcion: "Interrupción temporal del suministro eléctrico.",

    ubicacion: {
        id_ubicacion: 18,
        zona: "Zona Norte"
    },

    sensores_relacionados: [
        125,
        126
    ],

    estado: "reportado",

    datos_adicionales: {
        duracion_estimada_minutos: 30,
        edificios_afectados: 4
    },

    metadatos: {
        origen: "sintetico",
        metodo_generacion: "reglas_basadas_en_datos"
    }
}
```

### Justificación

Un incidente puede estar relacionado con múltiples sensores, por lo que se utiliza el arreglo `sensores_relacionados`.

El objeto `datos_adicionales` permite almacenar atributos variables dependiendo de la categoría del incidente.

Los metadatos permiten distinguir claramente entre información sintética y datos provenientes de fuentes externas.

---

## 7. Estrategia de embedding y referencias

El modelo utiliza una estrategia híbrida que combina documentos embebidos y referencias.

### Información embebida

Se embebe información pequeña y utilizada frecuentemente junto con el documento principal, entre ella:

- mediciones;
- resumen de ubicación;
- resumen del tipo de sensor;
- metadatos;
- información específica de eventos;
- datos adicionales de incidentes.

Esto reduce la necesidad de realizar consultas adicionales para operaciones frecuentes de análisis.

### Información referenciada

Se utilizan referencias para entidades que poseen una identidad independiente o cuya información maestra se encuentra almacenada en PostgreSQL.

Entre ellas:

- `id_sensor`;
- `id_ubicacion`;
- `id_evento`;
- sensores relacionados con incidentes.

Los identificadores de sensor y ubicación permiten mantener una relación lógica entre MongoDB y PostgreSQL sin replicar completamente las entidades relacionales.

---

## 8. Relación lógica con PostgreSQL

PostgreSQL funciona como fuente principal para la información estructurada y maestra del sistema.

Entre esta información se encuentran:

- sensores;
- edificios;
- ubicaciones;
- categorías de sensores;
- usuarios;
- organismos responsables.

MongoDB almacena principalmente información temporal, dinámica y semiestructurada.

La integración entre ambos sistemas se realiza mediante identificadores compartidos, principalmente `id_sensor` e `id_ubicacion`.

De esta manera, ambas tecnologías cumplen funciones complementarias dentro de la arquitectura de SmartCityCE.

---

## 9. Compatibilidad con las consultas requeridas

El modelo fue diseñado considerando las consultas obligatorias que posteriormente deberán implementarse en MongoDB.

| Consulta | Campos principales |
|---|---|
| Lecturas de un sensor específico | `lecturas.id_sensor` |
| Lecturas en un rango de fechas | `lecturas.fecha_hora` |
| Valores máximos y mínimos | `lecturas.medicion.valor` |
| Eventos críticos | Colección propuesta `eventos`, campo `severidad` |
| Alertas por zona geográfica | Colección propuesta `alertas`, campo `ubicacion.zona` |
| Promedio de mediciones por zona | `lecturas.ubicacion.zona`, `lecturas.medicion.valor` |
| Promedio por tipo de sensor | `lecturas.sensor.tipo`, `lecturas.medicion.valor` |
| Incidentes por categoría | Colección propuesta `incidentes`, campo `categoria` |
| Consulta mediante agregaciones | Diferentes colecciones según el análisis |
| Consulta con múltiples filtros | Campos temporales, ubicación, sensor, categoría y severidad |

Por lo tanto, el modelo permite implementar las consultas requeridas sin depender de una consulta a PostgreSQL para cada operación analítica.

---

## 10. Diagrama del modelo

El diagrama del modelo documental se encuentra en:

```text
docs/MongoDB/modelo_documental.mmd
```

El diagrama representa las cinco colecciones principales, las estructuras embebidas y la relación existente entre eventos y alertas.

---

## 11 Justificación de MongoDB frente a PostgreSQL

MongoDB se utiliza para almacenar mediciones documentales que incluyen
información temporal, datos anidados y metadatos asociados a cada
lectura. Su modelo BSON permite mantener juntos los atributos que
pertenecen a una misma medición y consultar directamente campos como
`medicion.valor`, `ubicacion.zona` y `sensor.tipo`.

PostgreSQL complementa esta función al gestionar información
estructurada y relaciones entre entidades del sistema. En una base
relacional, las mediciones y sus atributos relacionados pueden
representarse mediante tablas y claves foráneas; en MongoDB, los
datos que se consultan conjuntamente pueden agruparse en un documento.

La elección de MongoDB para las lecturas facilita las consultas sobre
documentos anidados y el uso del Aggregation Framework para resumir
mediciones por zona, tipo de sensor o intervalo temporal.

Esto no significa que MongoDB sea siempre superior a PostgreSQL.
PostgreSQL ofrece ventajas para relaciones complejas, restricciones
referenciales y consultas relacionales. La arquitectura híbrida
permite utilizar cada tecnología según las necesidades de los datos.

## 12. Conclusión

El modelo documental propuesto utiliza MongoDB para almacenar información que presenta alta frecuencia, variabilidad estructural y crecimiento continuo.

El uso de documentos embebidos facilita las consultas analíticas frecuentes, mientras que las referencias permiten conservar la relación lógica con los datos maestros almacenados en PostgreSQL.

Esta separación evita duplicar innecesariamente el modelo relacional y permite aprovechar las características particulares de ambas tecnologías dentro de SmartCityCE.
