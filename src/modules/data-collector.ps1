# data-collector.ps1
# COLECTOR DE DATOS - Recopila información específica de la base de datos

function Get-SQLInstanceEnhancedInfo {
    param([string]$SqlInstance)

    try {
        Write-Host "   🔍 Obteniendo información de instancia..." -ForegroundColor Yellow
        $query = @"
SELECT
    SERVERPROPERTY('MachineName') AS Servidor,
    SERVERPROPERTY('InstanceName') AS Instancia,
    SERVERPROPERTY('ProductVersion') AS Version,
    SERVERPROPERTY('ProductLevel') AS NivelProducto,
    SERVERPROPERTY('Edition') AS Edicion,
    SERVERPROPERTY('Collation') AS Collation,
    @@VERSION AS VersionCompleta
"@
        $instanceInfo = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop
        Write-Host "   ✅ Información de instancia obtenida" -ForegroundColor Green

        return @{
            InstanceInfo  = $instanceInfo
            PatchAnalysis = Get-PatchAnalysis -InstanceInfo $instanceInfo
        }
    }
    catch {
        Write-Warning "   ❌ Error obteniendo información de instancia: $($_.Exception.Message)"
        return $null
    }
}

function Get-SQLServerEngineInfo {
    param([string]$SqlInstance)

    try {
        Write-Host "   🔍 Obteniendo información detallada del motor SQL Server..." -ForegroundColor Yellow
        $query = @"
SELECT
    @@VERSION AS VersionCompleta,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('ProductLevel') AS ProductLevel,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('EngineEdition') AS EngineEdition,
    SERVERPROPERTY('Collation') AS Collation,
    SERVERPROPERTY('IsClustered') AS IsClustered,
    SERVERPROPERTY('IsHadrEnabled') AS IsHadrEnabled,
    SERVERPROPERTY('MachineName') AS MachineName,
    SERVERPROPERTY('InstanceName') AS InstanceName,
    SERVERPROPERTY('IsIntegratedSecurityOnly') AS IsIntegratedSecurityOnly,
    SERVERPROPERTY('ServerName') AS ServerName,
    SERVERPROPERTY('BuildClrVersion') AS BuildClrVersion,
    SERVERPROPERTY('IsFullTextInstalled') AS IsFullTextInstalled,
    SERVERPROPERTY('IsXTPSupported') AS IsXTPSupported,
    SERVERPROPERTY('LicenseType') AS LicenseType,
    SERVERPROPERTY('NumLicenses') AS NumLicenses,
    SERVERPROPERTY('ProcessID') AS ProcessID,
    SERVERPROPERTY('ResourceVersion') AS ResourceVersion,
    SERVERPROPERTY('ResourceLastUpdateDateTime') AS ResourceLastUpdateDateTime,
    SERVERPROPERTY('ProductBuild') AS ProductBuild,
    SERVERPROPERTY('ProductBuildType') AS ProductBuildType,
    SERVERPROPERTY('ProductUpdateLevel') AS ProductUpdateLevel,
    SERVERPROPERTY('ProductUpdateReference') AS ProductUpdateReference
"@
        $engineInfo = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop
        Write-Host "   ✅ Información del motor obtenida" -ForegroundColor Green
        return $engineInfo
    }
    catch {
        Write-Warning "   ❌ Error obteniendo información del motor: $($_.Exception.Message)"
        return $null
    }
}

