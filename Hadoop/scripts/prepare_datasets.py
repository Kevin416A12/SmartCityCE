#!/usr/bin/env python3
"""Prepara CSV de BDG2 Panther y Open-Meteo para HDFS sin modificar originales.

Uso desde la raiz del repositorio:
    python3 Hadoop/scripts/prepare_datasets.py

Salidas: data/processed/hadoop/{buildings,electricity,weather}.csv
Solo biblioteca estandar de Python. Se procesa electricidad fila a fila.
"""

import argparse
import csv
import math
import os
from collections import Counter
from datetime import datetime
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_METADATA = ROOT / "data/raw/bdg2/metadata/metadata.csv"
DEFAULT_METERS = ROOT / "data/raw/bdg2/meters/cleaned/electricity_cleaned.csv"
DEFAULT_WEATHER = ROOT / "data/raw/open_meteo/orlando_weather_2016_2017.csv"
DEFAULT_OUTPUT = ROOT / "data/processed/hadoop"

BUILDING_COLUMNS = ("building_id", "site_id", "primaryspaceusage", "sub_primaryspaceusage", "sqm", "timezone", "electricity")
WEATHER_COLUMNS = {
    "temperature_2m": "temperature_c",
    "relative_humidity_2m": "humidity_pct",
    "precipitation": "precipitation_mm",
    "cloud_cover_high": "cloud_cover_high_pct",
    "cloud_cover_mid": "cloud_cover_mid_pct",
    "cloud_cover_low": "cloud_cover_low_pct",
    "cloud_cover": "cloud_cover_pct",
    "wind_speed_10m": "wind_speed_kmh",
}


def require_columns(found, required, path):
    missing = set(required) - set(found or ())
    if missing:
        raise ValueError(f"{path}: faltan columnas: {', '.join(sorted(missing))}")


def timestamp(value):
    """Valida fechas sin convertirlas a UTC ni asumir equivalencias de husos."""
    raw = (value or "").strip()
    if not raw:
        return None
    try:
        parsed = datetime.fromisoformat(raw)
    except ValueError:
        return None
    if parsed.tzinfo is not None:
        # Evitar mezclar marcas con y sin offset sin regla documentada.
        return None
    return parsed.isoformat(sep=" ", timespec="seconds")


def numeric(value):
    raw = (value or "").strip()
    if not raw:
        return None
    try:
        number = float(raw)
    except ValueError:
        return None
    return raw if math.isfinite(number) else None


def create_temp(folder, filename):
    folder.mkdir(parents=True, exist_ok=True)
    fd, path = tempfile.mkstemp(prefix=f".{filename}.", suffix=".tmp", dir=folder, text=True)
    return os.fdopen(fd, "w", encoding="utf-8", newline=""), Path(path)


def prepare_buildings(src, output, site):
    counts = Counter()
    electric_ids = set()
    buildings = set()
    with src.open(encoding="utf-8-sig", newline="") as inf, output.open("w", encoding="utf-8", newline="") as outf:
        reader = csv.DictReader(inf)
        require_columns(reader.fieldnames, ("building_id", "site_id", "electricity"), src)
        writer = csv.writer(outf)
        writer.writerow(BUILDING_COLUMNS)
        for row in reader:
            counts["metadata_rows"] += 1
            if (row.get("site_id") or "").strip() != site:
                continue
            ident = (row.get("building_id") or "").strip()
            if not ident or ident in buildings:
                counts["metadata_blank_or_duplicate"] += 1
                continue
            buildings.add(ident)
            electricity = (row.get("electricity") or "").strip()
            if electricity.lower() == "yes":
                electric_ids.add(ident)
            writer.writerow([(row.get(c) or "").strip() for c in BUILDING_COLUMNS])
            counts["buildings"] += 1
    if not buildings:
        raise ValueError(f"No hay edificios con site_id={site!r} en {src}")
    if not electric_ids:
        raise ValueError(f"No hay edificios con electricity=Yes en site_id={site!r}")
    counts["buildings_electricity_yes"] = len(electric_ids)
    return electric_ids, counts


def prepare_electricity(src, output, electric_ids, max_hours):
    counts = Counter()
    with src.open(encoding="utf-8-sig", newline="") as inf, output.open("w", encoding="utf-8", newline="") as outf:
        reader = csv.DictReader(inf)
        require_columns(reader.fieldnames, ("timestamp",), src)
        selected = [c for c in reader.fieldnames if c in electric_ids]
        counts["selected_meter_columns"] = len(selected)
        counts["metadata_meters_absent_in_csv"] = len(electric_ids - set(selected))
        if not selected:
            raise ValueError("Ningun edificio con electricity=Yes coincide con las columnas de electricidad")
        writer = csv.writer(outf)
        writer.writerow(("timestamp", "building_id", "value"))
        for row in reader:
            if max_hours and counts["hours_read"] >= max_hours:
                break
            counts["hours_read"] += 1
            ts = timestamp(row.get("timestamp"))
            if ts is None:
                counts["invalid_timestamp_rows"] += 1
                continue
            for building_id in selected:
                value = numeric(row.get(building_id))
                if value is None:
                    counts["missing_or_invalid_values"] += 1
                    continue
                writer.writerow((ts, building_id, value))
                counts["electricity_rows"] += 1
    if not counts["electricity_rows"]:
        raise ValueError("No se generaron lecturas electricas validas")
    return counts


