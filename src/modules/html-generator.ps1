# html-generator.ps1 (OPTIMIZADO)
# Generador de reportes HTML para SQL Server
# ============================================================================

function Generate-CompleteHTMLReport {
    <#
    .SYNOPSIS
    Genera un reporte HTML completo con todos los datos recolectados.
    .PARAMETER ReportData
    Hashtable con todos los datos recolectados por Get-CompleteDatabaseInfo
    .PARAMETER OutputPath
    Ruta donde se guardará el archivo HTML
    .PARAMETER CssFile
    Ruta al archivo CSS para estilos
    #>
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$ReportData,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$CssFile
    )

    Write-Host "🎨 Creando reporte HTML en $OutputPath..." -ForegroundColor Cyan

    try {
        # Cargar CSS
        $cssContent = Get-CSSContent -CssFile $CssFile

        # ========================================================================
        # EXTRAER DATOS DE LA ESTRUCTURA REFACTORIZADA
        # ========================================================================

        # Datos básicos (siempre presentes)
        $instanceInfo = $ReportData.InstanceInfo
        $indexStats = $ReportData.IndexStats
        $diskStatsDB = $ReportData.DiskStatsDB  # CORREGIDO: era DiskStats
        $resourceUsage = $ReportData.ResourceUsage
        $expensiveQueries = $ReportData.ExpensiveQueries
        $memoryStats = $ReportData.MemoryStats
        $backupHistory = $ReportData.BackupHistory

        # Datos mejorados (opcionales)
        $enhancedData = $ReportData.EnhancedData
        $allDiskSpace = if ($enhancedData) { $enhancedData.AllDiskSpace } else { @() }
        $backupJobStatus = if ($enhancedData -and $enhancedData.BackupJobStatus) {
            $enhancedData.BackupJobStatus
        }
        else {
            @{ JobStatusReport = @(); HasErrors = $false; TotalJobs = 0; FailedJobs = 0 }
        }

        # ========================================================================
        # CALCULAR MÉTRICAS PARA EL DASHBOARD
        # ========================================================================

        # Métricas de índices
        $totalIndexes = if ($indexStats) { $indexStats.Count } else { 0 }
        $rebuildRecommended = if ($indexStats) {
            ($indexStats | Where-Object { $_.RecommendedAction -eq 'REBUILD' }).Count
        }
        else { 0 }
        $reorganizeRecommended = if ($indexStats) {
            ($indexStats | Where-Object { $_.RecommendedAction -eq 'REORGANIZE' }).Count
        }
        else { 0 }

        # Métricas de disco (archivos de BD)
        $totalFiles = if ($diskStatsDB) { $diskStatsDB.Count } else { 0 }
        $criticalFiles = if ($diskStatsDB) {
            ($diskStatsDB | Where-Object { $_.PercentUsed -gt 90 }).Count
        }
        else { 0 }

        # Métricas de recursos
        $connectionCount = if ($resourceUsage) { $resourceUsage.ConnectionCount } else { 0 }

        # Métricas de backups
        $recentBackups = if ($backupHistory) { $backupHistory.Count } else { 0 }

        # Métricas mejoradas
        $totalDisks = if ($allDiskSpace) { $allDiskSpace.Count } else { 0 }
        $criticalDisks = if ($allDiskSpace) {
            ($allDiskSpace | Where-Object { $_.AlertLevel -eq "Critico" }).Count
        }
        else { 0 }
        $warningDisks = if ($allDiskSpace) {
            ($allDiskSpace | Where-Object { $_.AlertLevel -eq "Advertencia" }).Count
        }
        else { 0 }
        $mountPoints = if ($allDiskSpace) {
            ($allDiskSpace | Where-Object { $_.Type -eq "Punto de Montaje" }).Count
        }
        else { 0 }

        # Métricas de parches
        $needsPatches = if ($instanceInfo -and $instanceInfo.PatchAnalysis) {
            $instanceInfo.PatchAnalysis.NeedsPatches
        }
        else { $false }

        # Métricas de jobs de backup
        $failedBackupJobs = $backupJobStatus.FailedJobs
        $totalBackupJobs = $backupJobStatus.TotalJobs

        # ========================================================================
        # GENERAR HTML
        # ========================================================================

        $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte SQL Server - $($ReportData.DatabaseName)</title>
    <style>
        $cssContent
    </style>
</head>
<body>
    <div class="container">
        <!-- HEADER -->
        <header class="header">
            <div class="header-content">
                <h1>📊 Reporte de Salud de SQL Server</h1>
                <p class="subtitle">Análisis completo de rendimiento y mantenimiento</p>
            </div>
        </header>

<div class="metadata-grid">
    <div class="metadata-item">
        <span class="metadata-icon">🖥️</span>
        <div class="metadata-content">
            <div class="metadata-label">Servidor</div>
            <div class="metadata-value">$($instanceInfo.ServerName)</div>
        </div>
    </div>
    <div class="metadata-item">
        <span class="metadata-icon">🗃️</span>
        <div class="metadata-content">
            <div class="metadata-label">Base de datos</div>
            <div class="metadata-value">$DatabaseName</div>
        </div>
    </div>
    <div class="metadata-item full-width">
        <span class="metadata-icon">📋</span>
        <div class="metadata-content">
            <div class="metadata-label">Instancia</div>
            <div class="metadata-value">
                Microsoft SQL Server $($instanceInfo.ProductLevel) • $($instanceInfo.ProductUpdateReference)<br>
                $($instanceInfo.ProductVersion) • $($instanceInfo.Edition -replace '\(64-bit\)', '(X64)')
            </div>
        </div>
    </div>
</div>

        <!-- STATS GRID -->
        <div class="stats-grid">
            <div class="stat-card $(if ($rebuildRecommended -gt 0) { 'critical' } elseif ($reorganizeRecommended -gt 0) { 'warning' } else { 'success' })">
                <div class="stat-icon">📈</div>
                <div class="stat-value">$totalIndexes</div>
                <div class="stat-label">Índices Totales</div>
            </div>
            <div class="stat-card $(if ($criticalFiles -gt 0) { 'warning' } else { 'info' })">
                <div class="stat-icon">💾</div>
                <div class="stat-value">$totalFiles</div>
                <div class="stat-label">Archivos BD</div>
            </div>
            <div class="stat-card info">
                <div class="stat-icon">🔌</div>
                <div class="stat-value">$connectionCount</div>
                <div class="stat-label">Conexiones</div>
            </div>
            <div class="stat-card $(if ($recentBackups -eq 0) { 'warning' } else { 'success' })">
                <div class="stat-icon">🔄</div>
                <div class="stat-value">$recentBackups</div>
                <div class="stat-label">Backups</div>
            </div>
            <div class="stat-card $(if ($needsPatches) { 'warning' } else { 'success' })">
                <div class="stat-icon">🔧</div>
                <div class="stat-value">$(if ($needsPatches) { 'SÍ' } else { 'NO' })</div>
                <div class="stat-label">Parches Pendientes</div>
            </div>
            <div class="stat-card $(if ($failedBackupJobs -gt 0) { 'critical' } else { 'success' })">
                <div class="stat-icon">⚠️</div>
                <div class="stat-value">$failedBackupJobs</div>
                <div class="stat-label">Jobs Fallidos</div>
            </div>
        </div>

        $(Generate-VersionSection -InstanceInfo $instanceInfo)
        $(Generate-DiskSpaceSection -AllDiskSpace $allDiskSpace -MountPoints $mountPoints -CriticalDisks $criticalDisks -WarningDisks $warningDisks)
        $(Generate-BackupJobsSection -BackupJobStatus $backupJobStatus)
        $(Generate-IndexSection -IndexStats $indexStats -TotalIndexes $totalIndexes)
        $(Generate-DatabaseFilesSection -DiskStatsDB $diskStatsDB)
        $(Generate-BackupHistorySection -BackupHistory $backupHistory)
        $(Generate-ExpensiveQueriesSection -ExpensiveQueries $expensiveQueries)
        $(Generate-ResourceUsageSection -ResourceUsage $resourceUsage)
        $(Generate-AlertsSection -RebuildRecommended $rebuildRecommended -ReorganizeRecommended $reorganizeRecommended -CriticalFiles $criticalFiles -RecentBackups $recentBackups -ConnectionCount $connectionCount -NeedsPatches $needsPatches -FailedBackupJobs $failedBackupJobs -CriticalDisks $criticalDisks)

        <!-- FOOTER -->
        <footer class="footer">
            <p>Reporte generado el $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')</p>
            <p>dbatools-AW2022-v2 - Sistema de Monitoreo SQL Server by Santiago Guevara</p>
            <p><strong>Funciones:</strong> Análisis de parches • Monitoreo de discos • Estado de jobs • Análisis de rendimiento</p>
        </footer>
    </div>
</body>
</html>
"@

        Set-Content -Path $OutputPath -Value $html -Encoding UTF8
        Write-Host "✅ Reporte HTML generado exitosamente" -ForegroundColor Green
        return $OutputPath
    }
    catch {
        Write-Error "❌ Error generando HTML: $($_.Exception.Message)"
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        throw
    }
}

