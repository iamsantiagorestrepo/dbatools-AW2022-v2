# main.ps1 - CORREGIDO PARA USAR FUNCIONES REFACTORIZADAS
# ============================================================================

# --- CONFIGURACIÓN PRINCIPAL ---
$ProjectPath = "C:\Users\santiago.guevara\dbatools-AW2022-v2"
$ConfigPath = Join-Path $ProjectPath "config\settings.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

$SqlInstance = $Config.SqlInstance
$DatabaseName = $Config.Database
$ReportPath = Join-Path $ProjectPath "reports"
$CssFile = Join-Path $ProjectPath "src\templates\style.css"

# --- IMPORTAR MÓDULOS Y FUNCIONES ---
try {
    Import-Module dbatools -ErrorAction Stop

    # Importar módulos locales
    $modulesPath = Join-Path $ProjectPath "src\modules"
    . (Join-Path $modulesPath "data-collector.ps1")
    . (Join-Path $modulesPath "html-generator.ps1")
    . (Join-Path $modulesPath "dbatools-functions.ps1")

    Write-Host "✅ Configuración cargada desde: $ConfigPath" -ForegroundColor Green
    Write-Host "✅ Módulo dbatools importado correctamente" -ForegroundColor Green
    Write-Host "✅ Funciones personalizadas cargadas" -ForegroundColor Green
}
catch {
    Write-Error "❌ Error al cargar módulos o funciones: $($_.Exception.Message)"
    exit 1
}

# --- FUNCIÓN PARA EJECUTAR REPORTE DIARIO AUTOMÁTICO ---
function Invoke-DailyAutomatedReport {
    param(
        [string[]]$SqlInstances,
        [string]$ReportPath
    )

    try {
        Write-Host "`n🌅 EJECUTANDO REPORTE DIARIO AUTOMÁTICO (6 AM)..." -ForegroundColor Cyan

        # 1. Reporte diario de discos
        Write-Host "   💽 Ejecutando reporte diario de discos..." -ForegroundColor Yellow
        $diskReport = Get-DailyDiskReport -SqlInstances $SqlInstances -ReportPath $ReportPath

        # 2. Reporte de cumplimiento de versiones
        Write-Host "   🔄 Verificando versiones y parches..." -ForegroundColor Yellow
        $versionReport = Get-VersionComplianceReport -SqlInstances $SqlInstances -ReportPath $ReportPath

        # 3. Reporte de salud de jobs de backup (CORREGIDO)
        Write-Host "   📊 Verificando jobs de backup..." -ForegroundColor Yellow
        $backupJobsReport = Get-BackupJobsReport -SqlInstances $SqlInstances -ReportPath $ReportPath

        Write-Host "   ✅ Reporte diario completado exitosamente" -ForegroundColor Green

        return @{
            DiskReport       = $diskReport
            VersionReport    = $versionReport
            BackupJobsReport = $backupJobsReport
            Success          = $true
        }
    }
    catch {
        Write-Error "   ❌ Error en reporte diario automático: $($_.Exception.Message)"
        return @{
            Success = $false
            Error   = $_.Exception.Message
        }
    }
}

# --- FUNCIÓN PARA MOSTRAR MENÚ PRINCIPAL ---
function Show-MainMenu {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "🚀 DBATOOLS-AW2022-V2 - SISTEMA DE MONITOREO SQL SERVER" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    Write-Host "📊 OPCIONES DISPONIBLES:" -ForegroundColor Yellow
    Write-Host "   1. 📋 Reporte Completo (Todos los datos)" -ForegroundColor White
    Write-Host "   2. 💽 Reporte Diario de Discos" -ForegroundColor White
    Write-Host "   3. 🔄 Verificación de Versiones y Parches" -ForegroundColor White
    Write-Host "   4. 📊 Estado de Jobs de Backup" -ForegroundColor White
    Write-Host "   5. 🚀 Colección Multi-Instancia Completa" -ForegroundColor Green
    Write-Host "   6. 📜 Mostrar Funciones Disponibles" -ForegroundColor White
    Write-Host "   7. ❌ Salir" -ForegroundColor Red
    Write-Host ""
}

