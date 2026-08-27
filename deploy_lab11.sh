#!/usr/bin/env bash
# =========================================================
# deploy_lab11.sh
# Orquestación de infraestructura como código (IaC) - Lab 11
# Genera todos los archivos necesarios y levanta el stack con
# Docker Compose en un host Ubuntu.
# =========================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "==> Directorio del proyecto: $PROJECT_DIR"

# ---------------------------------------------------------
# 0) Verificar dependencias (docker, docker compose) e instalar
#    automáticamente desde el repositorio OFICIAL de Docker si
#    faltan (el repo de Ubuntu no siempre trae docker-compose-plugin).
# ---------------------------------------------------------
echo "==> Verificando dependencias..."

instalar_docker_oficial() {
    echo "==> Instalando Docker Engine + Compose plugin desde el repo oficial de Docker..."

    sudo apt update
    sudo apt install -y ca-certificates curl gnupg

    sudo install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
    fi

    ARCH="$(dpkg --print-architecture)"
    CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"

    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "==> Habilitando e iniciando el servicio Docker..."
    sudo systemctl enable --now docker

    # Permitir usar docker sin sudo al usuario real que invocó el script
    REAL_USER="${SUDO_USER:-$USER}"
    if [ "$REAL_USER" != "root" ]; then
        sudo usermod -aG docker "$REAL_USER" || true
        echo "==> Usuario '$REAL_USER' agregado al grupo 'docker'."
        echo "    (Deberás cerrar sesión y volver a entrar, o correr 'newgrp docker',"
        echo "     para usar docker sin sudo en el futuro.)"
    fi
}

if ! command -v docker &>/dev/null; then
    echo "==> Docker no está instalado. Instalando automáticamente..."
    instalar_docker_oficial
else
    echo "==> Docker ya está instalado: $(docker --version)"
fi

if docker compose version &>/dev/null; then
    DC="docker compose"
elif command -v docker-compose &>/dev/null; then
    DC="docker-compose"
else
    echo "==> El plugin 'docker compose' no está disponible. Instalándolo..."
    instalar_docker_oficial
    if docker compose version &>/dev/null; then
        DC="docker compose"
    else
        echo "ERROR: no se pudo instalar docker compose automáticamente."
        echo "Revisa manualmente: https://docs.docker.com/engine/install/ubuntu/"
        exit 1
    fi
fi
echo "==> Usando: $DC"

# Si el script se corrió con sudo, docker compose ya funciona en esta sesión.
# Si el usuario acaba de ser agregado al grupo docker, seguimos usando sudo
# dentro de este mismo script para no fallar por falta de permisos.
if [ "$(id -u)" -ne 0 ] && ! docker info &>/dev/null; then
    echo "==> Reintentando comandos docker con sudo en esta ejecución..."
    DC="sudo $DC"
    DOCKER_CMD="sudo docker"
else
    DOCKER_CMD="docker"
fi

# ---------------------------------------------------------
# 1) Crear estructura de carpetas
# ---------------------------------------------------------
echo "==> Creando estructura de carpetas..."
mkdir -p nginx app pgadmin scripts

# ---------------------------------------------------------
# 1.5) Detectar interfaz/IP de RED INTERNA (vs NAT)
# ---------------------------------------------------------
# Heurística: la interfaz con ruta por defecto (0.0.0.0/0) es casi
# siempre la NAT (sale a Internet). La(s) otra(s) interfaz(es) con IP
# son la(s) red(es) interna(s)/host-only. Se le pide confirmación
# al usuario para evitar publicar el servicio en la tarjeta equivocada.
echo "==> Detectando interfaces de red..."

NAT_IFACE="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
echo "    Interfaz con salida a Internet (NAT, se excluirá): ${NAT_IFACE:-desconocida}"

mapfile -t CANDIDATAS < <(ip -o -4 addr show up | awk -v nat="$NAT_IFACE" \
    '{iface=$2; ip=$4} iface!="lo" && iface!=nat {print iface" "ip}')

if [ "${#CANDIDATAS[@]}" -eq 0 ]; then
    echo "ERROR: no se detectó ninguna interfaz interna distinta de '$NAT_IFACE'."
    echo "Revisa 'ip a' y define manualmente NGINX_HOST_IP en .env luego de este script."
    INTERNAL_IFACE=""
    INTERNAL_IP=""
elif [ "${#CANDIDATAS[@]}" -eq 1 ]; then
    INTERNAL_IFACE="$(echo "${CANDIDATAS[0]}" | awk '{print $1}')"
    INTERNAL_IP="$(echo "${CANDIDATAS[0]}" | awk '{print $2}' | cut -d/ -f1)"
    echo "    Interfaz interna detectada: $INTERNAL_IFACE -> $INTERNAL_IP"
