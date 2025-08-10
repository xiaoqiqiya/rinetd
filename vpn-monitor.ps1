# vpn-monitor.ps1

$ip_target = "192.168.4.241"
$ahk_script = "C:\Users\Administrator\Desktop\reconnect-vpn.ahk"
$pagerduty_routing_key = "00000000000000000000000000000"
$dedup_key = "vpn-down-event"
$rinetd_script_path = "C:\Users\Administrator\Desktop\iniciar_rinetd.bat"

function Test-Ping {
    return Test-Connection -ComputerName $ip_target -Count 1 -Quiet
}

function Reconnect-VPN {
    Write-Output "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss') - Intentando reconectar VPN con AutoHotkey..."

    # Cerrar FortiClient si está abierto
    Get-Process -Name FortiClient -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "Cerrando instancia previa de FortiClient (PID $_.Id)"
        Stop-Process -Id $_.Id -Force
    }
    # Cierra procesos existentes de rinetd
    Get-Process -Name rinetd -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "Cerrando rinetd (PID $_.Id)"
        Stop-Process -Id $_.Id -Force
    }
    Start-Sleep -Seconds 2

    # Ejecutar AutoHotkey para reconectar
    Start-Process "C:\Program Files\AutoHotkey\AutoHotkey.exe" -ArgumentList "`"$ahk_script`"" -WindowStyle Hidden
    Start-Sleep -Seconds 20
}

function Restart-Rinetd {
    Write-Output "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss') - Reiniciando rinetd..."

    # Cierra procesos existentes de rinetd
    Get-Process -Name rinetd -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "Cerrando rinetd (PID $_.Id)"
        Stop-Process -Id $_.Id -Force
    }

    Start-Sleep -Seconds 2

    # Iniciar el script .bat
    if (Test-Path $rinetd_script_path) {
        Write-Output "Ejecutando script: $rinetd_script_path"
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$rinetd_script_path`"" -WindowStyle Hidden
    } else {
        Write-Output "Script iniciar_rinetd.bat no encontrado en el escritorio."
    }
}

function Send-PagerDutyAlert {
    Write-Output "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss') - Enviando alerta a PagerDuty con curl..."

    $jsonBody = @"
{
  "routing_key": "$pagerduty_routing_key",
  "event_action": "trigger",
  "dedup_key": "$dedup_key",
  "payload": {
    "summary": "Fallo de conexión VPN: $ip_target sigue sin responder.",
    "severity": "error",
    "source": "$env:COMPUTERNAME",
    "component": "FortiClient",
    "group": "network",
    "class": "vpn",
    "custom_details": {
      "description": "El script vpn-monitor.ps1 detecto perdida de conectividad y no logro reconectar via AutoHotkey."
    }
  }
}
"@

    $tempFile = "$env:TEMP\pagerduty_trigger.json"
    $jsonBody | Out-File -Encoding ascii -FilePath $tempFile

    & "$env:SystemRoot\System32\curl.exe" -X POST "https://events.pagerduty.com/v2/enqueue" `
        -H "Content-Type: application/json" `
        -d "@$tempFile"

    Remove-Item $tempFile
}

function Resolve-PagerDutyAlert {
    Write-Output "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss') - Resolviendo alerta en PagerDuty con curl..."

    $jsonBody = @"
{
  "routing_key": "$pagerduty_routing_key",
  "event_action": "resolve",
  "dedup_key": "$dedup_key"
}
"@

    $tempFile = "$env:TEMP\pagerduty_resolve.json"
    $jsonBody | Out-File -Encoding ascii -FilePath $tempFile

    & "$env:SystemRoot\System32\curl.exe" -X POST "https://events.pagerduty.com/v2/enqueue" `
        -H "Content-Type: application/json" `
        -d "@$tempFile"

    Remove-Item $tempFile
}

# Bucle infinito de monitoreo
while ($true) {
    if (-not (Test-Ping)) {
        Write-Output "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss') - Sin respuesta de $ip_target"

        Reconnect-VPN

        if (-not (Test-Ping)) {
            Write-Output "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss') - Aun sin respuesta tras reconexion"
            Send-PagerDutyAlert
        } else {
            Write-Output "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss') - Conexion restaurada tras reconexion"
            Restart-Rinetd
            Resolve-PagerDutyAlert
        }
    } else {
        Write-Output "$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss') - Ping OK a $ip_target"
    }

    Start-Sleep -Seconds 30
}
