use std::collections::HashMap;
use std::fs::File;
use std::process;

use clap::Parser;
use pcap::{Capture, Device, Offline};
use serde::Deserialize;

/// Argumentos de línea de comandos
#[derive(Parser)]
#[command(author, version, about = "Rust Network Inventory desde PCAP")]
struct Args {
    /// Archivo PCAP de entrada
    #[arg(short, long, required_unless_present("iface"))]
    pcap: Option<String>,

    /// Interfaz de red para sniffing en vivo
    #[arg(short, long, required_unless_present("pcap"))]
    iface: Option<String>,

    /// Ruta al archivo JSON de fabricantes OUI (por defecto: mac-vendors-export.json)
    #[arg(short = 'j', long, default_value = "mac-vendors-export.json")]
    oui_db: String,
}

/// Estructura para leer cada fabricante desde el JSON de mac-vendors-export.json
#[derive(Deserialize)]
struct Manufacturer {
    #[serde(rename = "macPrefix")]
    prefix: String,
    #[serde(rename = "vendorName")]
    name: String,
}

fn main() {
    let args = Args::parse();

    // Cargar la base de datos OUI desde el JSON
    let file = File::open(&args.oui_db).unwrap_or_else(|e| {
        eprintln!("Error al abrir {}: {}", &args.oui_db, e);
        process::exit(1);
    });

    // Deserializar array de registros
    let manufacturers: Vec<Manufacturer> = serde_json::from_reader(file).unwrap_or_else(|e| {
        eprintln!("Error al parsear JSON {}: {}", &args.oui_db, e);
        process::exit(1);
    });

    // Construir mapa OUI -> Manufacturer
    let mut oui_map: HashMap<String, Manufacturer> = HashMap::new();
    for m in manufacturers {
        oui_map.insert(m.prefix.clone(), m);
    }

    // Inventario: clave = MAC, valor = (vendor, conteo)
    let mut inventory: HashMap<String, (String, u64)> = HashMap::new();

    if let Some(pcap_path) = args.pcap {
        // Modo lectura de archivo PCAP (Offline)
        println!("Procesando archivo PCAP: {}", pcap_path);
        let mut cap = Capture::<Offline>::from_file(&pcap_path).unwrap_or_else(|e| {
            eprintln!("Error al abrir PCAP {}: {}", pcap_path, e);
            process::exit(1);
        });
        process_offline(&mut cap, &oui_map, &mut inventory);
    } else if let Some(iface_name) = args.iface {
        // Modo sniffer en vivo (Active)
        println!("Iniciando captura en interfaz: {}", iface_name);
        // Buscar dispositivo por nombre
        let device = Device::list().unwrap_or_else(|e| {
            eprintln!("Error listando dispositivos: {}", e);
            process::exit(1);
        })
        .into_iter()
        .find(|d| d.name == iface_name)
        .unwrap_or_else(|| {
            eprintln!("Interfaz {} no encontrada", iface_name);
            process::exit(1);
        });
        // Crear captura activa: FromDevice -> Inactive -> .open() -> Active
        let mut cap = Capture::from_device(device).unwrap_or_else(|e| {
            eprintln!("Error al preparar dispositivo {}: {}", iface_name, e);
            process::exit(1);
        })
        .promisc(true)
        .open()
        .unwrap_or_else(|e| {
            eprintln!("Error iniciando captura en {}: {}", iface_name, e);
            process::exit(1);
        });
        process_live(&mut cap, &oui_map, &mut inventory);
    }

    // Mostrar inventario
    println!("\n----- Inventario de Dispositivos -----");
    println!("MAC Address, Vendor, Count");
    for (mac, (vendor, count)) in &inventory {
        println!("{}, {}, {}", mac, vendor, count);
    }
}

/// Procesa paquetes de una captura offline (archivo PCAP)
fn process_offline(
    cap: &mut Capture<Offline>,
    oui_map: &HashMap<String, Manufacturer>,
    inventory: &mut HashMap<String, (String, u64)>,
) {
    while let Ok(packet) = cap.next_packet() {
        handle_packet(&packet.data, oui_map, inventory);
    }
}

/// Procesa paquetes de una captura en vivo (sniffer)
fn process_live(
    cap: &mut Capture<pcap::Active>,
    oui_map: &HashMap<String, Manufacturer>,
    inventory: &mut HashMap<String, (String, u64)>,
) {
    while let Ok(packet) = cap.next_packet() {
        handle_packet(&packet.data, oui_map, inventory);
    }
}

/// Maneja un único paquete: extrae MACs, busca fabricante y actualiza inventario
fn handle_packet(
    data: &[u8],
    oui_map: &HashMap<String, Manufacturer>,
    inventory: &mut HashMap<String, (String, u64)>,
) {
    // Verificamos que haya al menos cabecera Ethernet (14 bytes)
    if data.len() < 14 {
        return;
    }
    let dst = &data[0..6];
    let src = &data[6..12];
    // Convertimos a string con formato "aa:bb:cc:dd:ee:ff"
    let src_mac = format!(
        "{:02x}:{:02x}:{:02x}:{:02x}:{:02x}:{:02x}",
        src[0], src[1], src[2], src[3], src[4], src[5]
    );
    let dst_mac = format!(
        "{:02x}:{:02x}:{:02x}:{:02x}:{:02x}:{:02x}",
        dst[0], dst[1], dst[2], dst[3], dst[4], dst[5]
    );

    for mac in &[src_mac.clone(), dst_mac.clone()] {
        let parts: Vec<&str> = mac.split(':').collect();
        if parts.len() != 6 {
            continue;
        }
        // Construir clave OUI con separadores para coincidir con json
        let oui_key = format!(
            "{}:{}:{}",
            parts[0].to_uppercase(),
            parts[1].to_uppercase(),
            parts[2].to_uppercase()
        );
        let vendor = oui_map
            .get(&oui_key)
            .map(|m| m.name.clone())
            .unwrap_or_else(|| "Unknown".to_string());

        // Actualizar inventario: incrementar conteo o insertar
        let entry = inventory.entry(mac.clone()).or_insert((vendor.clone(), 0));
        entry.0 = vendor;
        entry.1 += 1;
    }
}
