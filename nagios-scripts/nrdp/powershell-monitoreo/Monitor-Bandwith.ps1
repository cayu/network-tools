# =============================================================================
# NOMBRE: Monitor-Bandwidth.ps1
# DESCRIPCIÓN: Monitorea ancho de banda y genera Performance Data.
# VERSIÓN: 2.0 (Filtro mejorado para interfaces en reposo)
# =============================================================================

# --- 1. CARGA DE CONFIGURACIÓN ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"
if (-not (Test-Path $JsonPath)) { Write-Error "Config file not found"; exit 1 }
$Cfg = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

Import-Module "$PSScriptRoot\Send-NRDP.psm1" -Force

# --- 2. PARÁMETROS DE UMBRAL ---
$WarnPct = 80
$CritPct = 90

# --- 3. LÓGICA DE MONITOREO ---
try {
    # CORRECCIÓN:
    # 1. Eliminamos el filtro "BytesTotalPerSec -gt 0" para detectar interfaces aunque estén idle.
    # 2. Ordenamos por Ancho de Banda (para preferir la de 1Gbps sobre interfaces virtuales lentas).
    # 3. Luego ordenamos por Tráfico (para preferir la que tenga actividad si hay empate).
    
    $nics = Get-WmiObject Win32_PerfFormattedData_Tcpip_NetworkInterface | 
            Where-Object { $_.CurrentBandwidth -gt 0 } | 
            Sort-Object CurrentBandwidth, BytesTotalPerSec -Descending

    # Seleccionamos la primera (la más rápida/activa)
    $nic = $nics | Select-Object -First 1

    if (-not $nic) {
        # Si falla, listamos qué ve WMI para debug en el mensaje de error
        $debugList = Get-WmiObject Win32_PerfFormattedData_Tcpip_NetworkInterface | Select -ExpandProperty Name
        throw "No valid interface found. WMI sees: $($debugList -join ', ')"
    }

    # -- CÁLCULOS --
    $SpeedBits = $nic.CurrentBandwidth
    
    # Validación anti-división por cero (aunque el filtro lo evita, seguridad extra)
    if ($SpeedBits -eq 0) { $SpeedBits = 100000000 } # Asumir 100Mbps si falla

    $InBits    = $nic.BytesReceivedPerSec * 8
    $OutBits   = $nic.BytesSentPerSec * 8

    # Porcentajes
    $InPct  = [math]::Round(($InBits / $SpeedBits) * 100, 2)
    $OutPct = [math]::Round(($OutBits / $SpeedBits) * 100, 2)

    # Conversión humana
    $SpeedMbps = [math]::Round($SpeedBits / 1Mb, 0)
    $InMbps    = [math]::Round($InBits / 1Mb, 2)
    $OutMbps   = [math]::Round($OutBits / 1Mb, 2)
    
    # Limpieza del nombre (quitar caracteres raros como #, (, ))
    $Name = $nic.Name -replace '[^a-zA-Z0-9\s]', ''

    # -- ESTADO --
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

    # -- SALIDA --
    $TextOutput = "$StatusMsg - Interface: '$Name' ($SpeedMbps Mbps) - In: $InMbps Mbps ($InPct%) - Out: $OutMbps Mbps ($OutPct%)"

    # -- PERF DATA --
    $WarnBits = ($SpeedBits * ($WarnPct / 100))
    $CritBits = ($SpeedBits * ($CritPct / 100))
    
    # Formato: label=value[UOM];[warn];[crit];[min];[max]
    $PerfData = "in_bps=$($InBits)bps;$WarnBits;$CritBits;0;$SpeedBits out_bps=$($OutBits)bps;$WarnBits;$CritBits;0;$SpeedBits"

    $FinalOutput = "$TextOutput | $PerfData"

}
catch {
    $State = 3
    $FinalOutput = "UNKNOWN - Error checking bandwidth: $_"
}

# --- 4. ENVÍO ---
Send-NRDP -NRDPUrl $Cfg.NRDPUrl `
          -Token $Cfg.Token `
          -User $Cfg.User `
          -Password $Cfg.Password `
          -Service "Network Bandwidth" `
          -State $State `
          -Output $FinalOutput
