#!/bin/bash
# 1. Idempotencia: Verificar si el servicio ya existe
if ! dpkg -l | grep -q isc-dhcp-server;
then
 echo "Instalando isc-dhcp-serverde forma desatendida..."
 sudo apt-get update && sudo aptget install -y isc-dhcp-server
else
 echo "El servicio DHCP ya está instalado. Omitiendo paso."
fi
# 2. Orquestación Dinámica (Interactivo)
echo "--- Configuración del Ámbito DHCP ---"
read -p "Nombre del Ámbito: " SCOPE_NAME

read -p "Rango Inicial (ej.192.168.100.50): " START_IP

read -p "Rango Final (ej.192.168.100.150): " END_IP

read -p "Puerta de Enlace: " GW_IP

read -p "DNS Server: " DNS_IP

# Validación simple de IP (Regex)
if [[ ! $START_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
 echo "Error: Formato de IP inválido."
 exit 1
fi
# 3. Aplicar Configuración
cat <<EOF | sudo tee/etc/dhcp/dhcpd.conf 
option domain-name "sistemas.local";

option domain-name-servers $DNS_IP;

default-lease-time 600;

max-lease-time 7200;

authoritative;


subnet 192.168.100.0 netmask 255.255.255.0 {
 range $START_IP $END_IP;
 option routers $GW_IP;
}
EOF
# Reiniciar y Validar
sudo systemctl restart isc-dhcpserver
echo "--- Módulo de Monitoreo ---"
sudo systemctl status isc-dhcp-server
--no-pager
echo "Concesiones activas:"
cat /var/lib/dhcp/dhcpd.leases