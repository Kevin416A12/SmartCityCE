#!/usr/bin/env python3
"""SmartCityCE: carga reproducible de BDG2 Panther y Open-Meteo.

Uso (desde la raíz del repo):
  python scripts/load_postgresql.py --phase metadata
  python scripts/load_postgresql.py --phase weather
  python scripts/load_postgresql.py --phase meters --meters-file data/raw/bdg2/meters/cleaned/electricity_cleaned.csv
  python scripts/load_postgresql.py --phase all --meters-file RUTA_CSV

Admite las dos variantes de esquema usadas en el proyecto; no crea tablas.
"""
import argparse
import csv
import logging
import os
from pathlib import Path

import pandas as pd
import psycopg2
from psycopg2.extras import execute_values
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
LOG = logging.getLogger('smartcityce.etl')


def existing_file(requested, candidates, label):
    if requested:
        path = Path(requested).expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f'{label} no existe: {path}')
        return path
    for candidate in candidates:
        p = ROOT / candidate
        if p.is_file():
            return p
    raise FileNotFoundError(f'No se encontró {label}. Indica su ruta con el argumento correspondiente.')


def columns(conn, table):
    with conn.cursor() as cur:
        cur.execute('''SELECT column_name FROM information_schema.columns
                       WHERE table_schema = 'public' AND table_name = %s''', (table,))
        result = {name for (name,) in cur.fetchall()}
    if not result:
        raise RuntimeError(f'Falta la tabla public.{table}. Ejecuta SQL/01_schema.sql primero.')
    return result


def column(cols, choices, table, required=True):
    match = next((c for c in choices if c in cols), None)
    if match is None and required:
        raise RuntimeError(f'{table}: esperaba una columna entre {choices}; encontradas: {sorted(cols)}')
    return match


def number(v):
    if pd.isna(v) or str(v).strip() == '':
        return None
    try:
        return float(v)
    except (ValueError, TypeError):
        return None


def integer(v):
    n = number(v)
    return int(n) if n is not None else None


def connect():
    load_dotenv(ROOT / '.env')
    return psycopg2.connect(host=os.getenv('DB_HOST', 'localhost'),
                            port=os.getenv('DB_PORT', '5432'),
                            dbname=os.getenv('DB_NAME', 'smartcityce'),
                            user=os.getenv('DB_USER', 'smartcity'),
                            password=os.getenv('DB_PASSWORD'),
                            connect_timeout=10)


def get_location(conn, site='Panther', lat=None, lon=None, tz=None):
    cols = columns(conn, 'ubicacion')
    with conn.cursor() as cur:
        cur.execute('SELECT id_ubicacion FROM ubicacion WHERE nombre_zona = %s ORDER BY id_ubicacion LIMIT 1', (site,))
        found = cur.fetchone()
        if found:
            return found[0]
        values = {'nombre_zona': site}
        if lat is not None and lon is not None:
            values.update(latitud=lat, longitud=lon)
        if 'zona_horaria' in cols and tz:
            values['zona_horaria'] = tz
        keys = list(values)
        cur.execute(f"INSERT INTO ubicacion ({', '.join(keys)}) VALUES ({', '.join(['%s'] * len(keys))}) RETURNING id_ubicacion", tuple(values.values()))
        return cur.fetchone()[0]


def category_id(conn):
    cols = columns(conn, 'categoria_sensor')
    with conn.cursor() as cur:
        cur.execute('SELECT id_categoria FROM categoria_sensor WHERE nombre_categoria = %s', ('Electricidad',))
        found = cur.fetchone()
        if found:
            return found[0]
        if 'unidad_base' in cols:
            cur.execute("INSERT INTO categoria_sensor (nombre_categoria, unidad_base) VALUES (%s, %s) RETURNING id_categoria", ('Electricidad', 'kWh'))
        else:
            cur.execute('INSERT INTO categoria_sensor (nombre_categoria) VALUES (%s) RETURNING id_categoria', ('Electricidad',))
        return cur.fetchone()[0]


