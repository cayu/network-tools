
# --- CARGA DE CONFIGURACIÓN ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"
if (-not (Test-Path $JsonPath)) { Write-Error "Config file not found: $JsonPath"; exit 1 }
$Cfg = Get-Content $JsonPath -Raw | ConvertFrom-Json

Import-Module "$PSScriptRoot\Send-NRDP.psm1" -Force


try {
    $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    $cpu = [math]::Round($cpu, 1)
    if ($cpu -gt 90) { $s=2; $m="CRITICAL" } elseif ($cpu -gt 75) { $s=1; $m="WARNING" } else { $s=0; $m="OK" }
#    $out = "$m - CPU Load: $cpu%"
    $out = "$m - CPU Load: $cpu% | cpu=${cpu}%;75;90;0;100"
} catch { $s=3; $out="UNKNOWN: $_" }

Send-NRDP -NRDPUrl $Cfg.NRDPUrl -Token $Cfg.Token -User $Cfg.User -Password $Cfg.Password -Service "CPU Load" -State $s -Output $out