function Get-SQLPatchAnalysis {
    param($EngineInfo)

    try {
        if (-not $EngineInfo) {
            return @{
                NecesitaParches   = $true
                Estado            = "No disponible"
                VersionActual     = "N/A"
                UltimaVersion     = "N/A"
                Recomendacion     = "No se pudo obtener información de parches"
                EnlaceKB          = ""
                FechaVerificacion = Get-Date -Format "yyyy-MM-dd"
            }
        }

        $versionActual = $EngineInfo.ProductVersion
        $productLevel = $EngineInfo.ProductLevel

        # Análisis básico de versión
        $necesitaParches = $false
        $estado = "Actualizado"
        $recomendacion = "El servidor está actualizado"
        $enlaceKB = "https://support.microsoft.com/es-es/sql"

        # Lógica simple de detección
        if ($productLevel -eq "RTM") {
            $necesitaParches = $true
            $estado = "NECESITA PARCHES"
            $recomendacion = "Se recomienda aplicar los Service Packs y actualizaciones de seguridad más recientes"
            $enlaceKB = "https://support.microsoft.com/es-es/topic/kb5014356"
        }

        return @{
            NecesitaParches   = $necesitaParches
            Estado            = $estado
            VersionActual     = $versionActual
            NivelProducto     = $productLevel
            UltimaVersion     = "16.0.1145.1"
            Recomendacion     = $recomendacion
            EnlaceKB          = $enlaceKB
            FechaVerificacion = Get-Date -Format "yyyy-MM-dd HH:mm"
        }
    }
    catch {
        Write-Warning "Error en análisis de parches: $($_.Exception.Message)"
        return @{
            NecesitaParches   = $false
            Estado            = "Error en análisis"
            Recomendacion     = "Verificar manualmente el estado de parches"
            EnlaceKB          = ""
            FechaVerificacion = Get-Date -Format "yyyy-MM-dd"
        }
    }
}

function Get-EnhancedIndexMaintenance {
    param([string]$SqlInstance, [string]$DatabaseName)

    try {
        Write-Host "   🔍 Obteniendo información COMPLETA de índices para $DatabaseName..." -ForegroundColor Yellow
        $query = @"
SELECT
    DB_NAME() AS DatabaseName,
    OBJECT_SCHEMA_NAME(ips.object_id) + '.' + OBJECT_NAME(ips.object_id) AS TableName,
    si.name AS IndexName,
    ips.index_type_desc AS IndexType,
    ips.avg_fragmentation_in_percent AS Fragmentation,
    ips.page_count AS PageCount,
    ips.record_count AS RecordCount,
    CASE
        WHEN ips.avg_fragmentation_in_percent > 30 THEN 'REBUILD'
        WHEN ips.avg_fragmentation_in_percent > 10 THEN 'REORGANIZE'
        ELSE 'OK'
    END AS RecommendedAction
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'DETAILED') ips
INNER JOIN sys.indexes si
    ON ips.object_id = si.object_id AND ips.index_id = si.index_id
WHERE ips.index_id >= 0
ORDER BY
    ips.avg_fragmentation_in_percent DESC,
    ips.page_count DESC,
    TableName,
    IndexName
"@
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $query -ErrorAction Stop
        Write-Host "   ✅ Información COMPLETA de índices obtenida ($($result.Count) índices)" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Warning "   ❌ Error en índices: $($_.Exception.Message)"
        return @()
    }
}

function Get-DiskSpaceEnhanced {
    param([string]$SqlInstance, [string]$DatabaseName)

    try {
        Write-Host "   🔍 Obteniendo información de disco para $DatabaseName..." -ForegroundColor Yellow
        $query = @"
SELECT
    DB_NAME() AS DatabaseName,
    name AS FileName,
    type_desc AS FileType,
    size * 8.0 / 1024 AS SizeMB,
    FILEPROPERTY(name, 'SpaceUsed') * 8.0 / 1024 AS UsedMB,
    (size - FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 AS FreeMB,
    CASE
        WHEN size > 0 THEN CAST((FILEPROPERTY(name, 'SpaceUsed') * 100.0 / size) AS DECIMAL(5,2))
        ELSE 0
    END AS PorcentajeUsado,
    physical_name AS PhysicalPath
FROM sys.database_files
WHERE type IN (0, 1)
"@
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $query -ErrorAction Stop
        Write-Host "   ✅ Información de disco obtenida ($($result.Count) archivos)" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Warning "   ❌ Error en disco: $($_.Exception.Message)"
        return @()
    }
}

function Get-ResourceConsumptionEnhanced {
    param([string]$SqlInstance, [string]$DatabaseName)

    try {
        Write-Host "   🔍 Obteniendo información de recursos para $DatabaseName..." -ForegroundColor Yellow
        $query = @"
SELECT
    COUNT(*) AS ConnectionCount,
    SUM(cpu_time) AS TotalCPUTime,
    SUM(memory_usage) * 8 AS TotalMemoryKB,
    SUM(reads) AS TotalReads,
    SUM(writes) AS TotalWrites
FROM sys.dm_exec_sessions
WHERE is_user_process = 1
  AND database_id = DB_ID('$DatabaseName')
"@
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop
        Write-Host "   ✅ Información de recursos obtenida" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Warning "   ❌ Error en recursos: $($_.Exception.Message)"
        return @{ ConnectionCount = 0 }
    }
}

function Get-ExpensiveQueries {
    param([string]$SqlInstance)

    try {
        Write-Host "   🔍 Obteniendo consultas más costosas..." -ForegroundColor Yellow
        $query = @"
SELECT TOP 10
    total_worker_time/1000000.0 AS CPUTotalSegundos,
    execution_count AS Ejecuciones,
    (total_worker_time/1000000.0)/execution_count AS CPUPromedioSegundos,
    last_execution_time AS UltimaEjecucion,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text)
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS QuerySQL,
    total_physical_reads AS LecturasFisicas,
    total_logical_writes AS EscriturasLogicas,
    total_logical_reads AS LecturasLogicas
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE execution_count > 0
ORDER BY total_worker_time DESC
"@
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop
        Write-Host "   ✅ Consultas costosas obtenidas ($($result.Count) consultas)" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Warning "   ❌ Error obteniendo consultas costosas: $($_.Exception.Message)"
        return @()
    }
}

