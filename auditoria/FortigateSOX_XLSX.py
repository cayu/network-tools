#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FortigateSOX_XLSX.py

Toma como entrada un archivo de configuración completo de FortiGate (.conf)
y genera un Excel (.xlsx) estructurado para auditorías CIS/NIST/ISO27001.

Incluye:
  - Hoja "Índice" con hipervínculos a cada sección.
  - Pestañas por sección crítica:
      • Información General
      • Usuarios Administrativos
      • Interfaces de Red
      • Configuración NTP
      • Objetos de Dirección
      • Servicios de Firewall
      • Políticas de Firewall
      • NAT - VIPs
      • NAT - IP Pools
      • Rutas Estáticas
      • VPN IPsec Phase1
      • VPN IPsec Phase2

Cada hoja usa un Excel Table con estilo, bordes y filas alternadas.

Uso:
    python3 fortisox_excel.py <entrada.conf> <salida.xlsx>

Requiere:
    pip install pandas xlsxwriter
"""
import sys, os, re
import pandas as pd
from datetime import datetime
from xlsxwriter.utility import xl_range

# -----------------------------
# Funciones de parsing
# -----------------------------

def agrupa_secciones(lines):
    secciones = {}
    contador = {}
    current = None
    for raw in lines:
        line = raw.strip()
        m = re.match(r'^config\s+(.+)$', line, re.IGNORECASE)
        if m:
            name = m.group(1).strip().lower()
            contador[name] = contador.get(name, 0) + 1
            key = f"{name}__{contador[name]}" if contador[name] > 1 else name
            secciones[key] = []
            current = key
        elif re.match(r'^end$', line, re.IGNORECASE):
            current = None
        elif current:
            secciones[current].append(line)
    return secciones


def parsear_objetos(lines):
    objs = {}
    current = None
    for line in lines:
        m = re.match(r'^edit\s+"?(.+?)"?$', line, re.IGNORECASE)
        if m:
            current = m.group(1)
            objs[current] = []
        elif re.match(r'^next$', line, re.IGNORECASE):
            current = None
        elif current:
            objs[current].append(line)
        else:
            objs.setdefault("__global__", []).append(line)
    return objs


def extraer_sets(lines):
    entries = []
    for line in lines:
        m = re.match(r'^set\s+(\S+)(?:\s+(.+))?$', line, re.IGNORECASE)
        if m:
            param = m.group(1)
            val = (m.group(2) or "").strip().strip('"')
            entries.append((param, val))
    return entries

# -----------------------------
# DataFrames por sección
# -----------------------------

def df_info_general(secs):
    rows = []
    key = next((k for k in secs if k.startswith('system global')), None)
    if key:
        for p, v in extraer_sets(parsear_objetos(secs[key]).get('__global__', [])):
            if p.lower() in ['hostname','timezone','timezone-tz','admintimeout']:
                rows.append({'Parámetro': p, 'Valor': v})
    return pd.DataFrame(rows)


def df_usuarios(secs):
    rows = []
    key = next((k for k in secs if k.startswith('system admin')), None)
    if key:
        for user, lines in parsear_objetos(secs[key]).items():
            p = dict(extraer_sets(lines))
            rows.append({
                'Usuario': user,
                'Acceso': p.get('accprofile',''),
                'Timeout': p.get('timeout',''),
                'SSH Key': p.get('ssh-public-key1','')
            })
    return pd.DataFrame(rows)


def df_interfaces(secs):
    rows = []
    key = next((k for k in secs if k.startswith('system interface')), None)
    if key:
        for iface, lines in parsear_objetos(secs[key]).items():
            p = dict(extraer_sets(lines))
            rows.append({
                'Interfaz': iface,
                'IP/Subnet': p.get('ip',''),
                'Tipo': p.get('type',''),
                'Alias': p.get('alias',''),
                'Status': p.get('status','')
            })
    return pd.DataFrame(rows)


def df_ntp(secs):
    rows = []
    key = next((k for k in secs if k.startswith('system ntp')), None)
    if key:
        for p, v in extraer_sets(parsear_objetos(secs[key]).get('__global__', [])):
            rows.append({'Parámetro': p, 'Valor': v})
    return pd.DataFrame(rows)


def df_direccion(secs):
    rows = []
    key = next((k for k in secs if k.startswith('firewall address')), None)
    if key:
        for obj, lines in parsear_objetos(secs[key]).items():
            for p, v in extraer_sets(lines):
                rows.append({'Objeto': obj, 'Parámetro': p, 'Valor': v})
    return pd.DataFrame(rows)


def df_servicios(secs):
    rows = []
    key = next((k for k in secs if k.startswith('firewall service')), None)
    if key:
        for svc, lines in parsear_objetos(secs[key]).items():
            p = dict(extraer_sets(lines))
            proto = p.get('protocol','').lower()
            port = p.get('tcp-portrange','') if proto=='tcp' else p.get('udp-portrange','') if proto=='udp' else p.get('protocol-number','')
            rows.append({'Servicio': svc, 'Protocolo': proto, 'Puerto/Intervalo': port})
    return pd.DataFrame(rows)


def df_politicas(secs):
    rows = []
    key = next((k for k in secs if k.startswith('firewall policy')), None)
    if key:
        for pid, lines in parsear_objetos(secs[key]).items():
            p = dict(extraer_sets(lines))
            rows.append({
                'ID': pid,
                'Nombre': p.get('name',''),
                'srcintf': p.get('srcintf',''),
                'dstintf': p.get('dstintf',''),
                'srcaddr': p.get('srcaddr',''),
                'dstaddr': p.get('dstaddr',''),
                'Servicio': p.get('service',''),
                'Acción': p.get('action',''),
                'Schedule': p.get('schedule',''),
                'LogTraffic': p.get('logtraffic','')
            })
    cols = ['ID','Nombre','srcintf','dstintf','srcaddr','dstaddr','Servicio','Acción','Schedule','LogTraffic']
    return pd.DataFrame(rows, columns=cols)


def df_vips(secs):
    rows = []
    key = next((k for k in secs if k.startswith('firewall vip')), None)
    if key:
        for vip, lines in parsear_objetos(secs[key]).items():
            for p, v in extraer_sets(lines):
                rows.append({'VIP': vip, 'Parámetro': p, 'Valor': v})
    return pd.DataFrame(rows)


def df_ippool(secs):
    rows = []
    key = next((k for k in secs if k.startswith('firewall ippool')), None)
    if key:
        for pool, lines in parsear_objetos(secs[key]).items():
            for p, v in extraer_sets(lines):
                rows.append({'Pool': pool, 'Parámetro': p, 'Valor': v})
    return pd.DataFrame(rows)


def df_rutas(secs):
    rows = []
    key = next((k for k in secs if k.startswith('router static')), None)
    if key:
        for rid, lines in parsear_objetos(secs[key]).items():
            p = dict(extraer_sets(lines))
            rows.append({
                'ID': rid,
                'Destino': p.get('dst',''),
                'Gateway': p.get('gateway',''),
                'Device': p.get('device',''),
                'Distance': p.get('distance','')
            })
    return pd.DataFrame(rows)


def df_vpn(secs):
    p1 = []
    p2 = []
    key1 = next((k for k in secs if k.startswith('vpn ipsec phase1-interface')), None)
    if key1:
        for tun, lines in parsear_objetos(secs[key1]).items():
            for pr, vl in extraer_sets(lines): p1.append({'Tunnel': tun, 'Parámetro': pr, 'Valor': vl})
    key2 = next((k for k in secs if k.startswith('vpn ipsec phase2-interface')), None)
    if key2:
        for tun, lines in parsear_objetos(secs[key2]).items():
            for pr, vl in extraer_sets(lines): p2.append({'Tunnel': tun, 'Parámetro': pr, 'Valor': vl})
    return pd.DataFrame(p1), pd.DataFrame(p2)

# -----------------------------
# Escritura del Excel
# -----------------------------

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Uso: python3 fortisox_excel.py <entrada.conf> <salida.xlsx>')
        sys.exit(1)
    infile, outfile = sys.argv[1], sys.argv[2]
    if not os.path.isfile(infile):
        print(f'ERROR: {infile} no existe')
        sys.exit(1)

    lines = open(infile, 'r', encoding='utf-8', errors='ignore').readlines()
    secs = agrupa_secciones(lines)

    # Preparar DataFrames
    dfs = {
        'Información General': df_info_general(secs),
        'Usuarios Administrativos': df_usuarios(secs),
        'Interfaces de Red': df_interfaces(secs),
        'Configuración NTP': df_ntp(secs),
        'Objetos de Dirección': df_direccion(secs),
        'Servicios de Firewall': df_servicios(secs),
        'Políticas de Firewall': df_politicas(secs),
        'NAT - VIPs': df_vips(secs),
        'NAT - IP Pools': df_ippool(secs),
        'Rutas Estáticas': df_rutas(secs),
    }
    vpn1, vpn2 = df_vpn(secs)
    dfs['VPN IPsec Phase1'] = vpn1
    dfs['VPN IPsec Phase2'] = vpn2

    # Colores de pestañas
    tab_colors = {
        'Información General': '#4F81BD',
        'Usuarios Administrativos': '#9BBB59',
        'Interfaces de Red': '#8064A2',
        'Configuración NTP': '#F79646',
        'Objetos de Dirección': '#4BACC6',
        'Servicios de Firewall': '#C0504D',
        'Políticas de Firewall': '#9E480E',
        'NAT - VIPs': '#1F497D',
        'NAT - IP Pools': '#4F81BD',
        'Rutas Estáticas': '#8064A2',
        'VPN IPsec Phase1': '#9BBB59',
        'VPN IPsec Phase2': '#F79646'
    }

    # Escribir Excel
    with pd.ExcelWriter(outfile, engine='xlsxwriter') as writer:
        wb = writer.book
        # Índice
        idx = pd.DataFrame([{'Sección': k, 'Hoja': k} for k in dfs.keys()], columns=['Sección','Hoja'])
        idx.to_excel(writer, sheet_name='Índice', index=False)
        ws_idx = writer.sheets['Índice']
        hdr_fmt = wb.add_format({'bold': True, 'bg_color': '#D9E1F2', 'border': 1})
        for c in range(len(idx.columns)):
            ws_idx.write(0, c, idx.columns[c], hdr_fmt)
        for r, row in enumerate(idx.itertuples(), start=1):
            ws_idx.write_url(r, 1, f"internal:'{row.Hoja}'!A1", string=row.Hoja)
        ws_idx.freeze_panes(1,0)
        ws_idx.set_column('A:B', 30)
        ws_idx.set_tab_color(tab_colors.get('Índice','#FFD966'))

        # Estilos comunes
        title_fmt = wb.add_format({'bold': True, 'font_size': 14, 'align': 'center', 'bg_color': '#4F81BD', 'font_color': 'white', 'border':1})
        header_fmt = wb.add_format({'bold': True, 'bg_color': '#D9E1F2', 'border':1})

        # Páginas
        for sheet, df in dfs.items():
            df.to_excel(writer, sheet_name=sheet, startrow=1, index=False)
            ws = writer.sheets[sheet]
            nrows, ncols = df.shape
            # Título fusionado
            ws.merge_range(0,0,0,ncols-1, f'Documentación SOX - {sheet}', title_fmt)
            # Encabezados
            for c, col in enumerate(df.columns):
                ws.write(1, c, col, header_fmt)
            # Tabla excel
            if nrows>0:
                tbl_range = xl_range(1, 0, 1+nrows, ncols-1)
                # Sanitizar nombre de tabla: solo alfanuméricos y guión bajo
                table_name = re.sub(r'[^A-Za-z0-9_]','_', sheet)
                # Asegurar que empiece con letra o guión bajo
                if table_name and table_name[0].isdigit():
                    table_name = '_' + table_name
                ws.add_table(tbl_range, {
                    'name': table_name,
                    'columns': [{'header': col} for col in df.columns],
                    'style': 'Table Style Medium 9',
                    'banded_rows': True
                })
            # Ajuste ancho y wrap
            for i, col in enumerate(df.columns):
                max_len = max(df[col].astype(str).map(len).max() if nrows>0 else 0, len(col)) + 2
                fmt = wb.add_format({'text_wrap': True, 'border':1})
                ws.set_column(i, i, max_len, fmt)
            ws.freeze_panes(2,0)
            ws.set_tab_color(tab_colors.get(sheet))
    print(f'[OK] Excel generado en: {outfile}')
