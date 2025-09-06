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
read -p "🌐 Enter your Domain (e.g. panel.example.com): " DOMAIN
read -p "🔌 Enter Port for Marzban (default 8000): " PORT
read -p "🖥️Enter Username for Marzban (default:admin) " USERS
read -p "🔑Enter Password for Marzban (default admin): " PASSWD

USERS=${USERS:-admin}
PASSWD=${PASSWD:-admin}
PORT=${PORT:-8000}

# --- Step 3: Install Certbot & Obtain SSL ---
echo "🔑 Obtaining SSL certificate..."
sudo apt update
sudo apt install -y certbot

sudo certbot certonly --standalone -d $DOMAIN --register-unsafely-without-email --agree-tos --non-interactive

# --- Step 4: Copy SSL Certs ---
echo "📂 Copying SSL certs..."
sudo mkdir -p /var/lib/marzban/certs
sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem /var/lib/marzban/certs/Fullchain.pem
sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem /var/lib/marzban/certs/Key.pem

# --- Step 5: Download Custom Subscription Template ---
echo "⬇️ Downloading custom subscription template..."
sudo mkdir -p /var/lib/marzban/templates/subscription
sudo wget -O /var/lib/marzban/templates/subscription/index.html https://github.com/MuhammadAshouri/marzban-templates/blob/d0caed6f7b8e4d6f21c60c9a7330bf542dbe7515/template-01/index.html

# --- Step 6: Configure .env ---
ENV_FILE="/opt/marzban/.env"

echo "⚙️ Configuring .env..."
sudo sed -i "s|^UVICORN_PORT.*|UVICORN_PORT = $PORT|" $ENV_FILE
sudo sed -i "s|^# SUDO_USERNAME.*|SUDO_USERNAME= $USERS|" $ENV_FILE
sudo sed -i "s|^# SUDO_PASSWORD.*|SUDO_PASSWORD= $PASSWD|" $ENV_FILE
sudo sed -i "s|^# UVICORN_SSL_CERTFILE.*|UVICORN_SSL_CERTFILE = \"/var/lib/marzban/certs/Fullchain.pem\"|" $ENV_FILE
sudo sed -i "s|^# UVICORN_SSL_KEYFILE.*|UVICORN_SSL_KEYFILE = \"/var/lib/marzban/certs/Key.pem\"|" $ENV_FILE
sudo sed -i "s|^# XRAY_SUBSCRIPTION_URL_PREFIX.*|XRAY_SUBSCRIPTION_URL_PREFIX = \"https://$DOMAIN:$PORT\"|" $ENV_FILE
sudo sed -i "s|^# CUSTOM_TEMPLATES_DIRECTORY.*|CUSTOM_TEMPLATES_DIRECTORY=\"/var/lib/marzban/templates/\"|" $ENV_FILE
sudo sed -i "s|^# SUBSCRIPTION_PAGE_TEMPLATE.*|SUBSCRIPTION_PAGE_TEMPLATE=\"subscription/index.html\"|" $ENV_FILE


echo "✅ Configuration finished!"
echo "🔗 Access panel: https://$DOMAIN:$PORT/dashboard"
echo "🖥️ User Name: $USERS"
echo "🔑 Password: $PASSWD"
echo "Script by 𝙇𝙊𝙍𝘿 𝙂𝙍𝙄𝙈 ᶻ 𝗓 𐰁 .ᐟ❤️"

# --- Step 8: Restart Marzban ---
echo "🔄 Restarting Marzban..."
sudo marzban restart