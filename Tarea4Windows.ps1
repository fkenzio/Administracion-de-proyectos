# Main.ps1

# Importar módulos (Dot-sourcing)
. .\modules\Utils_Module.ps1
. .\modules\SSH_Module.ps1

Test-IsAdmin

Write-Host "--- Menú de Gestión Windows ---"
$choice = Read-Host "1. Instalar SSH`n2. Salir"

if ($choice -eq "1") {
    Install-SSHServer
}