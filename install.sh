#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# --- 0. CHECAGEM DE ROOT E SISTEMA ---
# Checar Root logo de cara
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31m[ERRO] Execute como root (sudo su).\033[0m"
    exit 1
fi

# Identificar SO
. /etc/os-release
OS=$ID
VER=$VERSION_ID

# === OTIMIZAÇÃO DE REPOSITÓRIOS PARA O BRASIL ANTES DE TUDO ===
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    if [ "$OS" == "ubuntu" ]; then
        if [ -f /etc/apt/sources.list ]; then
            sed -i -E 's/http:\/\/([a-z]{2}\.)?archive\.ubuntu\.com/http:\/\/br.archive.ubuntu.com/g' /etc/apt/sources.list
        fi
        if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
            sed -i -E 's/http:\/\/([a-z]{2}\.)?archive\.ubuntu\.com/http:\/\/br.archive.ubuntu.com/g' /etc/apt/sources.list.d/ubuntu.sources
        fi
    elif [ "$OS" == "debian" ]; then
        if [ -f /etc/apt/sources.list ]; then
            sed -i -E 's/deb\.debian\.org/ftp.br.debian.org/g' /etc/apt/sources.list
        fi
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then
            sed -i -E 's/deb\.debian\.org/ftp.br.debian.org/g' /etc/apt/sources.list.d/debian.sources
        fi
    fi
fi

# --- CORES ---
CYAN='\033[0;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

clear
echo -e "${CYAN}"
echo "    ___       __            __  ________                __ "
echo "   / _ | ___ / /________ _/ / / ___/ /___  __ _____   / / "
echo "  / __ |(_-</ __/ __/ _ \`/ / / /__/ / __ \/ // / _ \ /_/  "
echo " /_/ |_/___/\__/_/  \_,_/_/  \___/_/\___/\_,_/_//_/ (_)   "
echo -e "${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "${YELLOW} Instalador Automático - Astral Cloud${NC}"
echo -e "${GREEN}======================================================${NC}"
echo ""

echo -e "${GREEN}[INFO] Sistema identificado: $PRETTY_NAME...${NC}"
echo -e "${GREEN}[INFO] Repositórios otimizados para o Brasil!${NC}"
echo ""

# --- 1. COLETA DE DADOS INICIAIS ---
echo -e "${CYAN}Precisamos de alguns dados para configurar tudo automaticamente:${NC}"
echo -e "${YELLOW}ATENÇÃO: Os domínios já devem estar apontados (DNS) para o IP desta máquina!${NC}"
echo ""

read -p "Qual o domínio do PAINEL? (ex: painel.dominio.com.br): " FQDN < /dev/tty
read -p "Deseja instalar SSL (HTTPS) no PAINEL? [y/n]: " USE_SSL < /dev/tty

read -p "Qual o domínio do NODE/WINGS? (ex: node.dominio.com.br): " NODE_FQDN < /dev/tty
read -p "Deseja instalar SSL (HTTPS) no NODE? [y/n]: " NODE_USE_SSL < /dev/tty

read -p "Qual o seu e-mail de administrador?: " ADMIN_EMAIL < /dev/tty
echo -e "${YELLOW}(A senha deve ter no mínimo 8 caracteres, com letras e números)${NC}"
read -s -p "Crie uma senha para o Banco de Dados e para o Admin: " PASSWORD < /dev/tty
echo ""
echo ""

if [[ "$USE_SSL" =~ ^[Yy]$ ]]; then
    PROTOCOL="https"
else
    PROTOCOL="http"
fi

# --- TRATAMENTO SELINUX (ROCKY/ALMALINUX/RHEL) ---
if [[ "$OS" =~ ^(rocky|almalinux|rhel)$ ]]; then
    echo -e "${YELLOW}[INFO] Configurando SELinux para Permissive...${NC}"
    setenforce 0 > /dev/null 2>&1
    sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config > /dev/null 2>&1
fi

# --- 2. INSTALANDO DEPENDÊNCIAS ---
echo -e "${YELLOW}[1/8] Configurando repositórios e instalando pacotes base...${NC}"

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    
    apt-get update -y -qq
    apt-get install -y -qq curl apt-transport-https ca-certificates gnupg tar unzip git redis-server mariadb-server nginx certbot python3-certbot-nginx > /dev/null
    
    if [ "$OS" == "ubuntu" ]; then
        apt-get install -y -qq software-properties-common > /dev/null
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
    else
        curl -sSL https://packages.sury.org/php/README.txt | bash -x > /dev/null 2>&1
    fi
    apt-get update -y -qq
    apt-get install -y -qq php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl} > /dev/null
    
    WEB_USER="www-data"
    PHP_SOCKET="unix:/run/php/php8.3-fpm.sock"
    NGINX_CONF_DIR="/etc/nginx/sites-available"

