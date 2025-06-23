# FortiSOX

**FortiSOX** es un script Python que extrae y documenta la configuración de dispositivos FortiGate. Genera dos tipos de salidas:

* **Markdown** (`.md`): estructura pensada para auditorías SOX (índice automático, secciones, tablas).
* **Excel** (`.xlsx`): formato profesional para auditorías CIS, NIST e ISO27001, con tablas Excel, bordes, colores y ajuste automático de columnas.

---

## Características

* Agrupa automáticamente las secciones `config ... end`.
* Extrae objetos (`edit ... next`) y parámetros (`set ...`).
* Genera Índice con hipervínculos.
* Secciones cubiertas:

  * Información General del Sistema
  * Usuarios Administrativos
  * Interfaces de Red
  * Configuración NTP
  * Objetos de Dirección
  * Servicios de Firewall
  * Políticas de Firewall
  * NAT (VIPs e IP Pools)
  * Rutas Estáticas
  * VPN IPsec (Phase1 / Phase2)
* Formato Markdown limpio para revisión rápida.
* Excel con:

  * Hoja Índice con hipervínculos.
  * Pestañas por sección, cada una como *Excel Table* (bordes, filas alternadas).
  * Títulos fusionados, encabezados en negrita, texto envuelto.
  * Congelación de paneles y autofiltros.
  * Colores de pestañas para cada sección.

---

## Requisitos

* Python 3.7 o superior
* Pandas
* XlsxWriter

Instalación rápida de dependencias:

```bash
pip install pandas xlsxwriter
```

---

## Uso

Ejecuta `fortisox.py` pasando como primer argumento el archivo de configuración `.conf` y luego una o más salidas:

```bash
# Solo Markdown
python3 fortisox.py firewall.conf reporte.md

# Solo Excel
python3 fortisox.py firewall.conf auditoria.xlsx

# Ambos simultáneamente
python3 fortisox.py firewall.conf reporte.md auditoria.xlsx
```

---

## Autor

Sergio Cayuqueo ([cayu@cayu.com.ar](mailto:cayu@cayu.com.ar))

---

## Licencia

MIT © Sergio Cayuqueo