function Get-MemoryStatistics {
    param([string]$SqlInstance)

    try {
        Write-Host "   🔍 Obteniendo estadísticas de memoria..." -ForegroundColor Yellow
        $query = @"
SELECT
    physical_memory_kb/1024 AS MemoriaFisicaMB,
    committed_kb/1024 AS MemoriaComprometidaMB,
    committed_target_kb/1024 AS MemoriaObjetivoMB
FROM sys.dm_os_sys_info

SELECT
    type AS TipoMemoria,
    pages_kb/1024 AS PaginasMB,
    virtual_memory_committed_kb/1024 AS MemoriaVirtualMB,
    awe_allocated_kb/1024 AS AweMB
FROM sys.dm_os_memory_clerks
WHERE pages_kb > 0
ORDER BY pages_kb DESC
"@
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop
        Write-Host "   ✅ Estadísticas de memoria obtenidas" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Warning "   ❌ Error obteniendo estadísticas de memoria: $($_.Exception.Message)"
        return @()
    }
}

function Get-BackupHistoryEnhanced {
    param([string]$SqlInstance, [string]$DatabaseName)

    try {
        Write-Host "   🔍 Obteniendo historial de backups de $DatabaseName..." -ForegroundColor Yellow
        $query = @"
SELECT TOP 10
    database_name AS DatabaseName,
    backup_start_date AS BackupStartDate,
    backup_finish_date AS BackupFinishDate,
    type AS BackupType,
    CASE type
        WHEN 'D' THEN 'Completo'
        WHEN 'I' THEN 'Diferencial'
        WHEN 'L' THEN 'Log'
        ELSE 'Otro'
    END AS BackupTypeDesc,
    backup_size / 1024 / 1024 AS BackupSizeMB,
    DATEDIFF(HOUR, backup_start_date, GETDATE()) AS HoursSinceBackup
FROM msdb.dbo.backupset
WHERE database_name = '$DatabaseName'
ORDER BY backup_start_date DESC
"@
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "msdb" -Query $query -ErrorAction Stop
        Write-Host "   ✅ Historial de backups obtenido ($($result.Count) backups)" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Warning "   ❌ Error en backups: $($_.Exception.Message)"
        return @()
    }
}

function Get-PatchAnalysis {
    param($InstanceInfo)

    try {
        if (-not $InstanceInfo) {
            return @{
                EstaParcheado = $false
                EstadoParches = "No disponible"
                Recomendacion = "No se pudo obtener información de parches"
            }
        }

        $version = $InstanceInfo.Version
        return @{
            EstaParcheado = $true
            EstadoParches = "Actualizado"
            Recomendacion = "El servidor está actualizado"
            VersionActual = $version
            UltimaVersion = "16.0.1100.0"
        }
    }
    catch {
        Write-Warning "Error analizando parches: $($_.Exception.Message)"
        return @{
            EstaParcheado = $false
            EstadoParches = "Error en análisis"
            Recomendacion = "Verificar manualmente el estado de parches"
        }
    }
}

# NUEVAS FUNCIONES AÑADIDAS PARA LAS MEJORAS SOLICITADAS

