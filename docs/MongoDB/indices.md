# Índices de MongoDB

## 1. Objetivo

El objetivo de esta etapa es definir índices para optimizar las consultas realizadas sobre la colección `lecturas` de MongoDB.

La colección contiene 500 000 documentos correspondientes a mediciones eléctricas, por lo que los índices permiten evitar recorridos completos de la colección para patrones de consulta frecuentes.

Los índices implementados se encuentran definidos en:

`MongoDB/indexes.js`

---

## 2. Índices implementados

Se definieron cuatro índices adicionales al índice `_id_` creado automáticamente por MongoDB:

| Índice | Campos | Propósito |
|---|---|---|
| `idx_lecturas_sensor` | `id_sensor` | Búsquedas por sensor |
| `idx_lecturas_fecha` | `fecha_hora` | Consultas por rangos temporales |
| `idx_lecturas_zona` | `ubicacion.zona` | Consultas y agregaciones por zona |
| `idx_lecturas_sensor_fecha` | `id_sensor`, `fecha_hora` | Historial temporal de un sensor |

---

## 3. Índice por sensor

El índice:


{ id_sensor: 1 }

## Estado de los índices en la base de datos

La consulta `db.lecturas.getIndexes()` ejecutada en la base
`smartcityce` devolvió el índice predeterminado `_id_`.

Por lo tanto, los índices adicionales descritos en este documento
no deben considerarse confirmados como creados en la instancia
verificada. Su existencia y uso deben comprobarse ejecutando el
script `MongoDB/indexes.js` y consultando nuevamente los índices
de la colección.

El índice `_id_` es creado automáticamente por MongoDB y permite
identificar de manera única los documentos mediante su campo `_id`.