# --- PROGRAMA PRINCIPAL ---
Write-Host "🚀 INICIANDO DBATOOLS-AW2022-V2..." -ForegroundColor Cyan
Write-Host "   Proyecto: $ProjectPath" -ForegroundColor Yellow
Write-Host "   Servidor: $SqlInstance" -ForegroundColor Yellow
Write-Host "   Base de datos: $DatabaseName" -ForegroundColor Yellow
Write-Host "   Ruta reportes: $ReportPath" -ForegroundColor Yellow
Write-Host ""

# Verificar si es ejecución automática (6 AM) o manual
$currentTime = Get-Date
$isScheduledRun = $currentTime.Hour -eq 6 -and $currentTime.Minute -le 30

if ($isScheduledRun) {
    Write-Host "⏰ EJECUCIÓN PROGRAMADA DETECTADA (6 AM)..." -ForegroundColor Cyan
    Write-Host "   Ejecutando reporte diario automático..." -ForegroundColor Yellow

    # Ejecutar reporte diario automático
    $dailyReport = Invoke-DailyAutomatedReport -SqlInstances @($SqlInstance) -ReportPath $ReportPath

    if ($dailyReport.Success) {
        Write-Host "✅ Reporte diario automático completado exitosamente" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Error "❌ Error en reporte diario automático: $($dailyReport.Error)"
        exit 1
    }
}