def weather_header_line(src):
    # Algunos CSV descargados desde Open-Meteo tienen encabezados de metadatos previos.
    with src.open(encoding="utf-8-sig", newline="") as inf:
        for index, line in enumerate(inf):
            if line.lstrip().startswith("time,"):
                return index
    raise ValueError(f"{src}: no se encontro encabezado que empiece con time,")


def match_weather_fields(fieldnames, src):
    chosen = {}
    for prefix, name in WEATHER_COLUMNS.items():
        matches = [c for c in fieldnames if c == prefix or c.startswith(prefix + " (")]
        if len(matches) != 1:
            raise ValueError(f"{src}: se esperaba una columna unica para {prefix}, encontradas {matches}")
        chosen[name] = matches[0]
    expected_units = {"temperature_c": "°C", "humidity_pct": "%", "precipitation_mm": "mm",
                      "cloud_cover_high_pct": "%", "cloud_cover_mid_pct": "%", "cloud_cover_low_pct": "%",
                      "cloud_cover_pct": "%", "wind_speed_kmh": "km/h"}
    for name, original in chosen.items():
        # Cabeceras sin unidad requieren comprobacion independiente (no se asume la unidad).
        if f"({expected_units[name]})" not in original:
            raise ValueError(f"{src}: unidad no verificada para {original!r} (se esperaba {expected_units[name]})")
    return chosen


def prepare_weather(src, output):
    counts = Counter()
    header_index = weather_header_line(src)
    with src.open(encoding="utf-8-sig", newline="") as inf, output.open("w", encoding="utf-8", newline="") as outf:
        for _ in range(header_index):
            next(inf)
        reader = csv.DictReader(inf)
        require_columns(reader.fieldnames, ("time",), src)
        mapped = match_weather_fields(reader.fieldnames, src)
        writer = csv.writer(outf)
        writer.writerow(("timestamp", *mapped.keys()))
        for row in reader:
            counts["weather_input_rows"] += 1
            ts = timestamp(row.get("time"))
            if ts is None:
                counts["weather_invalid_timestamps"] += 1
                continue
            vals = [numeric(row.get(source_col)) for source_col in mapped.values()]
            if any(val is None for val in vals):
                counts["weather_incomplete_rows"] += 1
                continue
            writer.writerow((ts, *vals))
            counts["weather_rows"] += 1
    if not counts["weather_rows"]:
        raise ValueError("No se generaron registros meteorologicos validos")
    return counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata", type=Path, default=DEFAULT_METADATA)
    parser.add_argument("--electricity", type=Path, default=DEFAULT_METERS)
    parser.add_argument("--weather", type=Path, default=DEFAULT_WEATHER)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--site", default="Panther")
    parser.add_argument("--max-hours", type=int, default=0, help="Prueba con N filas horarias de electricidad; 0=todas")
    args = parser.parse_args()
    if args.max_hours < 0:
        parser.error("--max-hours debe ser >= 0")
    for source in (args.metadata, args.electricity, args.weather):
        if not source.is_file():
            parser.error(f"No existe: {source}")
    if args.output.resolve() in {args.metadata.resolve().parent, args.electricity.resolve().parent, args.weather.resolve().parent}:
        parser.error("El directorio de salida no puede ser el de un dataset original")

    temporary = {}
    try:
        for name in ("buildings.csv", "electricity.csv", "weather.csv"):
            fh, temp_path = create_temp(args.output, name)
            fh.close()
            temporary[name] = temp_path
        electric_ids, buildings = prepare_buildings(args.metadata, temporary["buildings.csv"], args.site)
        electricity = prepare_electricity(args.electricity, temporary["electricity.csv"], electric_ids, args.max_hours)
        weather = prepare_weather(args.weather, temporary["weather.csv"])
        for name, temp_path in temporary.items():
            os.replace(temp_path, args.output / name)
    finally:
        for p in temporary.values():
            p.unlink(missing_ok=True)
    print("Preparacion finalizada. Salida:", args.output)
    for label, values in (("Metadatos", buildings), ("Electricidad", electricity), ("Clima", weather)):
        print(f"\n[{label}]")
        for key, val in sorted(values.items()):
            print(f"  {key}: {val:,}")
    print("\nNota: 'value' conserva la unidad original de BDG2; no se infiere kWh.")
    print("Las horas de ambas fuentes se conservan como horas locales sin conversion de zona horaria.")
    if args.max_hours:
        print("AVISO: resultado parcial por --max-hours. No usar para evaluar volumen final.")


if __name__ == "__main__":
    main()
