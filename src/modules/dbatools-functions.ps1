# dbatools-functions.ps1
# Funciones básicas de dbatools - herramientas y utilidades

function Test-SQLConnection {
    param([string]$SqlInstance)

    try {
        Write-Host "   🔌 Probando conexión a $SqlInstance..." -ForegroundColor Yellow
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query "SELECT @@SERVERNAME AS ServerName" -ErrorAction Stop
        Write-Host "   ✅ Conexión exitosa a $SqlInstance" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "   ❌ Error de conexión: $($_.Exception.Message)"
        return $false
    }
}

function Get-BasicServerInfo {
    param([string]$SqlInstance)

    try {
        Write-Host "   🔍 Obteniendo información básica del servidor..." -ForegroundColor Yellow
        $query = @"
SELECT
    @@SERVERNAME AS ServerName,
    @@VERSION AS SQLVersion,
    DB_NAME() AS CurrentDatabase
"@
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop
        Write-Host "   ✅ Información básica obtenida" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Error "   ❌ Error obteniendo información básica: $($_.Exception.Message)"
        return $null
    }
}

function Get-DatabaseList {
    param([string]$SqlInstance)

    try {
        Write-Host "   📋 Obteniendo lista de bases de datos..." -ForegroundColor Yellow
        $query = @"
SELECT
    name AS DatabaseName,
    state_desc AS Status,
    recovery_model_desc AS RecoveryModel,
    create_date AS CreateDate
FROM sys.databases
WHERE state = 0  -- Solo bases de datos online
ORDER BY name
"@
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop
        Write-Host "   ✅ Lista de bases de datos obtenida ($($result.Count) bases de datos)" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Error "   ❌ Error obteniendo lista de bases de datos: $($_.Exception.Message)"
        return @()
    }
}

function Backup-DatabaseSimple {
    param([string]$SqlInstance, [string]$DatabaseName, [string]$BackupPath)

    try {
        Write-Host "   💾 Realizando backup de $DatabaseName..." -ForegroundColor Yellow
        $backupResult = Backup-DbaDatabase -SqlInstance $SqlInstance -Database $DatabaseName -Path $BackupPath -Type Full -CompressBackup
        Write-Host "   ✅ Backup completado exitosamente" -ForegroundColor Green
        return $backupResult
    }
    catch {
        Write-Error "   ❌ Error en backup: $($_.Exception.Message)"
        return $null
    }
}

function Get-ServerSpace {
    param([string]$SqlInstance)

    try {
        Write-Host "   💽 Obteniendo espacio en disco del servidor..." -ForegroundColor Yellow
        $spaceInfo = Get-DbaDiskSpace -SqlInstance $SqlInstance
        Write-Host "   ✅ Información de espacio obtenida" -ForegroundColor Green
        return $spaceInfo
    }
    catch {
        Write-Warning "   ⚠️  No se pudo obtener información de espacio: $($_.Exception.Message)"
        return @()
    }
}

function Test-DatabaseConnectivity {
    param([string]$SqlInstance, [string]$DatabaseName)

    try {
        Write-Host "   🔌 Probando conectividad a $DatabaseName..." -ForegroundColor Yellow
        $testQuery = "SELECT DB_NAME() AS DatabaseName, GETDATE() AS CurrentTime"
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $testQuery -ErrorAction Stop
        Write-Host "   ✅ Conexión a $DatabaseName exitosa" -ForegroundColor Green
        return $true
    }
    catch {
        # CORRECCIÓN: Usar comillas dobles o formato diferente para Write-Error
        Write-Error "   ❌ Error conectando a la base de datos '$DatabaseName': $($_.Exception.Message)"
        return $false
    }
}

function Get-SQLServices {
    param([string]$ComputerName)

    try {
        Write-Host "   🔧 Obteniendo servicios de SQL Server..." -ForegroundColor Yellow
        $services = Get-DbaService -ComputerName $ComputerName
        Write-Host "   ✅ Servicios obtenidos ($($services.Count) servicios)" -ForegroundColor Green
        return $services
    }
    catch {
        Write-Warning "   ⚠️  No se pudieron obtener servicios: $($_.Exception.Message)"
        return @()
    }
}

