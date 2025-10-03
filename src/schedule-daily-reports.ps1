# schedule-daily-reports.ps1
# Programa la ejecución automática diaria a las 6 AM
# Ubicación: En la raíz del proyecto, junto a main.ps1

param(
    [string]$ProjectPath = "C:\Users\santiago.guevara\dbatools-AW2022-v2",
    [string]$TaskName = "DBATools-DailyReport"
)

# El script main.ps1 está en src\main.ps1 - CORREGIDO
$ScriptPath = Join-Path $ProjectPath "src\main.ps1"

Write-Host "🚀 PROGRAMADOR DE TAREAS DBATOOLS-AW2022-V2" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan
Write-Host "Proyecto: $ProjectPath" -ForegroundColor Yellow
Write-Host "Script: $ScriptPath" -ForegroundColor Yellow
Write-Host "Tarea: $TaskName" -ForegroundColor Yellow
Write-Host ""

try {
    # Verificar si PowerShell se ejecuta como administrador
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    if (-not $isAdmin) {
        Write-Host "❌ Este script requiere permisos de administrador." -ForegroundColor Red
        Write-Host "   Por favor, ejecute PowerShell como administrador." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "✅ Verificando permisos de administrador..." -ForegroundColor Green

    # Verificar si el script main.ps1 existe - CORREGIDO
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "❌ No se encuentra el script main.ps1 en: $ScriptPath" -ForegroundColor Red
        Write-Host "   Asegúrese de que main.ps1 esté en la carpeta src" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "✅ Script main.ps1 encontrado..." -ForegroundColor Green

    # Verificar si la tarea ya existe
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($existingTask) {
        Write-Host "🔄 Tarea existente encontrada. Actualizando..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "✅ Tarea anterior eliminada." -ForegroundColor Green
    }

    # Crear nueva tarea programada
    Write-Host "📅 Creando nueva tarea programada..." -ForegroundColor Yellow

    $action = New-ScheduledTaskAction `
        -Execute "PowerShell.exe" `
        -Argument "-NoProfile -WindowStyle Hidden -File `"$ScriptPath`""

    $trigger = New-ScheduledTaskTrigger `
        -Daily `
        -At "6:00 AM"

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 5)

    $principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    # Registrar la tarea
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Ejecución diaria automática de reportes DBATOOLS-AW2022-V2 a las 6:00 AM. Genera reportes de discos, versiones y jobs de backup."

    Write-Host "✅ Tarea programada creada exitosamente!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 DETALLES DE LA TAREA:" -ForegroundColor Cyan
    Write-Host "   • Nombre: $TaskName" -ForegroundColor White
    Write-Host "   • Ejecución: Diaria a las 6:00 AM" -ForegroundColor White
    Write-Host "   • Usuario: SYSTEM (Servicio)" -ForegroundColor White
    Write-Host "   • Script: src\main.ps1" -ForegroundColor White
    Write-Host "   • Modo: Ventana oculta" -ForegroundColor White

    # Mostrar información de la tarea creada
    Write-Host ""
    Write-Host "🔍 VERIFICANDO TAREA CREADA..." -ForegroundColor Cyan
    $taskInfo = Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo
    Write-Host "   • Estado: $($taskInfo.LastTaskResult)" -ForegroundColor White
    Write-Host "   • Última ejecución: $($taskInfo.LastRunTime)" -ForegroundColor White
    Write-Host "   • Próxima ejecución: $($taskInfo.NextRunTime)" -ForegroundColor White

    Write-Host ""
    Write-Host "🎯 COMANDOS ÚTILES:" -ForegroundColor Cyan
    Write-Host "   • Ver estado: Get-ScheduledTask -TaskName `"$TaskName`" | Get-ScheduledTaskInfo" -ForegroundColor White
    Write-Host "   • Ejecutar ahora: Start-ScheduledTask -TaskName `"$TaskName`"" -ForegroundColor White
    Write-Host "   • Detener tarea: Stop-ScheduledTask -TaskName `"$TaskName`"" -ForegroundColor White
    Write-Host "   • Eliminar tarea: Unregister-ScheduledTask -TaskName `"$TaskName`" -Confirm:`$false" -ForegroundColor White

    Write-Host ""
    Write-Host "📝 Los reportes diarios se guardarán en: $ProjectPath\reports\" -ForegroundColor Yellow
    Write-Host "⏰ La primera ejecución automática será mañana a las 6:00 AM" -ForegroundColor Green

}
catch {
    Write-Host "❌ Error programando tarea automática: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Asegúrese de ejecutar PowerShell como administrador." -ForegroundColor Yellow
}