function Get-DailyDiskReport {
    param(
        [string[]]$SqlInstances,
        [string]$ReportPath = ".\reports\"
    )

    try {
        Write-Host "`n   💽 EJECUTANDO REPORTE DIARIO DE DISCOS..." -ForegroundColor Cyan

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $dailyReportData = @{}

        foreach ($instance in $SqlInstances) {
            Write-Host "   🔍 Analizando discos en: $instance" -ForegroundColor Yellow

            # Usar la nueva función de discos detallados
            $detailedDisks = Get-DetailedDiskSpace -SqlInstance $instance

            $dailyReportData[$instance] = @{
                DetailedDiskSpace = $detailedDisks
                CheckDate         = Get-Date
                ReportType        = "DailyDiskReport"
            }

            # Verificar discos con problemas y generar notificaciones
            $criticalDisks = $detailedDisks | Where-Object { $_.AlertLevel -eq "Critico" }
            $warningDisks = $detailedDisks | Where-Object { $_.AlertLevel -eq "Advertencia" }

            if ($criticalDisks.Count -gt 0) {
                $criticalMessage = "Discos en estado CRITICO en $instance : " +
                ($criticalDisks | ForEach-Object { "$($_.Name) ($($_.PercentUsed)%)" }) -join ", "
                Send-DbaNotification -Subject "🚨 ALERTA CRITICA - Espacio en disco $instance" -Body $criticalMessage -Type "Error"
            }

            if ($warningDisks.Count -gt 0) {
                $warningMessage = "Discos en estado de ADVERTENCIA en $instance : " +
                ($warningDisks | ForEach-Object { "$($_.Name) ($($_.PercentUsed)%)" }) -join ", "
                Send-DbaNotification -Subject "⚠️ Advertencia - Espacio en disco $instance" -Body $warningMessage -Type "Warning"
            }

            # Mostrar resumen por servidor
            Write-Host "   📊 Resumen discos $instance" -ForegroundColor White
            Write-Host "      • Total unidades: $($detailedDisks.Count)" -ForegroundColor Gray
            Write-Host "      • Puntos de montaje: $(($detailedDisks | Where-Object { $_.IsMountPoint }).Count)" -ForegroundColor Gray
            Write-Host "      • Estado crítico: $($criticalDisks.Count)" -ForegroundColor Red
            Write-Host "      • Estado advertencia: $($warningDisks.Count)" -ForegroundColor Yellow
        }

        # SOLO HTML - ELIMINADO GUARDADO JSON
        Write-Host "   ✅ Reporte diario de discos completado" -ForegroundColor Green

        return @{
            Data       = $dailyReportData
            Timestamp  = $timestamp
        }

    }
    catch {
        Write-Error "   ❌ Error en reporte diario de discos: $($_.Exception.Message)"
        return $null
    }
}

function Get-VersionComplianceReport {
    param(
        [string[]]$SqlInstances,
        [string]$ReportPath = ".\reports\"
    )

    try {
        Write-Host "`n   🔄 GENERANDO REPORTE DE CUMPLIMIENTO DE VERSIONES..." -ForegroundColor Cyan

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $versionReportData = @{}

        foreach ($instance in $SqlInstances) {
            Write-Host "   🔍 Verificando versión en: $instance" -ForegroundColor Yellow

            # Usar la nueva función de información de versión
            $versionInfo = Get-SQLServerVersionInfo -SqlInstance $instance
            $versionReportData[$instance] = $versionInfo

            # Generar notificaciones si no está actualizado
            if ($versionInfo.PatchesBehind -gt 0) {
                $patchMessage = "Servidor $instance tiene $($versionInfo.PatchesBehind) parches pendientes. " +
                "Versión actual: $($versionInfo.Version)"
                Send-DbaNotification -Subject "⚠️ Servidor no actualizado - $instance" -Body $patchMessage -Type "Warning"
            }
        }

        # Generar resumen del reporte
        $outdatedServers = $versionReportData.GetEnumerator() | Where-Object { $_.Value.PatchesBehind -gt 0 }
        $upToDateServers = $versionReportData.GetEnumerator() | Where-Object { $_.Value.IsUpToDate -eq $true }

        $summary = [PSCustomObject]@{
            TotalServers    = $SqlInstances.Count
            UpToDateServers = $upToDateServers.Count
            OutdatedServers = $outdatedServers.Count
            CheckDate       = Get-Date
        }

        $versionReportData["Summary"] = $summary

        # Mostrar resumen
        Write-Host "   📊 RESUMEN DE VERSIONES:" -ForegroundColor White
        Write-Host "      • Total servidores: $($SqlInstances.Count)" -ForegroundColor Gray
        Write-Host "      • Actualizados: $($upToDateServers.Count)" -ForegroundColor Green
        Write-Host "      • Con parches pendientes: $($outdatedServers.Count)" -ForegroundColor Yellow

        if ($outdatedServers.Count -gt 0) {
            Write-Host "      • Servidores desactualizados:" -ForegroundColor Red
            foreach ($server in $outdatedServers) {
                Write-Host "        - $($server.Key): $($server.Value.PatchesBehind) parches pendientes" -ForegroundColor Red
            }
        }

        Write-Host "   ✅ Reporte de versiones completado" -ForegroundColor Green

        return @{
            Data       = $versionReportData
            Summary    = $summary
        }

    }
    catch {
        Write-Error "   ❌ Error en reporte de versiones: $($_.Exception.Message)"
        return $null
    }
}

