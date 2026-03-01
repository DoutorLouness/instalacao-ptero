#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# --- CORES ---
CYAN='\033[0;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

# Checar Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERRO] Execute como root (sudo su).${NC}"
    exit 1
fi

# Identificar SO Globalmente
. /etc/os-release
OS=$ID
VER=$VERSION_ID

# Define WEB_USER globalmente para uso nas funções de update
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    WEB_USER="www-data"
elif [[ "$OS" =~ ^(rocky|almalinux|rhel)$ ]]; then
    WEB_USER="nginx"
fi

# ==========================================
# FUNÇÕES DE INSTALAÇÃO
# ==========================================

setup_base_system() {
    echo -e "${YELLOW}>> Configurando Mirrors, Firewall, Swap e Pacotes Base...${NC}"
    
    # Swap
    if [ -z "$(swapon --show)" ]; then
        fallocate -l 2G /swapfile
        chmod 600 /swapfile
        mkswap /swapfile > /dev/null 2>&1
        swapon /swapfile
        echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab > /dev/null
    fi

    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        # Mirrors BR
        if [ "$OS" == "ubuntu" ]; then
            sed -i -E 's/http:\/\/([a-z]{2}\.)?archive\.ubuntu\.com/http:\/\/br.archive.ubuntu.com/g' /etc/apt/sources.list 2>/dev/null
            sed -i -E 's/http:\/\/([a-z]{2}\.)?archive\.ubuntu\.com/http:\/\/br.archive.ubuntu.com/g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null
        elif [ "$OS" == "debian" ]; then
            sed -i -E 's/deb\.debian\.org/ftp.br.debian.org/g' /etc/apt/sources.list 2>/dev/null
            sed -i -E 's/deb\.debian\.org/ftp.br.debian.org/g' /etc/apt/sources.list.d/debian.sources 2>/dev/null
        fi

        apt update -y -qq
        apt install -y -qq software-properties-common curl apt-transport-https ca-certificates gnupg tar unzip git redis-server mariadb-server nginx certbot python3-certbot-nginx ufw > /dev/null
        
        # UFW
        ufw allow 22/tcp > /dev/null 2>&1
        ufw allow 80/tcp > /dev/null 2>&1
        ufw allow 443/tcp > /dev/null 2>&1
        ufw allow 8080/tcp > /dev/null 2>&1
        ufw allow 2022/tcp > /dev/null 2>&1
        ufw --force enable > /dev/null 2>&1

        if [ "$OS" == "ubuntu" ]; then
            LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
        else
            curl -sSL https://packages.sury.org/php/README.txt | bash -x > /dev/null 2>&1
        fi
        apt update -y -qq
        apt install -y -qq php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} > /dev/null
        
        PHP_SOCKET="unix:/run/php/php8.3-fpm.sock"
        NGINX_CONF_DIR="/etc/nginx/sites-available"

    elif [[ "$OS" =~ ^(rocky|almalinux|rhel)$ ]]; then
        dnf install -y -q epel-release curl tar unzip git redis mariadb-server nginx certbot python3-certbot-nginx > /dev/null
        dnf install -y -q https://rpms.remirepo.net/enterprise/remi-release-${VER%%.*}.rpm > /dev/null
        dnf module reset php -y -q && dnf module enable php:remi-8.3 -y -q > /dev/null
        dnf install -y -q php php-{common,cli,gd,mysqlnd,mbstring,bcmath,xml,fpm,curl,zip} > /dev/null
        systemctl enable --now mariadb redis php-fpm nginx > /dev/null
        
        # Firewalld
        systemctl start firewalld
        systemctl enable firewalld > /dev/null 2>&1
        firewall-cmd --add-service=ssh --permanent > /dev/null 2>&1
        firewall-cmd --add-port=80/tcp --permanent > /dev/null 2>&1
        firewall-cmd --add-port=443/tcp --permanent > /dev/null 2>&1
        firewall-cmd --add-port=8080/tcp --permanent > /dev/null 2>&1
        firewall-cmd --add-port=2022/tcp --permanent > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1

        PHP_SOCKET="unix:/run/php-fpm/www.sock"
        NGINX_CONF_DIR="/etc/nginx/conf.d"
    fi

    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer > /dev/null 2>&1
    curl -sSL https://get.docker.com/ | CHANNEL=stable bash > /dev/null 2>&1
    systemctl enable --now docker > /dev/null 2>&1
}

