# SmartCityCE — Instalación local de Hadoop y HDFS

## Objetivo

Configurar Apache Hadoop 3.4.3 en modo pseudodistribuido (un solo equipo) para las Issues #40–#42. La instalación de Hadoop y los datos internos de HDFS se mantienen **fuera** del repositorio.

## Requisitos

- Ubuntu con Java 11 (`openjdk-11-jdk`).
- Cliente y servidor SSH, y `rsync`.
- Hadoop 3.4.3 extraído en `~/hadoop` (o indicar su ubicación mediante `HADOOP_HOME`).
- Acceso SSH local sin pedir contraseña para utilizar `start-dfs.sh`.

Comprobar:

```bash
/usr/lib/jvm/java-11-openjdk-amd64/bin/java -version
ssh -V
hadoop version
ssh localhost
```

Si `ssh localhost` solicita contraseña, configurar una clave SSH local y autorizar la clave pública. No incluir claves privadas en Git.

## Configurar HDFS

Desde la raíz del repositorio:

```bash
bash Hadoop/scripts/setup_hadoop.sh
```

El script establece:

- `fs.defaultFS = hdfs://localhost:9000`
- `dfs.replication = 1`
- Directorios locales del NameNode y DataNode en `~/hadoop_data/`
- Java 11 para Hadoop, sin cambiar el Java predeterminado del equipo.

Se realizan copias de seguridad de los archivos de configuración que cambien. **El script no formatea HDFS, no instala Hadoop y no inicia servicios.**

Si la instalación de Hadoop está en otra ruta:

```bash
HADOOP_HOME="$HOME/otra_ruta/hadoop" bash Hadoop/scripts/setup_hadoop.sh
```

Si Java 11 está en otra ruta:

```bash
HADOOP_JAVA_HOME="/ruta/a/java11" bash Hadoop/scripts/setup_hadoop.sh
```

> **Precaución:** si ya existe un HDFS con datos, comprobar sus rutas y configuración antes de ejecutar el script. Nunca volver a formatear su NameNode.

## Primer inicio de una instalación nueva

Solo cuando el NameNode **nunca se ha inicializado** y los directorios de datos están vacíos:

```bash
hdfs namenode -format
```

No repetir este paso tras haber creado archivos en HDFS.

Para iniciar los servicios, usar el script existente:

```bash
./Hadoop/scripts/start_hadoop.sh
```

Comprobar:

```bash
jps
hdfs dfsadmin -report
```

Deben aparecer `NameNode`, `DataNode` y `SecondaryNameNode`, con **1 DataNode activo**. La interfaz web del NameNode suele estar en `http://localhost:9870`.

## Prueba de lectura y escritura

```bash
printf 'SmartCityCE - Prueba de HDFS\n' > /tmp/smartcityce_test.txt
hdfs dfs -mkdir -p /smartcityce/tests
hdfs dfs -put -f /tmp/smartcityce_test.txt /smartcityce/tests/
hdfs dfs -cat /smartcityce/tests/smartcityce_test.txt
hdfs dfs -get -f /smartcityce/tests/smartcityce_test.txt /tmp/smartcityce_descargado.txt
cmp /tmp/smartcityce_test.txt /tmp/smartcityce_descargado.txt
hdfs dfs -rm /smartcityce/tests/smartcityce_test.txt
hdfs dfs -rmdir /smartcityce/tests
```

`cmp` termina sin salida cuando ambos archivos son idénticos.

## Detener servicios

```bash
./Hadoop/scripts/stop_hadoop.sh
```

## Notas para el equipo

- El directorio local `~/hadoop_data/` **no** es parte del repositorio Git.
- El espacio disponible para HDFS depende del espacio libre en el disco de cada equipo.
- Esta configuración sirve para desarrollo local; no representa un clúster distribuido de varias máquinas.
- Después de completar esta instalación, continuar con la Issue #41 (preparación de datasets) y la #42 (carga y comprobación en HDFS).
