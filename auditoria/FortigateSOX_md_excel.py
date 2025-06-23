#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fortisox.py

Toma como entrada un archivo de configuración completo de FortiGate (.conf)
y genera, según las extensiones de salida:

  - Markdown (.md): auditoría SOX (índice, secciones, tablas).
  - Excel (.xlsx): auditoría CIS/NIST/ISO27001 (tablas con estilo).

Uso:
    python3 fortisox.py config.conf salida.md [salida.xlsx ...]
"""
import sys, os, re
from datetime import datetime
import pandas as pd
from xlsxwriter.utility import xl_range

# -----------------------------
# Parsing del .conf
# -----------------------------

def agrupa_secciones(lines):
    secciones, contador, current = {}, {}, None
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
    objs, current = {}, None
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
    out = []
    for line in lines:
        m = re.match(r'^set\s+(\S+)(?:\s+(.+))?$', line, re.IGNORECASE)
        if m:
            param = m.group(1)
            val = (m.group(2) or "").strip().strip('"')
            out.append((param, val))
    return out

# -----------------------------
# Definición de DataFrame por sección
# -----------------------------

def df_info_general(secs):
    rows = []
    key = next((k for k in secs if k.startswith('system global')), None)
    if key:
        for p,v in extraer_sets(parsear_objetos(secs[key]).get('__global__', [])):
            if p.lower() in ['hostname','timezone','timezone-tz','admintimeout']:
                rows.append({'Parámetro':p,'Valor':v})
    return pd.DataFrame(rows)


def df_usuarios(secs):
    rows = []
    key = next((k for k in secs if k.startswith('system admin')), None)
    if key:
        for user, lines in parsear_objetos(secs[key]).items():
            p = dict(extraer_sets(lines))
            rows.append({
                'Usuario':user,
                'Acceso':p.get('accprofile',''),
                'Timeout':p.get('timeout',''),
                'SSH Key':p.get('ssh-public-key1','')
            })
    return pd.DataFrame(rows)


def df_interfaces(secs):
    rows = []
    key = next((k for k in secs if k.startswith('system interface')), None)
    if key:
        for iface, lines in parsear_objetos(secs[key]).items():
            p = dict(extraer_sets(lines))
            rows.append({
                'Interfaz':iface,
                'IP/Subnet':p.get('ip',''),
                'Tipo':p.get('type',''),
                'Alias':p.get('alias',''),
                'Status':p.get('status','')
            })
    return pd.DataFrame(rows)


def df_ntp(secs):
    rows = []
    key = next((k for k in secs if k.startswith('system ntp')), None)
    if key:
        for p,v in extraer_sets(parsear_objetos(secs[key]).get('__global__', [])):
            rows.append({'Parámetro':p,'Valor':v})
    return pd.DataFrame(rows)


def df_direccion(secs):
    rows = []
    key = next((k for k in secs if k.startswith('firewall address')), None)
    if key:
        for obj, lines in parsear_objetos(secs[key]).items():
            for p,v in extraer_sets(lines): rows.append({'Objeto':obj,'Parámetro':p,'Valor':v})
    return pd.DataFrame(rows)


def df_servicios(secs):
    rows = []
    key = next((k for k in secs if k.startswith('firewall service')), None)
    if key:
        for svc, lines in parsear_objetos(secs[key]).items():
            p = dict(extraer_sets(lines)); proto=p.get('protocol','').lower()
            port = p.get('tcp-portrange','') if proto=='tcp' else p.get('udp-portrange','') if proto=='udp' else p.get('protocol-number','')
            rows.append({'Servicio':svc,'Protocolo':proto,'Puerto/Intervalo':port})
    return pd.DataFrame(rows)


def df_politicas(secs):
    rows=[]
    key = next((k for k in secs if k.startswith('firewall policy')), None)
    if key:
        for pid, lines in parsear_objetos(secs[key]).items():
            p = dict(extraer_sets(lines))
            rows.append({
                'ID':pid,
                'Nombre':p.get('name',''),
                'srcintf':p.get('srcintf',''),
                'dstintf':p.get('dstintf',''),
                'srcaddr':p.get('srcaddr',''),
                'dstaddr':p.get('dstaddr',''),
                'Servicio':p.get('service',''),
                'Acción':p.get('action',''),
                'Schedule':p.get('schedule',''),
                'LogTraffic':p.get('logtraffic','')
            })
    cols=['ID','Nombre','srcintf','dstintf','srcaddr','dstaddr','Servicio','Acción','Schedule','LogTraffic']
    return pd.DataFrame(rows, columns=cols)


def df_vips(secs):
    rows=[]
    key = next((k for k in secs if k.startswith('firewall vip')), None)
    if key:
        for vip, lines in parsear_objetos(secs[key]).items():
            for p,v in extraer_sets(lines): rows.append({'VIP':vip,'Parámetro':p,'Valor':v})
    return pd.DataFrame(rows)


def df_ippool(secs):
    rows=[]
    key = next((k for k in secs if k.startswith('firewall ippool')), None)
    if key:
        for pool, lines in parsear_objetos(secs[key]).items():
            for p,v in extraer_sets(lines): rows.append({'Pool':pool,'Parámetro':p,'Valor':v})
    return pd.DataFrame(rows)


def df_rutas(secs):
    rows=[]
    key = next((k for k in secs if k.startswith('router static')), None)
    if key:
        for rid, lines in parsear_objetos(secs[key]).items():
            p=dict(extraer_sets(lines))
            rows.append({'ID':rid,'Destino':p.get('dst',''),'Gateway':p.get('gateway',''),'Device':p.get('device',''),'Distance':p.get('distance','')})
    return pd.DataFrame(rows)


def df_vpn(secs):
    p1,p2=[],[]
    key1=next((k for k in secs if k.startswith('vpn ipsec phase1-interface')),None)
    if key1:
        for tun, lines in parsear_objetos(secs[key1]).items():
            for pr,vl in extraer_sets(lines): p1.append({'Tunnel':tun,'Parámetro':pr,'Valor':vl})
    key2=next((k for k in secs if k.startswith('vpn ipsec phase2-interface')),None)
    if key2:
        for tun, lines in parsear_objetos(secs[key2]).items():
            for pr,vl in extraer_sets(lines): p2.append({'Tunnel':tun,'Parámetro':pr,'Valor':vl})
    return pd.DataFrame(p1), pd.DataFrame(p2)

# -----------------------------
# Generar Markdown
# -----------------------------

def generar_markdown(entrada, salida):
    lines=open(entrada,'r',encoding='utf-8',errors='ignore').readlines()
    secs=agrupa_secciones(lines)
    md=[]
    md.append(f"# Documentación SOX - FortiGate\n")
    md.append(f"- **Fuente:** `{os.path.basename(entrada)}`  \n")
    md.append(f"- **Generado por:** fortisox.py  \n")
    md.append(f"- **Fecha:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  \n\n---\n\n")
    sec_info=[('system global','Información General'),('system admin','Usuarios Administrativos'),('system interface','Interfaces de Red'),('system ntp','Configuración NTP'),('firewall address','Objetos de Dirección'),('firewall service','Servicios de Firewall'),('firewall policy','Políticas de Firewall'),('firewall vip','NAT - VIPs'),('firewall ippool','NAT - IP Pools'),('router static','Rutas Estáticas'),('vpn ipsec phase1-interface','VPN IPsec Phase1'),('vpn ipsec phase2-interface','VPN IPsec Phase2')]
    # Índice
    md.append('## Índice\n')
    for pref,tit in sec_info:
        if any(k.startswith(pref) for k in secs):
            anc=re.sub(r'[^a-z0-9\-]','',tit.lower().replace(' ','-'))
            md.append(f"- [{tit}](#{anc})")
    md.append('\n---\n')
    # Bloques
    def blk(pref,tit,tab=True,cols=None):
        md.append(f"## {tit}\n")
        key=next((k for k in secs if k.startswith(pref)),None)
        if not key: md.append(f"- Sección `{pref}` no encontrada.\n\n");return
        objs=parsear_objetos(secs[key])
        if tab and cols:
            rows=[ [obj,p,v] for obj,ln in objs.items() for p,v in extraer_sets(ln) ]
            hdr='| ' + ' | '.join(cols) + ' |';sp='|'+'|'.join(['-'*(len(c)+2) for c in cols])+'|'
            md.append(hdr);md.append(sp)
            for r in rows: md.append('| '+' | '.join(r)+' |')
        else:
            for obj,ln in objs.items(): md.append(f"### {obj}\n") or [md.append(f"- **{p}**: `{v}`") for p,v in extraer_sets(ln)]
        md.append('\n')
    for p,t in sec_info:
        if t in ['Usuarios Administrativos','Interfaces de Red','Políticas de Firewall','NAT - VIPs','NAT - IP Pools','Rutas Estáticas','VPN IPsec Phase1','VPN IPsec Phase2','Configuración NTP','Objetos de Dirección','Servicios de Firewall']:
            blk(p,t,True,['Objeto','Parámetro','Valor'])
        else:
            blk(p,t,False,None)
    open(salida,'w',encoding='utf-8').write('\n'.join(md))
    print(f'[OK] Markdown generado en: {salida}')

# -----------------------------
# Generar Excel
# -----------------------------

def generar_excel(entrada, salida):
    lines=open(entrada,'r',encoding='utf-8',errors='ignore').readlines()
    secs=agrupa_secciones(lines)
    dfs={
        'Información General':df_info_general(secs),
        'Usuarios Administrativos':df_usuarios(secs),
        'Interfaces de Red':df_interfaces(secs),
        'Configuración NTP':df_ntp(secs),
        'Objetos de Dirección':df_direccion(secs),
        'Servicios de Firewall':df_servicios(secs),
        'Políticas de Firewall':df_politicas(secs),
        'NAT - VIPs':df_vips(secs),
        'NAT - IP Pools':df_ippool(secs),
        'Rutas Estáticas':df_rutas(secs)
    }
    v1,v2=df_vpn(secs)
    dfs['VPN IPsec Phase1']=v1;dfs['VPN IPsec Phase2']=v2
    tab_colors={sheet:'#DDEBF7' for sheet in dfs}
    with pd.ExcelWriter(salida,engine='xlsxwriter') as writer:
        wb=writer.book
        # Índice
        idx=pd.DataFrame([{'Sección':k,'Hoja':k} for k in dfs],columns=['Sección','Hoja'])
        idx.to_excel(writer,sheet_name='Índice',index=False)
        ws=writer.sheets['Índice']
        fmt=wb.add_format({'bold':True,'bg_color':'#D9E1F2','border':1})
        for c in range(2): ws.write(0,c,idx.columns[c],fmt)
        for r,row in enumerate(idx.itertuples(),1): ws.write_url(r,1,f"internal:'{row.Hoja}'!A1",string=row.Hoja)
        ws.freeze_panes(1,0);ws.set_column('A:B',30);ws.set_tab_color('#B4C6E7')
        # Sheets
        title_fmt=wb.add_format({'bold':True,'font_size':14,'align':'center','bg_color':'#4F81BD','font_color':'white','border':1})
        header_fmt=wb.add_format({'bold':True,'bg_color':'#D9E1F2','border':1})
        for sheet,df in dfs.items():
            df.to_excel(writer,sheet_name=sheet,startrow=1,index=False)
            ws=writer.sheets[sheet]
            nrows,ncols=df.shape
            ws.merge_range(0,0,0,ncols-1,f'Documentación SOX - {sheet}',title_fmt)
            if nrows>0:
                tbl=xl_range(1,0,1+nrows,ncols-1)
                tbl_name=re.sub(r'[^A-Za-z0-9_]','_',sheet)
                if tbl_name[0].isdigit(): tbl_name='_'+tbl_name
                ws.add_table(tbl,{'name':tbl_name,'columns':[{'header':c} for c in df.columns],'style':'Table Style Medium 9','banded_rows':True})
            for i,col in enumerate(df.columns):
                length=max(df[col].astype(str).map(len).max(),len(col))+2
                fmt=wb.add_format({'text_wrap':True,'border':1})
                ws.set_column(i,i,length,fmt)
            ws.freeze_panes(2,0)
            ws.set_tab_color(tab_colors[sheet])
    print(f'[OK] Excel generado en: {salida}')

# -----------------------------
# Main
# -----------------------------

if __name__=='__main__':
    if len(sys.argv)<3:
        print('Uso: python3 fortisox.py <entrada.conf> <salida1> [<salida2> ...]')
        sys.exit(1)
    entrada=sys.argv[1]
    for salida in sys.argv[2:]:
        ext=os.path.splitext(salida)[1].lower()
        if ext=='.md': generar_markdown(entrada,salida)
        elif ext in ['.xlsx']: generar_excel(entrada,salida)
        else: print(f'ERROR: formato no soportado: {salida}')
