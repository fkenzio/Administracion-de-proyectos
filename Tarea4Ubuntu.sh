#!/bin/bash
# main.sh

# Cargar módulos
source ./lib/functions_utils.sh
source ./lib/functions_ssh.sh

check_root

echo "--- Menú de Administración Modular ---"
echo "1. Configurar SSH"
echo "2. Salir"
read -p "Selecciona una opción: " OPT

case $OPT in
    1) configurar_ssh ;;
    2) exit 0 ;;
    *) echo "Opción inválida." ;;
esac