# ============================================================================
# FUNCIONES AUXILIARES PARA GENERAR SECCIONES HTML
# ============================================================================

function Generate-VersionSection {
    param($InstanceInfo)

    if (-not $InstanceInfo -or -not $InstanceInfo.PatchAnalysis) {
        return "<section class='section'><h2 class='section-title'><span class='section-icon'>🔍</span>Información de Versión y Parches</h2><div class='no-data'>Información no disponible</div></section>"
    }

    $patchInfo = $InstanceInfo.PatchAnalysis
    $statusClass = if ($patchInfo.NeedsPatches) { "badge-warning" } else { "badge-success" }
    $statusText = if ($patchInfo.NeedsPatches) { "⚠️ Necesita Actualización" } else { "✅ Actualizado" }

    return @"
<section class="section">
    <h2 class="section-title">
        <span class="section-icon">🔍</span>
        Información de Versión y Cumplimiento de Parches
    </h2>
    <div class='table-container'>
        <table>
            <thead>
                <tr>
                    <th>Propiedad</th>
                    <th>Valor</th>
                    <th>Estado</th>
                    <th>Recomendación</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td><strong>Servidor</strong></td>
                    <td>$($InstanceInfo.ServerName)</td>
                    <td><span class='badge $statusClass'>$statusText</span></td>
                    <td>$($patchInfo.Recommendation)</td>
                </tr>
                <tr>
                    <td><strong>Versión</strong></td>
                    <td>$($InstanceInfo.ProductVersion)</td>
                    <td><span class='badge badge-info'>$($InstanceInfo.ProductLevel)</span></td>
                    <td>Versión actual del motor SQL</td>
                </tr>
                <tr>
                    <td><strong>Build</strong></td>
                    <td>$($InstanceInfo.ProductBuild)</td>
                    <td><span class='badge badge-info'>Build actual</span></td>
                    <td>Número de compilación</td>
                </tr>
                <tr>
                    <td><strong>Edición</strong></td>
                    <td>$($InstanceInfo.Edition)</td>
                    <td><span class='badge badge-info'>$($InstanceInfo.Edition)</span></td>
                    <td>Edición instalada</td>
                </tr>
                <tr>
                    <td><strong>Estado de Parches</strong></td>
                    <td>$($patchInfo.Status)</td>
                    <td><span class='badge $statusClass'>$($patchInfo.Status)</span></td>
                    <td>$($patchInfo.Recommendation)</td>
                </tr>
                <tr>
                    <td><strong>Verificación</strong></td>
                    <td>$($patchInfo.CheckDate)</td>
                    <td><span class='badge badge-success'>Completada</span></td>
                    <td>Última verificación de parches</td>
                </tr>
            </tbody>
        </table>
    </div>
    $(if ($patchInfo.NeedsPatches) {
        @"
    <div class='alert-warning' style='margin-top: 15px;'>
        <strong>⚠️ Acción Recomendada:</strong> $($patchInfo.Recommendation)
        $(if ($patchInfo.KBLink) { "<br>Más información: <a href='$($patchInfo.KBLink)' target='_blank'>$($patchInfo.KBLink)</a>" })
    </div>
"@
    })
</section>
"@
}

