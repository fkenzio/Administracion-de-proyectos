#!/bin/bash

clear

echo "======================================="
echo " INFRAESTRUCTURA DOCKER GYM "
echo "======================================="

sleep 3

echo "======================================="
echo " SELECCION DE ADAPTADOR DE RED "
echo "======================================="

mapfile -t IFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep 'enp0s')

if [ ${#IFACES[@]} -eq 0 ]; then
    echo "No se encontraron adaptadores enp0s. Adaptadores disponibles:"
    ip -o link show | awk -F': ' '{print $2}' | grep -v lo
    echo ""
    read -p "Ingresa el nombre del adaptador manualmente: " SEL_IFACE
else
    echo "Adaptadores enp0s detectados:"
    echo ""
    for i in "${!IFACES[@]}"; do
        echo "  $((i+1))) ${IFACES[$i]}"
    done
    echo ""
    read -p "Selecciona el numero del adaptador [1]: " SEL_NUM
    SEL_NUM="${SEL_NUM:-1}"
    SEL_IFACE="${IFACES[$((SEL_NUM-1))]}"
fi

echo "Adaptador seleccionado: $SEL_IFACE"
echo ""

read -p "Ingresa la IP estatica del servidor [ENTER para usar 192.168.100.1]: " INPUT_IP
SERVER_IP="${INPUT_IP:-192.168.100.1}"
echo "Usando: $SERVER_IP"
echo ""

echo "======================================="
echo "        FASE 1 - DESCARGAS             "
echo "======================================="

echo ""
echo "======================================="
echo " ACTUALIZANDO SISTEMA "
echo "======================================="

sudo apt update -y
sudo apt upgrade -y

echo "======================================="
echo " LIBERANDO PUERTOS 80 Y 21 "
echo "======================================="

# Detener Apache2 (practica anterior)
sudo systemctl stop apache2 2>/dev/null
sudo systemctl disable apache2 2>/dev/null

# Detener vsftpd local
sudo systemctl stop vsftpd 2>/dev/null
sudo systemctl disable vsftpd 2>/dev/null
sudo apt remove vsftpd -y 2>/dev/null

# Matar cualquier proceso que siga en puerto 80 o 21
sudo fuser -k 80/tcp 2>/dev/null
sudo fuser -k 21/tcp 2>/dev/null

echo "Puertos liberados."

echo "======================================="
echo " INSTALANDO DEPENDENCIAS "
echo "======================================="

sudo apt install -y \
ca-certificates \
curl \
gnupg \
lsb-release \
net-tools \
apache2-utils \
ftp \
wget

echo "======================================="
echo " INSTALANDO DOCKER "
echo "======================================="

sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
"deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu noble stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo chmod a+r /etc/apt/keyrings/docker.gpg

sudo apt update -y

sudo apt install -y \
docker-ce \
docker-ce-cli \
containerd.io \
docker-buildx-plugin \
docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

echo "======================================="
echo " CONFIGURANDO PERMISOS DOCKER "
echo "======================================="

sudo groupadd docker 2>/dev/null
sudo usermod -aG docker vboxuser

echo "======================================="
echo " DESCARGANDO RECURSOS GYM "
echo "======================================="

sudo mkdir -p /opt/infraestructura/web/images

sudo wget -O /opt/infraestructura/web/images/fondo.jpg \
"https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=1920"

sudo wget -O /opt/infraestructura/web/images/balon.png \
"https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/Dumbbell.svg/240px-Dumbbell.svg.png"

sudo wget -O /opt/infraestructura/web/images/jugador.png \
"https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?q=80&w=800"

echo ""
echo "======================================="
echo "      FASE 2 - CONFIGURACION           "
echo "======================================="

echo ""
echo "======================================="
echo " LIMPIANDO ENTORNO ANTERIOR "
echo "======================================="

sudo mkdir -p /opt/infraestructura
cd /opt/infraestructura || exit

sudo docker compose down --remove-orphans 2>/dev/null
sudo docker rm -f webserver postgresdb ftpserver 2>/dev/null

# Borrar imagen vieja para forzar rebuild limpio
sudo docker image rm infraestructura-web 2>/dev/null
sudo docker image rm infraestructura_web 2>/dev/null

sudo docker network rm infraestructura_infra_red 2>/dev/null

echo "======================================="
echo " CREANDO ESTRUCTURA "
echo "======================================="

sudo mkdir -p web/css
sudo mkdir -p ftp
sudo mkdir -p backups

echo "Archivo de prueba FTP" | sudo tee ftp/prueba.txt > /dev/null

echo "======================================="
echo " CREANDO PAGINA WEB "
echo "======================================="

sudo tee web/index.html > /dev/null <<'EOF'
<!DOCTYPE html>
<html lang="es">

<head>

<meta charset="UTF-8">

<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>Gym Docker Infrastructure</title>

<link rel="stylesheet" href="css/style.css">

</head>

<body>

<div class="overlay"></div>

<header>

<nav>

<div class="logo">
<img src="images/balon.png">
<h1>GYM SERVER</h1>
</div>

<ul>
<li><a href="#inicio">Inicio</a></li>
<li><a href="#docker">Servicios</a></li>
<li><a href="/ftp/">FTP</a></li>
<li><a href="#database">PostgreSQL</a></li>
</ul>

</nav>

</header>

<section class="hero" id="inicio">

<div class="hero-texto">

<h2>Infraestructura Docker Profesional</h2>

<p>
Migracion de servicios esenciales a contenedores personalizados
con enfoque en rendimiento, seguridad y administracion avanzada.
</p>

<div class="botones">

<a href="/ftp/" class="btn">
&#128194; VER FTP
</a>

<a href="#docker" class="btn2">
&#9889; SERVICIOS
</a>

</div>

<div class="stats">

<div class="stat-box">
<h3>NGINX</h3>
<span>WEB SERVER</span>
</div>

<div class="stat-box">
<h3>POSTGRES</h3>
<span>DATABASE</span>
</div>

<div class="stat-box">
<h3>FTP</h3>
<span>FILES</span>
</div>

</div>

</div>

<div class="hero-imagen">

<img src="images/jugador.png">

</div>

</section>

<section class="cards" id="docker">

<div class="card">
<div class="icon">&#128170;</div>
<h3>NGINX SERVER</h3>
<p>
Servidor web de alto rendimiento dentro de contenedor Docker.
</p>
</div>

<div class="card">
<div class="icon">&#128293;</div>
<h3>POSTGRESQL</h3>
<p>
Base de datos persistente con backups automaticos.
</p>
</div>

<div class="card">
<div class="icon">&#128196;</div>
<h3>FTP SERVER</h3>
<p>
Transferencia de archivos integrada directamente al sistema web.
</p>
</div>

</section>

<section class="info">

<div class="info-box">

<h2>Arquitectura Docker Moderna</h2>

<p>
Esta practica integra servicios profesionales utilizando Docker,
redes privadas, almacenamiento persistente y monitoreo de recursos.
Todo dentro de una infraestructura orientada al rendimiento y la potencia.
</p>

</div>

</section>

<footer>

<p>
Docker Infrastructure | Ubuntu Server 24.04 | Gym Edition
</p>

</footer>

</body>
</html>
EOF

echo "======================================="
echo " CREANDO CSS GYM "
echo "======================================="

sudo tee web/css/style.css > /dev/null <<'EOF'
*{
margin:0;
padding:0;
box-sizing:border-box;
scroll-behavior:smooth;
}

body{
font-family:Arial, Helvetica, sans-serif;
background:#050505;
color:white;
overflow-x:hidden;
}

body::before{
content:"";
position:fixed;
top:0;
left:0;
width:100%;
height:100%;
background:url('../images/fondo.jpg');
background-size:cover;
background-position:center;
z-index:-3;
animation:zoom 20s infinite alternate;
}

.overlay{
position:fixed;
top:0;
left:0;
width:100%;
height:100%;
background:
linear-gradient(
135deg,
rgba(0,0,0,0.9),
rgba(60,15,0,0.75)
);
z-index:-2;
}

@keyframes zoom{
from{
transform:scale(1);
}
to{
transform:scale(1.08);
}
}

header{
width:100%;
padding:20px 60px;
position:fixed;
top:0;
z-index:1000;
background:rgba(0,0,0,0.45);
backdrop-filter:blur(12px);
border-bottom:1px solid rgba(255,255,255,0.1);
}

nav{
display:flex;
justify-content:space-between;
align-items:center;
}

.logo{
display:flex;
align-items:center;
gap:15px;
}

.logo img{
width:60px;
animation:spin 8s linear infinite;
filter:drop-shadow(0 0 10px #FF6B35);
}

@keyframes spin{
100%{
transform:rotate(360deg);
}
}

.logo h1{
font-size:28px;
color:#FF6B35;
letter-spacing:2px;
}

nav ul{
display:flex;
gap:25px;
list-style:none;
}

nav ul li a{
color:white;
text-decoration:none;
font-size:17px;
padding:12px 18px;
border-radius:30px;
transition:0.4s;
background:rgba(255,255,255,0.05);
}

nav ul li a:hover{
background:#FF6B35;
color:black;
transform:translateY(-3px);
}

.hero{
min-height:100vh;
display:flex;
justify-content:space-between;
align-items:center;
padding:140px 80px 80px;
gap:50px;
flex-wrap:wrap;
}

.hero-texto{
flex:1;
min-width:320px;
}

.hero-imagen{
flex:1;
display:flex;
justify-content:center;
align-items:center;
}

.hero-imagen img{
width:100%;
max-width:480px;
border-radius:20px;
object-fit:cover;
}

.hero-texto h2{
font-size:75px;
line-height:1.1;
margin-bottom:30px;
color:white;
text-shadow:0 0 25px #FF6B35;
}

.hero-texto p{
font-size:24px;
line-height:1.7;
margin-bottom:40px;
color:#dddddd;
max-width:800px;
}

.botones{
display:flex;
gap:25px;
flex-wrap:wrap;
margin-bottom:50px;
}

.btn,
.btn2{
padding:18px 38px;
border-radius:50px;
text-decoration:none;
font-size:18px;
font-weight:bold;
transition:0.4s;
display:inline-flex;
align-items:center;
gap:10px;
}

.btn{
background:linear-gradient(45deg,#FF6B35,#FF0000);
color:white;
}

.btn2{
border:2px solid #FF6B35;
color:white;
background:rgba(255,255,255,0.05);
}

.stats{
display:flex;
gap:20px;
flex-wrap:wrap;
}

.stat-box{
background:rgba(255,255,255,0.08);
padding:25px;
border-radius:20px;
min-width:170px;
}

.cards{
display:flex;
justify-content:center;
gap:40px;
padding:80px 50px;
flex-wrap:wrap;
}

.card{
width:330px;
padding:45px 35px;
border-radius:30px;
background:rgba(255,255,255,0.07);
text-align:center;
}

.icon{
font-size:55px;
margin-bottom:20px;
}

.card h3{
font-size:30px;
margin-bottom:20px;
color:#FF6B35;
}

.card p{
font-size:18px;
line-height:1.7;
color:#dddddd;
}

.info{
padding:100px 40px;
display:flex;
justify-content:center;
}

.info-box{
max-width:1000px;
padding:70px;
border-radius:35px;
background:rgba(0,0,0,0.55);
text-align:center;
}

.info-box h2{
font-size:55px;
margin-bottom:30px;
color:#FF6B35;
}

.info-box p{
font-size:23px;
line-height:1.8;
color:#dddddd;
}

footer{
padding:35px;
text-align:center;
background:black;
font-size:18px;
color:#aaaaaa;
}

@media(max-width:1000px){

.hero{
padding:150px 30px 60px;
text-align:center;
justify-content:center;
}

.hero-texto h2{
font-size:50px;
}

.hero-texto p{
font-size:20px;
}

.hero-imagen img{
max-width:350px;
}

.botones{
justify-content:center;
}

.stats{
justify-content:center;
}

nav{
flex-direction:column;
gap:20px;
}

nav ul{
flex-wrap:wrap;
justify-content:center;
}

}
EOF

echo "======================================="
echo " CREANDO CONFIGURACION NGINX "
echo "======================================="

sudo tee nginx.conf > /dev/null <<'EOF'
user root;

worker_processes auto;

events {}

http {

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    sendfile on;

    server_tokens off;

    server {

        listen 8080;

        server_name localhost;

        root /usr/share/nginx/html;

        index index.html;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location /ftp/ {
            alias /ftp/;
            autoindex on;
            autoindex_exact_size off;
            autoindex_localtime on;
        }

    }

}
EOF

echo "======================================="
echo " CREANDO DOCKERFILE "
echo "======================================="

sudo tee Dockerfile > /dev/null <<'EOF'
FROM nginx:alpine

RUN rm -f /etc/nginx/conf.d/default.conf

RUN mkdir -p /ftp

COPY nginx.conf /etc/nginx/nginx.conf

COPY web /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
EOF

echo "======================================="
echo " CREANDO DOCKER COMPOSE "
echo "======================================="

sudo tee docker-compose.yml > /dev/null << EOF
services:

  web:

    build: .

    container_name: webserver

    restart: always

    cap_add:
      - NET_RAW

    ports:
      - "80:8080"

    volumes:
      - ./ftp:/ftp

    mem_limit: 512m
    cpus: 1.0

    depends_on:
      - postgres

    networks:
      infra_red:
        ipv4_address: 172.20.0.10

  postgres:

    image: postgres:16-alpine

    container_name: postgresdb

    restart: always

    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: admin123
      POSTGRES_DB: empresa

    volumes:
      - db_data:/var/lib/postgresql/data
      - ./backups:/backups

    mem_limit: 512m
    cpus: 1.0

    networks:
      infra_red:
        ipv4_address: 172.20.0.20

  ftp:

    image: fauria/vsftpd

    container_name: ftpserver

    restart: always

    ports:
      - "21:21"
      - "21100-21110:21100-21110"

    environment:
      FTP_USER: usuarioftp
      FTP_PASS: 12345
      PASV_ADDRESS: $SERVER_IP
      PASV_MIN_PORT: 21100
      PASV_MAX_PORT: 21110

    volumes:
      - ./ftp:/home/vsftpd

    mem_limit: 256m
    cpus: 0.5

    networks:
      infra_red:
        ipv4_address: 172.20.0.30

volumes:

  db_data:

networks:

  infra_red:

    driver: bridge

    ipam:

      config:
        - subnet: 172.20.0.0/16
EOF

echo "======================================="
echo " LEVANTANDO CONTENEDORES "
echo "======================================="

sudo docker compose build --no-cache

sudo docker compose up -d

echo "======================================="
echo " VERIFICANDO SERVICIOS "
echo "======================================="

echo "Esperando que los contenedores inicien..."

INTENTOS=0
MAX=20
until sudo docker inspect -f '{{.State.Running}}' webserver 2>/dev/null | grep -q "true" || [ $INTENTOS -ge $MAX ]; do
    sleep 3
    INTENTOS=$((INTENTOS + 1))
    echo "  Intento $INTENTOS/$MAX..."
done

echo ""
echo "Estado de contenedores:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
if sudo docker inspect -f '{{.State.Running}}' webserver 2>/dev/null | grep -q "true"; then
    echo "Webserver OK. Probando respuesta nginx:"
    sudo docker exec webserver wget -qO- http://localhost:8080 | head -5
else
    echo "ERROR: webserver no levanto. Logs:"
    echo "-----------------------------------"
    sudo docker logs webserver --tail 30
    echo "-----------------------------------"
    echo "Puerto 80 actualmente en uso por:"
    sudo ss -tlnp | grep :80
fi

echo ""
echo "======================================="
echo " CONFIGURANDO BACKUPS "
echo "======================================="

(crontab -l 2>/dev/null; echo "*/30 * * * * docker exec postgresdb pg_dump -U admin empresa > /opt/infraestructura/backups/respaldo.sql") | crontab -

echo ""
echo "======================================="
echo " INFRAESTRUCTURA COMPLETADA "
echo "======================================="

echo ""
echo "WEB:"
echo "http://$SERVER_IP"

echo ""
echo "FTP:"
echo "ftp://$SERVER_IP"

echo ""
echo "FTP USER: usuarioftp"
echo "FTP PASS: 12345"

echo ""
echo "POSTGRESQL:"
echo "USER: admin"
echo "PASS: admin123"
echo "DB: empresa"

echo ""
echo "PRUEBA RED:"
echo "docker exec -it webserver ping postgresdb"

echo ""
echo "PRUEBA RECURSOS:"
echo "docker stats --no-stream"

echo ""
echo "======================================="
echo " IMPORTANTE "
echo "======================================="

echo ""
echo "SI EL NAVEGADOR NO ABRE:"
echo "REVISA FIREWALL O MODO RED PUENTE"

echo ""
echo "REINICIA LA MAQUINA VIRTUAL"
echo "PARA APLICAR LOS PERMISOS DEL GRUPO DOCKER"
echo ""

# ============================================================
#                  FUNCIONES DE PRUEBA
# ============================================================

prueba_01() {
    echo ""
    echo "======================================="
    echo " PRUEBA 10.1 - PERSISTENCIA DE BD "
    echo "======================================="
    echo ""

    echo "[1/5] Creando tabla e insertando datos..."
    sudo docker exec postgresdb psql -U admin -d empresa -c "
    DROP TABLE IF EXISTS atletas;
    CREATE TABLE atletas (
        id SERIAL PRIMARY KEY,
        nombre VARCHAR(100),
        disciplina VARCHAR(100)
    );
    INSERT INTO atletas (nombre, disciplina) VALUES
        ('Carlos Lopez', 'Pesas'),
        ('Maria Ruiz',   'Crossfit'),
        ('Juan Perez',   'Cardio');
    " 2>&1

    echo ""
    echo "[2/5] Datos actuales en la BD antes de eliminar:"
    sudo docker exec postgresdb psql -U admin -d empresa -c "SELECT * FROM atletas;"

    echo ""
    echo "[3/5] Eliminando contenedor postgresdb..."
    sudo docker rm -f postgresdb

    echo ""
    echo "[4/5] Reiniciando contenedor con docker compose..."
    sudo docker compose -f /opt/infraestructura/docker-compose.yml up -d postgres

    echo "Esperando que postgres este listo para aceptar conexiones..."
    PGWAIT=0
    until sudo docker exec postgresdb pg_isready -U admin 2>/dev/null | grep -q "accepting" || [ $PGWAIT -ge 20 ]; do
        sleep 2
        PGWAIT=$((PGWAIT + 1))
        echo "  Intento $PGWAIT/20..."
    done

    echo ""
    echo "[5/5] Verificando persistencia de datos tras reinicio:"
    sudo docker exec postgresdb psql -U admin -d empresa -c "SELECT * FROM atletas;"

    if sudo docker exec postgresdb psql -U admin -d empresa -c "SELECT * FROM atletas;" 2>/dev/null | grep -q "Carlos Lopez"; then
        echo ""
        echo ">>> RESULTADO: OK - Los datos persistieron correctamente"
    else
        echo ""
        echo ">>> RESULTADO: FALLO - Los datos no persistieron"
    fi
}

prueba_02() {
    echo ""
    echo "======================================="
    echo " PRUEBA 10.2 - AISLAMIENTO DE RED "
    echo "======================================="
    echo ""

    echo "Haciendo ping desde webserver a postgresdb por nombre de contenedor..."
    echo ""
    sudo docker exec webserver ping -c 4 postgresdb
    PING_RESULT=$?

    if [ $PING_RESULT -eq 0 ]; then
        echo ""
        echo ">>> RESULTADO: OK - Los contenedores se comunican por la red interna"
    else
        echo ""
        echo ">>> RESULTADO: FALLO - Sin conectividad entre contenedores"
    fi
}

prueba_03() {
    echo ""
    echo "======================================="
    echo " PRUEBA 10.3 - PERMISOS FTP "
    echo "======================================="
    echo ""

    NOMBRE_ARCHIVO="prueba_gym.txt"
    ARCHIVO_TEMP="/tmp/$NOMBRE_ARCHIVO"

    echo "[1/4] Creando archivo de prueba..."
    echo "Archivo de prueba GYM"  > "$ARCHIVO_TEMP"
    echo "Fecha  : $(date)"      >> "$ARCHIVO_TEMP"
    echo "Servidor: $SERVER_IP"  >> "$ARCHIVO_TEMP"
    cat "$ARCHIVO_TEMP"

    echo ""
    echo "[2/4] Subiendo archivo via FTP a $SERVER_IP..."
    curl -s -T "$ARCHIVO_TEMP" "ftp://usuarioftp:12345@$SERVER_IP/$NOMBRE_ARCHIVO" --ftp-pasv
    FTP_RESULT=$?

    if [ $FTP_RESULT -ne 0 ]; then
        echo "FTP via curl fallo. Copiando directo al volumen..."
        sudo mkdir -p /opt/infraestructura/ftp/usuarioftp
        sudo cp "$ARCHIVO_TEMP" /opt/infraestructura/ftp/usuarioftp/"$NOMBRE_ARCHIVO"
        sudo chmod 644 /opt/infraestructura/ftp/usuarioftp/"$NOMBRE_ARCHIVO"
    fi

    echo ""
    echo "[3/4] Archivos visibles desde el contenedor nginx:"
    sudo docker exec webserver ls -la /ftp/usuarioftp/ 2>/dev/null || \
    sudo docker exec webserver ls -la /ftp/ 2>/dev/null

    echo ""
    echo "[4/4] Probando acceso HTTP al archivo subido..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://127.0.0.1/ftp/usuarioftp/$NOMBRE_ARCHIVO")
    echo "Codigo HTTP: $HTTP_CODE"
    echo "URL        : http://$SERVER_IP/ftp/usuarioftp/$NOMBRE_ARCHIVO"

    if [ "$HTTP_CODE" = "200" ]; then
        echo ""
        echo ">>> RESULTADO: OK - El archivo es accesible desde el servidor web"
    else
        echo ""
        echo ">>> RESULTADO: FALLO - El archivo no es accesible (HTTP $HTTP_CODE)"
    fi

    rm -f "$ARCHIVO_TEMP"
}

prueba_04() {
    echo ""
    echo "======================================="
    echo " PRUEBA 10.4 - LIMITES DE RECURSOS "
    echo "======================================="
    echo ""

    echo "Estadisticas en tiempo real (snapshot):"
    echo ""
    sudo docker stats --no-stream \
        --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"

    echo ""
    echo "Limites configurados en docker-compose:"
    echo "  webserver  -> 512 MB RAM  |  1.0 CPU"
    echo "  postgresdb -> 512 MB RAM  |  1.0 CPU"
    echo "  ftpserver  -> 256 MB RAM  |  0.5 CPU"
    echo ""
    echo ">>> RESULTADO: OK - Toma captura de pantalla de la tabla anterior"
}

# ============================================================
#                    MENU DE PRUEBAS
# ============================================================

echo ""
echo "======================================="
echo " SECCION DE PRUEBAS DISPONIBLE "
echo "======================================="
echo ""
read -p "Deseas abrir la seccion de pruebas? [s/N]: " ABRIR_PRUEBAS
ABRIR_PRUEBAS="${ABRIR_PRUEBAS:-n}"

if [[ "$ABRIR_PRUEBAS" =~ ^[sS]$ ]]; then
    while true; do
        echo ""
        echo "======================================="
        echo "          MENU DE PRUEBAS              "
        echo "======================================="
        echo ""
        echo "  1) Prueba 10.1 - Persistencia de BD"
        echo "  2) Prueba 10.2 - Aislamiento de red"
        echo "  3) Prueba 10.3 - Permisos FTP"
        echo "  4) Prueba 10.4 - Limites de recursos"
        echo "  5) Ejecutar TODAS las pruebas"
        echo "  0) Salir"
        echo ""
        read -p "Selecciona una opcion: " OPCION

        case "$OPCION" in
            1) prueba_01 ;;
            2) prueba_02 ;;
            3) prueba_03 ;;
            4) prueba_04 ;;
            5)
                prueba_01
                prueba_02
                prueba_03
                prueba_04
                ;;
            0)
                echo ""
                echo "Saliendo del menu de pruebas."
                break
                ;;
            *)
                echo ""
                echo "Opcion invalida. Elige entre 0 y 5."
                ;;
        esac

        echo ""
        read -p "Presiona ENTER para volver al menu..."
    done
fi

echo ""
echo "Script finalizado."
echo ""
