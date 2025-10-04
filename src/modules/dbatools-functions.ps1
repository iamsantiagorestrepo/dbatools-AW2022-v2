# dbatools-functions.ps1 (OPTIMIZADO)
# Funciones básicas y utilidades de dbatools
# ============================================================================

# ============================================================================
# SECCIÓN 1: FUNCIONES DE CONEXIÓN Y PRUEBAS
# ============================================================================

function Test-SQLConnection {
    <#
    .SYNOPSIS
    Prueba la conexión a una instancia SQL Server.
    .PARAMETER SqlInstance
    Nombre de la instancia SQL Server a probar.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlInstance
    )

    try {
        Write-Host "   🔌 Probando conexión a $SqlInstance..." -ForegroundColor Yellow
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database "master" -Query "SELECT @@SERVERNAME AS ServerName, GETDATE() AS CurrentTime" -ErrorAction Stop
        Write-Host "   ✅ Conexión exitosa a $SqlInstance" -ForegroundColor Green
        return @{
            Success     = $true
            ServerName  = $result.ServerName
            CurrentTime = $result.CurrentTime
            Message     = "Conexión exitosa"
        }
    }
    catch {
        Write-Error "   ❌ Error de conexión: $($_.Exception.Message)"
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}

function Test-DatabaseConnectivity {
    <#
    .SYNOPSIS
    Prueba la conectividad a una base de datos específica.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlInstance,

        [Parameter(Mandatory = $true)]
        [string]$DatabaseName
    )

    try {
        Write-Host "   🔌 Probando conectividad a $DatabaseName..." -ForegroundColor Yellow
        $testQuery = "SELECT DB_NAME() AS DatabaseName, GETDATE() AS CurrentTime, @@VERSION AS Version"
        $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database $DatabaseName -Query $testQuery -ErrorAction Stop
        Write-Host "   ✅ Conexión a $DatabaseName exitosa" -ForegroundColor Green
        return @{
            Success      = $true
            DatabaseName = $result.DatabaseName
            CurrentTime  = $result.CurrentTime
            Message      = "Conexión exitosa a la base de datos"
        }
    }
    catch {
        Write-Error "   ❌ Error conectando a la base de datos '$DatabaseName': $($_.Exception.Message)"
        return @{
            Success = $false
            Message = $_.Exception.Message
        }
    }
}

# ============================================================================
# SECCIÓN 2: INFORMACIÓN BÁSICA DEL SERVIDOR
# ============================================================================

function Get-BasicServerInfo {
    <#
    .SYNOPSIS
    Obtiene información básica del servidor SQL.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlInstance
    )

    try {
        Write-Host "   🔍 Obteniendo información básica del servidor..." -ForegroundColor Yellow
        $query = @"
SELECT
    @@SERVERNAME AS ServerName,
    SERVERPROPERTY('MachineName') AS MachineName,
    SERVERPROPERTY('InstanceName') AS InstanceName,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('ProductLevel') AS ProductLevel,
    SERVERPROPERTY('Edition') AS Edition,
    @@VERSION AS SQLVersion,
    DB_NAME() AS CurrentDatabase,
    GETDATE() AS CurrentTime
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
    <#
    .SYNOPSIS
    Obtiene lista de bases de datos en el servidor.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlInstance,

        [Parameter(Mandatory = $false)]
        [switch]$OnlineOnly = $true
    )

    try {
        Write-Host "   📋 Obteniendo lista de bases de datos..." -ForegroundColor Yellow

        $whereClause = if ($OnlineOnly) { "WHERE state = 0  -- Solo bases de datos online" } else { "" }

        $query = @"
SELECT
    name AS DatabaseName,
    database_id AS DatabaseID,
    state_desc AS Status,
    recovery_model_desc AS RecoveryModel,
    compatibility_level AS CompatibilityLevel,
    create_date AS CreateDate,
    CAST((size * 8.0 / 1024) AS DECIMAL(10,2)) AS SizeMB
FROM sys.databases
$whereClause
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

function Get-SQLServices {
    <#
    .SYNOPSIS
    Obtiene información de servicios SQL Server en el equipo.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )

    try {
        Write-Host "   🔧 Obteniendo servicios de SQL Server..." -ForegroundColor Yellow
        $services = Get-DbaService -ComputerName $ComputerName -ErrorAction Stop
        Write-Host "   ✅ Servicios obtenidos ($($services.Count) servicios)" -ForegroundColor Green

        return $services | Select-Object @{
            Name       = 'ServiceName'
            Expression = { $_.ServiceName }
        }, @{
            Name       = 'DisplayName'
            Expression = { $_.DisplayName }
        }, @{
            Name       = 'Status'
            Expression = { $_.State }
        }, @{
            Name       = 'StartMode'
            Expression = { $_.StartMode }
        }, @{
            Name       = 'ServiceAccount'
            Expression = { $_.StartName }
        }
    }
    catch {
        Write-Warning "   ⚠️  No se pudieron obtener servicios: $($_.Exception.Message)"
        return @()
    }
}