# NUEVAS FUNCIONES AÑADIDAS

function Get-SQLServerVersionInfo {
    param([string]$SqlInstance)

    try {
        Write-Host "   🔄 Verificando versión de SQL Server y parches..." -ForegroundColor Yellow

        # Consulta directa para información de versión
        $query = @"
SELECT
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('ProductLevel') AS ProductLevel,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('ProductUpdateLevel') AS ProductUpdateReference,
    SERVERPROPERTY('BuildClrVersion') AS BuildClrVersion,
    SERVERPROPERTY('Collation') AS Collation,
    @@VERSION AS FullVersion
"@
        $versionInfo = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query $query -ErrorAction Stop

        # Análisis básico de versión
        $productVersion = $versionInfo.ProductVersion
        $productLevel = $versionInfo.ProductLevel
        $edition = $versionInfo.Edition

        # Extraer el número de build de la versión del producto
        $buildNumber = $productVersion.Split('.')[2]

        # Determinar si necesita parches (lógica simple basada en nivel de producto)
        $isUpToDate = $true
        $patchesBehind = 0
        $status = "Actualizado"
        $recommendation = "El servidor está actualizado"

        # Lógica simple para determinar estado de parches
        if ($productLevel -eq "RTM") {
            $isUpToDate = $false
            $patchesBehind = 1
            $status = "Necesita Service Pack"
            $recommendation = "Se recomienda aplicar Service Pack más reciente"
        }
        elseif ($productLevel -eq "SP1") {
            $isUpToDate = $false
            $patchesBehind = 1
            $status = "Necesita actualización"
            $recommendation = "Se recomienda aplicar Service Pack más reciente"
        }

        # Para SQL Server 2022, verificar si está en la versión más reciente
        if ($productVersion.StartsWith("16.")) {
            # SQL Server 2022
            # Build 16.0.1000.6 es RTM, builds más recientes tienen mejoras
            if ($buildNumber -eq "1000") {
                $isUpToDate = $false
                $patchesBehind = 1
                $status = "Necesita actualización acumulativa"
                $recommendation = "Se recomienda aplicar la última actualización acumulativa para SQL Server 2022"
            }
        }

        return @{
            Version        = $productVersion
            BuildNumber    = $buildNumber
            ProductLevel   = $productLevel
            Edition        = $edition
            IsUpToDate     = $isUpToDate
            PatchesBehind  = $patchesBehind
            Status         = $status
            Recommendation = $recommendation
            FullVersion    = $versionInfo.FullVersion
            Collation      = $versionInfo.Collation
            CheckDate      = Get-Date
        }
    }
    catch {
        Write-Error "   ❌ Error verificando versión de SQL Server: $($_.Exception.Message)"
        return @{
            Version        = "N/A"
            BuildNumber    = "N/A"
            ProductLevel   = "N/A"
            Edition        = "N/A"
            IsUpToDate     = $false
            PatchesBehind  = 999
            Status         = "Error"
            Recommendation = "No se pudo verificar el estado de parches"
            FullVersion    = "N/A"
            Collation      = "N/A"
            CheckDate      = Get-Date
        }
    }
 }