function Generate-DiskSpaceSection {
    param($AllDiskSpace, $MountPoints, $CriticalDisks, $WarningDisks)

    if (-not $AllDiskSpace -or $AllDiskSpace.Count -eq 0) {
        return "<section class='section'><h2 class='section-title'><span class='section-icon'>💽</span>Espacio en Disco</h2><div class='no-data'>Información no disponible</div></section>"
    }

    $tableRows = foreach ($disk in $AllDiskSpace) {
        $usageClass = if ($disk.PercentUsed -gt 90) { 'status-critical' }
        elseif ($disk.PercentUsed -gt 80) { 'status-warning' }
        else { 'status-success' }
        $badgeClass = if ($disk.AlertLevel -eq "Critico") { 'badge-critical' }
        elseif ($disk.AlertLevel -eq "Advertencia") { 'badge-warning' }
        else { 'badge-success' }
        $typeIcon = if ($disk.Type -eq "Punto de Montaje") { '📌' } else { '💾' }

        @"
        <tr>
            <td><strong>$typeIcon $($disk.Name)</strong></td>
            <td>$([math]::Round($disk.TotalGB, 2)) GB</td>
            <td>$([math]::Round($disk.UsedGB, 2)) GB</td>
            <td>$([math]::Round($disk.FreeGB, 2)) GB</td>
            <td><span class="$usageClass">$([math]::Round($disk.PercentUsed, 2))%</span></td>
            <td><span class="badge badge-info">$($disk.Type)</span></td>
            <td><span class="badge $badgeClass">$($disk.AlertLevel)</span></td>
        </tr>
"@
    }

    return @"
<section class="section">
    <h2 class="section-title">
        <span class="section-icon">💽</span>
        Reporte Detallado de Espacio en Disco
    </h2>
    <div class="table-container">
        <table>
            <thead>
                <tr>
                    <th>Unidad/Ruta</th>
                    <th>Total</th>
                    <th>Usado</th>
                    <th>Libre</th>
                    <th>% Usado</th>
                    <th>Tipo</th>
                    <th>Estado</th>
                </tr>
            </thead>
            <tbody>
                $($tableRows -join "`n")
            </tbody>
        </table>
    </div>
    <div class="stats-grid" style="margin-top: 15px;">
        <div class="stat-card $(if ($CriticalDisks -gt 0) { 'critical' } else { 'success' })">
            <div class="stat-icon">🚨</div>
            <div class="stat-value">$CriticalDisks</div>
            <div class="stat-label">Críticos</div>
        </div>
        <div class="stat-card $(if ($WarningDisks -gt 0) { 'warning' } else { 'info' })">
            <div class="stat-icon">⚠️</div>
            <div class="stat-value">$WarningDisks</div>
            <div class="stat-label">Advertencias</div>
        </div>
        <div class="stat-card info">
            <div class="stat-icon">📌</div>
            <div class="stat-value">$MountPoints</div>
            <div class="stat-label">Puntos Montaje</div>
        </div>
        <div class="stat-card success">
            <div class="stat-icon">✅</div>
            <div class="stat-value">$(($AllDiskSpace | Where-Object { $_.AlertLevel -eq 'Normal' }).Count)</div>
            <div class="stat-label">Normales</div>
        </div>
    </div>
</section>
"@
}

