# modules/SSH_Module.ps1

function Install-SSHServer {
    # Instalar característica de OpenSSH Server
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    
    # Iniciar y habilitar servicio
    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'
    
    # Configurar regla de Firewall
    if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow
    }
    Write-Host "OpenSSH instalado y puerto 22 abierto."
}