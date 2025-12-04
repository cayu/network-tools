# =============================================================================
# NOMBRE: Monitor-Bandwidth.ps1
# DESCRIPCIÓN: Monitorea ancho de banda y genera Performance Data para gráficas.
# =============================================================================

# --- 1. CARGA DE CONFIGURACIÓN ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"
if (-not (Test-Path $JsonPath)) { Write-Error "Config file not found"; exit 1 }
$Cfg = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

Import-Module "$PSScriptRoot\Send-NRDP.psm1" -Force

# --- 2. PARÁMETROS DE UMBRAL (Modificar si es necesario) ---
$WarnPct = 80  # Alerta Warning al 80% de uso del ancho de banda
$CritPct = 90  # Alerta Critical al 90% de uso del ancho de banda

# --- 3. LÓGICA DE MONITOREO ---
try {
    # Buscamos la interfaz activa (BytesTotal > 0 y Ancho de banda > 0)
    # Win32_PerfFormattedData ya nos da el cálculo por segundo (no hace falta diff de tiempo)
    $nic = Get-WmiObject Win32_PerfFormattedData_Tcpip_NetworkInterface | 
           Where-Object { $_.BytesTotalPerSec -gt 0 -and $_.CurrentBandwidth -gt 0 } | 
           Sort-Object BytesTotalPerSec -Descending | 
           Select-Object -First 1

    if (-not $nic) {
        throw "No active network interface found."
    }

    # -- CÁLCULOS --
    # Nota: WMI devuelve Bytes, las redes se miden en Bits (x8)
    $SpeedBits = $nic.CurrentBandwidth
    $InBits    = $nic.BytesReceivedPerSec * 8
    $OutBits   = $nic.BytesSentPerSec * 8

    # Porcentajes
    $InPct  = [math]::Round(($InBits / $SpeedBits) * 100, 2)
    $OutPct = [math]::Round(($OutBits / $SpeedBits) * 100, 2)

    # Conversión humana (para el texto legible)
    $SpeedMbps = [math]::Round($SpeedBits / 1Mb, 0)
    $InMbps    = [math]::Round($InBits / 1Mb, 2)
    $OutMbps   = [math]::Round($OutBits / 1Mb, 2)
    
    # Limpieza del nombre de la interfaz
    $Name = $nic.Name -replace '[^a-zA-Z0-9\s]', ''

    # -- ESTADO (Nagios Logic) --
    $State = 0
    $StatusMsg = "OK"

    if ($InPct -ge $CritPct -or $OutPct -ge $CritPct) {
        $State = 2
        $StatusMsg = "CRITICAL"
    }
    elseif ($InPct -ge $WarnPct -or $OutPct -ge $WarnPct) {
        $State = 1
        $StatusMsg = "WARNING"
    }

    # -- TEXTO DE SALIDA (Lo que lee el humano) --
    $TextOutput = "$StatusMsg - Interface: '$Name' ($SpeedMbps Mbps) - In: $InMbps Mbps ($InPct%) - Out: $OutMbps Mbps ($OutPct%)"

    # -- PERFORMANCE DATA (Lo que lee PNP4Nagios) --
    # Sintaxis: label=value[UOM];[warn];[crit];[min];[max]
    # Calculamos los valores absolutos para warn/crit en bits para la gráfica
    $WarnBits = ($SpeedBits * ($WarnPct / 100))
    $CritBits = ($SpeedBits * ($CritPct / 100))

    # Importante: Usamos el PIPE '|' para separar texto de datos
    # Usamos 'bits' o 'bps' como unidad.
    $PerfData = "in_bps=$($InBits)bps;$WarnBits;$CritBits;0;$SpeedBits out_bps=$($OutBits)bps;$WarnBits;$CritBits;0;$SpeedBits"

    $FinalOutput = "$TextOutput | $PerfData"

}
catch {
    $State = 3
    $FinalOutput = "UNKNOWN - Error checking bandwidth: $_"
}

# --- 4. ENVÍO ---
# Usamos el módulo con la configuración cargada
Send-NRDP -NRDPUrl $Cfg.NRDPUrl `
          -Token $Cfg.Token `
          -User $Cfg.User `
          -Password $Cfg.Password `
          -Service "Network Bandwidth" `
          -State $State `
          -Output $FinalOutput