function Generate-BackupJobsSection {
    param($BackupJobStatus)

    if (-not $BackupJobStatus -or $BackupJobStatus.TotalJobs -eq 0) {
        return "<section class='section'>
                    <h2 class='section-title'>
                        <span class='section-icon'>📋</span>Estado de Jobs de Backup
                    </h2>
                    <div class='no-data'>No se encontraron jobs de backup</div>
                </section>"
    }

    # Limitar a los primeros 30 jobs
    $jobs = $BackupJobStatus.JobStatusReport | Select-Object -First 30

    $tableRows = foreach ($job in $jobs) {
        $statusClass = if ($job.HasErrors) { 'status-critical' } else { 'status-success' }
        $badgeClass = if ($job.HasErrors) { 'badge-critical' } else { 'badge-success' }
        $enabledIcon = if ($job.IsEnabled) { '✅' } else { '❌' }

        # Truncar mensaje de error a 100 caracteres
        $ShortError = if ($job.ErrorMessage -and $job.ErrorMessage.Length -gt 100) {
            $job.ErrorMessage.Substring(0, 100) + "…"
        }
        else { $job.ErrorMessage }

        $ErrorDisplay = if ($ShortError) {
            "<small title='$($job.ErrorMessage)'>$ShortError</small>"
        }
        else {
            "N/A"
        }

        @"
        <tr>
            <td><strong>$($job.JobName)</strong></td>
            <td>$enabledIcon</td>
            <td>$($job.LastRunDate)</td>
            <td>$($job.JobStatus)</td>
            <td><span class='badge $badgeClass'>$($job.JobStatus)</span></td>
            <td>$ErrorDisplay</td>
        </tr>
"@
    }

    $alertBox = if ($BackupJobStatus.HasErrors) {
        "<div class='alert-critical' style='margin-top: 15px;'>
            <strong>🚨 ALERTA:</strong> Se detectaron jobs de backup con errores. Revise la configuración inmediatamente.
        </div>"
    }
    else {
        "<div class='alert-success' style='margin-top: 15px;'>
            <strong>✅ TODO CORRECTO:</strong> Todos los jobs de backup funcionan correctamente.
        </div>"
    }

    return @"
<section class='section'>
    <h2 class='section-title'>
        <span class='section-icon'>📋</span>
        Estado de Jobs de Backup ($($BackupJobStatus.TotalJobs) jobs)
    </h2>
    <div class='table-container'>
        <table class='compact-table'>
            <thead>
                <tr>
                    <th>Nombre del Job</th>
                    <th>Habilitado</th>
                    <th>Última Ejecución</th>
                    <th>Resultado</th>
                    <th>Estado</th>
                    <th>Error</th>
                </tr>
            </thead>
            <tbody>
                $($tableRows -join "`n")
            </tbody>
        </table>
    </div>
    $alertBox
</section>
"@
}