else
    echo "    Se detectó más de una interfaz candidata:"
    i=1
    for c in "${CANDIDATAS[@]}"; do
        echo "      [$i] $c"
        i=$((i+1))
    done
    read -rp "    Elige el número de la interfaz INTERNA a usar: " sel
    elegido="${CANDIDATAS[$((sel-1))]}"
    INTERNAL_IFACE="$(echo "$elegido" | awk '{print $1}')"
    INTERNAL_IP="$(echo "$elegido" | awk '{print $2}' | cut -d/ -f1)"
fi

if [ -n "${INTERNAL_IP:-}" ]; then
    read -rp "==> Confirmar: usar $INTERNAL_IFACE ($INTERNAL_IP) como red interna [Enter para aceptar, o escribe otra IP]: " override
    if [ -n "$override" ]; then
        INTERNAL_IP="$override"
    fi
fi
echo "==> IP interna a usar para publicar Nginx: ${INTERNAL_IP:-<pendiente, definir manualmente en .env>}"

# ---------------------------------------------------------
# 2) Archivo .env (variables sensibles)
# ---------------------------------------------------------
if [ -f .env ]; then
    echo "==> .env ya existe, no se sobreescribe."
else
    echo "==> Generando .env..."
    cat > .env <<'EOF'
# =========================================================
# Variables de entorno - Lab 11 (IaC con Docker Compose)
# NO subir este archivo a repositorios públicos (.gitignore)
# =========================================================

# --- Base de datos PostgreSQL ---
POSTGRES_DB=appdb
POSTGRES_USER=admin_db
POSTGRES_PASSWORD=CambiaEstaClaveSegura123!
POSTGRES_PORT=5432

# --- pgAdmin ---
PGADMIN_DEFAULT_EMAIL=admin@lab11.com
PGADMIN_DEFAULT_PASSWORD=OtraClaveSegura456!
PGADMIN_LISTEN_PORT=80
# Puerto en el que pgAdmin queda enlazado SOLO a 127.0.0.1 del host,
# alcanzable únicamente vía túnel SSH (nunca desde la red).
PGADMIN_HOST_PORT=8081

# --- Nginx (balanceador / frontend público) ---
NGINX_PUBLIC_PORT=80

# --- App interna (servidor de aplicaciones) ---
APP_INTERNAL_PORT=8081

# --- IP de la tarjeta de RED INTERNA donde se publicará Nginx ---
# (dejar vacío para publicar en todas las interfaces, no recomendado)
NGINX_HOST_IP=
EOF
fi

# Si detectamos la IP interna en el paso anterior, la escribimos/actualizamos en .env
if [ -n "${INTERNAL_IP:-}" ]; then
    if grep -q '^NGINX_HOST_IP=' .env; then
        sed -i "s/^NGINX_HOST_IP=.*/NGINX_HOST_IP=${INTERNAL_IP}/" .env
    else
        echo "NGINX_HOST_IP=${INTERNAL_IP}" >> .env
    fi
    echo "==> .env actualizado con NGINX_HOST_IP=${INTERNAL_IP}"
fi

# ---------------------------------------------------------
# 3) Configuración de Nginx (frontend público, oculta versión)
# ---------------------------------------------------------
echo "==> Generando nginx/nginx.conf..."
cat > nginx/nginx.conf <<'EOF'
user  nginx;
worker_processes  auto;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    # Ocultar la cabecera "Server" con la versión de nginx
    server_tokens off;

    upstream backend_app {
        server app_interna:8081;
    }

    server {
        listen 80;
        server_name _;

        proxy_hide_header X-Powered-By;
        add_header X-Frame-Options "SAMEORIGIN" always;

        location / {
            proxy_pass http://backend_app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /nginx-health {
            access_log off;
            return 200 "ok\n";
        }
    }
}
EOF

# ---------------------------------------------------------
# 4) Configuración del servidor de aplicaciones interno
# ---------------------------------------------------------
echo "==> Generando app/app.conf y app/index.html..."
cat > app/app.conf <<'EOF'
server {
    listen 8081;
    server_name _;

    location / {
        root   /usr/share/nginx/html;
        index  index.html;
    }
}
EOF

cat > app/index.html <<'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>Servidor de Aplicaciones Interno</title>
</head>
<body>
    <h1>Aplicación interna funcionando correctamente</h1>
    <p>Este contenedor no tiene puertos publicados al host. Solo es accesible vía Nginx.</p>
