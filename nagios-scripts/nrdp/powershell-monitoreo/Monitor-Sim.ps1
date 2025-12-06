# --- 1. CARGA DE CONFIGURACIÓN ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"
if (-not (Test-Path $JsonPath)) { Write-Error "Falta nrdp_config.json"; exit 1 }
$Cfg = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

Import-Module "$PSScriptRoot\Send-NRDP.psm1" -Force

# Función auxiliar para extraer datos de netsh con Regex
function Get-Val($txt, $key) { ($txt | Select-String "$key\s*:\s*(.*)").Matches.Groups[1].Value.Trim() }

try {
    # --- 2. OBTENER DATOS DE HARDWARE (Netsh) ---
    $rawInt = netsh mbn show interface | Out-String
    $Nombre = Get-Val $rawInt "Name"
    
    if (-not $Nombre) { throw "No se detectó módem/SIM activo." }
    
    $rawSub = netsh mbn show subscriber interface="$Nombre" | Out-String
    
    # Extraemos datos clave
    $Modelo    = Get-Val $rawInt "Model"
    $IMEI      = Get-Val $rawInt "Device Id"
    $SignalStr = Get-Val $rawInt "Signal"       # Ej: "85%"
    $Estado    = Get-Val $rawInt "State"
    $NumSIM    = Get-Val $rawSub "Telephone number"
    $Proveedor = Get-Val $rawSub "Provider Name"

    # Limpiamos el valor de señal para graficar (quitar el %)
    $SignalVal = if ($SignalStr -match "(\d+)") { $matches[1] } else { 0 }

    # --- 3. OBTENER TRÁFICO INSTANTÁNEO (WMI) ---
    # Buscamos la interfaz de red asociada para medir velocidad
    $adapter = Get-NetAdapter | Where-Object { $_.Name -eq $Nombre -or $_.InterfaceDescription -match $Modelo } | Select-Object -First 1
    
    $SpeedIn = 0; $SpeedOut = 0; $SpeedInMbps = 0; $SpeedOutMbps = 0

    if ($adapter) {
        # Usamos contadores WMI para obtener la velocidad exacta en este segundo
        $perfName = $adapter.Name -replace '[^a-zA-Z0-9]', ''
        $perf = Get-WmiObject Win32_PerfFormattedData_Tcpip_NetworkInterface | 
                Where-Object { $_.Name -replace '[^a-zA-Z0-9]', '' -match $perfName } | Select-Object -First 1
        
        if ($perf) {
            $SpeedIn  = ($perf.BytesReceivedPerSec * 8)
            $SpeedOut = ($perf.BytesSentPerSec * 8)
            $SpeedInMbps  = [math]::Round($SpeedIn / 1Mb, 2)
            $SpeedOutMbps = [math]::Round($SpeedOut / 1Mb, 2)
        }
    }

    # --- 4. DEFINIR ESTADO NAGIOS ---
    # Estado simple: Si está conectado es OK. Si la señal es muy baja (<20%), es WARNING.
    $State = 0; $Msg = "OK"

    if ($Estado -ne "Connected" -and $Estado -ne "Conectado") {
        $State = 2; $Msg = "CRITICAL (Sin Conexión)"
    }
    elseif ($SignalVal -lt 20) {
        $State = 1; $Msg = "WARNING (Baja Señal)"
    }

    # --- 5. FORMATO DE SALIDA ---
    # Línea 1: Resumen rápido
    $Output = "$Msg - $Proveedor (Señal: $SignalStr) - Tráfico: In ${SpeedInMbps}Mbps / Out ${SpeedOutMbps}Mbps"
    
    # Línea 2: Detalles de Inventario (Multilínea)
    $Output += "`n[Hardware] Modelo: $Modelo | IMEI: $IMEI | SIM: $NumSIM"

    # --- 6. PERFDATA (Para Graficar) ---
    # Graficamos 3 cosas: Velocidad de Bajada, Subida y Fuerza de Señal
    $Perf = "traffic_in=$($SpeedIn)bps;;;; traffic_out=$($SpeedOut)bps;;;; signal_strength=$($SignalVal)%;20;10;0;100"
    
    $Final = "$Output | $Perf"

}
catch {
    $State = 3; $Final = "UNKNOWN - Error SIM Lite: $_"
}

# --- 7. ENVÍO ---
Send-NRDP -NRDPUrl $Cfg.NRDPUrl -Token $Cfg.Token -User $Cfg.User -Password $Cfg.Password `
          -Service "SIM Status" -State $State -Output $Final
