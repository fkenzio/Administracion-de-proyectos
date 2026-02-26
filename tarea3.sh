#!/interim/bash
# Script de Automatización DNS - Proyecto Reprobados (Linux)
# 1. Verificación de IP Estática
INTERFACE=$(ip route | grep default | awk '{print $5}')
IS_STATIC=$(grep "static" /etc/network/interfaces /etc/netplan/*.yaml 2>/dev/null)
if [ -z "$IS_STATIC" ]; then
 echo "--- Configuración de IP Estática Requerida ---"
 read -p "Introduce la IP para este servidor (ej: 192.168.1.10): " SERVER_IP
 read -p "Introduce la máscara (ej: 24): " MASK
 read -p "Introduce el Gateway: " GW

 # Configuración básica para Netplan (Ubuntu moderno)
 cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
 version: 2
 renderer: networkd
 ethernets:
 $INTERFACE:
 addresses: [$SERVER_IP/$MASK]
 gateway4: $GW
 nameservers:
 addresses: [8.8.8.8, 8.8.4.4]
EOF
 netplan apply
 echo "IP Estática configurada: $SERVER_IP"
else
 SERVER_IP=$(hostname -I | awk '{print $1}')
 echo "IP Estática detectada: $SERVER_IP"
fi
# 2. Instalación Idempotente
echo "Instalando BIND9..."
sudo apt update && sudo apt install -y bind9 bind9utils bind9-doc
# 3. Configuración de Zona
CLIENT_IP_TARGET=""
read -p "Introduce la IP del CLIENTE (Lubuntu) para el registro A: " CLIENT_IP_TARGET
# Configurar named.conf.local
if ! grep -q "reprobados.com" /etc/bind/named.conf.local; then
 cat <<EOF >> /etc/bind/named.conf.local
zone "reprobados.com" {
 type master;
 file "/var/cache/bind/db.reprobados.com";
};
EOF
fi
# 4. Creación del Archivo de Zona (Sobreescritura limpia)
cat <<EOF > /var/cache/bind/db.reprobados.com
\$TTL 604800
@ IN SOA ns1.reprobados.com. admin.reprobados.com. (
 3 ; Serial
 604800 ; Refresh
 86400 ; Retry
 2419200 ; Expire
 604800 ) ; Negative Cache TTL
;
@ IN NS ns1.reprobados.com.
ns1 IN A $SERVER_IP
@ IN A $CLIENT_IP_TARGET
www IN A $CLIENT_IP_TARGET
EOF
# 5. Validación y Reinicio
named-checkconf
chown bind:bind /var/cache/bind/db.reprobados.com
systemctl restart bind9
echo "¡DNS configurado con éxito en Linux!"