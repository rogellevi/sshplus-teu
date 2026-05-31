#!/bin/bash
# ============================================================
#   SSHPLUS MANAGER - Instalador Completo
#   GitHub: https://github.com/rogellevi/sshplus-manager
#   Instala: SSHPLUS + Apache + PHP + Panel Web + SSL
# ============================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'

# Verificar root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Este script debe ejecutarse como root${NC}"
    exit 1
fi

# ─── BANNER ─────────────────────────────────────────────────
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ███████╗███████╗██╗  ██╗██████╗ ██╗     ██╗   ██╗███████╗"
    echo "  ██╔════╝██╔════╝██║  ██║██╔══██╗██║     ██║   ██║██╔════╝"
    echo "  ███████╗███████╗███████║██████╔╝██║     ██║   ██║███████╗"
    echo "  ╚════██║╚════██║██╔══██║██╔═══╝ ██║     ██║   ██║╚════██║"
    echo "  ███████║███████║██║  ██║██║     ███████╗╚██████╔╝███████║"
    echo "  ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝ ╚══════╝"
    echo -e "${NC}"
    echo -e "${WHITE}            PANEL WEB MANAGER - Instalador v2.0${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
}

# ─── MENÚ PRINCIPAL ─────────────────────────────────────────
show_menu() {
    show_banner
    echo ""
    echo -e "${WHITE}  Selecciona una opción:${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} Instalar SSHPLUS"
    echo -e "  ${CYAN}[2]${NC} Instalar Panel Web (HTTP)"
    echo -e "  ${CYAN}[3]${NC} Instalar SSL con Let's Encrypt (HTTPS)"
    echo -e "  ${CYAN}[4]${NC} Instalación Completa (SSHPLUS + Panel + SSL)"
    echo -e "  ${CYAN}[5]${NC} Actualizar Panel"
    echo -e "  ${CYAN}[6]${NC} Renovar Certificado SSL"
    echo -e "  ${RED}[0]${NC} Salir"
    echo ""
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo -ne "${WHITE}  ¿QUÉ DESEAS HACER? : ${NC}"
    read OPTION
}

# ─── FUNCIONES COMUNES ───────────────────────────────────────
check_apache() {
    echo -e "${YELLOW}  Verificando Apache2...${NC}"
    if systemctl is-active --quiet apache2; then
        echo -e "${GREEN}  ✓ Apache2 activo${NC}"
    else
        echo -e "${YELLOW}  ⚠ Instalando Apache2...${NC}"
        apt-get update -qq
        apt-get install -y apache2 -qq
        systemctl start apache2
        systemctl enable apache2
        echo -e "${GREEN}  ✓ Apache2 instalado${NC}"
    fi
    APACHE_USER=$(ps aux | grep apache2 | grep -v root | grep -v grep | head -1 | awk '{print $1}')
    APACHE_USER=${APACHE_USER:-www-data}
}

check_php() {
    echo -e "${YELLOW}  Verificando PHP...${NC}"
    if ! command -v php &>/dev/null; then
        echo -e "${YELLOW}  ⚠ Instalando PHP...${NC}"
        apt-get install -y php libapache2-mod-php -qq
        systemctl restart apache2
    fi
    if ! apache2ctl -M 2>/dev/null | grep -q php; then
        apt-get install -y libapache2-mod-php -qq
        systemctl restart apache2
    fi
    apt-get install -y curl -qq
    echo -e "${GREEN}  ✓ PHP activo${NC}"
}

check_sshplus() {
    if [ ! -d "/etc/SSHPlus" ]; then
        echo -e "${RED}  ✗ SSHPLUS no está instalado${NC}"
        echo -ne "${WHITE}  ¿Deseas instalarlo ahora? (s/n): ${NC}"
        read INST
        if [ "$INST" = "s" ] || [ "$INST" = "S" ]; then
            install_sshplus
        else
            echo -e "${RED}  Instalación cancelada${NC}"
            return 1
        fi
    fi
    return 0
}