function Generate-IndexSection {
    param($IndexStats, $TotalIndexes)

    if (-not $IndexStats -or $IndexStats.Count -eq 0) {
        return "<section class='section'><h2 class='section-title'><span class='section-icon'>📊</span>Análisis de Índices</h2><div class='no-data'>No se encontraron índices</div></section>"
    }

    # Limitar a los primeros 30 registros
    $IndexStats = $IndexStats | Select-Object -First 50

    $tableRows = foreach ($index in $IndexStats) {
        # Truncar nombres largos
        $TableName = if ($index.TableName.Length -gt 25) { $index.TableName.Substring(0, 25) + "…" } else { $index.TableName }
        $IndexName = if ($index.IndexName.Length -gt 25) { $index.IndexName.Substring(0, 25) + "…" } else { $index.IndexName }

        # Clases de fragmentación y badge
        $statusClass = if ($index.Fragmentation -gt 30) { 'status-critical' }
        elseif ($index.Fragmentation -gt 10) { 'status-warning' }
        else { 'status-success' }

        $badgeClass = if ($index.RecommendedAction -eq 'REBUILD') { 'badge-critical' }
        elseif ($index.RecommendedAction -eq 'REORGANIZE') { 'badge-warning' }
        else { 'badge-success' }

        @"
        <tr>
            <td><strong>$TableName</strong></td>
            <td>$IndexName</td>
            <td>$($index.IndexType)</td>
            <td><span class='$statusClass'>$([math]::Round($index.Fragmentation, 2))%</span></td>
            <td>$($index.PageCount)</td>
            <td>$($index.RecordCount)</td>
            <td><span class='badge $badgeClass'>$($index.RecommendedAction)</span></td>
        </tr>
"@
    }

    return @"
<section class='section'>
    <h2 class='section-title'>
        <span class='section-icon'>📊</span>
        Análisis de Índices - $TotalIndexes Índices
    </h2>
    <div class='table-container'>
        <table class='compact-table'>
            <thead>
                <tr>
                    <th>Tabla</th>
                    <th>Índice</th>
                    <th>Tipo</th>
                    <th>Fragmentación</th>
                    <th>Páginas</th>
                    <th>Registros</th>
                    <th>Acción</th>
                </tr>
            </thead>
            <tbody>
                $($tableRows -join "`n")
            </tbody>
        </table>
    </div>
</section>
"@
}


function Generate-DatabaseFilesSection {
    param($DiskStatsDB)

    if (-not $DiskStatsDB -or $DiskStatsDB.Count -eq 0) {
        return "<section class='section'><h2 class='section-title'><span class='section-icon'>💾</span>Archivos de Base de Datos</h2><div class='no-data'>No se pudo obtener información</div></section>"
    }

    $tableRows = foreach ($file in $DiskStatsDB) {
        $usageClass = if ($file.PercentUsed -gt 90) { 'status-critical' }
        elseif ($file.PercentUsed -gt 80) { 'status-warning' }
        else { 'status-success' }

        @"
        <tr>
            <td><strong>$($file.FileName)</strong></td>
            <td>$($file.FileType)</td>
            <td>$([math]::Round($file.SizeMB, 2)) MB</td>
            <td>$([math]::Round($file.UsedMB, 2)) MB</td>
            <td>$([math]::Round($file.FreeMB, 2)) MB</td>
            <td><span class="$usageClass">$([math]::Round($file.PercentUsed, 2))%</span></td>
            <td><small>$($file.PhysicalPath)</small></td>
        </tr>
"@
    }

    return @"
<section class="section">
    <h2 class="section-title">
        <span class="section-icon">💾</span>
        Archivos de Base de Datos
    </h2>
    <div class="table-container">
        <table>
            <thead>
                <tr>
                    <th>Archivo</th>
                    <th>Tipo</th>
                    <th>Tamaño</th>
                    <th>Usado</th>
                    <th>Libre</th>
                    <th>% Usado</th>
                    <th>Ruta Física</th>
                </tr>
            </thead>
            <tbody>
                $($tableRows -join "`n")
            </tbody>
        </table>
    </div>
</section>
"@
}

function Generate-BackupHistorySection {
    param($BackupHistory)

    if (-not $BackupHistory -or $BackupHistory.Count -eq 0) {
        return "<section class='section'><h2 class='section-title'><span class='section-icon'>🔄</span>Historial de Backups</h2><div class='no-data'>No se encontraron backups recientes</div></section>"
    }

    $tableRows = foreach ($backup in $BackupHistory) {
        $hoursClass = if ($backup.HoursSinceBackup -gt 24) { 'status-warning' } else { 'status-success' }

        @"
        <tr>
            <td>$($backup.BackupStartDate)</td>
            <td>$($backup.BackupFinishDate)</td>
            <td>$($backup.BackupTypeDesc)</td>
            <td>$([math]::Round($backup.BackupSizeMB, 2)) MB</td>
            <td><span class="$hoursClass">$($backup.HoursSinceBackup)h</span></td>
        </tr>
"@
    }

    return @"
<section class="section">
    <h2 class="section-title">
        <span class="section-icon">🔄</span>
        Historial de Backups
    </h2>
    <div class="table-container compact-table">
        <table>
            <thead>
                <tr>
                    <th>Fecha Inicio</th>
                    <th>Fecha Fin</th>
                    <th>Tipo</th>
                    <th>Tamaño</th>
                    <th>Antigüedad</th>
                </tr>
            </thead>
            <tbody>
                $($tableRows -join "`n")
            </tbody>
        </table>
    </div>
</section>
"@
}

