#!/usr/bin/env python3
"""
Carga lecturas eléctricas de Building Data Genome Project 2 (BDG2)
en MongoDB.

Fuente de lecturas:
    data/raw/bdg2/meters/cleaned/electricity_cleaned.csv

Fuente de metadatos:
    data/raw/bdg2/metadata/metadata.csv
"""

import argparse
import csv
import os
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

from dotenv import load_dotenv
from pymongo import MongoClient


# Rutas del proyecto

ROOT = Path(__file__).resolve().parent.parent

LECTURAS_CSV = (
    ROOT
    / "data"
    / "raw"
    / "bdg2"
    / "meters"
    / "cleaned"
    / "electricity_cleaned.csv"
)

METADATA_CSV = (
    ROOT
    / "data"
    / "raw"
    / "bdg2"
    / "metadata"
    / "metadata.csv"
)


# Funciones auxiliares

def cargar_metadatos():
    """
    Carga los metadatos de BDG2 utilizando building_id como clave.
    """

    metadatos = {}

    with METADATA_CSV.open(encoding="utf-8") as archivo:
        lector = csv.DictReader(archivo)

        for fila in lector:
            metadatos[fila["building_id"]] = fila

    return metadatos


def convertir_float(valor):
    """
    Convierte un valor de texto a float.

    Retorna None si el valor está vacío o no puede convertirse.
    """

    if valor is None or valor.strip() == "":
        return None

    try:
        return float(valor)
    except ValueError:
        return None


def convertir_fecha_utc(fecha_local, nombre_zona):
    """
    Interpreta una fecha de BDG2 en la zona horaria correspondiente
    al sitio y la convierte a UTC.

    MongoDB almacena los BSON Date internamente en UTC.
    """

    if not nombre_zona:
        raise ValueError(
            "No se encontró zona horaria para la lectura."
        )

    zona_local = ZoneInfo(nombre_zona)

    fecha_con_zona = fecha_local.replace(
        tzinfo=zona_local
    )

    return fecha_con_zona.astimezone(timezone.utc)


def crear_documento(
    id_sensor,
    fecha_local,
    valor,
    metadata,
):
    """
    Construye un documento de lectura según el modelo documental
    definido para SmartCityCE.
    """

    latitud = convertir_float(metadata.get("lat"))
    longitud = convertir_float(metadata.get("lng"))

    zona_horaria = metadata.get("timezone")

    # Convertir la fecha local del sitio a UTC.
    fecha_utc = convertir_fecha_utc(
        fecha_local,
        zona_horaria,
    )

    # El site_id real de BDG2 se utiliza como zona lógica.
    ubicacion = {
        "id_ubicacion": metadata.get("site_id"),
        "zona": metadata.get("site_id"),
    }

    # Solo se almacenan coordenadas cuando realmente existen
    # en metadata.csv.
    if latitud is not None and longitud is not None:
        ubicacion["coordenadas"] = {
            "latitud": latitud,
            "longitud": longitud,
        }

    return {
        "id_sensor": id_sensor,

        # BSON Date almacenado correctamente en UTC.
        "fecha_hora": fecha_utc,

        "medicion": {
            "valor": valor,
            "unidad": "kWh_sum",
        },

        "ubicacion": ubicacion,

        "sensor": {
            "tipo": "energia",
            "categoria": "consumo_electrico",
            "uso_primario": metadata.get(
                "primaryspaceusage"
            ),
        },

        "metadatos": {
            "fuente": "BDG2",
            "calidad": "limpio",
            "zona_horaria_origen": zona_horaria,
        },
    }


# Carga principal

