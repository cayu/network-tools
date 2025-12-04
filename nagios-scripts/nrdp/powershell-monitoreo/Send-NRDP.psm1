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
    if (-not [string]::IsNullOrWhiteSpace($User) -and -not [string]::IsNullOrWhiteSpace($Password)) {
        $pair = "${User}:${Password}"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
        $encoded = [Convert]::ToBase64String($bytes)
        $headers["Authorization"] = "Basic $encoded"
    }

    $body = @{ token = $Token; cmd = "submitcheck"; XMLDATA = $xml }

    for ($i=1; $i -le $RetryCount; $i++) {
        try {
            $response = Invoke-RestMethod -Uri $NRDPUrl -Method Post -Headers $headers -Body $body -TimeoutSec $TimeoutSec -ErrorAction Stop
            Write-Host "[OK] '$Service' enviado. (Intento $i)" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "[ERROR] Fallo '$Service' (Intento $i/$RetryCount): $($_.Exception.Message)" -ForegroundColor Red
            if ($i -lt $RetryCount) { Start-Sleep -Seconds 3 }
        }
    }
    return $false
}
Export-ModuleMember -Function Send-NRDP