function Generate-ExpensiveQueriesSection {
    param($ExpensiveQueries)

    if (-not $ExpensiveQueries -or $ExpensiveQueries.Count -eq 0) {
        return "<section class='section'><h2 class='section-title'><span class='section-icon'>⚡</span>Consultas Costosas</h2><div class='no-data'>No hay consultas registradas</div></section>"
    }

    # Limitar a los primeros 30 registros para mayor compactación
    $ExpensiveQueries = $ExpensiveQueries | Select-Object -First 30

    $tableRows = foreach ($query in $ExpensiveQueries) {
        $cpuClass = if ($query.CPUTotalSegundos -gt 10) { 'status-critical' }
        elseif ($query.CPUTotalSegundos -gt 1) { 'status-warning' }
        else { 'status-success' }

        # MEJORA: Truncar consulta a 50 caracteres y limpiar espacios/lineas nuevas
        $fullQuery = $query.QuerySQL -replace '\s+', ' '  # Reemplazar múltiples espacios por uno
        $fullQuery = $fullQuery.Trim()                   # Eliminar espacios al inicio/fin

        # Truncar a 50 caracteres para mostrar
        $displayQuery = if ($fullQuery.Length -gt 50) {
            $fullQuery.Substring(0, 47) + "…"
        }
        else {
            $fullQuery
        }

        # MEJORA: También truncar el tooltip a 200 caracteres máximo
        $tooltipQuery = if ($fullQuery.Length -gt 200) {
            $fullQuery.Substring(0, 197) + "…"
        }
        else {
            $fullQuery
        }

        @"
        <tr>
            <td><span class='$cpuClass'>$([math]::Round($query.CPUTotalSegundos, 2))s</span></td>
            <td>$($query.Ejecuciones)</td>
            <td>$([math]::Round($query.CPUPromedioSegundos, 4))s</td>
            <td>$($query.UltimaEjecucion)</td>
            <td title="$tooltipQuery">
                <small style='white-space: nowrap; font-family: monospace;'>$displayQuery</small>
            </td>
        </tr>
"@
    }

    return @"
<section class='section'>
    <h2 class='section-title'>
        <span class='section-icon'>⚡</span>
        Consultas más Costosas (CPU) - Mostrando $($ExpensiveQueries.Count) consultas
    </h2>
    <div class='table-container'>
        <table class='compact-table'>
            <thead>
                <tr>
                    <th>CPU Total</th>
                    <th>Ejecuciones</th>
                    <th>CPU Promedio</th>
                    <th>Última Ejecución</th>
                    <th>Consulta SQL (primeros 50 chars)</th>
                </tr>
            </thead>
            <tbody>
                $($tableRows -join "`n")
            </tbody>
        </table>
    </div>
    <div class='section-note'>
        💡 <em>Pasa el mouse sobre la consulta para ver el texto completo (truncado a 200 caracteres)</em>
    </div>
</section>
"@
}

function Generate-ResourceUsageSection {
    param($ResourceUsage)

    if (-not $ResourceUsage -or $ResourceUsage.ConnectionCount -eq $null) {
        return "<section class='section'><h2 class='section-title'><span class='section-icon'>📊</span>Consumo de Recursos</h2><div class='no-data'>Información no disponible</div></section>"
    }

    # Usar datos REALES de la consulta mejorada
    $connectionCount = $ResourceUsage.ConnectionCount
    $totalCPUTime = [math]::Round($ResourceUsage.TotalCPUSeconds, 2)
    $totalMemoryMB = [math]::Round($ResourceUsage.TotalMemoryMB, 2)
    $totalReads = $ResourceUsage.TotalReads
    $totalWrites = $ResourceUsage.TotalWrites
    $databaseSizeMB = [math]::Round($ResourceUsage.DatabaseSizeMB, 2)

    return @"
<section class="section">
    <h2 class="section-title">
        <span class="section-icon">📊</span>
        Consumo de Recursos - DATOS REALES
    </h2>
    <div class="stats-grid">
        <div class="stat-card $(if ($connectionCount -gt 5) { 'warning' } else { 'info' })">
            <div class="stat-icon">🔌</div>
            <div class="stat-value">$connectionCount</div>
            <div class="stat-label">Conexiones Activas</div>
        </div>
        <div class="stat-card $(if ($totalCPUTime -gt 10) { 'warning' } else { 'info' })">
            <div class="stat-icon">⚡</div>
            <div class="stat-value">$totalCPUTime s</div>
            <div class="stat-label">CPU Total</div>
        </div>
        <div class="stat-card info">
            <div class="stat-icon">💾</div>
            <div class="stat-value">$totalMemoryMB MB</div>
            <div class="stat-label">Memoria Usada</div>
        </div>
        <div class="stat-card info">
            <div class="stat-icon">📖</div>
            <div class="stat-value">$($totalReads.ToString('N0'))</div>
            <div class="stat-label">Lecturas</div>
        </div>
        <div class="stat-card info">
            <div class="stat-icon">✍️</div>
            <div class="stat-value">$($totalWrites.ToString('N0'))</div>
            <div class="stat-label">Escrituras</div>
        </div>
        <div class="stat-card info">
            <div class="stat-icon">🗃️</div>
            <div class="stat-value">$databaseSizeMB MB</div>
            <div class="stat-label">Tamaño BD</div>
        </div>
    </div>
    <div class="section-note">
        💡 <em>Datos en tiempo real de la base de datos</em>
    </div>
</section>
"@
}