set_permissions() {
    echo -e "${YELLOW}  Configurando permisos...${NC}"
    chmod 755 /root
    chmod 777 /etc/SSHPlus/
    [ -f "/etc/SSHPlus/usuarios.db" ] && chmod 666 /etc/SSHPlus/usuarios.db
    [ -d "/etc/SSHPlus/senha" ]       && chmod 777 /etc/SSHPlus/senha/
    [ -f "/root/usuarios.db" ]        && chmod 666 /root/usuarios.db

    SUDOERS_LINE="${APACHE_USER} ALL=(ALL) NOPASSWD: /usr/sbin/useradd, /usr/sbin/userdel, /usr/sbin/chpasswd, /usr/bin/chage, /usr/sbin/chage"
    sed -i "/${APACHE_USER} ALL=(ALL) NOPASSWD/d" /etc/sudoers 2>/dev/null
    sed -i '/# SSHPLUS Manager Panel/d' /etc/sudoers 2>/dev/null
    echo "" >> /etc/sudoers
    echo "# SSHPLUS Manager Panel" >> /etc/sudoers
    echo "$SUDOERS_LINE" >> /etc/sudoers
    echo -e "${GREEN}  ✓ Permisos y sudoers configurados${NC}"

    RC_LOCAL="/etc/rc.local"
    [ ! -f "$RC_LOCAL" ] && echo '#!/bin/bash' > $RC_LOCAL && echo 'exit 0' >> $RC_LOCAL && chmod +x $RC_LOCAL
    if ! grep -q "SSHPlus Manager" $RC_LOCAL; then
        sed -i '/^exit 0/d' $RC_LOCAL
        cat >> $RC_LOCAL << 'EOF'

# SSHPlus Manager - Permisos
chmod 755 /root
chmod 666 /root/usuarios.db 2>/dev/null
chmod 777 /etc/SSHPlus/ 2>/dev/null
chmod 666 /etc/SSHPlus/usuarios.db 2>/dev/null
chmod 777 /etc/SSHPlus/senha/ 2>/dev/null

exit 0
EOF
    fi
    echo -e "${GREEN}  ✓ Permisos permanentes en rc.local${NC}"
}

ask_password() {
    echo ""
    while true; do
        echo -ne "${WHITE}  Contraseña para el panel web: ${NC}"
        read -s PANEL_PASS
        echo ""
        echo -ne "${WHITE}  Confirma la contraseña: ${NC}"
        read -s PANEL_PASS2
        echo ""
        if [ "$PANEL_PASS" = "$PANEL_PASS2" ] && [ -n "$PANEL_PASS" ]; then
            echo -e "${GREEN}  ✓ Contraseña configurada${NC}"
            break
        else
            echo -e "${RED}  ✗ No coinciden o están vacías, intenta de nuevo${NC}"
        fi
    done
}

download_panel() {
    echo -e "${YELLOW}  Descargando panel desde GitHub...${NC}"
    PANEL_URL="https://raw.githubusercontent.com/rogellevi/sshplus-manager/main/sshplus.php"
    TMP_FILE="/tmp/sshplus_panel.php"
    if curl -fsSL "$PANEL_URL" -o "$TMP_FILE" 2>/dev/null; then
        echo -e "${GREEN}  ✓ Panel descargado${NC}"
    else
        echo -e "${RED}  ✗ No se pudo descargar el panel desde GitHub${NC}"
        return 1
    fi
    sed -i "s|define('PANEL_PASSWORD', '.*')|define('PANEL_PASSWORD', '$PANEL_PASS')|g" "$TMP_FILE"
    cp "$TMP_FILE" /var/www/html/sshplus.php
    chmod 644 /var/www/html/sshplus.php
    rm -f "$TMP_FILE"
    echo -e "${GREEN}  ✓ Panel instalado en /var/www/html/sshplus.php${NC}"
}

# ─── OPCIÓN 1: INSTALAR SSHPLUS ─────────────────────────────
install_sshplus() {
    show_banner
    echo -e "${WHITE}  [INSTALANDO SSHPLUS]${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${YELLOW}  Actualizando sistema...${NC}"
    apt update -y -qq && apt upgrade -y -qq
    echo -e "${GREEN}  ✓ Sistema actualizado${NC}"
    echo ""
    echo -e "${YELLOW}  Descargando e instalando SSHPLUS...${NC}"
    echo -e "${YELLOW}  (Sigue las instrucciones en pantalla)${NC}"
    echo ""
    wget -q https://raw.githubusercontent.com/rogellevi/SSHPLUS/master/Plus -O /tmp/Plus
    chmod 777 /tmp/Plus
    /tmp/Plus
    rm -f /tmp/Plus
    echo ""
    echo -e "${GREEN}  ✓ SSHPLUS instalado${NC}"
    echo ""
    read -p "  Presiona Enter para continuar..."
}

