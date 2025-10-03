# --- CONFIGURACIÓN PRINCIPAL ---
$ProjectPath = "C:\Users\santiago.guevara\dbatools-AW2022-v2"
$ConfigPath = Join-Path $ProjectPath "config\settings.json"
$Config = Get-Content $ConfigPath | ConvertFrom-Json

$SqlInstance = $Config.SqlInstance
$DatabaseName = $Config.Database
$ReportPath = Join-Path $ProjectPath "reports"
$CssFile = Join-Path $ProjectPath "templates\style.css"

# --- IMPORTAR MÓDULOS Y FUNCIONES ---
try {
    Import-Module dbatools -ErrorAction Stop

    # Importar módulos locales
    $modulesPath = Join-Path $ProjectPath "modules"
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

        # 3. Reporte de salud de jobs de backup
        Write-Host "   📊 Verificando jobs de backup..." -ForegroundColor Yellow
        $backupJobsReport = Get-BackupJobsHealthReport -SqlInstances $SqlInstances -ReportPath $ReportPath

        Write-Host "   ✅ Reporte diario completado exitosamente" -ForegroundColor Green

        return @{
            DiskReport       = $diskReport
            VersionReport    = $versionReport
            BackupJobsReport = $backupJobsReport
        }
    }
    catch {
        Write-Error "   ❌ Error en reporte diario automático: $($_.Exception.Message)"
        return $null
    }
}

# --- FUNCIÓN PARA MOSTRAR MENÚ PRINCIPAL ---
function Show-MainMenu {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "🚀 DBATOOLS-AW2022-V2 - SISTEMA DE MONITOREO SQL SERVER" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    Write-Host "📊 OPCIONES DISPONIBLES:" -ForegroundColor Yellow
    Write-Host "   1. 📋 Reporte Completo (Todos los datos)" -ForegroundColor White
    Write-Host "   2. 💽 Reporte Diario de Discos (6 AM)" -ForegroundColor White
    Write-Host "   3. 🔄 Verificación de Versiones y Parches" -ForegroundColor White
    Write-Host "   4. 📊 Estado de Jobs de Backup" -ForegroundColor White
    Write-Host "   5. 🚀 Colección Mejorada (Todas las funciones)" -ForegroundColor Green
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

    if ($dailyReport) {
        Write-Host "✅ Reporte diario automático completado exitosamente" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Error "❌ Error en reporte diario automático"
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
                $completeData = Get-CompleteDatabaseInfo -SqlInstance $SqlInstance -DatabaseName $DatabaseName

                if (-not $completeData) {
                    throw "No se pudieron recolectar los datos de la base de datos"
                }

                Write-Host "✅ Datos recolectados exitosamente:" -ForegroundColor Green

                # Mostrar resumen de datos recolectados
                $indexCount = if ($completeData.IndexStats) { $completeData.IndexStats.Count } else { 0 }
                $diskCount = if ($completeData.DiskStats) { $completeData.DiskStats.Count } else { 0 }
                $backupCount = if ($completeData.BackupData) { $completeData.BackupData.Count } else { 0 }

                Write-Host "   - Información de instancia: ✓" -ForegroundColor Green
                Write-Host "   - Análisis de índices: $indexCount índices" -ForegroundColor Green
                Write-Host "   - Espacio en disco: $diskCount archivos analizados" -ForegroundColor Green
                Write-Host "   - Consumo de recursos: ✓" -ForegroundColor Green
                Write-Host "   - Historial de backups: $backupCount backups" -ForegroundColor Green

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
            }
        }

        "2" {
            # 💽 REPORTE DIARIO DE DISCOS
            Write-Host "`n💽 EJECUTANDO REPORTE DIARIO DE DISCOS..." -ForegroundColor Cyan
            $diskReport = Get-DailyDiskReport -SqlInstances @($SqlInstance) -ReportPath $ReportPath
            if ($diskReport) {
                Write-Host "✅ Reporte diario de discos completado" -ForegroundColor Green
                Write-Host "📁 Archivo: $($diskReport.ReportFile)" -ForegroundColor Yellow
            }
        }

        "3" {
            # 🔄 VERIFICACIÓN DE VERSIONES Y PARCHES
            Write-Host "`n🔄 EJECUTANDO VERIFICACIÓN DE VERSIONES Y PARCHES..." -ForegroundColor Cyan
            $versionReport = Get-VersionComplianceReport -SqlInstances @($SqlInstance) -ReportPath $ReportPath
            if ($versionReport) {
                Write-Host "✅ Verificación de versiones completada" -ForegroundColor Green
                Write-Host "📁 Archivo: $($versionReport.ReportFile)" -ForegroundColor Yellow

                # Mostrar resumen
                if ($versionReport.Summary.OutdatedServers -gt 0) {
                    Write-Host "⚠️  Servidores desactualizados: $($versionReport.Summary.OutdatedServers)" -ForegroundColor Red
                }
                else {
                    Write-Host "✅ Todos los servidores están actualizados" -ForegroundColor Green
                }
            }
        }

        "4" {
            # 📊 ESTADO DE JOBS DE BACKUP
            Write-Host "`n📊 VERIFICANDO ESTADO DE JOBS DE BACKUP..." -ForegroundColor Cyan
            $backupJobsReport = Get-BackupJobsHealthReport -SqlInstances @($SqlInstance) -ReportPath $ReportPath
            if ($backupJobsReport) {
                Write-Host "✅ Verificación de jobs de backup completada" -ForegroundColor Green
                Write-Host "📁 Archivo: $($backupJobsReport.ReportFile)" -ForegroundColor Yellow

                if ($backupJobsReport.TotalErrors -gt 0) {
                    Write-Host "🚨 Jobs con errores: $($backupJobsReport.TotalErrors)" -ForegroundColor Red
                }
                else {
                    Write-Host "✅ Todos los jobs de backup están funcionando correctamente" -ForegroundColor Green
                }
            }
        }

        "5" {
            # 🚀 COLECCIÓN MEJORADA (TODAS LAS FUNCIONES)
            Write-Host "`n🚀 EJECUTANDO COLECCIÓN MEJORADA COMPLETA..." -ForegroundColor Cyan
            $enhancedCollection = Invoke-EnhancedDataCollection -SqlInstances @($SqlInstance) -ReportPath $ReportPath -DailyMode:$true
            if ($enhancedCollection) {
                Write-Host "✅ Colección mejorada completada exitosamente" -ForegroundColor Green
                Write-Host "📁 Archivo principal: $($enhancedCollection.ReportFile)" -ForegroundColor Yellow
                Write-Host "📊 Servidores procesados: $($enhancedCollection.ServersProcessed)" -ForegroundColor Green

                # Preguntar si abrir reporte
                $answer = Read-Host "`n¿Desea abrir el reporte principal ahora? (S/N)"
                if ($answer -eq "S" -or $answer -eq "s") {
                    Write-Host "🌐 Abriendo reporte en el navegador..." -ForegroundColor Cyan
                    Start-Process $enhancedCollection.ReportFile
                }
            }
        }

        "6" {
            # 📜 MOSTRAR FUNCIONES DISPONIBLES
            Write-Host "`n🛠️  FUNCIONES DBATOOLS DISPONIBLES:" -ForegroundColor Cyan
            Show-DbaToolsFunctions
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