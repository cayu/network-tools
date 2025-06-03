#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fortisox.py

Toma como entrada un archivo de configuración completo de FortiGate (.conf)
y genera un Markdown (.md) con una estructura pensada para auditoría SOX:

  - Índice automático.
  - Información general del sistema.
  - Usuarios administrativos.
  - Interfaces de red.
  - Objetos de dirección.
  - Servicios de firewall.
  - Políticas de firewall (en tabla).
  - NAT (VIPs e IP pools).
  - Rutas estáticas.
  - VPN IPsec (Phase1 / Phase2).
  - NTP.

Para invocar:
    python3 fortisox.py <entrada.conf> <salida.md>

    Sergio Cayuqueo <cayu@cayu.com.ar>
"""

import sys
import os
import re
from datetime import datetime

# -----------------------------
# Funciones de parsing general
# -----------------------------

def agrupa_secciones(lines):
    """
    Agrupa el archivo de configuración en bloques por cada 'config <sección>' ... 'end'.
    Devuelve un diccionario: { clave_seccion_unica: lista_de_líneas_internas }.
    Si hay secciones repetidas (p. ej. varias "config firewall policy"), se agregan sufijos.
    """
    secciones = {}
    current_key = None
    buffer = []

    # Contador para secciones repetidas
    contador = {}

    for raw in lines:
        line = raw.strip()
        # Buscar "config <algo>", ignorando mayúsculas/minúsculas
        m = re.match(r'^config\s+(.+)$', line, re.IGNORECASE)
        if m:
            nombre = m.group(1).strip().lower()
            # Si esta sección ya existe, le agregamos sufijo numerado
            if nombre in contador:
                contador[nombre] += 1
                key = f"{nombre}__{contador[nombre]}"
            else:
                contador[nombre] = 1
                key = nombre

            current_key = key
            buffer = []
            secciones[current_key] = buffer
            continue

        # Detectar "end" que cierra el bloque de sección actual
        if re.match(r'^end$', line, re.IGNORECASE) and current_key:
            current_key = None
            buffer = []
            continue

        # Si estamos en el contexto de una sección abierta, agregamos la línea
        if current_key:
            secciones[current_key].append(line)

    return secciones


def parsear_objetos(seccion_lines):
    """
    Dada la lista de líneas de una sección (sin incluir 'config' ni 'end'),
    agrupa en objetos por cada 'edit <nombre>' ... 'next'. Retorna dict { objeto: [líneas_set] }.
    Si no hay 'edit', devuelve "__global__" con todas las líneas.
    """
    objetos = {}
    current_obj = None
    buffer = []

    for line in seccion_lines:
        m_edit = re.match(r'^edit\s+"?(.+?)"?$', line, re.IGNORECASE)
        if m_edit:
            name = m_edit.group(1)
            current_obj = name
            buffer = []
            objetos[current_obj] = buffer
            continue

        if re.match(r'^next$', line, re.IGNORECASE) and current_obj:
            current_obj = None
            buffer = []
            continue

        if current_obj:
            objetos[current_obj].append(line)
        else:
            # Si nunca se abrió un 'edit', usamos "__global__"
            if "__global__" not in objetos:
                objetos["__global__"] = []
            objetos["__global__"].append(line)

    return objetos


def extraer_sets(lines):
    """
    Dada una lista de líneas dentro de un objeto (o __global__),
    extrae pares (param, valor) de aquellas que empiecen con 'set '.
    Retorna lista de tuplas: [(param1, valor1), (param2, valor2), ...].
    """
    resultados = []
    for line in lines:
        m = re.match(r'^set\s+(\S+)(?:\s+(.+))?$', line, re.IGNORECASE)
        if m:
            param = m.group(1).strip()
            val = m.group(2).strip() if m.group(2) else ""
            resultados.append((param, val))
    return resultados


# -----------------------------
# Funciones de generación Markdown
# -----------------------------

def generar_indice(secciones_md):
    """
    Recibe una lista de tuplas (clave_seccion, titulo_legible) y produce
    un bloque Markdown de índice con enlaces internos (anchor links).
    """
    md = ["## Índice\n"]
    for key, titulo in secciones_md:
        # Creamos un anchor: todo en minúsculas, espacios→guiones, quitamos caracteres no alfanum/-
        anchor = re.sub(r'[^a-z0-9\-]+', '', titulo.lower().replace(' ', '-'))
        md.append(f"- [{titulo}](#{anchor})")
    md.append("\n---\n")
    return "\n".join(md)


def titulo_md(nivel, texto):
    """
    Retorna un encabezado Markdown con el nivel y el texto.
    """
    return f"{'#' * nivel} {texto}\n\n"


def tabla_markdown(columnas, filas):
    """
    Construye una tabla Markdown a partir de lista de encabezados y lista de filas.
    - columnas: ['col1', 'col2', ...]
    - filas: [[v11, v12, ...], [v21, v22, ...], ...]
    """
    # Encabezado
    header = "| " + " | ".join(columnas) + " |\n"
    # Línea separadora
    sep = "|" + "|".join(["-" * (len(c) + 2) for c in columnas]) + "|\n"
    # Filas
    rows = ""
    for fila in filas:
        escaped = [str(val).replace("|", "\\|") for val in fila]
        rows += "| " + " | ".join(escaped) + " |\n"
    return header + sep + rows + "\n"


# -----------------------------
# Bloques específicos para auditoría SOX
# -----------------------------

def procesar_info_general(secciones):
    """
    Extrae de 'config system global' parámetros clave (hostname, timezone, etc.).
    Retorna lista de líneas Markdown.
    """
    resultado = []
    clave_global = None
    for key in secciones:
        if key.startswith("system global"):
            clave_global = key
            break

    resultado.append(titulo_md(2, "Información General del Sistema"))
    if not clave_global:
        resultado.append("- No se encontró sección `config system global`.\n\n")
        return resultado

    objs = parsear_objetos(secciones[clave_global])
    params = extraer_sets(objs.get("__global__", []))

    if params:
        for (p, v) in params:
            lc = p.lower()
            if lc in ["hostname", "timezone", "admintimeout", "timezone-tz"]:
                resultado.append(f"- **{p}**: `{v}`  \n")
    else:
        resultado.append("- No se encontraron parámetros en `system global`.\n")

    resultado.append("\n")
    return resultado


def procesar_ntp(secciones):
    """
    Extrae configuración NTP de 'config system ntp'.
    Retorna lista Markdown.
    """
    resultado = []
    clave_ntp = None
    for key in secciones:
        if key.startswith("system ntp"):
            clave_ntp = key
            break

    resultado.append(titulo_md(2, "Configuración NTP"))
    if not clave_ntp:
        resultado.append("- No se encontró sección `config system ntp`.\n\n")
        return resultado

    objs = parsear_objetos(secciones[clave_ntp])
    params = extraer_sets(objs.get("__global__", []))
    if not params:
        resultado.append("- Sin parámetros NTP configurados.\n\n")
        return resultado

    for (p, v) in params:
        resultado.append(f"- **{p}**: `{v}`  \n")
    resultado.append("\n")
    return resultado


def procesar_admins(secciones):
    """
    Procesa 'config system admin' para listar usuarios administrativos y perfiles.
    Retorna lista Markdown.
    """
    resultado = []
    clave = None
    for key in secciones:
        if key.startswith("system admin"):
            clave = key
            break

    resultado.append(titulo_md(2, "Usuarios Administrativos (system admin)"))
    if not clave:
        resultado.append("- No se encontró sección `config system admin`.\n\n")
        return resultado

    objs = parsear_objetos(secciones[clave])
    filas = []
    columnas = ["Usuario", "Acceso (accprofile)", "Timeout", "SSH Key"]

    for usuario, lines in objs.items():
        params = dict(extraer_sets(lines))
        perfil  = params.get("accprofile", "")
        timeout = params.get("timeout", "")
        sshkey  = params.get("ssh-public-key1", "")
        filas.append([usuario, perfil, timeout, sshkey])

    if filas:
        resultado.append(tabla_markdown(columnas, filas))
    else:
        resultado.append("- No se encontraron usuarios configurados.\n")

    resultado.append("\n")
    return resultado


def procesar_interfaces(secciones):
    """
    Procesa 'config system interface' para listar interfaces con IP, tipo, alias, estado.
    """
    resultado = []
    clave = None
    for key in secciones:
        if key.startswith("system interface"):
            clave = key
            break

    resultado.append(titulo_md(2, "Interfaces de Red (system interface)"))
    if not clave:
        resultado.append("- No se encontró sección `config system interface`.\n\n")
        return resultado

    objs = parsear_objetos(secciones[clave])
    filas = []
    columnas = ["Interfaz", "IP/Subnet", "Tipo", "Alias", "Status"]
    for iface, lines in objs.items():
        params = dict(extraer_sets(lines))
        ip     = params.get("ip", "")
        tipo   = params.get("type", "")
        alias  = params.get("alias", "")
        status = params.get("status", "")
        filas.append([iface, ip, tipo, alias, status])

    if filas:
        resultado.append(tabla_markdown(columnas, filas))
    else:
        resultado.append("- Sin interfaces definidas.\n")

    resultado.append("\n")
    return resultado


def procesar_objetos_direccion(secciones):
    """
    Procesa 'config firewall address' para listar direcciones/objetos.
    """
    resultado = []
    clave = None
    for key in secciones:
        if key.startswith("firewall address"):
            clave = key
            break

    resultado.append(titulo_md(2, "Objetos de Dirección (firewall address)"))
    if not clave:
        resultado.append("- No se encontró sección `config firewall address`.\n\n")
        return resultado

    objs = parsear_objetos(secciones[clave])
    for obj, lines in objs.items():
        params = dict(extraer_sets(lines))
        resultado.append(f"#### {obj}\n")
        if params:
            for p, v in params.items():
                resultado.append(f"- **{p}**: `{v}`  \n")
        else:
            resultado.append("- Sin parámetros.\n")
        resultado.append("\n")

    return resultado


def procesar_servicios(secciones):
    """
    Procesa 'config firewall service custom' (o 'firewall service') para servicios.
    """
    resultado = []
    clave = None
    for key in secciones:
        if key.startswith("firewall service custom"):
            clave = key
            break
    if not clave:
        for key in secciones:
            if key.startswith("firewall service"):
                clave = key
                break

    resultado.append(titulo_md(2, "Servicios de Firewall (firewall service)"))
    if not clave:
        resultado.append("- No se encontró sección `config firewall service custom` ni `config firewall service`.\n\n")
        return resultado

    objs = parsear_objetos(secciones[clave])
    filas = []
    columnas = ["Servicio", "Protocolo", "Puerto/Intervalo"]
    for svc, lines in objs.items():
        params = dict(extraer_sets(lines))
        proto = params.get("protocol", "")
        if proto.lower() == "tcp":
            puerto = params.get("tcp-portrange", "")
        elif proto.lower() == "udp":
            puerto = params.get("udp-portrange", "")
        else:
            puerto = params.get("protocol-number", "")
        filas.append([svc, proto, puerto])

    if filas:
        resultado.append(tabla_markdown(columnas, filas))
    else:
        resultado.append("- Sin servicios personalizados definidos.\n")

    resultado.append("\n")
    return resultado


def procesar_políticas(secciones):
    """
    Procesa 'config firewall policy' y genera una tabla con columnas clave.
    """
    resultado = []
    clave = None
    for key in secciones:
        if key.startswith("firewall policy"):
            clave = key
            break

    resultado.append(titulo_md(2, "Políticas de Firewall (firewall policy)"))
    if not clave:
        resultado.append("- No se encontró sección `config firewall policy`.\n\n")
        return resultado

    objs = parsear_objetos(secciones[clave])
    filas = []
    columnas = [
        "ID", "Nombre", "srcintf", "dstintf", "srcaddr", "dstaddr",
        "Servicio", "Acción", "Schedule", "LogTraffic"
    ]
    for pid, lines in objs.items():
        params  = dict(extraer_sets(lines))
        nombre  = params.get("name", "")
        srcintf = params.get("srcintf", "")
        dstintf = params.get("dstintf", "")
        srcaddr = params.get("srcaddr", "")
        dstaddr = params.get("dstaddr", "")
        servicio = params.get("service", "")
        accion   = params.get("action", "")
        schedule = params.get("schedule", "")
        logt     = params.get("logtraffic", "")
        filas.append([pid, nombre, srcintf, dstintf, srcaddr, dstaddr, servicio, accion, schedule, logt])

    if filas:
        resultado.append(tabla_markdown(columnas, filas))
    else:
        resultado.append("- Sin políticas definidas.\n")

    resultado.append("\n")
    return resultado


def procesar_nat(secciones):
    """
    Procesa NAT: VIPs ('config firewall vip') e IP Pools ('config firewall ippool').
    """
    resultado = []
    # VIP
    clave_vip = None
    for key in secciones:
        if key.startswith("firewall vip"):
            clave_vip = key
            break

    resultado.append(titulo_md(2, "NAT - VIPs (firewall vip)"))
    if not clave_vip:
        resultado.append("- No se encontró sección `config firewall vip`.\n\n")
    else:
        objs_vip = parsear_objetos(secciones[clave_vip])
        for vip, lines in objs_vip.items():
            params = dict(extraer_sets(lines))
            resultado.append(f"#### {vip}\n")
            if params:
                for p, v in params.items():
                    resultado.append(f"- **{p}**: `{v}`  \n")
            else:
                resultado.append("- Sin parámetros.\n")
            resultado.append("\n")

    # IP pool
    clave_pool = None
    for key in secciones:
        if key.startswith("firewall ippool"):
            clave_pool = key
            break

    resultado.append(titulo_md(2, "NAT - IP Pools (firewall ippool)"))
    if not clave_pool:
        resultado.append("- No se encontró sección `config firewall ippool`.\n\n")
    else:
        objs_pool = parsear_objetos(secciones[clave_pool])
        for pool, lines in objs_pool.items():
            params = dict(extraer_sets(lines))
            resultado.append(f"#### {pool}\n")
            if params:
                for p, v in params.items():
                    resultado.append(f"- **{p}**: `{v}`  \n")
            else:
                resultado.append("- Sin parámetros.\n")
            resultado.append("\n")

    return resultado


def procesar_rutas(secciones):
    """
    Procesa 'config router static' para listar rutas estáticas.
    """
    resultado = []
    clave = None
    for key in secciones:
        if key.startswith("router static"):
            clave = key
            break

    resultado.append(titulo_md(2, "Rutas Estáticas (router static)"))
    if not clave:
        resultado.append("- No se encontró sección `config router static`.\n\n")
        return resultado

    objs = parsear_objetos(secciones[clave])
    filas = []
    columnas = ["ID", "Destino", "Gateway", "Device", "Distance"]
    for rid, lines in objs.items():
        params  = dict(extraer_sets(lines))
        dst     = params.get("dst", "")
        gateway = params.get("gateway", "")
        device  = params.get("device", "")
        dist    = params.get("distance", "")
        filas.append([rid, dst, gateway, device, dist])

    if filas:
        resultado.append(tabla_markdown(columnas, filas))
    else:
        resultado.append("- Sin rutas estáticas definidas.\n")

    resultado.append("\n")
    return resultado


def procesar_vpn_ipsec(secciones):
    """
    Procesa IPsec Phase1 y Phase2:
    - 'config vpn ipsec phase1-interface'
    - 'config vpn ipsec phase2-interface'
    """
    resultado = []
    # Phase1
    clave_p1 = None
    for key in secciones:
        if key.startswith("vpn ipsec phase1-interface"):
            clave_p1 = key
            break

    resultado.append(titulo_md(2, "VPN IPsec - Phase1"))
    if not clave_p1:
        resultado.append("- No se encontró `config vpn ipsec phase1-interface`.\n\n")
    else:
        objs = parsear_objetos(secciones[clave_p1])
        for túnel, lines in objs.items():
            params = dict(extraer_sets(lines))
            resultado.append(f"#### {túnel}\n")
            if params:
                for p, v in params.items():
                    resultado.append(f"- **{p}**: `{v}`  \n")
            else:
                resultado.append("- Sin parámetros.\n")
            resultado.append("\n")

    # Phase2
    clave_p2 = None
    for key in secciones:
        if key.startswith("vpn ipsec phase2-interface"):
            clave_p2 = key
            break

    resultado.append(titulo_md(2, "VPN IPsec - Phase2"))
    if not clave_p2:
        resultado.append("- No se encontró `config vpn ipsec phase2-interface`.\n\n")
    else:
        objs = parsear_objetos(secciones[clave_p2])
        for túnel, lines in objs.items():
            params = dict(extraer_sets(lines))
            resultado.append(f"#### {túnel}\n")
            if params:
                for p, v in params.items():
                    resultado.append(f"- **{p}**: `{v}`  \n")
            else:
                resultado.append("- Sin parámetros.\n")
            resultado.append("\n")

    return resultado


# -----------------------------
# Función principal
# -----------------------------

def main():
    if len(sys.argv) != 3:
        print("Uso: python3 fortisox.py <entrada.conf> <salida.md>")
        sys.exit(1)

    entrada = sys.argv[1]
    salida  = sys.argv[2]

    if not os.path.isfile(entrada):
        print(f"[ERROR] No existe el archivo de entrada: {entrada}")
        sys.exit(1)

    # Leemos todas las líneas del archivo .conf
    with open(entrada, "r", encoding="utf-8", errors="ignore") as f:
        todas_las_lineas = f.readlines()

    # 1) Agrupamos en secciones
    secciones = agrupa_secciones(todas_las_lineas)

    # 2) Preparamos la lista de secciones y títulos para el índice
    lista_indice = [
        ("system global", "Información General"),
        ("system admin", "Usuarios Administrativos"),
        ("system interface", "Interfaces de Red"),
        ("system ntp", "Configuración NTP"),
        ("firewall address", "Objetos de Dirección"),
        ("firewall service", "Servicios de Firewall"),
        ("firewall policy", "Políticas de Firewall"),
        ("firewall vip", "NAT - VIPs"),
        ("firewall ippool", "NAT - IP Pools"),
        ("router static", "Rutas Estáticas"),
        ("vpn ipsec phase1-interface", "VPN IPsec - Phase1"),
        ("vpn ipsec phase2-interface", "VPN IPsec - Phase2"),
    ]

    # 3) Construimos el Markdown de salida
    md_out = []

    # Título principal
    md_out.append(f"# Documentación SOX - FortiGate\n")
    md_out.append(f"- **Fuente:** `{os.path.basename(entrada)}`  \n")
    md_out.append(f"- **Generado por:** fortisox.py  \n")
    md_out.append(f"- **Fecha:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  \n")
    md_out.append("\n---\n\n")

    # Generar índice dinámico
    secciones_existentes = []
    for clave_base, titulo in lista_indice:
        for key in secciones:
            if key.startswith(clave_base):
                secciones_existentes.append((key, titulo))
                break

    md_out.append(generar_indice(secciones_existentes))

    # 4) Agregar bloques uno por uno
    md_out.extend(procesar_info_general(secciones))
    md_out.extend(procesar_admins(secciones))
    md_out.extend(procesar_interfaces(secciones))
    md_out.extend(procesar_ntp(secciones))
    md_out.extend(procesar_objetos_direccion(secciones))
    md_out.extend(procesar_servicios(secciones))
    md_out.extend(procesar_políticas(secciones))
    md_out.extend(procesar_nat(secciones))
    md_out.extend(procesar_rutas(secciones))
    md_out.extend(procesar_vpn_ipsec(secciones))

    # 5) Escribimos el archivo de salida
    with open(salida, "w", encoding="utf-8") as fout:
        fout.write("".join(md_out))

    print(f"[OK] Documentación generada en: {salida}")


if __name__ == "__main__":
    main()
