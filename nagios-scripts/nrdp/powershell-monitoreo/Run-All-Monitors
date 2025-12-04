# =============================================================================
# NOMBRE: Run-All-Monitors.ps1
# DESCRIPCIÓN: Ejecuta secuencialmente todos los scripts "Monitor-*.ps1".
# =============================================================================

# 1. Obtener la ruta actual del script
$ScriptPath = $PSScriptRoot

# 2. Buscar todos los scripts de monitoreo
#    Filtro: Archivos que empiecen con "Monitor-" y terminen en ".ps1"
$Scripts = Get-ChildItem -Path $ScriptPath -Filter "Monitor-*.ps1"

Write-Host "--- INICIANDO RONDA DE MONITOREO ---" -ForegroundColor Cyan
Write-Host "Carpeta: $ScriptPath"
Write-Host "Encontrados: $($Scripts.Count) scripts" -ForegroundColor Gray
Write-Host ""

# 3. Bucle de ejecución
foreach ($Script in $Scripts) {
    Write-Host "Ejecutando $($Script.Name)... " -NoNewline
    
    try {
        # El operador '&' ejecuta el script en la consola actual
        & $Script.FullName
        # El script hijo imprimirá su propio resultado
    }
    catch {
        Write-Host " [FALLO CRITICO]" -ForegroundColor Red
        Write-Host "   Error: $_" -ForegroundColor DarkRed
    }
    
    # Pequeña pausa opcional (0.5 seg)
    Start-Sleep -Milliseconds 500
}

# 4. Finalización (Separado para evitar errores de sintaxis)
Write-Host ""
Write-Host "--- RONDA FINALIZADA ---" -ForegroundColor Cyan