elif [[ "$OS" =~ ^(rocky|almalinux|rhel)$ ]]; then
    dnf install -y -q epel-release curl tar unzip git redis mariadb-server nginx certbot python3-certbot-nginx > /dev/null
    dnf install -y -q https://rpms.remirepo.net/enterprise/remi-release-${VER%%.*}.rpm > /dev/null
    dnf module reset php -y -q && dnf module enable php:remi-8.3 -y -q > /dev/null
    dnf install -y -q php php-{common,cli,gd,mysqlnd,mbstring,bcmath,xml,fpm,curl,zip,intl} > /dev/null
    systemctl enable --now mariadb redis php-fpm nginx > /dev/null
    
    WEB_USER="nginx"
    PHP_SOCKET="unix:/run/php-fpm/www.sock"
    NGINX_CONF_DIR="/etc/nginx/conf.d"
fi

# Instalar Composer e Docker
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer > /dev/null 2>&1
curl -sSL https://get.docker.com/ | CHANNEL=stable bash > /dev/null 2>&1
systemctl enable --now docker > /dev/null 2>&1

# --- 3. CONFIGURANDO FIREWALL & SWAP ---
echo -e "${YELLOW}[2/8] Configurando Firewall e Swap...${NC}"
# Swap
if [ -z "$(swapon --show)" ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile > /dev/null 2>&1
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab > /dev/null
fi

# Firewall
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    apt-get install -y -qq ufw > /dev/null
    ufw allow 22/tcp > /dev/null 2>&1
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    ufw allow 8080/tcp > /dev/null 2>&1
    ufw allow 2022/tcp > /dev/null 2>&1
    ufw --force enable > /dev/null 2>&1
elif [[ "$OS" =~ ^(rocky|almalinux|rhel)$ ]]; then
    systemctl start firewalld
    systemctl enable firewalld > /dev/null 2>&1
    firewall-cmd --add-service=ssh --permanent > /dev/null 2>&1
    firewall-cmd --add-port=80/tcp --permanent > /dev/null 2>&1
    firewall-cmd --add-port=443/tcp --permanent > /dev/null 2>&1
    firewall-cmd --add-port=8080/tcp --permanent > /dev/null 2>&1
    firewall-cmd --add-port=2022/tcp --permanent > /dev/null 2>&1
    firewall-cmd --reload > /dev/null 2>&1
fi

# --- 4. CONFIGURANDO BANCO DE DADOS ---
echo -e "${YELLOW}[3/8] Configurando Banco de Dados...${NC}"
systemctl start mariadb || systemctl start mysql
mysql -u root -e "CREATE DATABASE IF NOT EXISTS panel;"
mysql -u root -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${PASSWORD}';"
mysql -u root -e "ALTER USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${PASSWORD}';"
mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"

# --- 5. INSTALANDO O PAINEL E O PTEROQ ---
echo -e "${YELLOW}[4/8] Baixando e configurando o Painel...${NC}"
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -sSLo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzf panel.tar.gz && chmod -R 755 storage/* bootstrap/cache/
cp .env.example .env

# Instalar dependências do PHP com no-interaction
export COMPOSER_ALLOW_SUPERUSER=1
composer install --no-dev --optimize-autoloader --no-interaction -q

# --- BLINDAGEM MÁXIMA DO ARTISAN ---
php artisan key:generate --force --no-interaction -q

php artisan p:environment:setup \
  --author="${ADMIN_EMAIL}" \
  --url="${PROTOCOL}://${FQDN}" \
  --timezone="America/Sao_Paulo" \
  --cache="redis" \
  --session="redis" \
  --queue="redis" \
  --redis-host="127.0.0.1" \
  --redis-pass="null" \
  --redis-port="6379" \
  --settings-ui=true \
  --telemetry=false \
  --no-interaction

php artisan p:environment:database \
  --host="127.0.0.1" \
  --port="3306" \
  --database="panel" \
  --username="pterodactyl" \
  --password="${PASSWORD}" \
  --no-interaction

php artisan migrate --seed --force --no-interaction -q

php artisan p:user:make \
  --email="${ADMIN_EMAIL}" \
  --admin=1 \
  --password="${PASSWORD}" \
  --name-first="Admin" \
  --name-last="Astral" \
  --username="admin" \
  --no-interaction
# -----------------------------------

chown -R $WEB_USER:$WEB_USER /var/www/pterodactyl/*

# Configurar Cronjob (com verificação para não duplicar)
if ! crontab -l 2>/dev/null | grep -q "artisan schedule:run"; then
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -
fi

echo -e "${YELLOW}[5/8] Configurando Pteroq (Fila)...${NC}"
cat <<EOF > /etc/systemd/system/pteroq.service
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=$WEB_USER
Group=$WEB_USER
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now pteroq.service > /dev/null 2>&1

# --- 6. CONFIGURANDO NGINX E SSL DO PAINEL ---
echo -e "${YELLOW}[6/8] Configurando Nginx e SSL do Painel...${NC}"

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    rm -f /etc/nginx/sites-enabled/default
fi

cat <<EOF > ${NGINX_CONF_DIR}/pterodactyl.conf
server {
    listen 80;
    server_name ${FQDN};
    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass ${PHP_SOCKET};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    ln -s ${NGINX_CONF_DIR}/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf 2>/dev/null
fi

systemctl restart nginx

# Aplicar SSL no Painel
if [[ "$USE_SSL" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}[INFO] Gerando certificado SSL para o Painel...${NC}"
    certbot --nginx -d ${FQDN} --non-interactive --agree-tos -m ${ADMIN_EMAIL} --redirect > /dev/null 2>&1
fi

# --- 7. INSTALANDO O WINGS E SSL DO NODE ---
echo -e "${YELLOW}[7/8] Instalando o Wings e SSL do Node...${NC}"

if [[ "$NODE_USE_SSL" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}[INFO] Gerando certificado SSL para o Node (Wings)...${NC}"
    # Solução Certbot: Parar Nginx, rodar standalone, reiniciar Nginx
    systemctl stop nginx
    certbot certonly --standalone -d ${NODE_FQDN} --non-interactive --agree-tos -m ${ADMIN_EMAIL} > /dev/null 2>&1
    systemctl start nginx
fi

mkdir -p /etc/pterodactyl /var/lib/pterodactyl
curl -sSL -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"
chmod +x /usr/local/bin/wings

cat <<EOF > /etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service
[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=10s
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable wings > /dev/null 2>&1

echo -e "${YELLOW}[8/8] Limpando arquivos temporários...${NC}"
apt-get autoremove -y > /dev/null 2>&1
apt-get clean > /dev/null 2>&1

echo -e "${GREEN}======================================================${NC}"
echo -e "${CYAN} INSTALAÇÃO ASTRAL CLOUD CONCLUÍDA COM SUCESSO!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "Acesse seu painel agora: ${PROTOCOL}://${FQDN}"
echo -e "Usuário: admin | Senha: ${PASSWORD}"
echo -e ""
echo -e "${YELLOW}--- PRÓXIMOS PASSOS PARA O WINGS (NODE) ---${NC}"
echo -e "1. Acesse o Painel -> Admin -> Nodes -> Create New."
echo -e "2. Em FQDN, coloque: ${NODE_FQDN}"
if [[ "$NODE_USE_SSL" =~ ^[Yy]$ ]]; then
    echo -e "3. Em SSL Configuration, escolha: 'Use SSL Connection'"
else
    echo -e "3. Em SSL Configuration, escolha: 'Use HTTP Connection'"
fi
echo -e "4. Salve, vá na aba 'Configuration' do Node criado e clique em 'Generate Token'."
echo -e "5. Copie o bloco de código que aparecer, cole no arquivo /etc/pterodactyl/config.yml do servidor."
echo -e "6. Inicie o Wings rodando no terminal: systemctl start wings"
echo -e "${GREEN}======================================================${NC}"
