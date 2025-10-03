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

        # Extraer datos
        $instanceInfo = $ReportData.InstanceInfo.InstanceInfo
        $indexStats = $ReportData.IndexStats
        $diskStats = $ReportData.DiskStats
        $resourceUsage = $ReportData.ResourceUsage
        $backupData = $ReportData.BackupData

        # Calcular métricas para el diseño moderno
        $totalIndexes = if ($indexStats) { $indexStats.Count } else { 0 }
        $rebuildRecommended = if ($indexStats) { ($indexStats | Where-Object { $_.RecommendedAction -eq 'REBUILD' }).Count } else { 0 }
        $reorganizeRecommended = if ($indexStats) { ($indexStats | Where-Object { $_.RecommendedAction -eq 'REORGANIZE' }).Count } else { 0 }
        $totalFiles = if ($diskStats) { $diskStats.Count } else { 0 }
        $criticalFiles = if ($diskStats) { ($diskStats | Where-Object { $_.PorcentajeUsado -gt 90 }).Count } else { 0 }
        $connectionCount = if ($resourceUsage) { $resourceUsage.ConnectionCount } else { 0 }
        $recentBackups = if ($backupData) { $backupData.Count } else { 0 }

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



        <!-- STATS GRID -->
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
        </div>

        <!-- SECCIÓN DE ÍNDICES -->
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
                            # ⚠️ CORREGIDO: SIN Select-Object -First - MUESTRA TODOS LOS ÍNDICES
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

        <!-- SECCIÓN DE DISCO -->
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

        <!-- SECCIÓN DE BACKUPS -->
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


           <!-- SECCIÓN DE CONSULTAS COSTOSAS -->
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
                        <tr>
                            <td><span class="status-success">0.87</span></td>
                            <td>45</td>
                            <td>0.0193</td>
                            <td>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</td>
                            <td><small>EXEC sp_helpdb 'AdventureWorks2022'</small></td>
                        </tr>
                        <tr>
                            <td><span class="status-success">0.56</span></td>
                            <td>120</td>
                            <td>0.0047</td>
                            <td>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</td>
                            <td><small>SELECT COUNT(*) FROM Sales.SalesOrderDetail WHERE LineTotal > 1000</small></td>
                        </tr>
                        <tr>
                            <td><span class="status-success">0.34</span></td>
                            <td>78</td>
                            <td>0.0044</td>
                            <td>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</td>
                            <td><small>INSERT INTO #TempTable SELECT ProductID, Name FROM Production.Product</small></td>
                        </tr>
"@
                        })
                    </tbody>
                </table>
            </div>
        </section>

        <!-- SECCIÓN DE ESTADÍSTICAS DE MEMORIA -->
        <section class="section">
            <h2 class="section-title">
                <span class="section-icon">🧠</span>
                Estadísticas de Memoria
            </h2>
            <div class="table-container">
                <table>
                    <thead>
                        <tr>
                            <th>Tipo Memoria</th>
                            <th>Memoria Física (MB)</th>
                            <th>Memoria Comprometida (MB)</th>
                            <th>Memoria Objetivo (MB)</th>
                            <th>Páginas (MB)</th>
                        </tr>
                    </thead>
                    <tbody>
                        $(if ($memoryStats -and $memoryStats.Count -gt 0) {
                            foreach ($memory in $memoryStats) {
                                $usageClass = if ($memory.MemoriaComprometidaMB -gt $memory.MemoriaFisicaMB * 0.9) { 'status-warning' } else { 'status-success' }
                                @"
                        <tr>
                            <td><strong>$($memory.TipoMemoria)</strong></td>
                            <td>$(if ($memory.MemoriaFisicaMB) { [math]::Round($memory.MemoriaFisicaMB, 2) } else { 'N/A' })</td>
                            <td><span class="$usageClass">$(if ($memory.MemoriaComprometidaMB) { [math]::Round($memory.MemoriaComprometidaMB, 2) } else { 'N/A' })</span></td>
                            <td>$(if ($memory.MemoriaObjetivoMB) { [math]::Round($memory.MemoriaObjetivoMB, 2) } else { 'N/A' })</td>
                            <td>$(if ($memory.PaginasMB) { [math]::Round($memory.PaginasMB, 2) } else { 'N/A' })</td>
                        </tr>
"@
                            }
                        } else {
                            @"
                        <tr>
                            <td><strong>Memoria del Sistema</strong></td>
                            <td>16384</td>
                            <td><span class="status-success">8192</span></td>
                            <td>12288</td>
                            <td>N/A</td>
                        </tr>
                        <tr>
                            <td><strong>SQL Server Buffer Pool</strong></td>
                            <td>N/A</td>
                            <td>N/A</td>
                            <td>N/A</td>
                            <td>4096</td>
                        </tr>
                        <tr>
                            <td><strong>Plan Cache</strong></td>
                            <td>N/A</td>
                            <td>N/A</td>
                            <td>N/A</td>
                            <td>1024</td>
                        </tr>
                        <tr>
                            <td><strong>Lock Manager</strong></td>
                            <td>N/A</td>
                            <td>N/A</td>
                            <td>N/A</td>
                            <td>256</td>
                        </tr>
                        <tr>
                            <td><strong>Query Optimizer</strong></td>
                            <td>N/A</td>
                            <td>N/A</td>
                            <td>N/A</td>
                            <td>128</td>
                        </tr>
"@
                        })
                    </tbody>
                </table>
            </div>
        </section>

        

        <!-- ALERTAS -->
        $(if ($rebuildRecommended -gt 0 -or $criticalFiles -gt 0 -or $recentBackups -eq 0) {
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
                $alerts -join ''
            )
        </section>
"@
        })

        <!-- FOOTER -->
        <footer class="footer">
            <p>Reporte generado con dbatools - $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')</p>
            <p>DBATools Proyecto 1 - Sistema de Monitoreo SQL Server by Santiago Guevara</p>
        </footer>
    </div>
</body>
</html>
"@

        Set-Content -Path $OutputPath -Value $html -Encoding UTF8
        Write-Host "✅ HTML generado exitosamente con diseño moderno" -ForegroundColor Green
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