install_panel() {
    echo -e "${YELLOW}>> Instalando Banco de Dados e Pterodactyl Panel...${NC}"
    systemctl start mariadb || systemctl start mysql
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS panel;"
    mysql -u root -e "CREATE USER IF NOT EXISTS 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${PASSWORD}';"
    mysql -u root -e "ALTER USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${PASSWORD}';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;"
    mysql -u root -e "FLUSH PRIVILEGES;"

    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl
    curl -sSLo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    tar -xzf panel.tar.gz && chmod -R 755 storage/* bootstrap/cache/
    cp .env.example .env

    export COMPOSER_ALLOW_SUPERUSER=1
    composer install --no-dev --optimize-autoloader --no-interaction -q

    php artisan key:generate --force --no-interaction -q
    php artisan p:environment:setup --author="${ADMIN_EMAIL}" --url="${PROTOCOL}://${FQDN}" --timezone="America/Sao_Paulo" --cache="redis" --session="redis" --queue="redis" --redis-host="127.0.0.1" --redis-pass="null" --redis-port="6379" --settings-ui=true --telemetry=false --no-interaction
    php artisan p:environment:database --host="127.0.0.1" --port="3306" --database="panel" --username="pterodactyl" --password="${PASSWORD}" --no-interaction
    php artisan migrate --seed --force --no-interaction -q
    php artisan p:user:make --email="${ADMIN_EMAIL}" --admin=1 --password="${PASSWORD}" --name-first="Admin" --name-last="Astral" --username="admin" --no-interaction

    chown -R $WEB_USER:$WEB_USER /var/www/pterodactyl/*
    (crontab -l 2>/dev/null; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

    # Fila Pteroq
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

    # Nginx
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then rm -f /etc/nginx/sites-enabled/default; fi
    cat <<EOF > ${NGINX_CONF_DIR}/pterodactyl.conf
server {
    listen 80; server_name ${FQDN}; root /var/www/pterodactyl/public;
    index index.html index.htm index.php; charset utf-8;
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
    access_log off; error_log  /var/log/nginx/pterodactyl.app-error.log error;
    client_max_body_size 100m; client_body_timeout 120s; sendfile off;
    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$; fastcgi_pass ${PHP_SOCKET}; fastcgi_index index.php;
        include fastcgi_params; fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off; fastcgi_buffer_size 16k; fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300; fastcgi_send_timeout 300; fastcgi_read_timeout 300;
    }
    location ~ /\.ht { deny all; }
}
EOF
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then ln -s ${NGINX_CONF_DIR}/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf 2>/dev/null; fi
    systemctl restart nginx

    if [[ "$USE_SSL" =~ ^[Yy]$ ]]; then
        certbot --nginx -d ${FQDN} --non-interactive --agree-tos -m ${ADMIN_EMAIL} --redirect > /dev/null 2>&1
    fi
}

install_wings() {
    echo -e "${YELLOW}>> Instalando Wings (Node)...${NC}"
    if [[ "$NODE_USE_SSL" =~ ^[Yy]$ ]]; then
        certbot certonly --nginx -d ${NODE_FQDN} --non-interactive --agree-tos -m ${ADMIN_EMAIL} > /dev/null 2>&1
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
}

update_wings_bin() {
    echo -e "${CYAN}[INFO] Parando o serviço do Wings...${NC}"
    systemctl stop wings
    echo -e "${CYAN}[INFO] Baixando última versão...${NC}"
    curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"
    chmod +x /usr/local/bin/wings
    echo -e "${CYAN}[INFO] Iniciando o serviço...${NC}"
    systemctl start wings
    echo -e "${GREEN}Wings atualizado com sucesso!${NC}"
    sleep 3
}

update_panel() {
    echo -e "\n${CYAN}======================================================${NC}"
    echo -e "${YELLOW} INICIANDO ATUALIZAÇÃO SEGURA DO PAINEL...${NC}"
    echo -e "${CYAN}======================================================${NC}"
    
    cd /var/www/pterodactyl || { echo -e "${RED}[ERRO] Diretório do painel não encontrado!${NC}"; exit 1; }

    echo -e "${CYAN}[1/6] Colocando o painel em modo de manutenção...${NC}"
    php artisan down

    echo -e "${CYAN}[2/6] Baixando e extraindo a versão mais recente...${NC}"
    curl -sSLo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    # O tar por padrão sobreescreve, mas NÃO mexe no seu .env existente
    tar -xzf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/

    echo -e "${CYAN}[3/6] Atualizando as dependências do Composer...${NC}"
    export COMPOSER_ALLOW_SUPERUSER=1
    composer install --no-dev --optimize-autoloader --no-interaction -q

    echo -e "${CYAN}[4/6] Limpando caches de visualização e configuração...${NC}"
    php artisan view:clear > /dev/null 2>&1
    php artisan config:clear > /dev/null 2>&1

    echo -e "${CYAN}[5/6] Atualizando o Banco de Dados (MUITO SEGURO - Não deleta dados!)...${NC}"
    php artisan migrate --seed --force --no-interaction -q

    echo -e "${CYAN}[6/6] Ajustando permissões e reiniciando a fila...${NC}"
    chown -R $WEB_USER:$WEB_USER /var/www/pterodactyl/*
    systemctl restart pteroq.service

    echo -e "${GREEN}[INFO] Tirando o painel do modo de manutenção...${NC}"
    php artisan up

    echo -e "\n${GREEN}======================================================${NC}"
    echo -e "${GREEN} PAINEL ATUALIZADO COM SUCESSO! SEUS DADOS ESTÃO SALVOS! ufa kkkk${NC}"
    echo -e "${GREEN}======================================================${NC}"
    sleep 4
}

# ==========================================
# MENU PRINCIPAL
# ==========================================
while true; do
    clear
    echo -e "${CYAN}"
    echo "    ___       __           __  ________                __ "
    echo "   / _ | ___ / /________ _/ / / ___/ /___  __ _____   / / "
    echo "  / __ |(_-</ __/ __/ _ \`/ / / /__/ / __ \/ // / _ \ /_/  "
    echo " /_/ |_/___/\__/_/  \_,_/_/  \___/_/\___/\_,_/_//_/ (_)   "
    echo -e "${NC}"
    echo -e "${GREEN}======================================================${NC}"
    echo -e "${YELLOW} Instalador Modular - Astral Cloud${NC}"
    echo -e "${GREEN}======================================================${NC}"
    echo -e " Escolha uma opção de instalação para este servidor:"
    echo -e ""
    echo -e " [1] Instalação Completa (Painel + Wings)"
    echo -e " [2] Instalar APENAS o Painel Pterodactyl"
    echo -e " [3] Instalar APENAS o Wings (Novo Node)"
    echo -e " [4] Atualizar Wings (Manutenção)"
    echo -e " [5] Atualizar Painel Pterodactyl (Seguro, não deleta DB!)"
    echo -e " [0] Sair"
    echo -e "${GREEN}======================================================${NC}"
    read -p " Opção: " OPCAO

    case $OPCAO in
        1)
            echo -e "\n${CYAN}--- DADOS DO PAINEL ---${NC}"
            read -p "Domínio do PAINEL (ex: painel.dominio.com.br): " FQDN
            read -p "Instalar SSL no PAINEL? [y/n]: " USE_SSL
            read -p "E-mail Admin: " ADMIN_EMAIL
            read -s -p "Senha Admin e Banco: " PASSWORD; echo ""
            echo -e "\n${CYAN}--- DADOS DO NODE ---${NC}"
            read -p "Domínio do NODE (ex: node.dominio.com.br): " NODE_FQDN
            read -p "Instalar SSL no NODE? [y/n]: " NODE_USE_SSL
            
            [[ "$USE_SSL" =~ ^[Yy]$ ]] && PROTOCOL="https" || PROTOCOL="http"
            
            setup_base_system
            install_panel
            install_wings
            
            echo -e "\n${GREEN}Instalação Completa Finalizada!${NC}"
            echo "Painel: ${PROTOCOL}://${FQDN}"
            exit 0
            ;;
        2)
            echo -e "\n${CYAN}--- DADOS DO PAINEL ---${NC}"
            read -p "Domínio do PAINEL (ex: painel.dominio.com.br): " FQDN
            read -p "Instalar SSL no PAINEL? [y/n]: " USE_SSL
            read -p "E-mail Admin: " ADMIN_EMAIL
            read -s -p "Senha Admin e Banco: " PASSWORD; echo ""
            
            [[ "$USE_SSL" =~ ^[Yy]$ ]] && PROTOCOL="https" || PROTOCOL="http"
            
            setup_base_system
            install_panel
            
            echo -e "\n${GREEN}Painel Instalado com Sucesso!${NC}"
            echo "Acesse: ${PROTOCOL}://${FQDN}"
            exit 0
            ;;
        3)
            echo -e "\n${CYAN}--- DADOS DO NODE ---${NC}"
            read -p "Domínio do NODE (ex: node.dominio.com.br): " NODE_FQDN
            read -p "Instalar SSL no NODE? [y/n]: " NODE_USE_SSL
            read -p "E-mail (para o SSL certbot): " ADMIN_EMAIL
            
            setup_base_system
            install_wings
            
            echo -e "\n${GREEN}Node Instalado com Sucesso!${NC}"
            echo "Vá no Painel e crie o Node com FQDN: ${NODE_FQDN}"
            exit 0
            ;;
        4)
            update_wings_bin
            ;;
        5)
            update_panel
            ;;
        0)
            echo -e "${YELLOW}Saindo...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida!${NC}"
            sleep 2
            ;;
    esac
done
