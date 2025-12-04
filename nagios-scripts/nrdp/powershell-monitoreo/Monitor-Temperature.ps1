
# --- CARGA DE CONFIGURACIÓN ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"
if (-not (Test-Path $JsonPath)) { Write-Error "Config file not found: $JsonPath"; exit 1 }
$Cfg = Get-Content $JsonPath -Raw | ConvertFrom-Json

Import-Module "$PSScriptRoot\Send-NRDP.psm1" -Force


$out=""; $fs=0; $found=$false
try {
    $temps = Get-WmiObject MSAcpi_ThermalZoneTemperature -Namespace "root/wmi" -ErrorAction SilentlyContinue
    if ($temps) {
        foreach ($t in $temps) {
            $c = ($t.CurrentTemperature / 10) - 273.15
            $ln = "Sensor $($t.InstanceName): $([math]::Round($c,1))C"
            if ($c -gt 85) { $fs=2; $ln+=" (CRIT)" } elseif ($c -gt 70 -and $fs -ne 2) { $fs=1; $ln+=" (WARN)" }
            $out += "$ln | "
            $found=$true
        }
    }
} catch {}
if (-not $found) { $out="Sensors not available"; $fs=0 }
Send-NRDP -NRDPUrl $Cfg.NRDPUrl -Token $Cfg.Token -User $Cfg.User -Password $Cfg.Password -Service "Temperature" -State $fs -Output $out