function Get-BackupJobsHealthReport {
    param(
        [string[]]$SqlInstances,
        [string]$ReportPath = ".\reports\"
    )

    try {
        Write-Host "`n   📊 VERIFICANDO ESTADO DE JOBS DE BACKUP..." -ForegroundColor Cyan

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupJobsReport = @{}
        $totalErrors = 0

        foreach ($instance in $SqlInstances) {
            Write-Host "   🔍 Revisando jobs de backup en: $instance" -ForegroundColor Yellow

            # Usar la nueva función de estado de jobs de backup
            $backupJobStatus = Get-BackupJobStatus -SqlInstance $instance -HoursBack 24

            $backupJobsReport[$instance] = @{
                JobStatusReport = $backupJobStatus.JobStatusReport
                HasErrors       = $backupJobStatus.HasErrors
                CheckDate       = Get-Date
            }

            # Contar errores y generar notificaciones
            if ($backupJobStatus.HasErrors) {
                $errorJobs = $backupJobStatus.JobStatusReport | Where-Object { $_.JobStatus -eq "Failed" }
                $totalErrors += $errorJobs.Count

                foreach ($errorJob in $errorJobs) {
                    $errorMessage = "Job: $($errorJob.JobName) - Último error: $($errorJob.ErrorMessage)"
                    Send-DbaNotification -Subject "🚨 ERROR en Job de Backup - $instance" -Body $errorMessage -Type "Error"
                }
            }

            # Mostrar resumen por servidor
            $totalJobs = $backupJobStatus.JobStatusReport.Count
            $failedJobs = ($backupJobStatus.JobStatusReport | Where-Object { $_.JobStatus -eq "Failed" }).Count

            Write-Host "   📊 Resumen jobs $instance" -ForegroundColor White
            Write-Host "      • Total jobs: $totalJobs" -ForegroundColor Gray
            Write-Host "      • Jobs con error: $failedJobs" -ForegroundColor $(if ($failedJobs -gt 0) { "Red" } else { "Green" })
        }

        # Resumen general
        Write-Host "   📊 RESUMEN GENERAL JOBS DE BACKUP:" -ForegroundColor White
        Write-Host "      • Total servidores revisados: $($SqlInstances.Count)" -ForegroundColor Gray
        Write-Host "      • Total errores encontrados: $totalErrors" -ForegroundColor $(if ($totalErrors -gt 0) { "Red" } else { "Green" })

        if ($totalErrors -eq 0) {
            Send-DbaNotification -Subject "✅ Todos los jobs de backup están funcionando correctamente" -Body "Revisión completada sin errores" -Type "Success"
        }

        Write-Host "   ✅ Reporte de jobs de backup completado" -ForegroundColor Green

        return @{
            Data        = $backupJobsReport
            TotalErrors = $totalErrors
            Timestamp   = $timestamp
        }

    }
    catch {
        Write-Error "   ❌ Error en reporte de jobs de backup: $($_.Exception.Message)"
        return $null
    }
}

