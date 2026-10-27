# Integración entre PostgreSQL y MongoDB

## 1. Objetivo

SmartCityCE utiliza PostgreSQL y MongoDB de manera complementaria para almacenar y consultar la información del sistema.

PostgreSQL mantiene los datos maestros y estructurados, tales como sensores, edificios, ubicaciones, categorías de sensores, organismos responsables y usuarios. MongoDB almacena principalmente información temporal, dinámica y semiestructurada, como lecturas, eventos, alertas, incidentes y datos meteorológicos.

La integración entre ambas tecnologías se realiza mediante identificadores lógicos derivados de las fuentes de datos. No existe una clave foránea física entre PostgreSQL y MongoDB; en su lugar, se mantienen valores comunes que permiten relacionar conceptualmente los registros almacenados en ambas bases de datos.

---

## 2. Responsabilidad de cada base de datos

### PostgreSQL

PostgreSQL funciona como fuente principal para las entidades estructuradas del sistema.

Entre las principales entidades se encuentran:

- `ubicacion`
- `edificio`
- `categoria_sensor`
- `organismo_responsable`
- `sensor`
- `usuario_sistema`
- `lectura_sql`
- `registro_meteorologico`

El modelo relacional utiliza claves primarias y foráneas para garantizar la integridad entre estas entidades.

### MongoDB

MongoDB se utiliza para información de alta frecuencia o cuya estructura puede variar según el tipo de registro.

Las colecciones definidas son:

- `lecturas`
- `meteorologia`
- `eventos`
- `alertas`
- `incidentes`

Los documentos contienen información desnormalizada de sensores y ubicaciones para facilitar filtros, agregaciones y análisis sin requerir una consulta constante a PostgreSQL.

---

## 3. Estrategia de integración

La integración se basa en conservar identificadores provenientes de las fuentes originales.

Los identificadores internos generados automáticamente por PostgreSQL, como `sensor.id_sensor`, `ubicacion.id_ubicacion` y `categoria_sensor.id_categoria`, se utilizan para mantener la integridad del modelo relacional.

Sin embargo, estos valores numéricos no se utilizan directamente como identificadores compartidos con MongoDB, ya que son generados internamente por PostgreSQL.

Para relacionar ambas tecnologías se utilizan valores estables provenientes de los datasets originales.

---

## 4. Integración de sensores

En el dataset BDG2, cada edificio o medidor eléctrico posee un identificador `building_id`.

Por ejemplo:

```text
Panther_retail_Lester
```

Durante la carga en PostgreSQL este identificador se conserva en:

```text
edificio.id_edificio
sensor.nombre
```

En MongoDB el mismo identificador se utiliza en:

```text
lecturas.id_sensor
```

Por lo tanto, la relación lógica utilizada es:

```text
MongoDB
lecturas.id_sensor
        │
        │ building_id de BDG2
        ▼
PostgreSQL
sensor.nombre
        │
        ▼
edificio.id_edificio
```

De esta manera, aunque `sensor.id_sensor` en PostgreSQL sea un número generado automáticamente, es posible identificar el mismo sensor o medidor en ambas tecnologías mediante el identificador original de BDG2.

---

## 5. Integración de ubicaciones

Los datos utilizados actualmente pertenecen al sitio:

```text
Panther
```

En PostgreSQL, el sitio se registra mediante:

```text
ubicacion.nombre_zona = "Panther"
```

PostgreSQL genera además un `id_ubicacion` numérico que se utiliza internamente como clave primaria.

En MongoDB, la información de ubicación se almacena de forma embebida dentro de los documentos:

```javascript
ubicacion: {
    id_ubicacion: "Panther",
    zona: "Panther",
    coordenadas: {
        latitud: ...,
        longitud: ...
    }
}
```

Por lo tanto, la correspondencia lógica utilizada entre ambas bases es:

```text
PostgreSQL                         MongoDB

ubicacion.nombre_zona     <---->  ubicacion.id_ubicacion
        "Panther"                       "Panther"

ubicacion.nombre_zona     <---->  ubicacion.zona
        "Panther"                       "Panther"
```

Las coordenadas utilizadas en ambos sistemas provienen igualmente de los metadatos del sitio BDG2.

---

## 6. Integración de categorías de sensores

PostgreSQL mantiene las categorías de sensores como una entidad independiente.

Para los datos energéticos de BDG2 se utiliza:

```text
categoria_sensor.nombre_categoria = "Electricidad"
```

Los sensores correspondientes mantienen una referencia mediante:

```text
sensor.id_categoria
```

En MongoDB esta información se almacena de forma desnormalizada dentro de cada lectura:

```javascript
sensor: {
    tipo: "energia",
    categoria: "consumo_electrico",
    uso_primario: "..."
}
```