</body>
</html>
EOF

# ---------------------------------------------------------
# 5) docker-compose.yml (orquestación completa)
# ---------------------------------------------------------
echo "==> Generando docker-compose.yml..."
cat > docker-compose.yml <<'EOF'
services:

  # 1) Balanceador de carga / frontend público (único expuesto)
  nginx_lb:
    image: nginx:stable-alpine
    container_name: nginx_lb
    restart: always
    ports:
      # Publicado SOLO en la IP de la red interna (NGINX_HOST_IP en .env),
      # nunca en 0.0.0.0, para que no sea alcanzable desde la tarjeta NAT.
      - "${NGINX_HOST_IP}:${NGINX_PUBLIC_PORT}:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    networks:
      - red_publica
    depends_on:
      app_interna:
        condition: service_started
    healthcheck:
      test: ["CMD", "wget", "-q", "-O", "-", "http://localhost/nginx-health"]
      interval: 10s
      timeout: 5s
      retries: 5

  # 2) Servidor de aplicaciones interno (sin puertos al host)
  app_interna:
    image: nginx:stable-alpine
    container_name: app_interna
    restart: always
    expose:
      - "8081"
    volumes:
      - ./app/index.html:/usr/share/nginx/html/index.html:ro
      - ./app/app.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - red_publica
      - red_datos

  # 3) Clúster de base de datos PostgreSQL con persistencia
  db_postgres:
    image: postgres:16-alpine
    container_name: db_postgres
    restart: always
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    expose:
      - "5432"
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - red_datos
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  # 4) Panel administrativo pgAdmin (bloqueado de IP externa)
  servidor_pgadmin:
    image: dpage/pgadmin4:latest
    container_name: servidor_pgadmin
    restart: always
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_DEFAULT_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_DEFAULT_PASSWORD}
      PGADMIN_LISTEN_PORT: ${PGADMIN_LISTEN_PORT}
    # Enlazado SOLO a 127.0.0.1 del host (nunca a la red pública/interna).
    # El único camino de acceso es un túnel SSH hacia este loopback.
    ports:
      - "127.0.0.1:${PGADMIN_HOST_PORT}:${PGADMIN_LISTEN_PORT}"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    networks:
      - red_datos
    depends_on:
      db_postgres:
        condition: service_healthy

networks:
  red_publica:
    driver: bridge
  red_datos:
    driver: bridge
    internal: true

volumes:
  db_data:
  pgadmin_data:
EOF

# ---------------------------------------------------------
# 6) Firewall del host (UFW): cerrar puertos de BD/pgAdmin
# ---------------------------------------------------------
echo "==> Generando scripts/configurar_firewall.sh..."
cat > scripts/configurar_firewall.sh <<EOF
#!/usr/bin/env bash
# Configura UFW para exponer Nginx (80) SOLO en la interfaz de red
# interna detectada (${INTERNAL_IFACE:-<define-manualmente>}), y
# garantiza que PostgreSQL/pgAdmin no sean alcanzables desde ninguna
# interfaz (ni siquiera la interna). pgAdmin solo vía túnel SSH.
set -euo pipefail

IFACE_INTERNA="${INTERNAL_IFACE:-CAMBIAR_ESTA_INTERFAZ}"

if ! command -v ufw &>/dev/null; then
    echo "Instalando ufw..."
    sudo apt update && sudo apt install -y ufw
fi

echo "==> Política por defecto: denegar entrante, permitir saliente..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "==> Permitiendo SSH (22) en cualquier interfaz (para no perder acceso remoto)..."
sudo ufw allow 22/tcp

echo "==> Permitiendo Nginx (80) SOLO en la interfaz interna: \$IFACE_INTERNA ..."
sudo ufw allow in on "\$IFACE_INTERNA" to any port 80 proto tcp

echo "==> Denegando explícitamente puertos internos en TODAS las interfaces..."
sudo ufw deny 5432/tcp   # PostgreSQL
sudo ufw deny 8081/tcp   # App interna
# pgAdmin no publica puerto al host (usa 'expose', no 'ports'), así que
# ni siquiera escucha ahí; el deny es defensa adicional por si se
# modificara el compose en el futuro.

echo "==> Habilitando UFW..."
sudo ufw --force enable

echo "==> Estado actual del firewall:"
sudo ufw status verbose
EOF
chmod +x scripts/configurar_firewall.sh

