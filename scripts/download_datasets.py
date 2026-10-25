#!/usr/bin/env python3
"""Descarga datasets de SmartCityCE. Solo biblioteca estándar de Python."""
import argparse
import csv
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import sys
import tempfile
import time
from urllib.parse import urlencode
from urllib.request import Request, urlopen
import zipfile

ZENODO_API = 'https://zenodo.org/api/records/3887306'
GITHUB_ZIP = 'https://github.com/buds-lab/building-data-genome-project-2/archive/refs/heads/master.zip'
OPEN_METEO_API = 'https://archive-api.open-meteo.com/v1/archive'
VARIABLES = ['temperature_2m', 'relative_humidity_2m', 'precipitation', 'cloud_cover', 'wind_speed_10m']


def request(url, *, timeout=120):
    return urlopen(Request(url, headers={'User-Agent': 'SmartCityCE-dataset-downloader/1.0'}), timeout=timeout)


def get_json(url):
    with request(url) as response:
        return json.load(response)


def download(url, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + '.part')
    for attempt in range(3):
        try:
            with request(url, timeout=180) as response, temporary.open('wb') as output:
                shutil.copyfileobj(response, output, length=1024 * 1024)
            temporary.replace(destination)
            return
        except Exception:
            temporary.unlink(missing_ok=True)
            if attempt == 2:
                raise
            time.sleep(attempt + 1)


def zenodo_archive():
    record = get_json(ZENODO_API)
    files = record.get('files', [])
    candidates = [f for f in files if str(f.get('key', '')).lower().endswith('.zip')]
    if not candidates:
        available = ', '.join(f.get('key', '?') for f in files)
        raise RuntimeError(f'El registro de Zenodo no publica un ZIP. Archivos disponibles: {available}')
    preferred = [f for f in candidates if 'building-data-genome' in f.get('key', '').lower()]
    selected = (preferred or candidates)[0]
    links = selected.get('links', {})
    url = links.get('self') or links.get('download')
    if not url:
        raise RuntimeError('No se encontró enlace de descarga en Zenodo.')
    return url, selected.get('key', 'bdg2.zip')


def relative_data_path(name):
    """Restringe extracción a data/{metadata,meters,weather} de BDG2."""
    parts = PurePosixPath(name).parts
    if '..' in parts or name.startswith('/') or '\\' in name:
        return None
    try:
        idx = parts.index('data')
    except ValueError:
        return None
    rest = parts[idx + 1:]
    if len(rest) < 2 or rest[0] not in {'metadata', 'meters', 'weather'}:
        return None
    return Path(*rest)


def extract_bdg2(archive, destination, *, force=False):
    count = 0
    with zipfile.ZipFile(archive) as zf:
        for entry in zf.infolist():
            relative = relative_data_path(entry.filename)
            if relative is None or entry.is_dir():
                continue
            target = destination / relative
            if target.exists() and not force:
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(entry) as src, target.open('wb') as dst:
                shutil.copyfileobj(src, dst)
            count += 1
    if count == 0 and not any(destination.rglob('*.csv')):
        raise RuntimeError('No se encontraron archivos de datos BDG2 dentro del ZIP.')
    return count


def bdg2(root, source, force):
    dest = root / 'data' / 'raw' / 'bdg2'
    if dest.exists() and any(dest.rglob('*.csv')) and not force:
        print('[BDG2] Hay CSV existentes; se conservarán. Usa --force para volver a descargarlos.')
        return
    if source == 'zenodo':
        url, filename = zenodo_archive()
    else:
        url, filename = GITHUB_ZIP, 'bdg2-master.zip'
    print(f'[BDG2] Descargando {filename} ... (puede ser grande)')
    with tempfile.TemporaryDirectory(prefix='smartcityce_') as temp:
        archive = Path(temp) / 'bdg2.zip'
        download(url, archive)
        if not zipfile.is_zipfile(archive):
            raise RuntimeError('La descarga BDG2 no es un ZIP válido.')
        count = extract_bdg2(archive, dest, force=force)
    print(f'[BDG2] Listo: {count} archivos extraídos en {dest}')


def open_meteo(root, force, latitude, longitude, timezone):
    dest = root / 'data' / 'raw' / 'open_meteo' / 'orlando_weather_2016_2017.csv'
    if dest.exists() and not force:
        print(f'[Open-Meteo] Ya existe {dest}; se conserva (usa --force para sobrescribir).')
        return
    params = {
        'latitude': latitude, 'longitude': longitude,
        'start_date': '2016-01-01', 'end_date': '2017-12-31',
        'hourly': ','.join(VARIABLES), 'timezone': timezone,
        'models': 'era5',
    }
    print('[Open-Meteo] Descargando mediciones horarias 2016–2017 ...')
    obj = get_json(OPEN_METEO_API + '?' + urlencode(params))
    hourly = obj.get('hourly') or {}
    timestamps = hourly.get('time') or []
    if not timestamps:
        raise RuntimeError('Open-Meteo no devolvió mediciones horarias.')
    for variable in VARIABLES:
        if len(hourly.get(variable, [])) != len(timestamps):
            raise RuntimeError(f'Respuesta incompleta de Open-Meteo para {variable}.')
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix('.csv.part')
    with tmp.open('w', newline='', encoding='utf-8') as fh:
        writer = csv.writer(fh)
        writer.writerow(['time', *VARIABLES])
        for idx, timestamp in enumerate(timestamps):
            writer.writerow([timestamp, *[hourly[v][idx] for v in VARIABLES]])
    tmp.replace(dest)
    info = dest.with_suffix('.json')
    info.write_text(json.dumps({
        'source': OPEN_METEO_API, 'query': params,
        'returned_latitude': obj.get('latitude'),
        'returned_longitude': obj.get('longitude'),
        'timezone': obj.get('timezone'),
        'units': obj.get('hourly_units'),
        'rows': len(timestamps),
        'note': 'Coordenadas aproximadas de la zona Panther; no representan cada edificio. Revisar alineación horaria antes de cruzar con BDG2.'
    }, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f'[Open-Meteo] Listo: {len(timestamps)} filas en {dest}')


def main():
    ap = argparse.ArgumentParser(description='Descarga datasets del proyecto SmartCityCE')
    ap.add_argument('--dataset', choices=['all', 'bdg2', 'open-meteo'], default='all', help='Fuentes a descargar')
    ap.add_argument('--source', choices=['zenodo', 'github'], default='zenodo', help='Fuente del archivo BDG2')
    ap.add_argument('--force', action='store_true', help='Sobrescribir archivos existentes')
    ap.add_argument('--latitude', type=float, default=28.51, help='Latitud de Open-Meteo (zona Panther)')
    ap.add_argument('--longitude', type=float, default=-81.40, help='Longitud de Open-Meteo (zona Panther)')
    ap.add_argument('--timezone', default='America/New_York', help='Huso horario de Open-Meteo')
    args = ap.parse_args()
    root = Path(__file__).resolve().parent.parent
    try:
        if args.dataset in ('all', 'bdg2'):
            bdg2(root, args.source, args.force)
        if args.dataset in ('all', 'open-meteo'):
            open_meteo(root, args.force, args.latitude, args.longitude, args.timezone)
    except Exception as e:
        print(f'ERROR: {e}', file=sys.stderr)
        return 1
    print('Descargas completadas.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