La relación entre estos valores es semántica:

```text
PostgreSQL                         MongoDB

"Electricidad"             <---->  tipo = "energia"
                                   categoria = "consumo_electrico"
```

Esta estrategia permite que PostgreSQL mantenga un catálogo normalizado de categorías, mientras MongoDB conserva información suficiente dentro de cada documento para realizar agregaciones sin consultar la base relacional.

---

## 7. Consistencia entre ambas tecnologías

Para mantener la consistencia entre PostgreSQL y MongoDB se siguen las siguientes reglas:

1. El `building_id` original de BDG2 se conserva como identificador lógico del sensor o medidor.
2. El nombre del sitio de origen se conserva como identificador lógico de la ubicación.
3. Los identificadores numéricos generados por PostgreSQL se consideran claves internas del modelo relacional.
4. MongoDB conserva información resumida de sensores y ubicaciones para facilitar consultas analíticas.
5. Las categorías almacenadas en MongoDB deben mantener una equivalencia semántica con las categorías definidas en PostgreSQL.
6. Las fechas se almacenan utilizando tipos temporales apropiados en ambas tecnologías.
7. La procedencia de los datos se mantiene mediante los campos de metadatos correspondientes.

---

## 8. Flujo de datos

El flujo general de información puede representarse de la siguiente manera:

```text
                   FUENTES DE DATOS
                         │
            ┌────────────┴────────────┐
            │                         │
           BDG2                  Open-Meteo
            │                         │
            ▼                         ▼
     Procesamiento y transformación de datos
            │
      ┌─────┴──────────────────────┐
      │                            │
      ▼                            ▼
 PostgreSQL                     MongoDB
      │                            │
      │ Datos maestros             │ Datos temporales,
      │ y estructurados            │ dinámicos y
      │                            │ semiestructurados
      │                            │
      ├─ ubicaciones               ├─ lecturas
      ├─ edificios                 ├─ meteorologia
      ├─ sensores                  ├─ eventos
      ├─ categorías                ├─ alertas
      └─ organismos                └─ incidentes
      │                            │
      └──────────┬─────────────────┘
                 │
                 ▼
       Identificadores lógicos
          compartidos
```

La aplicación o las capas de procesamiento pueden utilizar estos identificadores para relacionar información proveniente de ambas tecnologías cuando sea necesario.

---

## 9. Correspondencias principales

| Concepto | PostgreSQL | MongoDB | Identificador lógico |
|---|---|---|---|
| Sensor | `sensor.nombre` | `lecturas.id_sensor` | `building_id` de BDG2 |
| Edificio | `edificio.id_edificio` | Asociado mediante `lecturas.id_sensor` | `building_id` de BDG2 |
| Ubicación | `ubicacion.nombre_zona` | `ubicacion.id_ubicacion` | `site_id` / nombre del sitio |
| Zona | `ubicacion.nombre_zona` | `ubicacion.zona` | nombre del sitio |
| Categoría | `categoria_sensor.nombre_categoria` | `sensor.tipo` / `sensor.categoria` | equivalencia semántica |
| Eventos | No aplica | `eventos` | referencias lógicas a sensor y ubicación |
| Alertas | No aplica | `alertas` | referencias lógicas a evento, sensor y ubicación |
| Incidentes | No aplica | `incidentes` | referencias lógicas a sensores y ubicación |

---

## 10. Separación de responsabilidades

La integración no busca replicar completamente la información de PostgreSQL dentro de MongoDB.

PostgreSQL mantiene la información maestra y las relaciones estructuradas, mientras MongoDB incluye únicamente la información contextual necesaria para realizar consultas analíticas de manera eficiente.

Por ejemplo, una lectura de MongoDB incluye el identificador lógico del sensor, la zona y un resumen de su tipo. No necesita almacenar nuevamente toda la entidad `sensor`, su organismo responsable o todas las relaciones existentes en PostgreSQL.

Esta separación reduce la duplicación innecesaria y permite aprovechar las características particulares de cada tecnología.

---

## 11. Conclusión

PostgreSQL y MongoDB forman un modelo de persistencia complementario dentro de SmartCityCE.

PostgreSQL proporciona integridad referencial y mantiene las entidades maestras del sistema, mientras MongoDB permite almacenar y analizar grandes volúmenes de información temporal y semiestructurada.

La correspondencia mediante identificadores provenientes de las fuentes originales permite relacionar ambos modelos sin depender de que las claves internas autogeneradas de PostgreSQL coincidan con los identificadores utilizados en MongoDB.

Esta estrategia permite mantener sensores, ubicaciones y categorías consistentes entre ambas tecnologías y establece una base clara para los procesos posteriores de análisis e integración.