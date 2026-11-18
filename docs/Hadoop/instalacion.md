# SmartCityCE — Instalación de Apache Hadoop y HDFS

Guía para instalar **Apache Hadoop 3.4.3** con **Java 11** en **Ubuntu 24.04**, configurar HDFS en modo **pseudodistribuido (un nodo)** y verificar su funcionamiento. Se utiliza la estructura de scripts incluida en el repositorio SmartCityCE.

> **Alcance:** esta instalación es local, para desarrollo y pruebas. No configura un clúster de varias computadoras ni instala Apache Spark. Los binarios de Hadoop y el almacenamiento interno de HDFS permanecen **fuera** del repositorio.

## 1. Requisitos previos

Desde cualquier directorio de la terminal, instalar las dependencias:

```bash
sudo apt update
sudo apt install -y openjdk-11-jdk openssh-server openssh-client rsync wget tar
```

Comprobar Java 11 y SSH:

```bash
/usr/lib/jvm/java-11-openjdk-amd64/bin/java -version
ssh -V
sudo systemctl enable --now ssh
sudo systemctl status ssh
```

La salida de Java debe indicar una versión **11**. Para Hadoop utilizaremos Java 11, aunque Ubuntu tenga otra versión predeterminada (por ejemplo, Java 21).

## 2. Descargar e instalar Hadoop

Ejecutar desde el directorio personal (`~`), **no dentro del repositorio**:

```bash
cd ~
wget https://downloads.apache.org/hadoop/common/hadoop-3.4.3/hadoop-3.4.3.tar.gz
tar -xzf hadoop-3.4.3.tar.gz
mv hadoop-3.4.3 hadoop
```

Esto deja la instalación en `~/hadoop`. Si `~/hadoop` ya existe, **no repitas `mv` ni reemplaces la instalación**: revisa la carpeta existente antes de continuar.

> Si el enlace de descarga ya no está disponible en `downloads.apache.org`, busca la versión 3.4.3 en el archivo oficial de Apache: https://archive.apache.org/dist/hadoop/common/hadoop-3.4.3/ . Para verificar la integridad de la descarga se recomienda contrastar las sumas de comprobación publicadas por Apache.

## 3. Configurar variables de entorno

Abrir `~/.bashrc`:

```bash
nano ~/.bashrc
```

Añadir al final (si todavía no existen estas declaraciones):

```bash
# SmartCityCE - Apache Hadoop
export HADOOP_HOME="$HOME/hadoop"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"
```

Aplicar los cambios:

```bash
source ~/.bashrc
hadoop version
```

La salida debe comenzar con `Hadoop 3.4.3`. No es necesario cambiar el Java predeterminado del sistema; `setup_hadoop.sh` configura **Java 11 para Hadoop**.

## 4. Preparar SSH local sin contraseña

Los scripts `start-dfs.sh` y `stop-dfs.sh` utilizan SSH para administrar servicios, incluso en un solo equipo.

Probar:

```bash
ssh localhost
```

Si se conecta sin solicitar contraseña de usuario, escribir `exit` y continuar. Si pide contraseña, configurar la autenticación por clave:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

**Solo si no existe ya** una clave `~/.ssh/id_ed25519`, generar una:

```bash
ssh-keygen -t ed25519
```

A continuación, autorizar la clave pública local sin duplicarla:

```bash
grep -qxF "$(cat ~/.ssh/id_ed25519.pub)" ~/.ssh/authorized_keys 2>/dev/null || cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Verificar nuevamente:

```bash
ssh localhost
```

Al conectarse por primera vez, SSH podría pedir confirmar la huella digital del equipo local. Confirmarla **solo si corresponde realmente a `localhost`**. Salir con `exit`.

> Nunca subas claves privadas de SSH a GitHub.

## 5. Configurar HDFS con los scripts de SmartCityCE

**A partir de aquí, ejecutar desde la raíz del repositorio** `SmartCityCE`:

```bash
cd ~/Documentos/GitHub/SmartCityCE
```

Si el repositorio está en otra ubicación, entra a su directorio real.

Ejecutar el configurador:

```bash
bash Hadoop/scripts/setup_hadoop.sh
```

El script existente en el proyecto:

- Busca Hadoop en `$HADOOP_HOME` o, por defecto, `~/hadoop`.
- Comprueba que esté disponible Java 11.
- Crea `~/hadoop_data/namenode` y `~/hadoop_data/datanode` (o utiliza `SMARTCITYCE_HDFS_DATA_DIR`, si se definió).
- Escribe los archivos **reales** `core-site.xml` y `hdfs-site.xml` en `~/hadoop/etc/hadoop/`.
- Establece `fs.defaultFS=hdfs://localhost:9000` y `dfs.replication=1`.
- Configura Java 11 en `hadoop-env.sh` y respalda los archivos anteriores cuando los cambia.

**No es necesario mantener una carpeta `Hadoop/config/` en el repositorio**: la configuración se genera desde `setup_hadoop.sh` para cada usuario.

Si la instalación o Java están en otro lugar, se pueden indicar rutas personalizadas:

```bash
HADOOP_HOME="$HOME/otra_ruta/hadoop" HADOOP_JAVA_HOME="/ruta/a/java11" bash Hadoop/scripts/setup_hadoop.sh
```