def load_metadata(conn, path, site):
    LOG.info('Leyendo metadatos: %s', path)
    frame = pd.read_csv(path, low_memory=False)
    frame.columns = frame.columns.str.strip()
    needed = {'building_id', 'site_id'}
    if not needed <= set(frame.columns):
        raise ValueError(f'Metadata sin columnas {needed - set(frame.columns)}')
    data = frame[frame.site_id.astype(str).str.strip().eq(site)].copy()
    data = data[data.building_id.notna()].drop_duplicates('building_id')
    if data.empty:
        raise ValueError(f'No se encontraron edificios para el sitio {site!r}')
    ec, sc = columns(conn, 'edificio'), columns(conn, 'sensor')
    area_col = column(ec, ['superficie_m2', 'superficie'], 'edificio')
    floor_col = 'numero_pisos' if 'numero_pisos' in ec else None
    sub_col = 'subuso' if 'subuso' in ec else None
    tipo_col = 'tipo_sensor' if 'tipo_sensor' in sc else None
    ident_col = 'identificador_fuente' if 'identificador_fuente' in sc else None
    # Una única ubicación para Panther; las coordenadas son del sitio.
    first = data.iloc[0]
    loc = get_location(conn, site, number(first.get('lat')), number(first.get('lng')), first.get('timezone'))
    cat = category_id(conn)
    buildings = sensors = 0
    with conn.cursor() as cur:
        for row in data.to_dict('records'):
            building = str(row['building_id']).strip()
            if not building:
                continue
            vals = {'id_edificio': building, 'id_ubicacion': loc,
                    'uso_principal': None if pd.isna(row.get('primaryspaceusage')) else str(row.get('primaryspaceusage')),
                    area_col: number(row.get('sqm')),
                    'anio_construccion': integer(row.get('yearbuilt'))}
            if sub_col:
                vals[sub_col] = None if pd.isna(row.get('sub_primaryspaceusage')) else str(row.get('sub_primaryspaceusage'))
            if floor_col:
                vals[floor_col] = integer(row.get('numberoffloors'))
            keys = list(vals)
            # Actualiza campos de metadatos al reejecutar, no duplica edificios.
            updates = ', '.join(f'{k}=EXCLUDED.{k}' for k in keys if k != 'id_edificio')
            cur.execute(f"INSERT INTO edificio ({', '.join(keys)}) VALUES ({', '.join(['%s']*len(keys))}) ON CONFLICT (id_edificio) DO UPDATE SET {updates}", tuple(vals.values()))
            buildings += 1
            # Crear sensor solo si BDG2 indica medidor eléctrico disponible.
            if str(row.get('electricity', '')).strip().lower() != 'yes':
                continue
            cur.execute('SELECT id_sensor FROM sensor WHERE nombre = %s ORDER BY id_sensor LIMIT 1', (building,))
            if cur.fetchone():
                continue
            sv = {'nombre': building, 'id_categoria': cat, 'id_edificio': building}
            if tipo_col:
                sv[tipo_col] = 'medidor_electrico'
            if ident_col:
                sv[ident_col] = building
            if 'estado' in sc and 'tipo_sensor' not in sc:
                sv['estado'] = 'desconocido'
            keys = list(sv)
            cur.execute(f"INSERT INTO sensor ({', '.join(keys)}) VALUES ({', '.join(['%s']*len(keys))})", tuple(sv.values()))
            sensors += 1
    conn.commit()
    LOG.info('Metadatos: %d edificios procesados, %d sensores nuevos.', buildings, sensors)