def cargar_lecturas(limite, tamano_lote, reiniciar):
    """
    Transforma las lecturas del CSV e inserta los documentos
    en MongoDB por lotes.
    """----
    # Configuració----

    load_dotenv(ROOT / ".env")

    usuario = os.getenv("MONGO_ROOT_USER")
    password = os.getenv("MONGO_ROOT_PASSWORD")
    puerto = os.getenv("MONGO_PORT", "27017")
    nombre_bd = os.getenv(
        "MONGO_DATABASE",
        "smartcityce",
    )

    if not usuario or not password:
        raise RuntimeError(
            "Faltan MONGO_ROOT_USER o "
            "MONGO_ROOT_PASSWORD en .env"
        )----
    # Verificación de archivo----

    if not LECTURAS_CSV.exists():
        raise FileNotFoundError(
            f"No se encontró el archivo de lecturas: "
            f"{LECTURAS_CSV}"
        )

    if not METADATA_CSV.exists():
        raise FileNotFoundError(
            f"No se encontró el archivo de metadatos: "
            f"{METADATA_CSV}"
        )----
    # Conexión con MongoD----

    uri = (
        f"mongodb://{usuario}:{password}"
        f"@localhost:{puerto}/?authSource=admin"
    )

    cliente = MongoClient(uri)

    cliente.admin.command("ping")

    bd = cliente[nombre_bd]
    coleccion = bd["lecturas"]

    print("Conectado a MongoDB.")
    print(f"Base de datos: {nombre_bd}")
    print("Colección: lecturas")----
    # Reinicio opciona----

    if reiniciar:
        coleccion.drop()
        print("Colección 'lecturas' reiniciada.")----
    # Metadato----

    metadatos = cargar_metadatos()

    print(
        f"Metadatos disponibles: "
        f"{len(metadatos):,}"
    )----
    # Procesamient----

    insertados = 0
    omitidos = 0
    lote = []

    try:
        with LECTURAS_CSV.open(
            encoding="utf-8"
        ) as archivo:

            lector = csv.reader(archivo)

            encabezado = next(lector)

            # Primera columna = timestamp.
            # Resto = sensores/edificios.
            sensores = encabezado[1:]

            print(
                f"Sensores encontrados: "
                f"{len(sensores):,}"
            )

            for fila in lector:

                # BDG2 proporciona el timestamp en la hora
                # local correspondiente al sitio.
                fecha_local = datetime.strptime(
                    fila[0],
                    "%Y-%m-%d %H:%M:%S",
                )

                for indice, valor_texto in enumerate(
                    fila[1:]
                ):

                    valor = convertir_float(
                        valor_texto
                    )

                    # Las celdas vacías se omiten.
                    if valor is None:
                        omitidos += 1
                        continue

                    id_sensor = sensores[indice]

                    info_sensor = metadatos.get(
                        id_sensor
                    )

                    if info_sensor is None:
                        omitidos += 1
                        continue

                    documento = crear_documento(
                        id_sensor=id_sensor,
                        fecha_local=fecha_local,
                        valor=valor,
                        metadata=info_sensor,
                    )

                    lote.append(documento)

                    # Inserción por lotes

                    if len(lote) >= tamano_lote:

                        coleccion.insert_many(
                            lote,
                            ordered=False,
                        )

                        insertados += len(lote)
                        lote.clear()

                        print(
                            "Documentos insertados: "
                            f"{insertados:,}"
                        )

                    # Límite solicitado

                    if (
                        limite is not None
                        and insertados + len(lote)
                        >= limite
                    ):
                        break

                if (
                    limite is not None
                    and insertados + len(lote)
                    >= limite
                ):
                    break

        # Último lote

        if lote:

            if limite is not None:
                restantes = limite - insertados
                lote = lote[:restantes]

            if lote:
                coleccion.insert_many(
                    lote,
                    ordered=False,
                )

                insertados += len(lote)

        # Resultado

        print()
        print("Carga finalizada.")
        print(
            f"Documentos insertados: "
            f"{insertados:,}"
        )
        print(
            f"Valores omitidos: "
            f"{omitidos:,}"
        )

    finally:
        cliente.close()


# Argumentos

def main():

    parser = argparse.ArgumentParser(
        description=(
            "Carga lecturas eléctricas de BDG2 "
            "en MongoDB."
        )
    )

    parser.add_argument(
        "--limite",
        type=int,
        default=None,
        help=(
            "Cantidad máxima de documentos a insertar. "
            "Si se omite, se procesan todas las lecturas."
        ),
    )

    parser.add_argument(
        "--lote",
        type=int,
        default=5000,
        help=(
            "Cantidad de documentos insertados "
            "por lote (predeterminado: 5000)."
        ),
    )

    parser.add_argument(
        "--reiniciar",
        action="store_true",
        help=(
            "Elimina la colección 'lecturas' "
            "antes de iniciar la carga."
        ),
    )

    args = parser.parse_args()

    if (
        args.limite is not None
        and args.limite <= 0
    ):
        parser.error(
            "--limite debe ser mayor que 0."
        )

    if args.lote <= 0:
        parser.error(
            "--lote debe ser mayor que 0."
        )

    cargar_lecturas(
        limite=args.limite,
        tamano_lote=args.lote,
        reiniciar=args.reiniciar,
    )


if __name__ == "__main__":
    main()