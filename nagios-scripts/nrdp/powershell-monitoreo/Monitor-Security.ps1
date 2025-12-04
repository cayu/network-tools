
# --- CARGA DE CONFIGURACIÓN ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"
if (-not (Test-Path $JsonPath)) { Write-Error "Config file not found: $JsonPath"; exit 1 }
$Cfg = Get-Content $JsonPath -Raw | ConvertFrom-Json

Import-Module "$PSScriptRoot\Send-NRDP.psm1" -Force


$events = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625; StartTime=(Get-Date).AddHours(-1)} -ErrorAction SilentlyContinue
if ($events) {
    $count = $events.Count
    $fs = 2
    $out = "SECURITY ALERT: $count failed logins detected in last hour!"
} else {
    $fs = 0
    $out = "Security OK: No failed logins recently."
}
Send-NRDP -NRDPUrl $Cfg.NRDPUrl -Token $Cfg.Token -User $Cfg.User -Password $Cfg.Password -Service "Security Events" -State $fs -Output $out
