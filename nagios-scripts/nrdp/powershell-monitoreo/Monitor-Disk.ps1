
# --- CARGA DE CONFIGURACIÓN ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"
if (-not (Test-Path $JsonPath)) { Write-Error "Config file not found: $JsonPath"; exit 1 }
$Cfg = Get-Content $JsonPath -Raw | ConvertFrom-Json

Import-Module "$PSScriptRoot\Send-NRDP.psm1" -Force


$out=""; $fs=0
Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    if ($_.Size -gt 0) {
        $pct = [math]::Round(($_.FreeSpace/$_.Size)*100, 1)
        $ln = "$($_.DeviceID) Free: $pct%"
        if ($pct -lt 5) { $fs=2; $ln+=" (CRIT)" } elseif ($pct -lt 15 -and $fs -ne 2) { $fs=1; $ln+=" (WARN)" }
        $out += "$ln | "
    }
}
if ($out -eq "") { $out="No disks"; $fs=3 }
Send-NRDP -NRDPUrl $Cfg.NRDPUrl -Token $Cfg.Token -User $Cfg.User -Password $Cfg.Password -Service "Disk Space" -State $fs -Output $out