# ─── OPCIÓN 2: INSTALAR PANEL HTTP ──────────────────────────
install_panel() {
    show_banner
    echo -e "${WHITE}  [INSTALANDO PANEL WEB HTTP]${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo ""
    check_apache
    check_php
    check_sshplus || { read -p "  Presiona Enter para continuar..."; return; }
    ask_password
    set_permissions
    download_panel || { read -p "  Presiona Enter para continuar..."; return; }
    systemctl restart apache2

    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    echo ""
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}  ✓ PANEL INSTALADO CORRECTAMENTE${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${WHITE}  URL del panel:${NC}"
    echo -e "${CYAN}  http://${SERVER_IP}:8888/sshplus.php${NC}"
    echo ""
    read -p "  Presiona Enter para continuar..."
}

# ─── OPCIÓN 3: INSTALAR SSL ──────────────────────────────────
install_ssl() {
    show_banner
    echo -e "${WHITE}  [CONFIGURANDO SSL - LET'S ENCRYPT]${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo ""

    while true; do
        echo -ne "${WHITE}  Dominio (ej: panel.midominio.com): ${NC}"
        read DOMAIN
        [ -n "$DOMAIN" ] && echo -e "${GREEN}  ✓ Dominio: ${DOMAIN}${NC}" && break
        echo -e "${RED}  ✗ El dominio no puede estar vacío${NC}"
    done

    while true; do
        echo -ne "${WHITE}  Puerto HTTPS a usar (ej: 8443): ${NC}"
        read SSL_PORT
        if [[ "$SSL_PORT" =~ ^[0-9]+$ ]] && [ "$SSL_PORT" -ge 1 ] && [ "$SSL_PORT" -le 65535 ]; then
            if ss -tlnp | grep -q ":${SSL_PORT} "; then
                echo -e "${RED}  ✗ Puerto ${SSL_PORT} en uso, elige otro${NC}"
            else
                echo -e "${GREEN}  ✓ Puerto HTTPS: ${SSL_PORT}${NC}"
                break
            fi
        else
            echo -e "${RED}  ✗ Puerto inválido${NC}"
        fi
    done

    while true; do
        echo -ne "${WHITE}  Email para Let's Encrypt: ${NC}"
        read LE_EMAIL
        if [[ "$LE_EMAIL" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; then
            echo -e "${GREEN}  ✓ Email: ${LE_EMAIL}${NC}"
            break
        else
            echo -e "${RED}  ✗ Email inválido${NC}"
        fi
    done

    echo ""
    echo -e "${YELLOW}  Instalando Certbot...${NC}"
    apt-get update -qq
    apt-get install -y certbot python3-certbot-apache curl -qq
    a2enmod ssl -q
    a2enmod rewrite -q
    a2enmod headers -q
    echo -e "${GREEN}  ✓ Certbot instalado${NC}"

    ufw allow 80/tcp >/dev/null 2>&1
    ufw allow ${SSL_PORT}/tcp >/dev/null 2>&1

    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    DOMAIN_IP=$(dig +short $DOMAIN 2>/dev/null | head -1)
    echo -e "${WHITE}  IP servidor: ${SERVER_IP} | IP dominio: ${DOMAIN_IP}${NC}"
    if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
        echo -e "${YELLOW}  ⚠ El dominio no apunta a este servidor${NC}"
        echo -ne "${WHITE}  ¿Continuar de todas formas? (s/n): ${NC}"
        read CONTINUE
        [ "$CONTINUE" != "s" ] && [ "$CONTINUE" != "S" ] && return
    fi

    echo -e "${YELLOW}  Obteniendo certificado SSL...${NC}"
    systemctl stop apache2
    certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "$LE_EMAIL" \
        -d "$DOMAIN" \
        --preferred-challenges http 2>&1
    CERTBOT_STATUS=$?
    systemctl start apache2

    if [ $CERTBOT_STATUS -ne 0 ]; then
        echo -e "${RED}  ✗ Error al obtener certificado SSL${NC}"
        echo -e "${YELLOW}  Verifica que el dominio apunte a este servidor y el puerto 80 esté accesible${NC}"
        read -p "  Presiona Enter para continuar..."
        return
    fi
    echo -e "${GREEN}  ✓ Certificado SSL obtenido${NC}"

    CERT_PATH="/etc/letsencrypt/live/${DOMAIN}"

    if ! grep -q "Listen ${SSL_PORT}" /etc/apache2/ports.conf; then
        echo "Listen ${SSL_PORT}" >> /etc/apache2/ports.conf
    fi

    cat > /etc/apache2/sites-enabled/sshplus-ssl.conf << EOF
<VirtualHost *:${SSL_PORT}>
    ServerName ${DOMAIN}
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile ${CERT_PATH}/fullchain.pem
    SSLCertificateKeyFile ${CERT_PATH}/privkey.pem

    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite HIGH:!aNULL:!MD5
    SSLHonorCipherOrder on

    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"

    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/sshplus-ssl-error.log
    CustomLog \${APACHE_LOG_DIR}/sshplus-ssl-access.log combined
</VirtualHost>
EOF

    CRON_JOB="0 3 * * * certbot renew --quiet --pre-hook 'systemctl stop apache2' --post-hook 'systemctl start apache2'"
    (crontab -l 2>/dev/null | grep -v certbot; echo "$CRON_JOB") | crontab -

    systemctl restart apache2
    sleep 1

    echo ""
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}  ✓ SSL CONFIGURADO CORRECTAMENTE${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${WHITE}  URL HTTPS del panel:${NC}"
    echo -e "${CYAN}  https://${DOMAIN}:${SSL_PORT}/sshplus.php${NC}"
    echo ""
    echo -e "${WHITE}  Renovación automática:${NC} ${GREEN}Activa (cada 90 días)${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo ""
    read -p "  Presiona Enter para continuar..."
}

# ─── OPCIÓN 4: INSTALACIÓN COMPLETA ─────────────────────────
install_complete() {
    show_banner
    echo -e "${WHITE}  [INSTALACIÓN COMPLETA]${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${WHITE}  Se instalará:${NC}"
    echo -e "  ${GREEN}✓${NC} SSHPLUS"
    echo -e "  ${GREEN}✓${NC} Apache + PHP"
    echo -e "  ${GREEN}✓${NC} Panel Web"
    echo -e "  ${GREEN}✓${NC} SSL Let's Encrypt"
    echo ""
    echo -ne "${WHITE}  ¿Confirmas la instalación completa? (s/n): ${NC}"
    read CONFIRM
    [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ] && return

    install_sshplus
    install_panel
    install_ssl
}

# ─── OPCIÓN 5: ACTUALIZAR PANEL ─────────────────────────────
update_panel() {
    show_banner
    echo -e "${WHITE}  [ACTUALIZANDO PANEL]${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo ""

    CURRENT_PASS=$(grep "define('PANEL_PASSWORD'" /var/www/html/sshplus.php 2>/dev/null | cut -d"'" -f4)
    if [ -n "$CURRENT_PASS" ]; then
        PANEL_PASS="$CURRENT_PASS"
        echo -e "${GREEN}  ✓ Contraseña actual conservada${NC}"
    else
        ask_password
    fi

    cp /var/www/html/sshplus.php /root/sshplus_backup_$(date +%Y%m%d_%H%M%S).php 2>/dev/null
    echo -e "${GREEN}  ✓ Backup creado en /root/${NC}"

    download_panel || { read -p "  Presiona Enter para continuar..."; return; }
    systemctl restart apache2

    echo ""
    echo -e "${GREEN}  ✓ Panel actualizado correctamente${NC}"
    echo ""
    read -p "  Presiona Enter para continuar..."
}

# ─── OPCIÓN 6: RENOVAR SSL ───────────────────────────────────
renew_ssl() {
    show_banner
    echo -e "${WHITE}  [RENOVANDO CERTIFICADO SSL]${NC}"
    echo -e "${BLUE}  ─────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "${YELLOW}  Renovando certificado...${NC}"
    systemctl stop apache2
    certbot renew 2>&1
    systemctl start apache2
    echo ""
    echo -e "${GREEN}  ✓ Proceso de renovación completado${NC}"
    echo ""
    read -p "  Presiona Enter para continuar..."
}

# ─── LOOP PRINCIPAL ─────────────────────────────────────────
while true; do
    show_menu
    case $OPTION in
        1) install_sshplus ;;
        2) install_panel ;;
        3) install_ssl ;;
        4) install_complete ;;
        5) update_panel ;;
        6) renew_ssl ;;
        0) echo -e "${GREEN}  ¡Hasta luego!${NC}"; echo ""; exit 0 ;;
        *) echo -e "${RED}  ✗ Opción inválida${NC}"; sleep 1 ;;
    esac
done
