
# --- 1. CONFIG ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"
if (-not (Test-Path $JsonPath)) { Write-Error "Falta nrdp_config.json"; exit 1 }
$Cfg = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

Import-Module "$PSScriptRoot\Send-NRDP.psm1" -Force

# --- 2. FUNCIÓN MULTI-IDIOMA ---
function Get-Val {
    param (
        [string]$Text,
        [string[]]$Keys
    )

    foreach ($key in $Keys) {
        $m = $Text | Select-String -Pattern "$key\s*:\s*(.+)"
        if ($m) {
            return $m.Matches[0].Groups[1].Value.Trim()
        }
    }
    return "N/A"
}

try {
    # --- 3. NETSH ---
    $rawInt = netsh mbn show interface | Out-String

    $Nombre = Get-Val $rawInt @("Name","Nombre")
    if ($Nombre -eq "N/A") {
        throw "No se detectó interfaz WWAN"
    }

    # --- 4. DATOS WWAN ---
    $Datos = @{
        # Identidad HW
        IMEI        = Get-Val $rawInt @("Device Id","Id\. de dispositivo")
        Fabricante  = Get-Val $rawInt @("Manufacturer","Fabricante")
        Modelo      = Get-Val $rawInt @("Model","Modelo")
        Firmware    = Get-Val $rawInt @("Firmware Version","Versión de firmware")
        ClaseMovil  = Get-Val $rawInt @("Mobile class","Clase de teléfono móvil")
        MAC         = Get-Val $rawInt @("Physical address","Dirección física")
        TipoHW      = Get-Val $rawInt @("Device type","Tipo de dispositivo")

        # Estado / Red
        Estado      = Get-Val $rawInt @("State","Estado")
        Proveedor   = Get-Val $rawInt @("Provider Name","Nombre del proveedor")
        Roaming     = Get-Val $rawInt @("Roaming","Itinerancia")

        # Señal
        SenalPct    = Get-Val $rawInt @("Signal","Señal")
        RSSIraw     = Get-Val $rawInt @("RSSI/RSCP")
    }

    # --- 5. NORMALIZACIÓN SEÑAL ---
    # % señal
    $SignalPctVal = 0
    if ($Datos.SenalPct -match "(\d+)") {
        $SignalPctVal = [int]$matches[1]
    }

    # RSSI dBm
    $RSSI = $null
    if ($Datos.RSSIraw -match "\((-?\d+)\s*dBm\)") {
        $RSSI = [int]$matches[1]
    }

    # --- 6. ESTADO ---
    $State = 0
    $Msg   = "OK"

    if ($Datos.Estado -notin @("Connected","Conectado")) {
        $State = 2
        $Msg   = "CRITICAL - Desconectado"
    }

    if ($RSSI -ne $null -and $State -eq 0) {
        if ($RSSI -lt -100) {
            $State = 2
            $Msg   = "CRITICAL - Señal muy débil"
        }
        elseif ($RSSI -lt -85) {
            $State = 1
            $Msg   = "WARNING - Señal baja"
        }
    }

    # --- 7. OUTPUT ---
    $Output = "$Msg - Prov: $($Datos.Proveedor) IMEI: $($Datos.IMEI) Señal: $SignalPctVal% ($RSSI dBm)"
    $Output += "`n[HW] $($Datos.Modelo) FW: $($Datos.Firmware) $($Datos.ClaseMovil) Roaming: $($Datos.Roaming)"

    # --- 8. PERFDATA ---
    $Perf = @()
    $Perf += "signal_pct=$SignalPctVal%;20;10;0;100"
    if ($RSSI -ne $null) {
        $Perf += "rssi=$RSSI;-85;-100;-120;-50"
    }

    $Final = "$Output | " + ($Perf -join " ")
}
catch {
    $State = 3
    $Final = "UNKNOWN - Error NETSH MBN: $_"
}

# --- 9. ENVÍO NRDP ---
Send-NRDP `
    -NRDPUrl $Cfg.NRDPUrl `
    -Token $Cfg.Token `
    -User $Cfg.User `
    -Password $Cfg.Password `
    -Service "WWAN Radio" `
    -State $State `
    -Output $Final
