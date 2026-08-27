#!/usr/bin/env bash
# =========================================================
# instalar_ssh.sh
# Instala y habilita el servidor OpenSSH en la VM Ubuntu,
# y abre el puerto 22 en el firewall (ufw) si está activo.
# =========================================================
set -euo pipefail

echo "==> Actualizando índice de paquetes..."
sudo apt update

echo "==> Instalando openssh-server..."
sudo apt install -y openssh-server

echo "==> Habilitando e iniciando el servicio SSH..."
sudo systemctl enable --now ssh

echo "==> Verificando estado del servicio..."
sudo systemctl status ssh --no-pager || true

echo ""
echo "==> Verificando que esté escuchando en el puerto 22..."
sudo ss -tlnp | grep ':22' || echo "ADVERTENCIA: no se detectó el puerto 22 escuchando."

echo ""
if command -v ufw &>/dev/null; then
    echo "==> Permitiendo puerto 22 en ufw..."
    sudo ufw allow 22/tcp
    sudo ufw status verbose
else
    echo "==> ufw no está instalado/activo, no se requiere abrir puerto ahí."
fi

echo ""
echo "============================================================"
echo " SSH instalado y corriendo."
echo " IP(s) de esta máquina para conectarte desde tu red interna:"
ip -4 -o addr show up | awk '{print "   "$2" -> "$4}'
echo ""
echo " Desde tu computadora FÍSICA (no desde esta VM), prueba:"
echo "   ssh $(whoami)@<IP_DE_LA_RED_INTERNA>"
echo "============================================================"
