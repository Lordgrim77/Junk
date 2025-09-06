#!/bin/bash

# ================================
#   Marzban Auto Config Script
# ================================

set -e

echo "=== ⚙️ Marzban Auto Configuration ==="

# --- Step 1: Disable Firewalls ---
echo "🔧 Disabling firewalls..."
sudo ufw disable || true
sudo iptables -F || true
sudo nft flush ruleset || true
sudo netfilter-persistent save || true

# --- Step 2: Ask Details for Configuration---
read -p "🖥️Enter Username for Marzban (default admin): " USERS
read -p "🔑Enter Password for Marzban (default admin): " PASSWD
read -p "🔌 Enter port for Marzban (default 8000): " PORT
read -p "📂 Enter dashboard path(default dashboard: " PATH

USERS=${USERS:-admin}
PASSWD=${PASSWD:-admin}
PORT=${PORT:-8000}
PATH=${PATH:-dashboard}

# --- Step 3: SSL Options ---
while true; do
  echo "Choose SSL installation method:"
  echo "1. SSL Certificate (Non-Cloudflare)"
  echo "2. Cloudflare SSL Certificate "
  read -p "Select option (1 or 2): " SSL_OPTION

  if [ "$SSL_OPTION" -eq 1 ]; then
    # --- Non-Cloudflare SSL ---
    read -p "🌐 Enter your domain (e.g. panel.example.com): " DOMAIN
    echo "🔑 Obtaining Non-Cloudflare SSL certificate..."
    sudo apt update
    sudo apt install -y certbot
    sudo certbot certonly --standalone -d $DOMAIN --register-unsafely-without-email --agree-tos --non-interactive

    # --- Copy SSL Certs ---
    echo "📂 Copying Non-Cloudflare SSL certs..."
    sudo mkdir -p /var/lib/marzban/certs
    sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /var/lib/marzban/certs/fullchain.pem
    sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /var/lib/marzban/certs/key.pem

    # --- Step 4: Set Up SSL Auto-Renewal (cron job) ---
    echo "⏳ Setting up SSL certificate auto-renewal..."
    (sudo crontab -l ; echo "0 0 * * * certbot renew --quiet && systemctl reload nginx") | sudo crontab -

    break  # Exit the loop if SSL is selected successfully

  elif [ "$SSL_OPTION" -eq 2 ]; then
    # --- Cloudflare SSL ---
    echo "🔑 Installing Cloudflare SSL..."
    # Run your Cloudflare SSL installation script here
    #!/bin/bash

# Function to log messages
log() {
    echo -e "[INFO] $1"
}

error() {
    echo -e "[ERROR] $1" >&2
    exit 1
}

# Install acme.sh if not installed
install_acme() {
    if ! command -v ~/.acme.sh/acme.sh &>/dev/null; then
        log "Installing acme.sh..."
        curl https://get.acme.sh | sh || error "Failed to install acme.sh"
        source ~/.bashrc
    fi
}

# Request user input for Cloudflare API details
get_cf_credentials() {
    read -p "Enter your Cloudflare Global API Key: " CF_Key
    read -p "Enter your Cloudflare registered email: " CF_Email

    export CF_Key
    export CF_Email
}

# Request user input for domain
get_domain() {
    read -p "Enter the domain you want to secure (e.g., example.com): " DOMAIN
}

# Set Let's Encrypt as the default CA
set_letsencrypt() {
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt || error "Failed to set Let's Encrypt as default CA"
}

# Issue SSL certificate
issue_certificate() {
    log "Issuing SSL certificate for ${DOMAIN}..."
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d "$DOMAIN" -d "*.$DOMAIN" --log || error "Certificate issuance failed"
}

# Install the certificate
install_certificate() {
    certPath="/var/lib/marzban/certs"
    mkdir -p "$certPath"

    log "Installing SSL certificate..."
    ~/.acme.sh/acme.sh --installcert -d "$DOMAIN" -d "*.$DOMAIN" \
        --fullchain-file "$certPath/fullchain.pem" \
        --key-file "$certPath/key.pem" || error "Certificate installation failed"

    log "Certificate installed successfully!"
    ls -lah "$certPath"
    chmod 755 "$certPath"
}

# Enable auto-renewal
enable_auto_renewal() {
    log "Enabling automatic certificate renewal..."
    ~/.acme.sh/acme.sh --upgrade --auto-upgrade || error "Auto-renewal setup failed"
}

# Main function to execute all steps
main() {
    install_acme
    get_cf_credentials
    get_domain
    set_letsencrypt
    issue_certificate
    install_certificate
    enable_auto_renewal

    log "SSL certificate setup complete!"
}

# Execute script
main

    break  # Exit the loop if Cloudflare SSL is selected

  else
    echo "❌ Invalid option. Please select 1 or 2."
    # Loop again for valid input
  fi
done

# --- Step 5: Download Custom Subscription Template ---
echo "⬇️ Downloading custom subscription template..."
sudo mkdir -p /var/lib/marzban/templates/subscription
sudo wget -O /var/lib/marzban/templates/subscription/index.html https://raw.githubusercontent.com/Lordgrim77/Junk/MarzbanAuto/index.html

# --- Step 6: Configure .env ---
ENV_FILE="/opt/marzban/.env"

echo "⚙️ Configuring .env..."
sudo sed -i "s|^UVICORN_PORT.*|UVICORN_PORT = $PORT|" $ENV_FILE
sudo sed -i "s|^# SUDO_USERNAME.*|SUDO_USERNAME= $USERS|" $ENV_FILE
sudo sed -i "s|^# SUDO_PASSWORD.*|SUDO_PASSWORD= $PASSWD|" $ENV_FILE
sudo sed -i "s|^# DASHBOARD_PATH.*|DASHBOARD_PATH= \"/$PATH/\"|" $ENV_FILE
sudo sed -i "s|^# UVICORN_SSL_CERTFILE.*|UVICORN_SSL_CERTFILE = \"/var/lib/marzban/certs/fullchain.pem\"|" $ENV_FILE
sudo sed -i "s|^# UVICORN_SSL_KEYFILE.*|UVICORN_SSL_KEYFILE = \"/var/lib/marzban/certs/key.pem\"|" $ENV_FILE
sudo sed -i "s|^# XRAY_SUBSCRIPTION_URL_PREFIX.*|XRAY_SUBSCRIPTION_URL_PREFIX = \"https://$DOMAIN:$PORT\"|" $ENV_FILE
sudo sed -i "s|^# CUSTOM_TEMPLATES_DIRECTORY.*|CUSTOM_TEMPLATES_DIRECTORY= \"/var/lib/marzban/templates/\"|" $ENV_FILE
sudo sed -i "s|^# SUBSCRIPTION_PAGE_TEMPLATE.*|SUBSCRIPTION_PAGE_TEMPLATE= \"subscription/index.html\"|" $ENV_FILE


echo "✅ Configuration finished!"
echo "🔗 Access panel: https://$DOMAIN:$PORT/$PATH"
echo "🖥️ User Name: $USERS"
echo "🔑 Password: $PASSWD"
echo "Script by 𝙇𝙊𝙍𝘿 𝙂𝙍𝙄𝙈 ᶻ 𝗓 𐰁 .ᐟ❤️"

# --- Step 8: Restart Marzban ---
echo "🔄 Restarting Marzban..."
sudo marzban restart
