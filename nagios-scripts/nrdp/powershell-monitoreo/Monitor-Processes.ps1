
# --- CARGA DE CONFIGURACIÓN ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"
if (-not (Test-Path $JsonPath)) { Write-Error "Config file not found: $JsonPath"; exit 1 }
$Cfg = Get-Content $JsonPath -Raw | ConvertFrom-Json

Import-Module "$PSScriptRoot\Send-NRDP.psm1" -Force


$procs = "lsass","wininit","services","explorer"
$out=""; $fs=0
foreach ($p in $procs) {
    if (-not (Get-Process -Name $p -ErrorAction SilentlyContinue)) {
        $out += "$p MISSING! "; $fs=2
    } else { $out += "$p OK. " }
}
Send-NRDP -NRDPUrl $Cfg.NRDPUrl -Token $Cfg.Token -User $Cfg.User -Password $Cfg.Password -Service "Critical Processes" -State $fs -Output $out
