#!/bin/bash
# lib/functions_utils.sh

# Validar si el usuario es root
check_root() {
    if [[ $EUID -ne 0 ]]; then
       echo "Este script debe ejecutarse como root (sudo)."
       exit 1
    fi
}

# Instalación genérica de paquetes (Idempotente)
instalar_paquete() {
    if dpkg -l | grep -q "$1"; then
        echo "El paquete $1 ya está instalado."
    else
        echo "Instalando $1..."
        apt update && apt install -y "$1"
    fi
}