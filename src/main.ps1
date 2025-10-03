# --- CONFIGURACIÓN PRINCIPAL ---
$ConfigPath = "C:\DBAToolsProyecto1\config\settings.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

$SqlInstance = $Config.SqlInstance
$DatabaseName = $Config.Database  # ⚠️ CORREGIDO: Debe ser $DatabaseName
$ReportPath = $Config.ReportPath
$CssFile = "C:\DBAToolsProyecto1\src\templates\style.css"  # ⚠️ CORREGIDO: Ruta correcta

# --- IMPORTAR MÓDULOS Y FUNCIONES ---
try {
    Import-Module dbatools -ErrorAction Stop

    # Importar módulos locales
    $modulesPath = "C:\DBAToolsProyecto1\src\modules"
    . "$modulesPath\data-collector.ps1"
    . "$modulesPath\html-generator.ps1"
    . "$modulesPath\dbatools-functions.ps1"

    Write-Host "✅ Configuración cargada desde: $ConfigPath" -ForegroundColor Green
    Write-Host "✅ Módulo dbatools importado correctamente" -ForegroundColor Green
    Write-Host "✅ Funciones personalizadas cargadas" -ForegroundColor Green
}
catch {
    Write-Error "❌ Error al cargar módulos o funciones: $($_.Exception.Message)"
    exit 1
}

Write-Host "🚀 INICIANDO GENERACIÓN DE REPORTE MEJORADO..." -ForegroundColor Cyan
Write-Host "   Servidor: $SqlInstance" -ForegroundColor Yellow
Write-Host "   Base de datos: $DatabaseName" -ForegroundColor Yellow
Write-Host "   Ruta reportes: $ReportPath" -ForegroundColor Yellow
Write-Host ""

# --- RECOLECCIÓN DE DATOS REALES ---
Write-Host "📊 RECOLECTANDO DATOS REALES DE LA BASE DE DATOS..." -ForegroundColor Cyan
Write-Host "🔍 Conectando a $SqlInstance y recolectando datos de $DatabaseName..." -ForegroundColor Yellow

