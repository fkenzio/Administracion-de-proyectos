#!/bin/bash
# lib/functions_ssh.sh

configurar_ssh() {
    instalar_paquete "openssh-server"
    systemctl enable ssh
    systemctl start ssh
    echo "SSH configurado y habilitado en el arranque."
}