# MODO INTERACTIVO - MOSTRAR MENÚ
do {
    Show-MainMenu
    $choice = Read-Host "Seleccione una opción (1-7)"

    switch ($choice) {
        "1" {
            # 📋 REPORTE COMPLETO
            Write-Host "`n📊 EJECUTANDO REPORTE COMPLETO..." -ForegroundColor Cyan
            Write-Host "🔍 Conectando a $SqlInstance y recolectando datos de $DatabaseName..." -ForegroundColor Yellow

            try {
                # USAR FUNCIÓN REFACTORIZADA CON CARACTERÍSTICAS MEJORADAS
                $completeData = Get-CompleteDatabaseInfo `
                    -SqlInstance $SqlInstance `
                    -DatabaseName $DatabaseName `
                    -IncludeEnhancedFeatures

                if (-not $completeData) {
                    throw "No se pudieron recolectar los datos de la base de datos"
                }

                Write-Host "✅ Datos recolectados exitosamente:" -ForegroundColor Green

                # Mostrar resumen de datos recolectados
                $indexCount = if ($completeData.IndexStats) { $completeData.IndexStats.Count } else { 0 }
                $diskCountDB = if ($completeData.DiskStatsDB) { $completeData.DiskStatsDB.Count } else { 0 }
                $backupCount = if ($completeData.BackupHistory) { $completeData.BackupHistory.Count } else { 0 }

                Write-Host "   - Información de instancia: ✓" -ForegroundColor Green
                Write-Host "   - Análisis de parches: $(if ($completeData.InstanceInfo.PatchAnalysis) { '✓' } else { '✗' })" -ForegroundColor $(if ($completeData.InstanceInfo.PatchAnalysis) { 'Green' } else { 'Red' })
                Write-Host "   - Análisis de índices: $indexCount índices" -ForegroundColor Green
                Write-Host "   - Espacio en disco (BD): $diskCountDB archivos" -ForegroundColor Green
                Write-Host "   - Consumo de recursos: ✓" -ForegroundColor Green
                Write-Host "   - Consultas costosas: $($completeData.ExpensiveQueries.Count) consultas" -ForegroundColor Green
                Write-Host "   - Estadísticas de memoria: ✓" -ForegroundColor Green
                Write-Host "   - Historial de backups: $backupCount backups" -ForegroundColor Green

                if ($completeData.EnhancedData) {
                    $diskCountAll = if ($completeData.EnhancedData.AllDiskSpace) { $completeData.EnhancedData.AllDiskSpace.Count } else { 0 }
                    $jobCount = if ($completeData.EnhancedData.BackupJobStatus) { $completeData.EnhancedData.BackupJobStatus.TotalJobs } else { 0 }

                    Write-Host "   - Espacio en disco (Todos): $diskCountAll volúmenes" -ForegroundColor Green
                    Write-Host "   - Estado de jobs backup: $jobCount jobs" -ForegroundColor Green
                }

                # Generar HTML
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $ReportFile = Join-Path $ReportPath "Reporte_Completo_${DatabaseName}_$timestamp.html"

                Generate-CompleteHTMLReport -ReportData $completeData -OutputPath $ReportFile -CssFile $CssFile

                Write-Host "`n✅ REPORTE COMPLETO GENERADO EXITOSAMENTE!" -ForegroundColor Green
                Write-Host "📁 Ubicación: $ReportFile" -ForegroundColor Yellow

                # Preguntar si abrir reporte
                $answer = Read-Host "`n¿Desea abrir el reporte ahora? (S/N)"
                if ($answer -eq "S" -or $answer -eq "s") {
                    Write-Host "🌐 Abriendo reporte en el navegador..." -ForegroundColor Cyan
                    Start-Process $ReportFile
                }
            }
            catch {
                Write-Error "❌ Error durante la generación del reporte: $($_.Exception.Message)"
                Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
            }
        }

        "2" {
            # 💽 REPORTE DIARIO DE DISCOS
            Write-Host "`n💽 EJECUTANDO REPORTE DIARIO DE DISCOS..." -ForegroundColor Cyan

            try {
                $diskReport = Get-DailyDiskReport -SqlInstances @($SqlInstance) -ReportPath $ReportPath

                if ($diskReport) {
                    Write-Host "✅ Reporte diario de discos completado" -ForegroundColor Green

                    # Mostrar resumen
                    foreach ($instance in $diskReport.Data.Keys) {
                        if ($instance -ne "Summary") {
                            $diskData = $diskReport.Data[$instance].DiskSpace
                            $critical = ($diskData | Where-Object { $_.AlertLevel -eq "Critico" }).Count
                            $warning = ($diskData | Where-Object { $_.AlertLevel -eq "Advertencia" }).Count

                            Write-Host "   📊 $instance : $($diskData.Count) discos" -ForegroundColor White
                            if ($critical -gt 0) {
                                Write-Host "      🚨 Críticos: $critical" -ForegroundColor Red
                            }
                            if ($warning -gt 0) {
                                Write-Host "      ⚠️  Advertencias: $warning" -ForegroundColor Yellow
                            }
                        }
                    }
                }
            }
            catch {
                Write-Error "❌ Error en reporte de discos: $($_.Exception.Message)"
            }
        }

        "3" {
            # 🔄 VERIFICACIÓN DE VERSIONES Y PARCHES
            Write-Host "`n🔄 EJECUTANDO VERIFICACIÓN DE VERSIONES Y PARCHES..." -ForegroundColor Cyan

            try {
                $versionReport = Get-VersionComplianceReport -SqlInstances @($SqlInstance) -ReportPath $ReportPath

                if ($versionReport) {
                    Write-Host "✅ Verificación de versiones completada" -ForegroundColor Green

                    # Mostrar detalles del servidor
                    foreach ($instance in $versionReport.Data.Keys) {
                        if ($instance -ne "Summary") {
                            $instanceData = $versionReport.Data[$instance]
                            Write-Host "`n   📊 Servidor: $instance" -ForegroundColor White
                            Write-Host "      Versión: $($instanceData.ProductVersion)" -ForegroundColor Gray
                            Write-Host "      Edición: $($instanceData.Edition)" -ForegroundColor Gray
                            Write-Host "      Estado parches: $($instanceData.PatchAnalysis.Status)" -ForegroundColor $(if ($instanceData.PatchAnalysis.NeedsPatches) { "Yellow" } else { "Green" })

                            if ($instanceData.PatchAnalysis.NeedsPatches) {
                                Write-Host "      ⚠️  $($instanceData.PatchAnalysis.Recommendation)" -ForegroundColor Yellow
                            }
                        }
                    }

                    # Mostrar resumen
                    if ($versionReport.Summary) {
                        Write-Host "`n   📈 RESUMEN:" -ForegroundColor Cyan
                        Write-Host "      Total: $($versionReport.Summary.TotalServers)" -ForegroundColor White
                        Write-Host "      Actualizados: $($versionReport.Summary.UpToDateServers)" -ForegroundColor Green
                        Write-Host "      Desactualizados: $($versionReport.Summary.OutdatedServers)" -ForegroundColor $(if ($versionReport.Summary.OutdatedServers -gt 0) { "Red" } else { "Green" })
                    }
                }
            }
            catch {
                Write-Error "❌ Error en verificación de versiones: $($_.Exception.Message)"
            }
        }

        "4" {
            # 📊 ESTADO DE JOBS DE BACKUP
            Write-Host "`n📊 VERIFICANDO ESTADO DE JOBS DE BACKUP..." -ForegroundColor Cyan

            try {
                $backupJobsReport = Get-BackupJobsReport -SqlInstances @($SqlInstance) -ReportPath $ReportPath

                if ($backupJobsReport) {
                    Write-Host "✅ Verificación de jobs de backup completada" -ForegroundColor Green

                    # Mostrar detalles por servidor
                    foreach ($instance in $backupJobsReport.Data.Keys) {
                        $instanceData = $backupJobsReport.Data[$instance]
                        Write-Host "`n   📊 Servidor: $instance" -ForegroundColor White
                        Write-Host "      Total jobs: $($instanceData.TotalJobs)" -ForegroundColor Gray
                        Write-Host "      Jobs con error: $($instanceData.FailedJobs)" -ForegroundColor $(if ($instanceData.FailedJobs -gt 0) { "Red" } else { "Green" })

                        if ($instanceData.HasErrors) {
                            $errorJobs = $instanceData.JobStatusReport | Where-Object { $_.HasErrors }
                            foreach ($job in $errorJobs) {
                                Write-Host "         🚨 $($job.JobName): $($job.JobStatus)" -ForegroundColor Red
                            }
                        }
                    }

                    # Resumen general
                    Write-Host "`n   📈 RESUMEN GENERAL:" -ForegroundColor Cyan
                    Write-Host "      Total errores: $($backupJobsReport.TotalErrors)" -ForegroundColor $(if ($backupJobsReport.TotalErrors -gt 0) { "Red" } else { "Green" })
                }
            }
            catch {
                Write-Error "❌ Error en verificación de jobs: $($_.Exception.Message)"
            }
        }

        "5" {
            # 🚀 COLECCIÓN MULTI-INSTANCIA COMPLETA
            Write-Host "`n🚀 EJECUTANDO COLECCIÓN MULTI-INSTANCIA COMPLETA..." -ForegroundColor Cyan

            # Preguntar por instancias adicionales
            Write-Host "   Instancia configurada: $SqlInstance" -ForegroundColor Yellow
            $addMore = Read-Host "   ¿Desea agregar más instancias? (S/N)"

            $instances = @($SqlInstance)

            if ($addMore -eq "S" -or $addMore -eq "s") {
                do {
                    $newInstance = Read-Host "   Ingrese nombre de instancia (o 'FIN' para terminar)"
                    if ($newInstance -ne "FIN" -and $newInstance -ne "fin" -and $newInstance -ne "") {
                        $instances += $newInstance
                        Write-Host "      ✅ Agregada: $newInstance" -ForegroundColor Green
                    }
                } while ($newInstance -ne "FIN" -and $newInstance -ne "fin")
            }

            Write-Host "`n   📋 Instancias a procesar: $($instances -join ', ')" -ForegroundColor Cyan

            try {
                # USAR FUNCIÓN REFACTORIZADA
                $result = Invoke-MultiInstanceDataCollection `
                    -SqlInstances $instances `
                    -DatabaseName $DatabaseName `
                    -ReportPath $ReportPath `
                    -GenerateDailyReports `
                    -IncludeEnhancedFeatures

                if ($result) {
                    Write-Host "`n✅ COLECCIÓN MULTI-INSTANCIA COMPLETADA" -ForegroundColor Green
                    Write-Host "   📊 Total instancias: $($result.TotalInstances)" -ForegroundColor White
                    Write-Host "   ✅ Exitosas: $($result.SuccessCount)" -ForegroundColor Green
                    Write-Host "   ❌ Fallidas: $($result.FailureCount)" -ForegroundColor $(if ($result.FailureCount -gt 0) { "Red" } else { "Green" })
                    Write-Host "   📅 Timestamp: $($result.Timestamp)" -ForegroundColor Gray

                    # Generar reporte HTML consolidado (si tienes la función)
                    # $ReportFile = Join-Path $ReportPath "Coleccion_MultiInstancia_$($result.Timestamp).html"
                    # Generate-MultiInstanceHTMLReport -ReportData $result -OutputPath $ReportFile -CssFile $CssFile
                }
            }
            catch {
                Write-Error "❌ Error en colección multi-instancia: $($_.Exception.Message)"
            }
        }

        "6" {
            # 📜 MOSTRAR FUNCIONES DISPONIBLES
            Write-Host "`n🛠️  FUNCIONES DISPONIBLES:" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "   📦 FUNCIONES DE RECOLECCIÓN:" -ForegroundColor Yellow
            Write-Host "      • Get-SQLInstanceInfo" -ForegroundColor White
            Write-Host "      • Get-PatchAnalysis" -ForegroundColor White
            Write-Host "      • Get-DiskSpaceInfo" -ForegroundColor White
            Write-Host "      • Get-IndexMaintenanceInfo" -ForegroundColor White
            Write-Host "      • Get-ResourceConsumption" -ForegroundColor White
            Write-Host "      • Get-ExpensiveQueries" -ForegroundColor White
            Write-Host "      • Get-MemoryStatistics" -ForegroundColor White
            Write-Host "      • Get-BackupHistory" -ForegroundColor White
            Write-Host "      • Get-BackupJobStatus" -ForegroundColor White
            Write-Host ""
            Write-Host "   📊 FUNCIONES DE REPORTES:" -ForegroundColor Yellow
            Write-Host "      • Get-DailyDiskReport" -ForegroundColor White
            Write-Host "      • Get-VersionComplianceReport" -ForegroundColor White
            Write-Host "      • Get-BackupJobsReport" -ForegroundColor White
            Write-Host ""
            Write-Host "   🚀 FUNCIONES PRINCIPALES:" -ForegroundColor Yellow
            Write-Host "      • Get-CompleteDatabaseInfo" -ForegroundColor White
            Write-Host "      • Invoke-MultiInstanceDataCollection" -ForegroundColor White
            Write-Host ""
            Write-Host "   🔔 UTILIDADES:" -ForegroundColor Yellow
            Write-Host "      • Send-DbaNotification" -ForegroundColor White
        }

        "7" {
            # ❌ SALIR
            Write-Host "`n👋 ¡Hasta pronto!" -ForegroundColor Green
            exit 0
        }

        default {
            Write-Host "❌ Opción no válida. Por favor seleccione 1-7." -ForegroundColor Red
        }
    }

    if ($choice -ne "7") {
        Write-Host "`n" + "-"*50 -ForegroundColor Gray
        $continue = Read-Host "¿Desea realizar otra operación? (S/N)"
        if ($continue -ne "S" -and $continue -ne "s") {
            Write-Host "👋 ¡Hasta pronto!" -ForegroundColor Green
            break
        }
    }

} while ($choice -ne "7")