function Generate-AlertsSection {
    param(
        $RebuildRecommended,
        $ReorganizeRecommended,
        $CriticalFiles,
        $RecentBackups,
        $ConnectionCount,
        $NeedsPatches,
        $FailedBackupJobs,
        $CriticalDisks
    )

    $hasAlerts = ($RebuildRecommended -gt 0) -or
    ($ReorganizeRecommended -gt 0) -or
    ($CriticalFiles -gt 0) -or
    ($RecentBackups -eq 0) -or
    ($ConnectionCount -gt 50) -or
    $NeedsPatches -or
    ($FailedBackupJobs -gt 0) -or
    ($CriticalDisks -gt 0)

    if (-not $hasAlerts) {
        return @"
<section class="section">
    <h2 class="section-title">
        <span class="section-icon">✅</span>
        Estado del Sistema
    </h2>
    <div class='alert-success'>
        <strong>✅ SISTEMA SALUDABLE:</strong> No se detectaron problemas críticos. El servidor está funcionando correctamente.
    </div>
</section>
"@
    }

    $alerts = @()

    if ($RebuildRecommended -gt 0) {
        $alerts += "<div class='alert-critical'>⚠️ <strong>CRÍTICO:</strong> $RebuildRecommended índice(s) necesitan REBUILD urgente - fragmentación superior al 30%</div>"
    }

    if ($ReorganizeRecommended -gt 0) {
        $alerts += "<div class='alert-warning'>🔄 <strong>ADVERTENCIA:</strong> $ReorganizeRecommended índice(s) necesitan REORGANIZE - fragmentación entre 10% y 30%</div>"
    }

    if ($CriticalFiles -gt 0) {
        $alerts += "<div class='alert-warning'>💾 <strong>ADVERTENCIA:</strong> $CriticalFiles archivo(s) de BD con más del 90% de espacio usado - considere expandir los archivos</div>"
    }

    if ($CriticalDisks -gt 0) {
        $alerts += "<div class='alert-critical'>💽 <strong>CRÍTICO:</strong> $CriticalDisks disco(s) en estado CRÍTICO - espacio insuficiente</div>"
    }

    if ($RecentBackups -eq 0) {
        $alerts += "<div class='alert-warning'>🔄 <strong>ADVERTENCIA:</strong> No se encontraron backups recientes - revise la estrategia de backup</div>"
    }

    if ($FailedBackupJobs -gt 0) {
        $alerts += "<div class='alert-critical'>🚨 <strong>CRÍTICO:</strong> $FailedBackupJobs job(s) de backup con errores - revise la configuración inmediatamente</div>"
    }

    if ($NeedsPatches) {
        $alerts += "<div class='alert-warning'>🔧 <strong>ADVERTENCIA:</strong> El servidor necesita actualización de parches - aplique los parches pendientes</div>"
    }

    if ($ConnectionCount -gt 50) {
        $alerts += "<div class='alert-info'>🔌 <strong>INFORMACIÓN:</strong> Alto número de conexiones activas ($ConnectionCount) - monitoree el rendimiento</div>"
    }

    return @"
<section class="section">
    <h2 class="section-title">
        <span class="section-icon">🚨</span>
        Alertas y Recomendaciones
    </h2>
    $($alerts -join "`n    ")
</section>
"@
}

# ============================================================================
# FUNCIÓN PARA CARGAR CSS
# ============================================================================

