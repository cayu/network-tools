
# --- CARGA DE CONFIGURACIÓN ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"
if (-not (Test-Path $JsonPath)) { Write-Error "Config file not found: $JsonPath"; exit 1 }
$Cfg = Get-Content $JsonPath -Raw | ConvertFrom-Json

Import-Module "$PSScriptRoot\Send-NRDP.psm1" -Force


try {
    $mem = Get-CimInstance Win32_OperatingSystem
    $used = [math]::Round((($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize) * 100, 2)
    if ($used -gt 90) { $s=2; $m="CRITICAL" } elseif ($used -gt 75) { $s=1; $m="WARNING" } else { $s=0; $m="OK" }
    $out = "$m - RAM Usage: $used%"
} catch { $s=3; $out="UNKNOWN: $_" }
Send-NRDP -NRDPUrl $Cfg.NRDPUrl -Token $Cfg.Token -User $Cfg.User -Password $Cfg.Password -Service "RAM Usage" -State $s -Output $out
