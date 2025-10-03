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
    Write-Host ""
}