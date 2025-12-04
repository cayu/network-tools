# =============================================================================
# NOMBRE: Monitor-Host.ps1
# DESCRIPCIÓN: Envía una señal de "Host UP" a Nagios NRDP.
#              Esto actualiza el estado del HOST (no de un servicio).
# =============================================================================

# --- 1. CARGA DE CONFIGURACIÓN ---
$JsonPath = "$PSScriptRoot\nrdp_config.json"

if (-not (Test-Path $JsonPath)) {
    Write-Error "Error: No se encontró el archivo de configuración en $JsonPath"
    exit 1
}

# Forzamos codificación UTF8 para evitar errores de JSON
$Cfg = Get-Content $JsonPath -Raw -Encoding UTF8 | ConvertFrom-Json

# Datos del Host
$Hostname = $env:COMPUTERNAME
$State    = 0                          # 0=UP, 1=DOWN, 2=UNREACHABLE
$Output   = "Host is UP (NRDP Agent)"  # Mensaje que se verá en Nagios

# --- 2. CONSTRUCCIÓN DEL XML (Específico para HOST) ---
# Nota: La diferencia clave es type='host' y la ausencia de <servicename>
$xml = @"
<?xml version='1.0'?>
<checkresults>
  <checkresult type='host'>
    <hostname>$Hostname</hostname>
    <state>$State</state>
    <output>$Output</output>
  </checkresult>
</checkresults>
"@

# --- 3. PREPARACIÓN DE HEADERS (Basic Auth) ---
$headers = @{}
if (-not [string]::IsNullOrWhiteSpace($Cfg.User) -and -not [string]::IsNullOrWhiteSpace($Cfg.Password)) {
    $pair = "${($Cfg.User)}:${($Cfg.Password)}"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
    $encoded = [Convert]::ToBase64String($bytes)
    $headers["Authorization"] = "Basic $encoded"
}

# --- 4. ENVÍO A NRDP ---
$body = @{
    token   = $Cfg.Token
    cmd     = "submitcheck"
    XMLDATA = $xml
}

Write-Host "Enviando Host Check para '$Hostname'..." -NoNewline

try {
    $response = Invoke-RestMethod -Uri $Cfg.NRDPUrl -Method Post -Headers $headers -Body $body -TimeoutSec 15 -ErrorAction Stop
    Write-Host " [OK]" -ForegroundColor Green
}
catch {
    Write-Host " [ERROR]" -ForegroundColor Red
    Write-Host "   Detalle: $($_.Exception.Message)" -ForegroundColor DarkRed
}