# ============================================================================
# SECCIÓN 3: OPERACIONES DE BACKUP
# ============================================================================

function Backup-DatabaseSimple {
    <#
    .SYNOPSIS
    Realiza un backup simple de una base de datos.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlInstance,

        [Parameter(Mandatory = $true)]
        [string]$DatabaseName,

        [Parameter(Mandatory = $true)]
        [string]$BackupPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Full', 'Differential', 'Log')]
        [string]$BackupType = 'Full',

        [Parameter(Mandatory = $false)]
        [switch]$CompressBackup = $true
    )

    try {
        Write-Host "   💾 Realizando backup $BackupType de $DatabaseName..." -ForegroundColor Yellow

        $backupParams = @{
            SqlInstance    = $SqlInstance
            Database       = $DatabaseName
            Path           = $BackupPath
            Type           = $BackupType
            CompressBackup = $CompressBackup
        }

        $backupResult = Backup-DbaDatabase @backupParams -ErrorAction Stop

        Write-Host "   ✅ Backup completado exitosamente" -ForegroundColor Green
        Write-Host "      Archivo: $($backupResult.Path)" -ForegroundColor Gray
        Write-Host "      Tamaño: $([math]::Round($backupResult.TotalSize / 1MB, 2)) MB" -ForegroundColor Gray

        return $backupResult
    }
    catch {
        Write-Error "   ❌ Error en backup: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
# SECCIÓN 4: INFORMACIÓN DE DISCOS (SIMPLIFICADA)
# ============================================================================

function Get-ServerDiskSpace {
    <#
    .SYNOPSIS
    Obtiene información de espacio en disco del servidor (versión simple).
    .DESCRIPTION
    Función simplificada para obtener espacio en disco.
    Para análisis detallado usar Get-DiskSpaceInfo del data-collector.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlInstance
    )

    try {
        Write-Host "   💽 Obteniendo espacio en disco del servidor..." -ForegroundColor Yellow
        $spaceInfo = Get-DbaDiskSpace -SqlInstance $SqlInstance -ErrorAction Stop

        $formattedSpace = $spaceInfo | Select-Object @{
            Name       = 'DiskName'
            Expression = { $_.Name }
        }, @{
            Name       = 'TotalGB'
            Expression = { [math]::Round($_.Capacity / 1GB, 2) }
        }, @{
            Name       = 'FreeGB'
            Expression = { [math]::Round($_.Free / 1GB, 2) }
        }, @{
            Name       = 'UsedGB'
            Expression = { [math]::Round(($_.Capacity - $_.Free) / 1GB, 2) }
        }, @{
            Name       = 'PercentFree'
            Expression = { [math]::Round(($_.Free / $_.Capacity) * 100, 2) }
        }

        Write-Host "   ✅ Información de espacio obtenida ($($formattedSpace.Count) discos)" -ForegroundColor Green
        return $formattedSpace
    }
    catch {
        Write-Warning "   ⚠️  No se pudo obtener información de espacio: $($_.Exception.Message)"
        return @()
    }
}

# ============================================================================
# SECCIÓN 5: UTILIDADES Y HELPERS
# ============================================================================

