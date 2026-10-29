<div align="center">

# SmartCityCE
### Sistema de Gestión y Análisis de Datos para Ciudades Inteligentes

**Instituto Tecnológico de Costa Rica**  
**Escuela de Ingeniería en Computadores**  
**CE-3101 — Bases de Datos**

**II Semestre, 2026**

Kevin Castro Pérez - 2024182200
Evans Corrales Valverde - 2024182013
Luis Adrián Prendas Arias - 2023147608
Yerik Jaslin Castro - 2024231163


GitHub: https://github.com/Kevin416A12/SmartCityCE
---

**Proyecto académico — SmartCityCE**

*Plataforma de almacenamiento, procesamiento y análisis de datos energéticos y meteorológicos.*

</div>

---

## Introducción

**SmartCityCE** es un proyecto académico desarrollado para el curso **CE-3101 — Bases de Datos** del Instituto Tecnológico de Costa Rica. El objetivo es implementar una plataforma de gestión y análisis de información orientada al concepto de ciudades inteligentes (*Smart Cities*).

El proyecto utiliza datos históricos de consumo eléctrico de edificios y registros meteorológicos para estudiar patrones de consumo energético y su relación con las condiciones ambientales.

Para ello, se integran diferentes tecnologías de almacenamiento y procesamiento de datos, incluyendo **PostgreSQL, MongoDB, Apache Hadoop y Apache Spark**, permitiendo trabajar con información estructurada, semiestructurada y grandes volúmenes de datos.

Las principales fuentes de información son:

- **Building Data Genome 2 (BDG2):** conjunto de datos históricos sobre el consumo energético de edificios.
- **Open-Meteo:** registros meteorológicos históricos utilizados para complementar el análisis energético.

El sistema busca demostrar las capacidades y diferencias de distintas tecnologías de bases de datos, así como su aplicación en escenarios de almacenamiento, consulta y procesamiento de información a gran escala.

## Tecnologías utilizadas

| Tecnología | Propósito |
|---|---|
| PostgreSQL | Almacenamiento de datos estructurados y relaciones entre entidades. |
| MongoDB | Almacenamiento de documentos y registros de mediciones. |
| Apache Hadoop | Almacenamiento y procesamiento distribuido de datos. |
| Apache Spark | Procesamiento y análisis de grandes volúmenes de información. |
| Python | Extracción, transformación y carga de datos (ETL). |
| Git y GitHub | Control de versiones y colaboración. |

## Estructura del repositorio

```text
SmartCityCE/
├── SQL/              # Scripts de PostgreSQL
├── MongoDB/          # Implementación de MongoDB
├── Hadoop/           # Archivos de Hadoop
├── Spark/            # Procesamiento con Spark
├── data/             # Datasets originales y procesados
├── docs/             # Documentación del proyecto
├── scripts/          # Scripts de configuración y ETL
├── tests/            # Pruebas automatizadas
├── requirements.txt  # Dependencias de Python
└── README.md
```

## Instalación y configuración

Para configurar el entorno de desarrollo, instalar PostgreSQL, descargar los datasets, cargar los datos y ejecutar las pruebas, consulta la siguiente documentación:

**[Guía de instalación y configuración de SmartCityCE](guia_instalacion.md)**

## Datos del proyecto

La implementación de PostgreSQL utiliza información histórica correspondiente al período **2016–2017**.

Durante las pruebas de carga se obtuvieron los siguientes resultados:

| Información | Cantidad |
|---|---:|
| Edificios | 136 |
| Sensores eléctricos | 105 |
| Lecturas eléctricas | 1.817.156 |
| Registros meteorológicos | 17.544 |

Estos datos permiten realizar consultas y análisis sobre el comportamiento del consumo energético y las condiciones meteorológicas.

---

<div align="center">

**SmartCityCE — CE-3101 Bases de Datos**

Instituto Tecnológico de Costa Rica · 2026

</div>