function Get-CSSContent {
    <#
    .SYNOPSIS
    Carga el contenido CSS desde un archivo.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$CssFile
    )

    try {
        if (-not (Test-Path $CssFile)) {
            Write-Warning "Archivo CSS no encontrado: $CssFile"

            # Buscar en rutas alternativas
            $alternativePaths = @(
                ".\src\templates\style.css",
                "..\templates\style.css",
                "$PSScriptRoot\..\templates\style.css",
                ".\templates\style.css"
            )

            foreach ($path in $alternativePaths) {
                if (Test-Path $path) {
                    $CssFile = $path
                    Write-Host "   ✅ CSS encontrado en: $CssFile" -ForegroundColor Green
                    break
                }
            }
        }

        if (-not (Test-Path $CssFile)) {
            Write-Warning "No se pudo encontrar el archivo CSS en ninguna ubicación"
            return Get-DefaultCSS
        }

        $cssContent = Get-Content $CssFile -Raw -ErrorAction Stop
        Write-Host "   ✅ CSS cargado desde: $CssFile" -ForegroundColor Green
        return $cssContent
    }
    catch {
        Write-Warning "Error cargando CSS: $($_.Exception.Message)"
        return Get-DefaultCSS
    }
}

function Get-DefaultCSS {
    <#
    .SYNOPSIS
    Retorna CSS por defecto si no se encuentra el archivo.
    #>
    return @"
/* CSS BÁSICO DE RESPALDO */
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f5f5f5; }
.container { max-width: 1400px; margin: 0 auto; padding: 20px; }
.header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }
.section { background: white; padding: 25px; margin-bottom: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
table { width: 100%; border-collapse: collapse; }
th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
th { background: #f8f9fa; font-weight: 600; }
.badge { padding: 4px 12px; border-radius: 4px; font-size: 12px; font-weight: 600; }
.badge-success { background: #d4edda; color: #155724; }
.badge-warning { background: #fff3cd; color: #856404; }
.badge-critical { background: #f8d7da; color: #721c24; }
.badge-info { background: #d1ecf1; color: #0c5460; }
.status-success { color: #28a745; font-weight: 600; }
.status-warning { color: #ffc107; font-weight: 600; }
.status-critical { color: #dc3545; font-weight: 600; }
.alert-success { background: #d4edda; border-left: 4px solid #28a745; padding: 15px; margin: 10px 0; }
.alert-warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 10px 0; }
.alert-critical { background: #f8d7da; border-left: 4px solid #dc3545; padding: 15px; margin: 10px 0; }
.no-data { text-align: center; padding: 40px; color: #6c757d; font-style: italic; }
.stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
.stat-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); text-align: center; }
.stat-value { font-size: 32px; font-weight: bold; margin: 10px 0; }
.footer { text-align: center; padding: 20px; color: #6c757d; }
"@
}

# ============================================================================
# FUNCIONES PARA REPORTES ESPECIALIZADOS
# ============================================================================

function Generate-DailyDiskReportHTML {
    <#
    .SYNOPSIS
    Genera un reporte HTML especializado para el análisis diario de discos.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$DiskReportData,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$CssFile
    )

    Write-Host "Generando reporte diario de discos HTML..." -ForegroundColor Cyan

    try {
        $cssContent = Get-CSSContent -CssFile $CssFile

        # Implementación simplificada - expandir según necesidades
        $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Reporte Diario de Discos</title>
    <style>$cssContent</style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>Reporte Diario de Discos - $(Get-Date -Format 'dd/MM/yyyy')</h1>
        </header>
        <!-- Agregar contenido del reporte -->
    </div>
</body>
</html>
"@

        Set-Content -Path $OutputPath -Value $html -Encoding UTF8
        Write-Host "Reporte de discos generado: $OutputPath" -ForegroundColor Green
        return $OutputPath
    }
    catch {
        Write-Error "Error generando reporte de discos: $($_.Exception.Message)"
        throw
    }
}

function Generate-VersionComplianceReportHTML {
    <#
    .SYNOPSIS
    Genera un reporte HTML especializado para cumplimiento de versiones.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$VersionReportData,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$CssFile
    )

    Write-Host "Generando reporte de versiones HTML..." -ForegroundColor Cyan

    try {
        $cssContent = Get-CSSContent -CssFile $CssFile

        # Implementación simplificada - expandir según necesidades
        $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Reporte de Cumplimiento de Versiones</title>
    <style>$cssContent</style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>Reporte de Versiones - $(Get-Date -Format 'dd/MM/yyyy')</h1>
        </header>
        <!-- Agregar contenido del reporte -->
    </div>
</body>
</html>
"@

        Set-Content -Path $OutputPath -Value $html -Encoding UTF8
        Write-Host "Reporte de versiones generado: $OutputPath" -ForegroundColor Green
        return $OutputPath
    }
    catch {
        Write-Error "Error generando reporte de versiones: $($_.Exception.Message)"
        throw
    }
}

# ============================================================================
# EXPORTAR FUNCIONES
# ============================================================================

<#
Export-ModuleMember -Function @(
    'Generate-CompleteHTMLReport',
    'Generate-DailyDiskReportHTML',
    'Generate-VersionComplianceReportHTML',
    'Get-CSSContent'
)
#>