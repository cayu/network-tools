function Send-NRDP {
    param(
        [Parameter(Mandatory=$true)] [string]$NRDPUrl,
        [Parameter(Mandatory=$true)] [string]$Token,
        [string]$User,      
        [string]$Password,  
        [string]$Hostname = $env:COMPUTERNAME,
        [Parameter(Mandatory=$true)] [string]$Service,
        [Parameter(Mandatory=$true)] [int]$State,
        [Parameter(Mandatory=$true)] [string]$Output,
        [int]$RetryCount = 3,
        [int]$TimeoutSec = 15
    )

    # ============================================================
    # BLOQUE DE LOGGING (VERBOSE)
    # Esto imprime en la consola los datos antes de enviarlos
    # ============================================================
    $Color = "Cyan"
    if ($State -eq 1) { $Color = "Yellow" }
    if ($State -eq 2) { $Color = "Red" }

    Write-Host "------------------------------------------------------------" -ForegroundColor Gray
    Write-Host " PREPARANDO ENVIO A NAGIOS (NRDP)" -ForegroundColor $Color
    Write-Host "------------------------------------------------------------" -ForegroundColor Gray
    Write-Host " Host:    $Hostname"
    Write-Host " Service: $Service"
    Write-Host " State:   $State (0=OK, 1=WARN, 2=CRIT)"
    Write-Host " Output:  $Output"
    Write-Host "------------------------------------------------------------" -ForegroundColor Gray
    # ============================================================

    $xml = @"
<?xml version='1.0'?>
<checkresults>
  <checkresult type='service'>
    <hostname>$Hostname</hostname>
    <servicename>$Service</servicename>
    <state>$State</state>
    <output>$Output</output>
  </checkresult>
</checkresults>
"@

    $headers = @{}
    # Forzamos TLS 1.2 por compatibilidad y seguridad
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    if (-not [string]::IsNullOrWhiteSpace($User) -and -not [string]::IsNullOrWhiteSpace($Password)) {
        $pair = "${User}:${Password}"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $encoded = [Convert]::ToBase64String($bytes)
        $headers["Authorization"] = "Basic $encoded"
    }

    $body = @{ token = $Token; cmd = "submitcheck"; XMLDATA = $xml }

    for ($i=1; $i -le $RetryCount; $i++) {
        try {
            Write-Host " -> Conectando a $NRDPUrl (Intento $i)..." -NoNewline
            
            $response = Invoke-RestMethod -Uri $NRDPUrl -Method Post -Headers $headers -Body $body -TimeoutSec $TimeoutSec -ErrorAction Stop
            
            Write-Host " [ENVIADO OK]" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host " [FALLO]" -ForegroundColor Red
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor DarkRed
            if ($i -lt $RetryCount) { Start-Sleep -Seconds 3 }
        }
    }
    return $false
}
Export-ModuleMember -Function Send-NRDP
