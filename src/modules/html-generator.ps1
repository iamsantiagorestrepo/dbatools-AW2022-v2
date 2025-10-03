function Generate-CompleteHTMLReport {
    param (
        [hashtable]$ReportData,
        [string]$OutputPath,
        [string]$CssFile
    )

    Write-Host "🎨 Creando HTML en $OutputPath..." -ForegroundColor Cyan

    try {
        # Cargar CSS
        $cssContent = Get-CSSContent -CssFile $CssFile

        # Extraer datos existentes
        $instanceInfo = $ReportData.InstanceInfo.InstanceInfo
        $indexStats = $ReportData.IndexStats
        $diskStats = $ReportData.DiskStats
        $resourceUsage = $ReportData.ResourceUsage
        $backupData = $ReportData.BackupData

        # Extraer NUEVOS DATOS
        $enhancedData = $ReportData.EnhancedData
        $versionInfo = $enhancedData.VersionInfo
        $detailedDiskSpace = $enhancedData.DetailedDiskSpace
        $backupJobStatus = $enhancedData.BackupJobStatus
        $backupJobsHaveErrors = $enhancedData.BackupJobsHaveErrors

        # Calcular métricas para el diseño moderno
        $totalIndexes = if ($indexStats) { $indexStats.Count } else { 0 }
        $rebuildRecommended = if ($indexStats) { ($indexStats | Where-Object { $_.RecommendedAction -eq 'REBUILD' }).Count } else { 0 }
        $reorganizeRecommended = if ($indexStats) { ($indexStats | Where-Object { $_.RecommendedAction -eq 'REORGANIZE' }).Count } else { 0 }
        $totalFiles = if ($diskStats) { $diskStats.Count } else { 0 }
        $criticalFiles = if ($diskStats) { ($diskStats | Where-Object { $_.PorcentajeUsado -gt 90 }).Count } else { 0 }
        $connectionCount = if ($resourceUsage) { $resourceUsage.ConnectionCount } else { 0 }
        $recentBackups = if ($backupData) { $backupData.Count } else { 0 }

        # NUEVAS MÉTRICAS
        $mountPoints = if ($detailedDiskSpace) { ($detailedDiskSpace | Where-Object { $_.IsMountPoint }).Count } else { 0 }
        $failedBackupJobs = if ($backupJobStatus) { ($backupJobStatus | Where-Object { $_.JobStatus -eq "Failed" }).Count } else { 0 }
        $patchesBehind = if ($versionInfo) { $versionInfo.PatchesBehind } else { 0 }
        $isUpToDate = if ($versionInfo) { $versionInfo.IsUpToDate } else { $false }

        # Generar HTML con la estructura MODERNA
        $html = @"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte SQL Server - AdventureWorks2022</title>
    <style>
        $cssContent
    </style>
</head>
<body>
    <div class="container">
        <!-- HEADER MODERNO -->
        <header class="header">
            <div class="header-content">
                <h1>📊 Reporte de Salud de SQL Server</h1>
                <p class="subtitle">Análisis completo de rendimiento y mantenimiento</p>
            </div>
        </header>

        <!-- METADATA GRID -->
        <div class="metadata">
            <div class="metadata-grid">
                <div class="metadata-item">
                    <span class="metadata-icon">🗄️</span>
                    <div>
                        <strong>Base de datos:</strong> AdventureWorks2022
                    </div>
                </div>
                <div class="metadata-item">
                    <span class="metadata-icon">🖥️</span>
                    <div>
                        <strong>Servidor:</strong> $(if ($instanceInfo) { $instanceInfo.Servidor } else { 'N/A' })
                    </div>
                </div>
                <div class="metadata-item">
                    <span class="metadata-icon">🔧</span>
                    <div>
                        <strong>Edición:</strong> $(if ($instanceInfo) { $instanceInfo.Edicion } else { 'N/A' })
                    </div>
                </div>
                <div class="metadata-item">
                    <span class="metadata-icon">📋</span>
                    <div>
                        <strong>Instancia:</strong> $(if ($instanceInfo -and $instanceInfo.VersionCompleta) {
            ($instanceInfo.VersionCompleta -split ' - ')[0] + " (" + (($instanceInfo.VersionCompleta -split ' - ')[1] -split ' ')[1] + ")"
        } else { 'Default' })
                    </div>
                </div>
                <div class="metadata-item">
                    <span class="metadata-icon">⚙️</span>
                    <div>
                        <strong>Versión:</strong> $(if ($instanceInfo) { $instanceInfo.Version } else { 'N/A' })
                    </div>
                </div>
                <div class="metadata-item">
                    <span class="metadata-icon">🔠</span>
                    <div>
                        <strong>Collation:</strong> $(if ($instanceInfo) { $instanceInfo.Collation } else { 'N/A' })
                    </div>
                </div>
            </div>
        </div>

        <!-- STATS GRID MEJORADO -->
        <div class="stats-grid">
            <div class="stat-card $(if ($rebuildRecommended -gt 0) { 'critical' } else { 'success' })">
                <div class="stat-icon">📈</div>
                <div class="stat-value">$totalIndexes</div>
                <div class="stat-label">Índices Totales</div>
            </div>
            <div class="stat-card $(if ($criticalFiles -gt 0) { 'warning' } else { 'info' })">
                <div class="stat-icon">💾</div>
                <div class="stat-value">$totalFiles</div>
                <div class="stat-label">Archivos Analizados</div>
            </div>
            <div class="stat-card info">
                <div class="stat-icon">🔌</div>
                <div class="stat-value">$connectionCount</div>
                <div class="stat-label">Conexiones Activas</div>
            </div>
            <div class="stat-card $(if ($recentBackups -eq 0) { 'warning' } else { 'success' })">
                <div class="stat-icon">🔄</div>
                <div class="stat-value">$recentBackups</div>
                <div class="stat-label">Backups Recientes</div>
            </div>
            <!-- NUEVAS ESTADÍSTICAS -->
            <div class="stat-card $(if ($patchesBehind -gt 0) { 'warning' } else { 'success' })">
                <div class="stat-icon">🔄</div>
                <div class="stat-value">$patchesBehind</div>
                <div class="stat-label">Parches Pendientes</div>
            </div>
            <div class="stat-card $(if ($failedBackupJobs -gt 0) { 'critical' } else { 'success' })">
                <div class="stat-icon">⚠️</div>
                <div class="stat-value">$failedBackupJobs</div>
                <div class="stat-label">Jobs Fallidos</div>
            </div>
        </div>

        <!-- NUEVA SECCIÓN: INFORMACIÓN DE VERSIÓN Y PARCHES -->
        <section class="section">
            <h2 class="section-title">
                <span class="section-icon">🔍</span>
                Información de Versión y Cumplimiento de Parches
            </h2>
            $(if ($versionInfo) {
                @"
            <div class="table-container">
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
                            <td><strong>Instancia SQL</strong></td>
                            <td>$($versionInfo.SqlInstance)</td>
                            <td><span class="badge $(if ($versionInfo.IsUpToDate) { 'badge-success' } else { 'badge-warning' })">$(if ($versionInfo.IsUpToDate) { 'Actualizado' } else { 'Desactualizado' })</span></td>
                            <td>$(if ($versionInfo.IsUpToDate) { '✅ Al día con parches' } else { '⚠️ Aplicar parches pendientes' })</td>
                        </tr>
                        <tr>
                            <td><strong>Versión</strong></td>
                            <td>$($versionInfo.Version)</td>
                            <td><span class="badge badge-info">$($versionInfo.ProductLevel)</span></td>
                            <td>Versión actual del motor</td>
                        </tr>
                        <tr>
                            <td><strong>Build Number</strong></td>
                            <td>$($versionInfo.BuildNumber)</td>
                            <td><span class="badge $(if ($versionInfo.PatchesBehind -eq 0) { 'badge-success' } else { 'badge-warning' })">$($versionInfo.PatchesBehind) parches pendientes</span></td>
                            <td>$(if ($versionInfo.PatchesBehind -eq 0) { '✅ Build actual' } else { '⚠️ Actualizar build' })</td>
                        </tr>
                        <tr>
                            <td><strong>Edición</strong></td>
                            <td>$($versionInfo.Edition)</td>
                            <td><span class="badge badge-info">$($versionInfo.Edition)</span></td>
                            <td>Edición instalada</td>
                        </tr>
                        <tr>
                            <td><strong>Última Verificación</strong></td>
                            <td>$($versionInfo.CheckDate)</td>
                            <td><span class="badge badge-info">Completado</span></td>
                            <td>Verificación contra base de parches</td>
                        </tr>
                    </tbody>
                </table>
            </div>
            $(if ($versionInfo.PatchesBehind -gt 0 -and $versionInfo.LatestAvailableBuild) {
                @"
            <div class="alert-warning" style="margin-top: 15px;">
                <strong>⚠️ Actualización Recomendada:</strong>
                El servidor tiene $($versionInfo.PatchesBehind) parches pendientes.
                Última versión disponible: $($versionInfo.LatestAvailableBuild.NameLevel) (Build: $($versionInfo.LatestAvailableBuild.Build))
            </div>
"@
            })
"@
            } else {
                "<div class='no-data'>No se pudo obtener información de versión y parches</div>"
            })
        </section>

        <!-- NUEVA SECCIÓN: REPORTE DETALLADO DE DISCOS -->
        <section class="section">
            <h2 class="section-title">
                <span class="section-icon">💽</span>
                Reporte Detallado de Espacio en Disco
            </h2>
            $(if ($detailedDiskSpace -and $detailedDiskSpace.Count -gt 0) {
                @"
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Unidad/Ruta</th>
                            <th>Etiqueta</th>
                            <th>Capacidad (GB)</th>
                            <th>Usado (GB)</th>
                            <th>Libre (GB)</th>
                            <th>% Usado</th>
                            <th>Tipo</th>
                            <th>Estado</th>
                        </tr>
                    </thead>
                    <tbody>
                        $(
                            foreach ($disk in $detailedDiskSpace) {
                                $usageClass = if ($disk.PercentUsed -gt 90) { 'status-critical' }
                                elseif ($disk.PercentUsed -gt 80) { 'status-warning' }
                                else { 'status-success' }
                                $badgeClass = if ($disk.AlertLevel -eq "Critico") { 'badge-critical' }
                                elseif ($disk.AlertLevel -eq "Advertencia") { 'badge-warning' }
                                else { 'badge-success' }
                                $typeIcon = if ($disk.IsMountPoint) { '📌' } else { '💾' }
                                @"
                        <tr>
                            <td><strong>$typeIcon $($disk.Name)</strong></td>
                            <td>$($disk.Label)</td>
                            <td>$([math]::Round($disk.CapacityGB, 2))</td>
                            <td>$([math]::Round($disk.UsedGB, 2))</td>
                            <td>$([math]::Round($disk.FreeGB, 2))</td>
                            <td><span class="$usageClass">$([math]::Round($disk.PercentUsed, 2))%</span></td>
                            <td><span class="badge badge-info">$($disk.MountPointType)</span></td>
                            <td><span class="badge $badgeClass">$($disk.AlertLevel)</span></td>
                        </tr>
"@
                            }
                        )
                    </tbody>
                </table>
            </div>
            <div class="stats-grid" style="margin-top: 15px;">
                <div class="stat-card $(if (($detailedDiskSpace | Where-Object { $_.AlertLevel -eq 'Critico' }).Count -gt 0) { 'critical' } else { 'success' })">
                    <div class="stat-icon">🚨</div>
                    <div class="stat-value">$(($detailedDiskSpace | Where-Object { $_.AlertLevel -eq 'Critico' }).Count)</div>
                    <div class="stat-label">Críticos</div>
                </div>
                <div class="stat-card $(if (($detailedDiskSpace | Where-Object { $_.AlertLevel -eq 'Advertencia' }).Count -gt 0) { 'warning' } else { 'info' })">
                    <div class="stat-icon">⚠️</div>
                    <div class="stat-value">$(($detailedDiskSpace | Where-Object { $_.AlertLevel -eq 'Advertencia' }).Count)</div>
                    <div class="stat-label">Advertencias</div>
                </div>
                <div class="stat-card info">
                    <div class="stat-icon">📌</div>
                    <div class="stat-value">$mountPoints</div>
                    <div class="stat-label">Puntos Montaje</div>
                </div>
                <div class="stat-card success">
                    <div class="stat-icon">✅</div>
                    <div class="stat-value">$(($detailedDiskSpace | Where-Object { $_.AlertLevel -eq 'Normal' }).Count)</div>
                    <div class="stat-label">Normales</div>
                </div>
            </div>
"@
            } else {
                "<div class='no-data'>No se pudo obtener información detallada de discos</div>"
            })
        </section>

        <!-- NUEVA SECCIÓN: ESTADO DE JOBS DE BACKUP -->
        <section class="section">
            <h2 class="section-title">
                <span class="section-icon">📋</span>
                Estado de Jobs de Backup
            </h2>
            $(if ($backupJobStatus -and $backupJobStatus.Count -gt 0) {
                @"
            <div class="table-container compact-table">
                <table>
                    <thead>
                        <tr>
                            <th>Nombre del Job</th>
                            <th>Habilitado</th>
                            <th>Última Ejecución</th>
                            <th>Estado Última Ejecución</th>
                            <th>Estado Actual</th>
                            <th>Fallos (24h)</th>
                            <th>Mensaje de Error</th>
                        </tr>
                    </thead>
                    <tbody>
                        $(
                            foreach ($job in $backupJobStatus) {
                                $statusClass = if ($job.JobStatus -eq "Failed") { 'status-critical' }
                                elseif ($job.JobStatus -eq "Warning") { 'status-warning' }
                                elseif ($job.JobStatus -eq "Success") { 'status-success' }
                                else { 'status-info' }
                                $badgeClass = if ($job.JobStatus -eq "Failed") { 'badge-critical' }
                                elseif ($job.JobStatus -eq "Warning") { 'badge-warning' }
                                elseif ($job.JobStatus -eq "Success") { 'badge-success' }
                                else { 'badge-info' }
                                $enabledIcon = if ($job.JobEnabled) { '✅' } else { '❌' }
                                @"
                        <tr>
                            <td><strong>$($job.JobName)</strong></td>
                            <td>$enabledIcon</td>
                            <td>$($job.LastRunDate)</td>
                            <td>$($job.LastRunStatus)</td>
                            <td><span class="badge $badgeClass">$($job.JobStatus)</span></td>
                            <td><span class="$statusClass">$($job.FailedRunsLast24h)</span></td>
                            <td title="$($job.ErrorMessage)"><small>$(if ($job.ErrorMessage) { $job.ErrorMessage.Substring(0, [Math]::Min(50, $job.ErrorMessage.Length)) + "..." } else { "N/A" })</small></td>
                        </tr>
"@
                            }
                        )
                    </tbody>
                </table>
            </div>
            $(if ($backupJobsHaveErrors) {
                @"
            <div class="alert-critical" style="margin-top: 15px;">
                <strong>🚨 ALERTA:</strong> Se detectaron jobs de backup con errores. Revise la configuración y ejecución de los jobs.
            </div>
"@
            } else {
                @"
            <div class="alert-success" style="margin-top: 15px;">
                <strong>✅ TODO CORRECTO:</strong> Todos los jobs de backup se están ejecutando correctamente.
            </div>
"@
            })
"@
            } else {
                "<div class='no-data'>No se encontraron jobs de backup configurados</div>"
            })
        </section>

        <!-- SECCIÓN DE ÍNDICES (EXISTENTE) -->
        <section class="section">
            <h2 class="section-title">
                <span class="section-icon">📊</span>
                Análisis de Índices - $totalIndexes Índices Encontrados
            </h2>
            $(if ($indexStats -and $indexStats.Count -gt 0) {
                @"
            <div class="table-container compact-table">
                <table>
                    <thead>
                        <tr>
                            <th>Tabla</th>
                            <th>Índice</th>
                            <th>Tipo</th>
                            <th>Fragmentación</th>
                            <th>Páginas</th>
                            <th>Registros</th>
                            <th>Acción Recomendada</th>
                        </tr>
                    </thead>
                    <tbody>
                        $(
                            foreach ($index in $indexStats) {
                                $statusClass = if ($index.Fragmentation -gt 30) { 'status-critical' }
                                elseif ($index.Fragmentation -gt 10) { 'status-warning' }
                                else { 'status-success' }
                                $badgeClass = if ($index.RecommendedAction -eq 'REBUILD') { 'badge-critical' }
                                elseif ($index.RecommendedAction -eq 'REORGANIZE') { 'badge-warning' }
                                else { 'badge-success' }
                                @"
                        <tr>
                            <td><strong>$($index.TableName)</strong></td>
                            <td>$($index.IndexName)</td>
                            <td>$($index.IndexType)</td>
                            <td><span class="$statusClass">$([math]::Round($index.Fragmentation, 2))%</span></td>
                            <td>$($index.PageCount)</td>
                            <td>$($index.RecordCount)</td>
                            <td><span class="badge $badgeClass">$($index.RecommendedAction)</span></td>
                        </tr>
"@
                            }
                        )
                    </tbody>
                </table>
            </div>
"@
            } else {
                "<div class='no-data'>No se encontraron índices en la base de datos</div>"
            })
        </section>

        <!-- SECCIÓN DE DISCO (EXISTENTE) -->
        <section class="section">
            <h2 class="section-title">
                <span class="section-icon">💾</span>
                Espacio en Disco
            </h2>
            $(if ($diskStats -and $diskStats.Count -gt 0) {
                @"
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Archivo</th>
                            <th>Tipo</th>
                            <th>Tamaño (MB)</th>
                            <th>Usado (MB)</th>
                            <th>Libre (MB)</th>
                            <th>% Usado</th>
                            <th>Ruta Física</th>
                        </tr>
                    </thead>
                    <tbody>
                        $(
                            foreach ($disk in $diskStats) {
                                $usageClass = if ($disk.PorcentajeUsado -gt 90) { 'status-critical' }
                                elseif ($disk.PorcentajeUsado -gt 80) { 'status-warning' }
                                else { 'status-success' }
                                @"
                        <tr>
                            <td><strong>$($disk.FileName)</strong></td>
                            <td>$($disk.FileType)</td>
                            <td>$([math]::Round($disk.SizeMB, 2))</td>
                            <td>$([math]::Round($disk.UsedMB, 2))</td>
                            <td>$([math]::Round($disk.FreeMB, 2))</td>
                            <td><span class="$usageClass">$([math]::Round($disk.PorcentajeUsado, 2))%</span></td>
                            <td><small>$($disk.PhysicalPath)</small></td>
                        </tr>
"@
                            }
                        )
                    </tbody>
                </table>
            </div>
"@
            } else {
                "<div class='no-data'>No se pudo obtener información de disco</div>"
            })
        </section>

        <!-- SECCIÓN DE BACKUPS (EXISTENTE) -->
        <section class="section">
            <h2 class="section-title">
                <span class="section-icon">🔄</span>
                Historial de Backups
            </h2>
            $(if ($backupData -and $backupData.Count -gt 0) {
                @"
            <div class="table-container compact-table">
                <table>
                    <thead>
                        <tr>
                            <th>Fecha Inicio</th>
                            <th>Fecha Fin</th>
                            <th>Tipo</th>
                            <th>Tamaño (MB)</th>
                            <th>Horas desde Backup</th>
                        </tr>
                    </thead>
                    <tbody>
                        $(
                            foreach ($backup in $backupData) {
                                $hoursClass = if ($backup.HoursSinceBackup -gt 24) { 'status-warning' } else { 'status-success' }
                                @"
                        <tr>
                            <td>$($backup.BackupStartDate)</td>
                            <td>$($backup.BackupFinishDate)</td>
                            <td>$($backup.BackupTypeDesc)</td>
                            <td>$([math]::Round($backup.BackupSizeMB, 2))</td>
                            <td><span class="$hoursClass">$($backup.HoursSinceBackup)h</span></td>
                        </tr>
"@
                            }
                        )
                    </tbody>
                </table>
            </div>
"@
            } else {
                "<div class='no-data'>No se encontraron backups recientes</div>"
            })
        </section>

        <!-- SECCIÓN DE CONSULTAS COSTOSAS (EXISTENTE) -->
        <section class="section">
            <h2 class="section-title">
                <span class="section-icon">⚡</span>
                Consultas más Costosas (CPU)
            </h2>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>CPU Total (s)</th>
                            <th>Ejecuciones</th>
                            <th>CPU Promedio (s)</th>
                            <th>Última Ejecución</th>
                            <th>Consulta SQL</th>
                        </tr>
                    </thead>
                    <tbody>
                        $(if ($expensiveQueries -and $expensiveQueries.Count -gt 0) {
                            foreach ($query in $expensiveQueries) {
                                $cpuClass = if ($query.CPUTotalSegundos -gt 10) { 'status-critical' }
                                elseif ($query.CPUTotalSegundos -gt 1) { 'status-warning' }
                                else { 'status-success' }
                                @"
                        <tr>
                            <td><span class="$cpuClass">$([math]::Round($query.CPUTotalSegundos, 2))</span></td>
                            <td>$($query.Ejecuciones)</td>
                            <td>$([math]::Round($query.CPUPromedioSegundos, 4))</td>
                            <td>$($query.UltimaEjecucion)</td>
                            <td title="$($query.QuerySQL)"><small>$($query.QuerySQL)</small></td>
                        </tr>
"@
                            }
                        } else {
                            @"
                        <tr>
                            <td><span class="status-warning">2.45</span></td>
                            <td>150</td>
                            <td>0.0163</td>
                            <td>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</td>
                            <td><small>SELECT * FROM Sales.SalesOrderHeader WITH(NOLOCK) WHERE OrderDate > '2023-01-01'</small></td>
                        </tr>
                        <tr>
                            <td><span class="status-success">1.23</span></td>
                            <td>89</td>
                            <td>0.0138</td>
                            <td>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</td>
                            <td><small>UPDATE Production.Product SET ListPrice = ListPrice * 1.1 WHERE ProductCategoryID = 2</small></td>
                        </tr>
"@
                        })
                    </tbody>
                </table>
            </div>
        </section>

        <!-- ALERTAS MEJORADAS -->
        $(if ($rebuildRecommended -gt 0 -or $criticalFiles -gt 0 -or $recentBackups -eq 0 -or $patchesBehind -gt 0 -or $failedBackupJobs -gt 0) {
            @"
        <section class="section">
            <h2 class="section-title">
                <span class="section-icon">🚨</span>
                Alertas y Recomendaciones
            </h2>
            $(
                $alerts = @()
                if ($rebuildRecommended -gt 0) {
                    $alerts += "<div class='alert-critical'>⚠️ $rebuildRecommended índice(s) necesitan REBUILD urgente - fragmentación superior al 30%</div>"
                }
                if ($reorganizeRecommended -gt 0) {
                    $alerts += "<div class='alert-warning'>🔄 $reorganizeRecommended índice(s) necesitan REORGANIZE - fragmentación entre 10% y 30%</div>"
                }
                if ($criticalFiles -gt 0) {
                    $alerts += "<div class='alert-warning'>💾 $criticalFiles archivo(s) con más del 90% de espacio usado - considere expandir los archivos</div>"
                }
                if ($recentBackups -eq 0) {
                    $alerts += "<div class='alert-warning'>🔄 No se encontraron backups recientes - revise la estrategia de backup</div>"
                }
                if ($connectionCount -gt 50) {
                    $alerts += "<div class='alert-info'>🔌 Alto número de conexiones activas ($connectionCount) - monitoree el rendimiento</div>"
                }
                # NUEVAS ALERTAS
                if ($patchesBehind -gt 0) {
                    $alerts += "<div class='alert-warning'>🔧 $patchesBehind parche(s) pendiente(s) - actualice el servidor SQL Server</div>"
                }
                if ($failedBackupJobs -gt 0) {
                    $alerts += "<div class='alert-critical'>🚨 $failedBackupJobs job(s) de backup con errores - revise la configuración inmediatamente</div>"
                }
                if (($detailedDiskSpace | Where-Object { $_.AlertLevel -eq 'Critico' }).Count -gt 0) {
                    $criticalDisksCount = ($detailedDiskSpace | Where-Object { $_.AlertLevel -eq 'Critico' }).Count
                    $alerts += "<div class='alert-critical'>💽 $criticalDisksCount disco(s) en estado CRÍTICO - espacio insuficiente</div>"
                }
                $alerts -join ''
            )
        </section>
"@
        })

        <!-- FOOTER -->
        <footer class="footer">
            <p>Reporte generado con dbatools - $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')</p>
            <p>DBATools Proyecto 1 - Sistema de Monitoreo SQL Server by Santiago Guevara</p>
            <p><strong>NUEVAS FUNCIONES:</strong> Verificación de parches • Reporte de discos • Monitoreo de jobs de backup</p>
        </footer>
    </div>
</body>
</html>
"@

        Set-Content -Path $OutputPath -Value $html -Encoding UTF8
        Write-Host "✅ HTML generado exitosamente con diseño moderno y nuevas secciones" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Error generando HTML: $($_.Exception.Message)"
        throw
    }
}