function Show-AvailableFunctions {
    <#
    .SYNOPSIS
    Muestra todas las funciones disponibles en este módulo.
    #>
    Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  FUNCIONES DISPONIBLES - DBATOOLS-FUNCTIONS               ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

    Write-Host "`n📦 CONEXIÓN Y PRUEBAS:" -ForegroundColor Yellow
    Write-Host "   • Test-SQLConnection" -ForegroundColor White
    Write-Host "   • Test-DatabaseConnectivity" -ForegroundColor White

    Write-Host "`n📊 INFORMACIÓN DEL SERVIDOR:" -ForegroundColor Yellow
    Write-Host "   • Get-BasicServerInfo" -ForegroundColor White
    Write-Host "   • Get-DatabaseList" -ForegroundColor White
    Write-Host "   • Get-SQLServices" -ForegroundColor White
    Write-Host "   • Get-ServerDiskSpace" -ForegroundColor White

    Write-Host "`n💾 OPERACIONES DE BACKUP:" -ForegroundColor Yellow
    Write-Host "   • Backup-DatabaseSimple" -ForegroundColor White

    Write-Host "`n🛠️  UTILIDADES:" -ForegroundColor Yellow
    Write-Host "   • Show-AvailableFunctions" -ForegroundColor White
    Write-Host "   • Export-ServerInventory" -ForegroundColor White

    Write-Host "`n💡 NOTA: Para funciones avanzadas de análisis, usar data-collector.ps1" -ForegroundColor Gray
    Write-Host ""
}

