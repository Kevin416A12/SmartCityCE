
# Vistas y funciones de SmartCityCE

## Vista: vw_sensor_resumen

Consolida informacion de los sensores con su categoria,
organismo responsable, edificio, ubicacion y estado.

Tambien presenta la cantidad de lecturas electricas
registradas y la fecha de la ultima actividad.

La vista facilita la consulta y el seguimiento del
estado de los sensores sin repetir los JOIN.

## Funcion: fn_sensores_por_ubicacion

Recibe como parametro el identificador de una ubicacion
y devuelve los sensores vinculados a edificios de esa zona.

Incluye categoria, organismo responsable, edificio,
estado y fecha de instalacion.

La funcion permite reutilizar la misma consulta para
distintas ubicaciones, proporcionando un resultado uniforme.

## Pruebas

1. Consultar la vista y verificar los campos obtenidos.
2. Invocar la funcion con un ID de ubicacion valido.
3. Comparar los resultados con las tablas originales.