try {
    # ⚠️ CORREGIDO: Usar $DatabaseName y variable correcta
    $completeData = Get-CompleteDatabaseInfo -SqlInstance $SqlInstance -DatabaseName $DatabaseName

    if (-not $completeData) {
        # ⚠️ CORREGIDO: minuscula
        throw "No se pudieron recolectar los datos de la base de datos"
    }
    

    Write-Host "✅ Datos recolectados exitosamente:" -ForegroundColor Green

    # ⚠️ CORREGIDO: Mostrar datos reales de la estructura actual
    $indexCount = if ($completeData.IndexStats) { $completeData.IndexStats.Count } else { 0 }
    $diskCount = if ($completeData.DiskStats) { $completeData.DiskStats.Count } else { 0 }
    $backupCount = if ($completeData.BackupData) { $completeData.BackupData.Count } else { 0 }

    Write-Host "   - Información de instancia: " -NoNewline
    if ($completeData.InstanceInfo) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "✗" -ForegroundColor Red }

    Write-Host "   - Análisis de índices: " -NoNewline
    Write-Host "$indexCount índices" -ForegroundColor Green

    Write-Host "   - Espacio en disco: " -NoNewline
    Write-Host "$diskCount archivos analizados" -ForegroundColor Green

    Write-Host "   - Consumo de recursos: " -NoNewline
    if ($completeData.ResourceUsage) { Write-Host "✓" -ForegroundColor Green } else { Write-Host "✗" -ForegroundColor Red }

    Write-Host "   - Historial de backups: " -NoNewline
    Write-Host "$backupCount backups" -ForegroundColor Green

    # --- GENERACIÓN DE HTML ---
    Write-Host ""
    Write-Host "🎨 GENERANDO REPORTE HTML..." -ForegroundColor Cyan

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $ReportFile = Join-Path $ReportPath "Reporte_Completo_${DatabaseName}_$timestamp.html"

    # ⚠️ CORREGIDO: Llamar a la función correcta con parámetros correctos
    Generate-CompleteHTMLReport -ReportData $completeData -OutputPath $ReportFile -CssFile $CssFile

    Write-Host ""
    Write-Host "✅ REPORTE COMPLETO GENERADO EXITOSAMENTE!" -ForegroundColor Green
    Write-Host "📁 Ubicación: $ReportFile" -ForegroundColor Yellow

    # --- RESUMEN EJECUTIVO ---
    Write-Host ""
    Write-Host "📈 RESUMEN EJECUTIVO:" -ForegroundColor Cyan

    # Mostrar información del motor
    if ($completeData.EngineInfo) {
        Write-Host ""
        Write-Host "🖥️  INFORMACIÓN DEL MOTOR:" -ForegroundColor Cyan
        Write-Host "   Versión: $($completeData.EngineInfo.ProductVersion)" -ForegroundColor Yellow
        Write-Host "   Edición: $($completeData.EngineInfo.Edition)" -ForegroundColor Yellow
        Write-Host "   Nivel: $($completeData.EngineInfo.ProductLevel)" -ForegroundColor Yellow
    }

    if ($completeData.PatchAnalysis) {
        Write-Host ""
        Write-Host "🔧 ANÁLISIS DE PARCHES:" -ForegroundColor Cyan
        Write-Host "   Estado: $($completeData.PatchAnalysis.Estado)" -ForegroundColor $(if ($completeData.PatchAnalysis.NecesitaParches) { 'Red' } else { 'Green' })
        Write-Host "   Recomendación: $($completeData.PatchAnalysis.Recomendacion)" -ForegroundColor Yellow
    }

    # Calcular métricas para el resumen
    $rebuildRecommended = if ($completeData.IndexStats) {
        ($completeData.IndexStats | Where-Object { $_.RecommendedAction -eq 'REBUILD' }).Count
    }
    else { 0 }

    $criticalFiles = if ($completeData.DiskStats) {
        ($completeData.DiskStats | Where-Object { $_.PorcentajeUsado -gt 90 }).Count
    }
    else { 0 }

    $connectionCount = if ($completeData.ResourceUsage) {
        $completeData.ResourceUsage.ConnectionCount
    }
    else { 0 }

    Write-Host "   Estado General: " -NoNewline
    if ($rebuildRecommended -gt 0 -or $criticalFiles -gt 0) {
        Write-Host "ATENCIÓN REQUERIDA" -ForegroundColor Red
    }
    else {
        Write-Host "ÓPTIMO" -ForegroundColor Green
    }

    Write-Host "   Índices para REBUILD: " -NoNewline
    Write-Host "$rebuildRecommended" -ForegroundColor $(if ($rebuildRecommended -gt 0) { 'Red' } else { 'Green' })

    Write-Host "   Archivos críticos (>90%): " -NoNewline
    Write-Host "$criticalFiles" -ForegroundColor $(if ($criticalFiles -gt 0) { 'Red' } else { 'Green' })

    Write-Host "   Conexiones activas: " -NoNewline
    Write-Host "$connectionCount" -ForegroundColor $(if ($connectionCount -gt 50) { 'Yellow' } else { 'Green' })

    # Mostrar alertas específicas
    $alerts = @()
    if ($rebuildRecommended -gt 0) {
        $alerts += "$rebuildRecommended índice(s) necesitan REBUILD urgente"
    }
    if ($criticalFiles -gt 0) {
        $alerts += "$criticalFiles archivo(s) con más del 90% de espacio usado"
    }
    if ($backupCount -eq 0) {
        $alerts += "No se encontraron backups recientes"
    }

    if ($alerts.Count -gt 0) {
        Write-Host ""
        Write-Host "🚨 ALERTAS:" -ForegroundColor Yellow
        foreach ($alert in $alerts) {
            Write-Host "   ⚠️ $alert" -ForegroundColor Yellow
        }
    }

    # Mostrar consultas costosas
    if ($completeData.ExpensiveQueries -and $completeData.ExpensiveQueries.Count -gt 0) {
        Write-Host ""
        Write-Host "⚡ CONSULTAS COSTOSAS:" -ForegroundColor Cyan
        $topQuery = $completeData.ExpensiveQueries[0]
        Write-Host "   Consulta más costosa: $([math]::Round($topQuery.CPUTotalSegundos, 2))s total" -ForegroundColor Yellow
    }

    # Preguntar si abrir reporte
    Write-Host ""
    $answer = Read-Host "¿Desea abrir el reporte ahora? (S/N)"
    if ($answer -eq "S" -or $answer -eq "s") {
        Write-Host "🌐 Abriendo reporte en el navegador..." -ForegroundColor Cyan
        Start-Process $ReportFile
    }

}
catch {
    Write-Error "❌ Error durante la generación del reporte: $($_.Exception.Message)"
    exit 1
}

Write-Host ""
Write-Host "🎯 SCRIPT COMPLETADO!" -ForegroundColor Green