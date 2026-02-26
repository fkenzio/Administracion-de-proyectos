# 1. Idempotencia: Verificar Rol
$check = Get-WindowsFeature -Name DHCP
if ($check.Installed -eq $false) {
 Write-Host "Instalando Rol DHCP..." -ForegroundColor Cyan
 Install-WindowsFeature -Name DHCP -IncludeManagementTools
} else {
 Write-Host "El Rol DHCP ya está presente." -ForegroundColor Green
}
# 2. Orquestación Dinámica
$ScopeName = Read-Host "Nombre del Ámbito"
$StartIP = Read-Host "Rango Inicial"
$EndIP = Read-Host "Rango Final"
$Gateway = Read-Host "Puerta de Enlace (Router)"
$DNS = Read-Host "DNS Server"
# 3. Configuración del Ámbito
Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartIP -EndRange $EndIP -
SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -OptionId 3 -Value $Gateway
Set-DhcpServerv4OptionValue -OptionId 6 -Value $DNS
# 4. Módulo de Monitoreo
Write-Host "`n--- ESTADO DEL SERVICIO ---" -ForegroundColor Yellow
Get-Service DHCPServer | Select-Object Status, DisplayName
Write-Host "`n--- CONCESIONES (LEASES) ACTIVAS ---" -ForegroundColor Yellow
Get-DhcpServerv4Lease -ScopeId 192.168.100.0