function Export-ServerInventory {
    <#
    .SYNOPSIS
    Genera un inventario rápido del servidor SQL.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlInstance,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ".\reports\inventory_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    )

    try {
        Write-Host "`n📋 GENERANDO INVENTARIO DEL SERVIDOR..." -ForegroundColor Cyan

        # Recolectar información básica
        $serverInfo = Get-BasicServerInfo -SqlInstance $SqlInstance
        $databases = Get-DatabaseList -SqlInstance $SqlInstance
        $diskSpace = Get-ServerDiskSpace -SqlInstance $SqlInstance

        # Crear inventario
        $inventory = @{
            GeneratedDate = Get-Date
            SqlInstance   = $SqlInstance
            ServerInfo    = $serverInfo
            Databases     = $databases
            DiskSpace     = $diskSpace
            Summary       = @{
                TotalDatabases = $databases.Count
                TotalDisks     = $diskSpace.Count
                ProductVersion = $serverInfo.ProductVersion
                Edition        = $serverInfo.Edition
            }
        }

        # Guardar a archivo JSON
        $inventory | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8

        Write-Host "✅ Inventario generado exitosamente" -ForegroundColor Green
        Write-Host "📁 Ubicación: $OutputPath" -ForegroundColor Yellow

        # Mostrar resumen
        Write-Host "`n📊 RESUMEN:" -ForegroundColor Cyan
        Write-Host "   • Servidor: $($serverInfo.ServerName)" -ForegroundColor White
        Write-Host "   • Versión: $($serverInfo.ProductVersion)" -ForegroundColor White
        Write-Host "   • Edición: $($serverInfo.Edition)" -ForegroundColor White
        Write-Host "   • Bases de datos: $($databases.Count)" -ForegroundColor White
        Write-Host "   • Discos monitoreados: $($diskSpace.Count)" -ForegroundColor White

        return $inventory
    }
    catch {
        Write-Error "❌ Error generando inventario: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
# SECCIÓN 6: FUNCIONES DE INTEGRACIÓN CON DATA-COLLECTOR
# ============================================================================

function Invoke-QuickHealthCheck {
    <#
    .SYNOPSIS
    Realiza un chequeo rápido de salud del servidor.
    .DESCRIPTION
    Función de conveniencia que ejecuta pruebas básicas de salud.
    Para análisis completo, usar Get-CompleteDatabaseInfo del data-collector.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlInstance,

        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = "master"
    )

    try {
        Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║  CHEQUEO RÁPIDO DE SALUD                                  ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

        $healthStatus = @{
            SqlInstance = $SqlInstance
            CheckDate   = Get-Date
            Tests       = @{}
        }

        # 1. Test de conexión
        Write-Host "`n1️⃣  Prueba de conexión..." -ForegroundColor Yellow
        $connectionTest = Test-SQLConnection -SqlInstance $SqlInstance
        $healthStatus.Tests.Connection = $connectionTest

        if (-not $connectionTest.Success) {
            Write-Host "   ❌ FALLO: No se pudo conectar al servidor" -ForegroundColor Red
            return $healthStatus
        }

        # 2. Información del servidor
        Write-Host "`n2️⃣  Información del servidor..." -ForegroundColor Yellow
        $serverInfo = Get-BasicServerInfo -SqlInstance $SqlInstance
        $healthStatus.Tests.ServerInfo = if ($serverInfo) { "OK" } else { "FAILED" }

        if ($serverInfo) {
            Write-Host "   ✅ Servidor: $($serverInfo.ServerName)" -ForegroundColor Green
            Write-Host "   ✅ Versión: $($serverInfo.ProductVersion)" -ForegroundColor Green
            Write-Host "   ✅ Edición: $($serverInfo.Edition)" -ForegroundColor Green
        }

        # 3. Espacio en disco
        Write-Host "`n3️⃣  Espacio en disco..." -ForegroundColor Yellow
        $diskSpace = Get-ServerDiskSpace -SqlInstance $SqlInstance
        $healthStatus.Tests.DiskSpace = @{
            TotalDisks    = $diskSpace.Count
            CriticalDisks = ($diskSpace | Where-Object { $_.PercentFree -lt 10 }).Count
            WarningDisks  = ($diskSpace | Where-Object { $_.PercentFree -lt 20 -and $_.PercentFree -ge 10 }).Count
        }

        $criticalDisks = $diskSpace | Where-Object { $_.PercentFree -lt 10 }
        if ($criticalDisks) {
            Write-Host "   🚨 CRÍTICO: $($criticalDisks.Count) disco(s) con menos del 10% libre" -ForegroundColor Red
            foreach ($disk in $criticalDisks) {
                Write-Host "      • $($disk.DiskName): $($disk.PercentFree)% libre" -ForegroundColor Red
            }
        }
        else {
            Write-Host "   ✅ Espacio en disco: OK" -ForegroundColor Green
        }

        # 4. Bases de datos
        Write-Host "`n4️⃣  Bases de datos..." -ForegroundColor Yellow
        $databases = Get-DatabaseList -SqlInstance $SqlInstance
        $offlineDbs = $databases | Where-Object { $_.Status -ne 'ONLINE' }
        $healthStatus.Tests.Databases = @{
            Total   = $databases.Count
            Online  = ($databases | Where-Object { $_.Status -eq 'ONLINE' }).Count
            Offline = $offlineDbs.Count
        }

        if ($offlineDbs) {
            Write-Host "   ⚠️  ADVERTENCIA: $($offlineDbs.Count) base(s) de datos no están ONLINE" -ForegroundColor Yellow
            foreach ($db in $offlineDbs) {
                Write-Host "      • $($db.DatabaseName): $($db.Status)" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "   ✅ Todas las bases de datos están ONLINE ($($databases.Count) bases)" -ForegroundColor Green
        }

        # Resumen final
        Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
        Write-Host "║  RESULTADO DEL CHEQUEO DE SALUD                           ║" -ForegroundColor Cyan
        Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

        $overallStatus = "SALUDABLE"
        $statusColor = "Green"

        if ($healthStatus.Tests.DiskSpace.CriticalDisks -gt 0) {
            $overallStatus = "CRÍTICO"
            $statusColor = "Red"
        }
        elseif ($healthStatus.Tests.DiskSpace.WarningDisks -gt 0 -or $healthStatus.Tests.Databases.Offline -gt 0) {
            $overallStatus = "ADVERTENCIA"
            $statusColor = "Yellow"
        }

        Write-Host "`n   Estado General: $overallStatus" -ForegroundColor $statusColor
        Write-Host ""

        return $healthStatus
    }
    catch {
        Write-Error "❌ Error en chequeo de salud: $($_.Exception.Message)"
        return $null
    }
}

# ============================================================================
# EXPORTAR FUNCIONES (opcional para módulos)
# ============================================================================

<#
Export-ModuleMember -Function @(
    'Test-SQLConnection',
    'Test-DatabaseConnectivity',
    'Get-BasicServerInfo',
    'Get-DatabaseList',
    'Get-SQLServices',
    'Get-ServerDiskSpace',
    'Backup-DatabaseSimple',
    'Show-AvailableFunctions',
    'Export-ServerInventory',
    'Invoke-QuickHealthCheck'
)
#>

# ============================================================================
# ALIAS PARA COMPATIBILIDAD
# ============================================================================

# Crear alias para funciones renombradas (compatibilidad con código antiguo)
Set-Alias -Name Get-ServerSpace -Value Get-ServerDiskSpace -ErrorAction SilentlyContinue
Set-Alias -Name Show-DbaToolsFunctions -Value Show-AvailableFunctions -ErrorAction SilentlyContinue