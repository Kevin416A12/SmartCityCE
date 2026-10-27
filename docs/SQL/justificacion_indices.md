
# Justificación de índices PostgreSQL — SmartCityCE

## 1. idx_lectura_fecha_hora

Tabla: lectura_sql
Columna: fecha_hora

Permite optimizar consultas que filtran las lecturas eléctricas
por intervalos temporales. Es el índice prioritario debido al
alto volumen de registros de esta tabla.

Ejemplo de uso:
consultar las lecturas registradas durante un día determinado.

## 2. idx_sensor_id_edificio

Tabla: sensor
Columna: id_edificio

Facilita la relación entre sensor y edificio en las consultas
JOIN. También permite localizar sensores asociados a un
edificio y ayuda a evitar búsquedas innecesarias al comprobar
relaciones de clave foránea.

## 3. idx_edificio_id_ubicacion

Tabla: edificio
Columna: id_ubicacion

Facilita la relación entre edificio y ubicación cuando se
consultan los edificios correspondientes a un sitio.

## Consideraciones

No se duplican índices sobre claves primarias ni sobre
combinaciones de columnas que ya cuentan con índices
generados por restricciones UNIQUE.

Los índices consumen espacio y pueden aumentar el costo
de las inserciones y actualizaciones. Su utilidad debe
comprobarse mediante los planes de ejecución de PostgreSQL.