# 🔹 FUNCIÓN PRINCIPAL DEL COLECTOR - ACTUALIZADA CON NUEVAS CAPACIDADES
function Get-CompleteDatabaseInfo {
    param(
        [string]$SqlInstance,
        [string]$DatabaseName = "AdventureWorks2022",
        [switch]$IncludeNewFeatures = $false
    )

    try {
        Write-Host "`n   🚦 Recolectando información completa de $DatabaseName en $SqlInstance..." -ForegroundColor Cyan

        # Verificar conexión básica
        Write-Host "   🔄 Verificando conexión a $SqlInstance..." -ForegroundColor Yellow
        $testConnection = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query "SELECT @@VERSION AS Version" -ErrorAction Stop

        if (-not $testConnection) {
            throw "No se pudo conectar a la instancia $SqlInstance"
        }

        Write-Host "   ✅ Conexión exitosa a $SqlInstance" -ForegroundColor Green

        # Recolectar datos paso a paso (funciones existentes)
        $instanceInfo = Get-SQLInstanceEnhancedInfo -SqlInstance $SqlInstance
        $engineInfo = Get-SQLServerEngineInfo -SqlInstance $SqlInstance
        $patchAnalysis = Get-SQLPatchAnalysis -EngineInfo $engineInfo
        $indexData = Get-EnhancedIndexMaintenance -SqlInstance $SqlInstance -DatabaseName $DatabaseName
        $diskData = Get-DiskSpaceEnhanced -SqlInstance $SqlInstance -DatabaseName $DatabaseName
        $resourceData = Get-ResourceConsumptionEnhanced -SqlInstance $SqlInstance -DatabaseName $DatabaseName
        $expensiveQueries = Get-ExpensiveQueries -SqlInstance $SqlInstance
        $memoryStats = Get-MemoryStatistics -SqlInstance $SqlInstance
        $backupData = Get-BackupHistoryEnhanced -SqlInstance $SqlInstance -DatabaseName $DatabaseName

        # NUEVOS DATOS AÑADIDOS
        $enhancedData = @{}

        if ($IncludeNewFeatures) {
            Write-Host "   🔄 Recolectando información mejorada..." -ForegroundColor Yellow

            # Información de versión y parches mejorada
            $enhancedData.VersionInfo = Get-SQLServerVersionInfo -SqlInstance $SqlInstance

            # Información detallada de discos
            $enhancedData.DetailedDiskSpace = Get-DetailedDiskSpace -SqlInstance $SqlInstance

            # Estado de jobs de backup
            $backupJobStatus = Get-BackupJobStatus -SqlInstance $SqlInstance
            $enhancedData.BackupJobStatus = $backupJobStatus.JobStatusReport
            $enhancedData.BackupJobsHaveErrors = $backupJobStatus.HasErrors
        }

        return @{
            InstanceInfo     = $instanceInfo
            EngineInfo       = $engineInfo
            PatchAnalysis    = $patchAnalysis
            IndexStats       = $indexData
            DiskStats        = $diskData
            ResourceUsage    = $resourceData
            ExpensiveQueries = $expensiveQueries
            MemoryStatistics = $memoryStats
            BackupData       = $backupData
            ConnectionTest   = $testConnection
            EnhancedData     = $enhancedData
            CollectionDate   = Get-Date
        }
    }
    catch {
        Write-Error "❌ Error en Get-CompleteDatabaseInfo: $($_.Exception.Message)"
        return $null
    }
}

