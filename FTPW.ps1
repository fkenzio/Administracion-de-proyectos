function instalarFTP {
    Import-Module ServerManager

    # Instalar IIS y servicio FTP primero
    Install-WindowsFeature Web-Server -IncludeAllSubFeature
    Install-WindowsFeature Web-FTP-Service
    Install-WindowsFeature Web-Basic-Auth

    # Importar WebAdministration DESPUÉS de instalar IIS
    Import-Module WebAdministration

    # Reglas de firewall
    New-NetFirewallRule -DisplayName "FTP" -Direction Inbound -Protocol TCP -LocalPort 21 -Action Allow
    New-NetFirewallRule -DisplayName "ICMPv4" -Protocol ICMPv4 -Direction Inbound -Action Allow
    New-NetFirewallRule -DisplayName "ICMPv6" -Protocol ICMPv6 -Direction Inbound -Action Allow

    # Crear estructura de directorios
    if (-not (Test-Path "C:\FTP")) {
        New-Item -Path "C:\FTP" -ItemType Directory
        New-Item -Path "C:\FTP\General" -ItemType Directory
        New-Item -Path "C:\FTP\LocalUser\Public" -ItemType Directory -Force
    }

    # Crear sitio web FTP si no existe
    if (-not (Get-Website | Where-Object { $_.Name -eq "FTP" })) {
        New-Website -Name "FTP" -PhysicalPath "C:\FTP" -Port 21 -Force
    }

    # Configurar FTP: Desactivar SSL
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/security/ssl" -Name "controlChannelPolicy" -Value "SslAllow"
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/security/ssl" -Name "dataChannelPolicy" -Value "SslAllow"

    # Aislamiento por usuario
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/userIsolation" -Name "mode" -Value "IsolateAllDirectories"

    # Habilitar autenticación básica y anónima
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/security/authentication/basicAuthentication" -Name "enabled" -Value $true
    Set-WebConfigurationProperty -Filter "/system.applicationHost/sites/site[@name='FTP']/ftpServer/security/authentication/anonymousAuthentication" -Name "enabled" -Value $true
}

function ConfigurarAnonimo {
    icacls "C:\FTP\General" /grant "IUSR:(OI)(CI)R" /T /C | Out-Null

    if (-not (Get-WebConfiguration "/system.ftpServer/security/authorization" | Where-Object { $_.Attributes["users"].Value -eq "*" })) {
        Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users="*";permissions=1}
    }
}

function CrearGrupos {
    $ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"

    if (-not ($ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq "Reprobados" })) {
        New-Item -Path "C:\FTP\Reprobados" -ItemType Directory -Force
        $grupo = $ADSI.Create("Group", "Reprobados")
        $grupo.SetInfo()
    }

    if (-not ($ADSI.Children | Where-Object { $_.SchemaClassName -eq "Group" -and $_.Name -eq "Recursadores" })) {
        New-Item -Path "C:\FTP\Recursadores" -ItemType Directory -Force
        $grupo = $ADSI.Create("Group", "Recursadores")
        $grupo.SetInfo()
    }
}

function CrearUsuario {
    while ($true) {
        $nombre = Read-Host "Nombre de usuario (minimo 4 letras, solo letras, escribir 'salir' para terminar)"
        if ($nombre -eq "salir") { return }

        if ($nombre.Length -lt 4 -or $nombre -notmatch "^[a-zA-Z]+$") {
            Write-Host "Nombre invalido. Debe tener al menos 4 letras sin numeros ni simbolos." -ForegroundColor Red
            continue
        }

        if (Get-LocalUser -Name $nombre -ErrorAction SilentlyContinue) {
            Write-Host "El usuario ya existe." -ForegroundColor Red
            continue
        }

        $grupo = ""
        while ($grupo -ne "Reprobados" -and $grupo -ne "Recursadores") {
            $op = Read-Host "Seleccione grupo (1: Reprobados, 2: Recursadores)"
            if ($op -eq "1") { $grupo = "Reprobados" }
            elseif ($op -eq "2") { $grupo = "Recursadores" }
            else { Write-Host "Opcion invalida." -ForegroundColor Red }
        }

        # Validación de contraseña más estricta para cumplir con la política de Windows Server 2022
        while ($true) {
            $pass = Read-Host "Contrasena segura (8+ caracteres, 1 mayuscula, 1 minuscula, 1 numero, 1 simbolo, sin espacios)"
            if ($pass.Length -ge 8 -and
                $pass -match "[A-Z]" -and
                $pass -match "[a-z]" -and
                $pass -match "[0-9]" -and
                $pass -match "[\W_]" -and
                $pass -notmatch "\s" -and
                $pass -notmatch [regex]::Escape($nombre)) {
                break
            } else {
                Write-Host "Contrasena no valida. Debe tener 8+ caracteres, al menos 1 mayuscula, 1 minuscula, 1 numero, 1 simbolo, sin espacios, y no puede contener el nombre de usuario." -ForegroundColor Red
            }
        }

        # Crear usuario con manejo de errores
        try {
            $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
            New-LocalUser -Name $nombre -Password $secPass -FullName $nombre -Description "Usuario FTP" -ErrorAction Stop
        } catch {
            Write-Host "Error al crear el usuario: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Intente con una contrasena diferente." -ForegroundColor Yellow
            continue
        }

        # Solo agregar al grupo si el usuario se creó correctamente
        try {
            Add-LocalGroupMember -Group $grupo -Member $nombre -ErrorAction Stop
        } catch {
            Write-Host "Error al agregar al grupo: $($_.Exception.Message)" -ForegroundColor Red
            continue
        }

        $ruta = "C:\FTP\LocalUser\$nombre"
        if (-not (Test-Path $ruta)) {
            New-Item -Path "$ruta\Personal" -ItemType Directory -Force
            New-Item -Path "$ruta\General" -ItemType Junction -Target "C:\FTP\General" -Force
            New-Item -Path "$ruta\$grupo" -ItemType Junction -Target "C:\FTP\$grupo" -Force
        }

        Add-WebConfiguration "/system.ftpServer/security/authorization" -Value @{accessType="Allow";users=$nombre;permissions=3}
        Write-Host "Usuario '$nombre' creado correctamente en el grupo '$grupo'." -ForegroundColor Green
    }
}

function AplicarPermisos {
    Stop-Website -Name "FTP"
    Start-Website -Name "FTP"
}

# EJECUCIÓN PRINCIPAL
Clear-Host
Write-Host "Instalando y configurando servidor FTP..." -ForegroundColor Cyan
instalarFTP
Write-Host "Configurando acceso anonimo..." -ForegroundColor Cyan
ConfigurarAnonimo
Write-Host "Creando grupos..." -ForegroundColor Cyan
CrearGrupos
Write-Host "Creando usuarios FTP..." -ForegroundColor Cyan
CrearUsuario
Write-Host "Reiniciando sitio FTP..." -ForegroundColor Cyan
AplicarPermisos
Write-Host "Servidor FTP configurado correctamente." -ForegroundColor Green