> **Atención:** el configurador **no instala Hadoop, no formatea el NameNode y no inicia HDFS**. Si ya existe un HDFS con datos, verifica antes que las rutas de NameNode y DataNode coincidan con la instalación existente. Si vas a cambiar esas rutas, detén primero los servicios y revisa los datos presentes.

## 6. Inicializar el NameNode (solo instalaciones nuevas)

**Este paso se hace una sola vez, únicamente si el NameNode nunca ha sido formateado y no existen datos que preservar.**

```bash
hdfs namenode -format
```

**NO ejecutes de nuevo `hdfs namenode -format`** si HDFS ya funciona o contiene archivos. Formatear otra vez puede causar pérdida del acceso a los datos existentes.

Para comprobar si el directorio configurado ya está inicializado, revisa si existe:

```bash
test -f ~/hadoop_data/namenode/current/VERSION && echo "NameNode ya inicializado"
```

Si utilizaste `SMARTCITYCE_HDFS_DATA_DIR`, comprueba la ruta correspondiente en lugar de `~/hadoop_data`.

## 7. Iniciar los servicios y verificar HDFS

Desde la raíz del repositorio:

```bash
bash Hadoop/scripts/start_hadoop.sh
jps
hdfs dfsadmin -report
```

En un entorno de un solo nodo deberían aparecer los procesos `NameNode`, `DataNode` y `SecondaryNameNode` en `jps`. En el reporte busca `Live datanodes (1)`.

La interfaz web del NameNode se encuentra normalmente en:

<http://localhost:9870>

> Si `jps` no muestra los tres servicios, revisa los errores de `start-dfs.sh`, la conexión `ssh localhost` y los registros de Hadoop antes de continuar.

## 8. Prueba de escritura, lectura, descarga y eliminación

Desde una terminal donde `hdfs` esté disponible:

```bash
# Crear archivo de prueba local
printf 'SmartCityCE - Prueba de HDFS\n' > /tmp/smartcityce_test.txt

# Crear directorio y subir archivo a HDFS
hdfs dfs -mkdir -p /smartcityce/tests
hdfs dfs -put -f /tmp/smartcityce_test.txt /smartcityce/tests/

# Comprobar existencia y leer contenido
hdfs dfs -ls /smartcityce/tests/
hdfs dfs -cat /smartcityce/tests/smartcityce_test.txt

# Descargar y comprobar integridad
hdfs dfs -get -f /smartcityce/tests/smartcityce_test.txt /tmp/smartcityce_descargado.txt
cmp /tmp/smartcityce_test.txt /tmp/smartcityce_descargado.txt

# Eliminar solo el archivo de prueba
hdfs dfs -rm /smartcityce/tests/smartcityce_test.txt
```

Si `cmp` termina **sin mostrar diferencias**, el archivo descargado es idéntico al original. Se puede eliminar también `/smartcityce/tests` con `hdfs dfs -rmdir /smartcityce/tests` **si está vacío**.

## 9. Detener HDFS

Desde la raíz de SmartCityCE:

```bash
bash Hadoop/scripts/stop_hadoop.sh
```

Verificar el estado con:

```bash
jps
```

Los procesos de HDFS deberían haber terminado.

## 10. Problemas habituales

| Problema | Qué revisar |
|---|---|
| `hadoop: command not found` | Ejecutar `source ~/.bashrc` y comprobar `HADOOP_HOME` y `PATH`. |
| `Permission denied` al ejecutar un `.sh` | Usar `bash Hadoop/scripts/setup_hadoop.sh` o dar permiso con `chmod +x`. |
| SSH pide contraseña | Revisar `ssh localhost`, clave pública autorizada y permisos de `~/.ssh`. |
| `JAVA_HOME` incorrecto | Comprobar Java 11; si está en otra ruta, usar `HADOOP_JAVA_HOME`. |
| No aparece `DataNode` en `jps` | Consultar logs de Hadoop y revisar la configuración y los permisos de `~/hadoop_data/datanode`. |
| Fallo al contactar `localhost:9000` | Comprobar que `NameNode` está ejecutándose y que `fs.defaultFS` apunta a `hdfs://localhost:9000`. |
| Poco espacio disponible en HDFS | Revisar `hdfs dfsadmin -report` y el espacio libre real del disco (`df -h`). |

## 11. Resumen de comandos

Una vez que Java 11, Hadoop y SSH estén instalados, desde la raíz de SmartCityCE:

```bash
# Configurar Hadoop y HDFS
bash Hadoop/scripts/setup_hadoop.sh

# SOLO primera instalación y sin NameNode existente:
# hdfs namenode -format

# Iniciar HDFS
bash Hadoop/scripts/start_hadoop.sh

# Verificar servicios
jps
hdfs dfsadmin -report

# Detener al finalizar
bash Hadoop/scripts/stop_hadoop.sh
```

## 12. Continuación del proyecto

Con HDFS operativo, continuar con:

- **Issue #41:** preparar los datasets BDG2 y Open-Meteo en `/Hadoop/scripts`.
- **Issue #42:** cargar los datasets en HDFS y validar los archivos desde `/tests`.

**Referencias oficiales:**

- [Apache Hadoop 3.4.3 — Single Node Setup](https://hadoop.apache.org/docs/r3.4.3/hadoop-project-dist/hadoop-common/SingleCluster.html)
- [Apache Hadoop — Releases](https://hadoop.apache.org/releases.html)