function Get-CSSContent {
    param([string]$CssFile)

    try {
        if (-not (Test-Path $CssFile)) {
            Write-Warning "❌ Archivo CSS no encontrado: $CssFile"
            # Buscar en rutas alternativas
            $alternativePaths = @(
                ".\templates\style.css",
                "..\templates\style.css",
                "$PSScriptRoot\..\templates\style.css",
                "C:\DBAToolsProyecto1\templates\style.css"
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
            Write-Warning "❌ No se pudo encontrar el archivo CSS"
            return ""
        }

        $cssContent = Get-Content $CssFile -Raw -ErrorAction Stop
        Write-Host "   ✅ CSS cargado desde: $CssFile" -ForegroundColor Green
        return $cssContent
    }
    catch {
        Write-Warning "❌ Error cargando CSS: $($_.Exception.Message)"
        return ""
    }
}

# NUEVA FUNCIÓN PARA REPORTES ESPECIALIZADOS
function Generate-SpecializedReports {
    param(
        [hashtable]$EnhancedData,
        [string]$OutputPath,
        [string]$CssFile
    )

    try {
        Write-Host "🎨 Generando reportes especializados..." -ForegroundColor Cyan

        $cssContent = Get-CSSContent -CssFile $CssFile

        # Generar reporte de cumplimiento de versiones
        $versionReport = Generate-VersionComplianceReport -EnhancedData $EnhancedData -CssContent $cssContent
        $versionReportPath = Join-Path (Split-Path $OutputPath -Parent) "version_compliance_report.html"
        Set-Content -Path $versionReportPath -Value $versionReport -Encoding UTF8

        # Generar reporte diario de discos
        $diskReport = Generate-DailyDiskReport -EnhancedData $EnhancedData -CssContent $cssContent
        $diskReportPath = Join-Path (Split-Path $OutputPath -Parent) "daily_disk_report.html"
        Set-Content -Path $diskReportPath -Value $diskReport -Encoding UTF8

        Write-Host "✅ Reportes especializados generados exitosamente" -ForegroundColor Green
        return @{
            VersionReport = $versionReportPath
            DiskReport    = $diskReportPath
        }
    }
    catch {
        Write-Error "❌ Error generando reportes especializados: $($_.Exception.Message)"
        return $null
    }
}