function Get-DetailedDiskSpaceLegacy {
    param([string]$SqlInstance)

    try {
        Write-Host "   💽 Obteniendo información detallada de discos..." -ForegroundColor Yellow

        # Obtener información de discos
        $diskInfo = Get-DbaDiskSpace -SqlInstance $SqlInstance -ErrorAction Stop

        # Procesar información para identificar puntos de montaje
        $detailedDisks = @()

        foreach ($disk in $diskInfo) {
            $isMountPoint = $false
            $mountPointInfo = ""

            # Detectar si es punto de montaje
            if ($disk.Name -match "\\[A-Z]\\" -and $disk.Name -notmatch "^[A-Z]:\\$") {
                $isMountPoint = $true
                $mountPointInfo = "Punto de Montaje"
            }
            elseif ($disk.Name -eq ($disk.Name.Substring(0, 2) + "\")) {
                $mountPointInfo = "Disco Principal"
            }
            else {
                $mountPointInfo = "Carpeta/Unidad"
            }

            # Calcular porcentaje de uso
            $percentUsed = 0
            if ($disk.Size -gt 0) {
                $percentUsed = [math]::Round(($disk.Used / $disk.Size) * 100, 2)
            }

            # Determinar estado de alerta
            $alertLevel = "Normal"
            if ($percentUsed -ge 90) {
                $alertLevel = "Critico"
            }
            elseif ($percentUsed -ge 80) {
                $alertLevel = "Advertencia"
            }

            $detailedDisks += [PSCustomObject]@{
                ComputerName   = $disk.ComputerName
                Name           = $disk.Name
                Label          = $disk.Label
                CapacityGB     = [math]::Round($disk.Size / 1GB, 2)
                FreeGB         = [math]::Round($disk.Free / 1GB, 2)
                UsedGB         = [math]::Round($disk.Used / 1GB, 2)
                PercentUsed    = $percentUsed
                IsMountPoint   = $isMountPoint
                MountPointType = $mountPointInfo
                AlertLevel     = $alertLevel
                CheckDate      = Get-Date
            }
        }

        Write-Host "   ✅ Información detallada de discos obtenida ($($detailedDisks.Count) unidades)" -ForegroundColor Green
        return $detailedDisks

    }
    catch {
        Write-Error "   ❌ Error obteniendo información de discos: $($_.Exception.Message)"
        return @()
    }
}

function Get-BackupJobStatus {
    param([string]$SqlInstance, [int]$HoursBack = 24)

    try {
        Write-Host "   📊 Verificando estado de jobs de backup..." -ForegroundColor Yellow

        # Obtener jobs de SQL Server Agent
        $jobs = Get-DbaAgentJob -SqlInstance $SqlInstance -ErrorAction Stop |
        Where-Object { $_.Name -like "*backup*" -or $_.Name -like "*Backup*" -or $_.Description -like "*backup*" }

        $jobStatusReport = @()
        $hasErrors = $false

        foreach ($job in $jobs) {
            # Obtener historial reciente del job
            $jobHistory = Get-DbaAgentJobHistory -SqlInstance $SqlInstance -Job $job.Name -Since (Get-Date).AddHours(-$HoursBack) -ErrorAction SilentlyContinue

            $lastRun = $jobHistory | Sort-Object RunDate -Descending | Select-Object -First 1
            $failedRuns = $jobHistory | Where-Object { $_.Status -eq "Failed" }

            $jobStatus = "Success"
            $errorMessage = ""

            if ($failedRuns.Count -gt 0) {
                $jobStatus = "Failed"
                $hasErrors = $true
                $errorMessage = ($failedRuns | Select-Object -First 1).Message
            }
            elseif ($lastRun -and $lastRun.Status -eq "Failed") {
                $jobStatus = "Failed"
                $hasErrors = $true
                $errorMessage = $lastRun.Message
            }
            elseif (-not $lastRun) {
                $jobStatus = "Unknown"
            }

            $jobStatusReport += [PSCustomObject]@{
                SqlInstance       = $SqlInstance
                JobName           = $job.Name
                JobEnabled        = $job.IsEnabled
                LastRunDate       = if ($lastRun) { $lastRun.RunDate } else { "Nunca" }
                LastRunStatus     = if ($lastRun) { $lastRun.Status } else { "Unknown" }
                JobStatus         = $jobStatus
                FailedRunsLast24h = $failedRuns.Count
                ErrorMessage      = $errorMessage
                CheckDate         = Get-Date
            }
        }

        # Si no se encontraron jobs de backup, reportar
        if ($jobs.Count -eq 0) {
            $jobStatusReport += [PSCustomObject]@{
                SqlInstance       = $SqlInstance
                JobName           = "No se encontraron jobs de backup"
                JobEnabled        = $false
                LastRunDate       = "N/A"
                LastRunStatus     = "Unknown"
                JobStatus         = "Warning"
                FailedRunsLast24h = 0
                ErrorMessage      = "No se detectaron jobs con nombre o descripción relacionada a backup"
                CheckDate         = Get-Date
            }
        }

        Write-Host "   ✅ Estado de jobs de backup verificado ($($jobStatusReport.Count) jobs)" -ForegroundColor Green

        return @{
            JobStatusReport = $jobStatusReport
            HasErrors       = $hasErrors
        }

    }
    catch {
        Write-Error "   ❌ Error verificando jobs de backup: $($_.Exception.Message)"
        return @{
            JobStatusReport = @([PSCustomObject]@{
                    SqlInstance       = $SqlInstance
                    JobName           = "Error"
                    JobEnabled        = $false
                    LastRunDate       = "N/A"
                    LastRunStatus     = "Error"
                    JobStatus         = "Error"
                    FailedRunsLast24h = 0
                    ErrorMessage      = $_.Exception.Message
                    CheckDate         = Get-Date
                })
            HasErrors       = $true
        }
    }
}

function Send-DbaNotification {
    param(
        [string]$Subject,
        [string]$Body,
        [string]$Type = "Warning"
    )

    try {
        # Configuración de notificaciones
        $notificationConfig = @{
            LogPath      = ".\reports\notifications.log"
            EmailEnabled = $false
            TeamsEnabled = $false
        }

        # Log de notificación
        $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$Type] - $Subject"
        Add-Content -Path $notificationConfig.LogPath -Value $logEntry

        # Mostrar notificación en consola
        switch ($Type) {
            "Error" {
                Write-Host "   🚨 NOTIFICACIÓN - $Subject" -ForegroundColor Red
                Write-Host "   📝 $Body" -ForegroundColor Red
            }
            "Warning" {
                Write-Host "   ⚠️  NOTIFICACIÓN - $Subject" -ForegroundColor Yellow
                Write-Host "   📝 $Body" -ForegroundColor Yellow
            }
            "Success" {
                Write-Host "   ✅ NOTIFICACIÓN - $Subject" -ForegroundColor Green
                Write-Host "   📝 $Body" -ForegroundColor Green
            }
            default {
                Write-Host "   ℹ️  NOTIFICACIÓN - $Subject" -ForegroundColor White
                Write-Host "   📝 $Body" -ForegroundColor White
            }
        }

        Write-Host "   ✅ Notificación registrada" -ForegroundColor Green
        return $true

    }
    catch {
        Write-Error "   ❌ Error enviando notificación: $($_.Exception.Message)"
        return $false
    }
}

# Función para mostrar resumen de herramientas disponibles
function Show-DbaToolsFunctions {
    Write-Host "`n🛠️  FUNCIONES DBATOOLS DISPONIBLES:" -ForegroundColor Cyan
    Write-Host "   • Test-SQLConnection" -ForegroundColor Yellow
    Write-Host "   • Get-BasicServerInfo" -ForegroundColor Yellow
    Write-Host "   • Get-DatabaseList" -ForegroundColor Yellow
    Write-Host "   • Backup-DatabaseSimple" -ForegroundColor Yellow
    Write-Host "   • Get-ServerSpace" -ForegroundColor Yellow
    Write-Host "   • Test-DatabaseConnectivity" -ForegroundColor Yellow
    Write-Host "   • Get-SQLServices" -ForegroundColor Yellow
    Write-Host "   • Get-SQLServerVersionInfo" -ForegroundColor Green
    Write-Host "   • Get-DetailedDiskSpace" -ForegroundColor Green
    Write-Host "   • Get-BackupJobStatus" -ForegroundColor Green
    Write-Host "   • Send-DbaNotification" -ForegroundColor Green
    Write-Host ""
}