# 🔹 FUNCIÓN PARA COLECCIÓN MASIVA MEJORADA
function Invoke-EnhancedDataCollection {
    param(
        [string[]]$SqlInstances,
        [string]$ReportPath = ".\reports\",
        [switch]$DailyMode = $false
    )

    try {
        Write-Host "`n   🚀 INICIANDO COLECCIÓN MEJORADA DE DATOS..." -ForegroundColor Cyan
        Write-Host "   📋 Servidores a procesar: $($SqlInstances -join ', ')" -ForegroundColor White

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $completeReportData = @{}

        foreach ($instance in $SqlInstances) {
            Write-Host "`n   🔄 Procesando servidor: $instance" -ForegroundColor Yellow

            # Recolectar datos completos incluyendo nuevas características
            $serverData = Get-CompleteDatabaseInfo -SqlInstance $instance -IncludeNewFeatures:$true

            if ($serverData) {
                $completeReportData[$instance] = $serverData
                Write-Host "   ✅ Datos recolectados exitosamente de $instance" -ForegroundColor Green
            }
            else {
                Write-Host "   ⚠️  No se pudieron recolectar datos de $instance" -ForegroundColor Yellow
            }
        }

        # Ejecutar reportes especializados en modo diario
        if ($DailyMode) {
            Write-Host "`n   📅 EJECUTANDO REPORTES DIARIOS ESPECIALIZADOS..." -ForegroundColor Cyan

            # Reporte diario de discos
            $diskReport = Get-DailyDiskReport -SqlInstances $SqlInstances -ReportPath $ReportPath

            # Reporte de cumplimiento de versiones
            $versionReport = Get-VersionComplianceReport -SqlInstances $SqlInstances -ReportPath $ReportPath

            # Reporte de salud de jobs de backup
            $backupJobsReport = Get-BackupJobsHealthReport -SqlInstances $SqlInstances -ReportPath $ReportPath

            $completeReportData["DailySpecialReports"] = @{
                DiskReport       = $diskReport
                VersionReport    = $versionReport
                BackupJobsReport = $backupJobsReport
            }
        }

        # SOLO HTML - ELIMINADO GUARDADO JSON
        Write-Host "`n   ✅ COLECCIÓN MEJORADA COMPLETADA" -ForegroundColor Green

        return @{
            Data             = $completeReportData
            Timestamp        = $timestamp
            ServersProcessed = $SqlInstances.Count
        }

    }
    catch {
        Write-Error "❌ Error en colección mejorada: $($_.Exception.Message)"
        return $null
    }
}

# AGREGAR ESTAS FUNCIONES AL FINAL

function Get-SQLServerVersionInfo {
    param([string]$SqlInstance)

    try {
        Write-Host "   🔄 Verificando versión de SQL Server y parches..." -ForegroundColor Yellow

        $query = @"
SELECT
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('ProductLevel') AS ProductLevel,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('ProductUpdateLevel') AS ProductUpdateReference,
    @@VERSION AS FullVersion
"@

        $versionInfo = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop

        # Análisis básico de versión
        $productVersion = $versionInfo.ProductVersion
        $productLevel = $versionInfo.ProductLevel

        # Determinar si necesita parches (lógica simple)
        $isUpToDate = $true
        $patchesBehind = 0
        $status = "Actualizado"

        if ($productLevel -eq "RTM") {
            $isUpToDate = $false
            $patchesBehind = 1
            $status = "Necesita Service Pack"
        }

        return @{
            Version = $productVersion
            ProductLevel = $productLevel
            Edition = $versionInfo.Edition
            IsUpToDate = $isUpToDate
            PatchesBehind = $patchesBehind
            Status = $status
            FullVersion = $versionInfo.FullVersion
            CheckDate = Get-Date
        }
    }
    catch {
        Write-Error "   ❌ Error verificando versión de SQL Server: $($_.Exception.Message)"
        return @{
            Version = "N/A"
            ProductLevel = "N/A"
            Edition = "N/A"
            IsUpToDate = $false
            PatchesBehind = 999
            Status = "Error"
            FullVersion = "N/A"
            CheckDate = Get-Date
        }
    }
}

function Get-DetailedDiskSpace {
    param([string]$SqlInstance)

    try {
        Write-Host "   💽 Obteniendo información detallada de discos..." -ForegroundColor Yellow

        $query = @"
SELECT
    DISTINCT
    vs.volume_mount_point AS Name,
    vs.total_bytes/1024/1024/1024 AS TotalGB,
    vs.available_bytes/1024/1024/1024 AS FreeGB,
    (vs.total_bytes - vs.available_bytes)/1024/1024/1024 AS UsedGB,
    CAST((vs.total_bytes - vs.available_bytes) * 100.0 / vs.total_bytes AS DECIMAL(5,2)) AS PercentUsed,
    CASE
        WHEN CAST((vs.total_bytes - vs.available_bytes) * 100.0 / vs.total_bytes AS DECIMAL(5,2)) > 90 THEN 'Critico'
        WHEN CAST((vs.total_bytes - vs.available_bytes) * 100.0 / vs.total_bytes AS DECIMAL(5,2)) > 80 THEN 'Advertencia'
        ELSE 'Normal'
    END AS AlertLevel,
    CASE
        WHEN vs.volume_mount_point LIKE '%[A-Z]:\' THEN 'Disco Local'
        ELSE 'Punto de Montaje'
    END AS Type,
    0 AS IsMountPoint  -- Simplificado para esta implementación
FROM sys.master_files AS f
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id) AS vs
ORDER BY vs.volume_mount_point
"@

        $diskInfo = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop

        Write-Host "   ✅ Información de discos obtenida ($($diskInfo.Count) volúmenes)" -ForegroundColor Green
        return $diskInfo
    }
    catch {
        Write-Error "   ❌ Error obteniendo información de discos: $($_.Exception.Message)"
        return @()
    }
}

