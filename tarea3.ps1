# Script de Automatización DNS - Proyecto Reprobados (Windows)
# 1. Verificación de IP Estática
Get-NetAdapter | Where-Object Status -eq "Up" | Format-Table Name, InterfaceAlias
$Interface = Read-Host "Escribe el InterfaceAlias que quieres configurar"
$IPInfo = Get-NetIPInterface -InterfaceAlias $Interface -AddressFamily IPv4

if ($IPInfo.Dhcp -eq "Enabled") {
    Write-Host "Configurando IP Estática..." -ForegroundColor Yellow

    $IP = Read-Host "IP para este servidor"
    $Mask = Read-Host "Prefijo de red (ej: 24)"
    $GW = Read-Host "Gateway"

    New-NetIPAddress -InterfaceAlias $Interface -IPAddress $IP -PrefixLength $Mask -DefaultGateway $GW
    Set-DnsClientServerAddress -InterfaceAlias $Interface -ServerAddresses ("127.0.0.1","8.8.8.8")
}
# 2. Instalación del Rol DNS (Idempotente)
if (!(Get-WindowsFeature DNS).Installed) {
 Write-Host "Instalando rol DNS..."
 Install-WindowsFeature DNS -IncludeManagementTools
}
# 3. Configuración de Zona y Registros
$ZoneName = "reprobados.com"
$ClientIP = Read-Host "Introduce la IP del CLIENTE (Lubuntu) para los registros"
# Crear Zona si no existe
if (!(Get-DnsServerZone -Name $ZoneName -ErrorAction SilentlyContinue)) {
 Add-DnsServerPrimaryZone -Name $ZoneName -ZoneFile "reprobados.com.dns"
 Write-Host "Zona $ZoneName creada."
}
# Agregar Registros A (Borra existentes para actualizar si ya existían)
Remove-DnsServerResourceRecord -ZoneName $ZoneName -Name "@" -RRType "A" -Force -ErrorAction SilentlyContinue
Remove-DnsServerResourceRecord -ZoneName $ZoneName -Name "www" -RRType "A" -Force -ErrorAction SilentlyContinue
Add-DnsServerResourceRecordA -ZoneName $ZoneName -Name "@" -IPv4Address $ClientIP
Add-DnsServerResourceRecordA -ZoneName $ZoneName -Name "www" -IPv4Address $ClientIP
Write-Host "Configuración completada. Registros A apuntando a $ClientIP" -ForegroundColor Green