# ---------------------------------------------------------
# 7) Script de pruebas de aceptación (11.1 a 11.4)
# ---------------------------------------------------------
echo "==> Generando scripts/pruebas_aceptacion.sh..."
cat > scripts/pruebas_aceptacion.sh <<'EOF'
#!/usr/bin/env bash
# Ejecuta las pruebas de aceptación 11.1 - 11.4 descritas en la práctica.
# Debe ejecutarse en el servidor Ubuntu (host), NO dentro de un contenedor.
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if docker compose version &>/dev/null; then DC="docker compose"; else DC="docker-compose"; fi

SERVER_IP="${1:-127.0.0.1}"

echo "============================================================"
echo "PRUEBA 11.1 - Aislamiento de red (BD y pgAdmin no accesibles)"
echo "============================================================"
echo "--> curl a PostgreSQL (5432)..."
timeout 5 curl -sv "http://${SERVER_IP}:5432" 2>&1 | tail -5 || echo "OK: conexión rechazada / timeout (esperado)"
echo ""
echo "--> curl a pgAdmin (asumiendo puerto 80 interno, no publicado)..."
timeout 5 curl -sv "http://${SERVER_IP}:81" 2>&1 | tail -5 || echo "OK: conexión rechazada / timeout (esperado)"

echo ""
echo "============================================================"
echo "PRUEBA 11.2 - Resolución interna DNS (nginx -> db_postgres)"
echo "============================================================"
docker exec nginx_lb sh -c "ping -c 3 db_postgres" || echo "NOTA: 'ping' puede no estar instalado en la imagen alpine; probando con getent..."
docker exec nginx_lb sh -c "getent hosts db_postgres" || true

echo ""
echo "============================================================"
echo "PRUEBA 11.3 - Túnel SSH cifrado hacia pgAdmin"
echo "============================================================"
echo "Ejecuta manualmente desde tu máquina LOCAL (no en el servidor):"
echo "  ssh -L 8080:127.0.0.1:8081 usuario@${SERVER_IP}"
echo "Luego abre en tu navegador local: http://localhost:8080"

echo ""
echo "============================================================"
echo "PRUEBA 11.4 - Persistencia y healthcheck"
echo "============================================================"
echo "--> Bajando el stack (down)..."
$DC down
echo "--> Levantando el stack de nuevo (up -d)..."
$DC up -d
echo "--> Esperando healthcheck de db_postgres..."
for i in $(seq 1 15); do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' db_postgres 2>/dev/null || echo "unknown")
    echo "   estado db_postgres: $STATUS"
    [ "$STATUS" = "healthy" ] && break
    sleep 3
done
echo "--> Estado final de contenedores:"
$DC ps
EOF
chmod +x scripts/pruebas_aceptacion.sh

# ---------------------------------------------------------
# 7.5) Reset opcional de volúmenes (útil si un intento previo dejó
#      el volumen de Postgres con credenciales/datos inconsistentes,
#      causando que el contenedor quede "unhealthy" al reiniciar)
# ---------------------------------------------------------
if [ "${1:-}" = "--reset" ]; then
    echo "==> Flag --reset detectado: bajando stack y borrando volúmenes..."
    $DC down -v
fi

# ---------------------------------------------------------
# 8) Levantar el stack
# ---------------------------------------------------------
echo "==> Levantando el stack con $DC up -d ..."
$DC up -d

echo ""
echo "==> Estado de los contenedores:"
$DC ps

echo ""
echo "==> Si db_postgres aparece 'unhealthy' o 'Restarting', revisa el log con:"
echo "      $DOCKER_CMD logs db_postgres --tail 50"
echo "    Si el volumen quedó con credenciales de un intento previo distinto,"
echo "    vuelve a correr este script así para empezar limpio (BORRA los datos):"
echo "      sudo bash ./deploy_lab11.sh --reset"

echo ""
echo "============================================================"
echo " Despliegue completado."
echo " - Nginx publicado SOLO en la red interna: ${INTERNAL_IP:-<no detectada, revisa .env>}:80"
echo " - Interfaz interna usada: ${INTERNAL_IFACE:-<no detectada>}"
echo " - Interfaz NAT excluida: ${NAT_IFACE:-desconocida}"
echo " - Para asegurar el firewall del host, ejecuta:"
echo "     ./scripts/configurar_firewall.sh"
echo " - Para correr las pruebas de aceptación (11.1-11.4):"
echo "     ./scripts/pruebas_aceptacion.sh ${INTERNAL_IP:-<IP_INTERNA>}"
echo " - Para administrar la BD vía pgAdmin, desde otra máquina EN LA RED INTERNA:"
echo "     ssh -L 8080:127.0.0.1:8081 usuario@${INTERNAL_IP:-<IP_INTERNA>}"
echo "     luego abre http://localhost:8080 en tu navegador"
echo "============================================================"
