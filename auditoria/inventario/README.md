# 🦀 Rust Network Inventory desde PCAP

Herramienta en **Rust** para generar un **inventario de dispositivos de red** a partir de:
- Archivos **PCAP** (capturas de tráfico),
- o tráfico **en vivo** desde una interfaz de red.

Identifica dispositivos por sus **direcciones MAC** y asocia cada una a su **fabricante (vendor)** usando una base de datos **OUI JSON** (como la de [maclookup.app](https://maclookup.app/downloads/json-database)).

---

## 🚀 Características

- Lee archivos `.pcap` o captura en vivo desde una interfaz.
- Extrae direcciones MAC de origen y destino de cada trama Ethernet.
- Busca el **fabricante** (OUI) de cada dirección.
- Mantiene un **inventario** de dispositivos únicos con su conteo de apariciones.
- Soporta base de datos de fabricantes en formato JSON (`mac-vendors-export.json`).

---

## ⚙️ Requisitos

- **Rust 1.70+** (instalar desde [https://rustup.rs](https://rustup.rs))
- Librerías del sistema para `libpcap` (en Linux/MacOS):

  ```bash
  sudo apt install libpcap-dev
  ```

- Archivo de base de datos de fabricantes:  
  👉 [Descargar JSON actualizado](https://maclookup.app/downloads/json-database)

---

## 📦 Dependencias (Cargo.toml)

Asegúrate de tener las siguientes dependencias en tu `Cargo.toml`:

```toml
[dependencies]
clap = { version = "4", features = ["derive"] }
pcap = "1"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

---

## 🧩 Uso

Compilá el proyecto:

```bash
cargo build --release
```

### 🔹 Modo 1: Analizar un archivo PCAP

```bash
./target/release/network_inventory --pcap captura.pcap
```

### 🔹 Modo 2: Capturar en vivo desde una interfaz

```bash
sudo ./target/release/network_inventory --iface eth0
```

### 🔹 Opcional: Especificar otra base de datos de fabricantes

```bash
./target/release/network_inventory --pcap red.pcap --oui-db vendors.json
```

---

## 📊 Salida

El programa imprime el inventario final en formato CSV:

```
----- Inventario de Dispositivos -----
MAC Address, Vendor, Count
00:11:22:33:44:55, Cisco Systems, 20
a4:5e:60:7b:9d:10, Unknown, 3
fc:aa:14:bb:88:01, Hewlett Packard, 5
```

---

## 🧠 Estructura interna

| Módulo | Función |
|--------|----------|
| `Args` | Define los argumentos de CLI con `clap`. |
| `Manufacturer` | Estructura de fabricantes para leer el JSON. |
| `process_offline()` | Procesa un archivo PCAP. |
| `process_live()` | Captura paquetes en tiempo real. |
| `handle_packet()` | Extrae MACs, busca fabricante y actualiza inventario. |

---

## 🧪 Ejemplo rápido

```bash
# Descargar OUI database
wget https://maclookup.app/downloads/json-database -O mac-vendors-export.json

# Ejecutar análisis sobre captura existente
cargo run -- --pcap ejemplo.pcap
```

---

## 🧰 Notas técnicas

- Las direcciones MAC se formatean como `aa:bb:cc:dd:ee:ff`.
- Los tres primeros bytes se usan como OUI key (`AA:BB:CC`) en mayúsculas.
- El inventario se almacena en un `HashMap<String, (String, u64)>`, donde:
  - Clave = MAC Address  
  - Valor = (Vendor, Conteo de apariciones)