def weather_header(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        for i, line in enumerate(f):
            if line.lstrip().startswith('time,'):
                return i
    raise ValueError('Open-Meteo: no encontré la fila de encabezados que comienza con time,')


def weather_column(header, prefix):
    return next((x for x in header if x.startswith(prefix)), None)


def load_weather(conn, path, site):
    LOG.info('Leyendo clima: %s', path)
    wc = columns(conn, 'registro_meteorologico')
    names = {'temperatura': column(wc, ['temperatura_c', 'temperatura'], 'registro_meteorologico'),
             'humedad': column(wc, ['humedad_relativa_pct', 'humedad_relativa'], 'registro_meteorologico'),
             'precipitacion': column(wc, ['precipitacion_mm', 'precipitacion'], 'registro_meteorologico'),
             'nubosidad': column(wc, ['nubosidad_pct', 'nubosidad'], 'registro_meteorologico'),
             'viento': column(wc, ['viento_kmh', 'velocidad_viento'], 'registro_meteorologico')}
    skip = weather_header(path)
    head = pd.read_csv(path, skiprows=skip, nrows=0).columns.tolist()
    src = {'temperatura': weather_column(head, 'temperature_2m'),
           'humedad': weather_column(head, 'relative_humidity_2m'),
           'precipitacion': weather_column(head, 'precipitation'),
           'nubosidad': weather_column(head, 'cloud_cover'),
           'viento': weather_column(head, 'wind_speed_10m')}
    if any(v is None for v in src.values()):
        raise ValueError(f'Faltan variables meteorológicas: {[k for k,v in src.items() if v is None]}. Encabezados: {head}')
    loc = get_location(conn, site)
    # Los CSV Open-Meteo descargados son horarios locales sin offset, igual que el esquema.
    with conn.cursor() as cur:
        cur.execute('SELECT fecha_hora FROM registro_meteorologico WHERE id_ubicacion=%s', (loc,))
        existing = {r[0] for r in cur.fetchall()}
        cols = ['id_ubicacion', 'fecha_hora'] + [names[k] for k in src]
        inserted = 0
        for block in pd.read_csv(path, skiprows=skip, chunksize=3000):
            rows = []
            for r in block.to_dict('records'):
                dt = pd.to_datetime(r.get('time'), errors='coerce')
                if pd.isna(dt) or dt.to_pydatetime() in existing:
                    continue
                vals = [loc, dt.to_pydatetime()]
                vals += [number(r[src[key]]) for key in src]
                rows.append(tuple(vals))
            if rows:
                execute_values(cur, f"INSERT INTO registro_meteorologico ({', '.join(cols)}) VALUES %s", rows, page_size=1000)
                existing.update(row[1] for row in rows)
                inserted += len(rows)
                conn.commit()
    conn.commit()
    LOG.info('Clima: %d nuevos registros.', inserted)


def load_meters(conn, path, site, max_rows=0):
    LOG.info('Leyendo medidores: %s', path)
    lc = columns(conn, 'lectura_sql')
    has_fuente = 'fuente' in lc
    has_unidad = 'unidad' in lc
    if not (has_fuente or has_unidad):
        raise RuntimeError('lectura_sql: no encuentro fuente ni unidad; revisa tu esquema.')
    with conn.cursor() as cur:
        cur.execute('SELECT id_sensor, nombre FROM sensor WHERE nombre LIKE %s', (site + '_%',))
        sensors = {name: ident for ident, name in cur.fetchall()}
    if not sensors:
        raise RuntimeError('No hay sensores de Panther. Ejecuta primero --phase metadata.')
    # Sólo se procesan sensores previamente validados en metadata (electricity=Yes).
    header = pd.read_csv(path, nrows=0).columns.str.strip().tolist()
    time_col = 'timestamp' if 'timestamp' in header else ('time' if 'time' in header else None)
    if not time_col:
        raise ValueError(f'CSV de medidores sin timestamp/time: {header[:5]}')
    wanted = [x for x in header if x in sensors]
    if not wanted:
        raise ValueError(f'No hay columnas de sensores de {site!r} en {path.name}')
    LOG.info('%d sensores eléctricos de %s presentes en el CSV.', len(wanted), site)
    keys = ['id_sensor', 'fecha_hora', 'valor', 'fuente' if has_fuente else 'unidad']
    # Esquema normalizado sin UNIQUE: prevenir duplicados explícitamente.
    # El esquema alternativo tiene UNIQUE(id_sensor,fecha_hora).
    with conn.cursor() as cur:
        cur.execute('''SELECT COUNT(*) FROM pg_constraint WHERE conrelid='public.lectura_sql'::regclass AND contype='u' ''')
        has_unique = cur.fetchone()[0] > 0
    processed = inserted = 0
    for block in pd.read_csv(path, usecols=[time_col] + wanted, chunksize=240, low_memory=False):
        if max_rows and processed >= max_rows:
            break
        if max_rows:
            block = block.head(max_rows-processed)
        block[time_col] = pd.to_datetime(block[time_col], errors='coerce')
        tidy = block.melt(id_vars=time_col, value_vars=wanted, var_name='sensor', value_name='valor')
        tidy = tidy.dropna(subset=[time_col, 'valor'])
        tidy['valor'] = pd.to_numeric(tidy.valor, errors='coerce')
        tidy = tidy.dropna(subset=['valor'])
        values = [(sensors[s], dt.to_pydatetime(), float(v), 'BDG2' if has_fuente else 'kWh')
                  for dt, s, v in tidy[[time_col, 'sensor', 'valor']].itertuples(index=False, name=None)]
        with conn.cursor() as cur:
            if has_unique:
                execute_values(cur, f"INSERT INTO lectura_sql ({', '.join(keys)}) VALUES %s ON CONFLICT (id_sensor, fecha_hora) DO NOTHING", values, page_size=1000) if values else None
            else:
                # Optimización para reejecuciones sin constraint UNIQUE.
                existing = set()
                if values:
                    ids = list({r[0] for r in values})
                    lo = min(r[1] for r in values)
                    hi = max(r[1] for r in values)
                    cur.execute('SELECT id_sensor, fecha_hora FROM lectura_sql WHERE id_sensor=ANY(%s) AND fecha_hora BETWEEN %s AND %s', (ids, lo, hi))
                    existing = set(cur.fetchall())
                values = [r for r in values if (r[0], r[1]) not in existing]
                if values:
                    execute_values(cur, f"INSERT INTO lectura_sql ({', '.join(keys)}) VALUES %s", values, page_size=1000)
            inserted += len(values)
        conn.commit()
        processed += len(block)
        if processed % 2400 == 0:
            LOG.info('Horas CSV procesadas: %s; lecturas candidatas insertadas: %s', processed, inserted)
    LOG.info('Medidores: %d horas CSV procesadas, hasta %d lecturas nuevas.', processed, inserted)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--phase', choices=['metadata', 'weather', 'meters', 'all'], default='metadata')
    parser.add_argument('--site', default='Panther', help='Site BDG2 (predeterminado: Panther)')
    parser.add_argument('--metadata-file', help='Ruta a metadata.csv')
    parser.add_argument('--weather-file', help='Ruta al CSV histórico de Open-Meteo')
    parser.add_argument('--meters-file', help='Ruta al CSV ancho de medidores de electricidad')
    parser.add_argument('--max-meter-rows', type=int, default=0, help='Limitar horas para prueba; 0=todo')
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
    with connect() as conn:
        try:
            if args.phase in ('metadata', 'all'):
                metadata = existing_file(args.metadata_file, ['data/raw/bdg2/metadata/metadata.csv', 'data/raw/bdg2/metadata.csv'], 'metadata.csv')
                load_metadata(conn, metadata, args.site)
            if args.phase in ('weather', 'all'):
                weather = existing_file(args.weather_file, ['data/raw/open_meteo/orlando_weather_2016_2017.csv', 'data/raw/open_meteo/open-meteo-28.51N81.40W35m.csv'], 'CSV Open-Meteo')
                load_weather(conn, weather, args.site)
            if args.phase in ('meters', 'all'):
                meter = existing_file(args.meters_file, ['data/raw/bdg2/meters/cleaned/electricity_cleaned.csv', 'data/raw/bdg2/meters/cleaned/electricity.csv'], 'CSV de electricidad')
                load_meters(conn, meter, args.site, args.max_meter_rows)
        except Exception:
            conn.rollback()
            raise
    LOG.info('ETL completado.')


if __name__ == '__main__':
    main()