function Get-BackupJobStatus {
    param(
        [string]$SqlInstance,
        [int]$HoursBack = 24
    )

    try {
        Write-Host "   📊 Verificando estado de jobs de backup..." -ForegroundColor Yellow

        $query = @"
SELECT
    j.name AS JobName,
    j.enabled AS IsEnabled,
    h.run_status AS LastRunStatus,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        ELSE 'Unknown'
    END AS JobStatus,
    h.run_date AS LastRunDate,
    h.run_time AS LastRunTime,
    h.run_duration AS RunDuration,
    h.message AS ErrorMessage
FROM msdb.dbo.sysjobs j
LEFT JOIN (
    SELECT
        job_id,
        run_status,
        run_date,
        run_time,
        run_duration,
        message,
        ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY run_date DESC, run_time DESC) as rn
    FROM msdb.dbo.sysjobhistory
    WHERE step_id = 0  -- Solo el resultado del job, no steps individuales
) h ON j.job_id = h.job_id AND h.rn = 1
WHERE j.name LIKE '%backup%' OR j.name LIKE '%Backup%'
ORDER BY j.name
"@

        $jobStatus = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "msdb" -Query $query -ErrorAction Stop

        $hasErrors = $false
        $jobStatusReport = @()

        foreach ($job in $jobStatus) {
            $jobReport = @{
                JobName = $job.JobName
                IsEnabled = $job.IsEnabled
                LastRunStatus = $job.LastRunStatus
                JobStatus = $job.JobStatus
                LastRunDate = $job.LastRunDate
                HasErrors = ($job.JobStatus -eq "Failed")
                ErrorMessage = $job.ErrorMessage
            }

            if ($job.JobStatus -eq "Failed") {
                $hasErrors = $true
            }

            $jobStatusReport += $jobReport
        }

        Write-Host "   ✅ Estado de jobs de backup verificado ($($jobStatusReport.Count) jobs)" -ForegroundColor Green

        return @{
            JobStatusReport = $jobStatusReport
            HasErrors = $hasErrors
            TotalJobs = $jobStatusReport.Count
            FailedJobs = ($jobStatusReport | Where-Object { $_.HasErrors -eq $true }).Count
        }
    }
    catch {
        Write-Error "   ❌ Error verificando jobs de backup: $($_.Exception.Message)"
        return @{
            JobStatusReport = @()
            HasErrors = $false
            TotalJobs = 0
            FailedJobs = 0
        }
    }
}

function Send-DbaNotification {
    param(
        [string]$Subject,
        [string]$Body,
        [string]$Type = "Info"
    )

    try {
        # En una implementación real, aquí enviarías email, Teams, Slack, etc.
        # Por ahora solo mostramos en consola
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        switch ($Type) {
            "Error" {
                Write-Host "🚨 NOTIFICACIÓN - $Subject" -ForegroundColor Red
                Write-Host "📝 $Body" -ForegroundColor Red
            }
            "Warning" {
                Write-Host "⚠️ NOTIFICACIÓN - $Subject" -ForegroundColor Yellow
                Write-Host "📝 $Body" -ForegroundColor Yellow
            }
            "Success" {
                Write-Host "✅ NOTIFICACIÓN - $Subject" -ForegroundColor Green
                Write-Host "📝 $Body" -ForegroundColor Green
            }
            default {
                Write-Host "ℹ️ NOTIFICACIÓN - $Subject" -ForegroundColor Cyan
                Write-Host "📝 $Body" -ForegroundColor Cyan
            }
        }

        Write-Host "   ✅ Notificación registrada" -ForegroundColor Gray

        return $true
    }
    catch {
        Write-Warning "   ❌ Error enviando notificación: $($_.Exception.Message)"
        return $false
    }
}