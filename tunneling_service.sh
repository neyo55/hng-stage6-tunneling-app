#!/bin/bash

# Load environment variables from .env file
set -o allexport
source .env
set -o allexport

# Check if required variables are set
if [[ -z "$DOMAIN" ]]; then
    echo "Missing required environment variables. Please check your .env file."
    exit 1
fi

# Install OpenSSH Server if not already installed
if ! dpkg -s openssh-server >/dev/null 2>&1; then
    echo "Installing OpenSSH Server..."
    sudo apt update
    sudo apt install -y openssh-server
    echo "OpenSSH Server installed."
else
    echo "OpenSSH Server is already installed."
fi

# Configure SSH for Reverse Forwarding
echo "Configuring SSH for reverse forwarding..."
sudo sed -i '/AllowTcpForwarding/d' /etc/ssh/sshd_config
sudo sed -i '/GatewayPorts/d' /etc/ssh/sshd_config
echo "AllowTcpForwarding yes" | sudo tee -a /etc/ssh/sshd_config
echo "GatewayPorts yes" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart ssh
echo "SSH configured and restarted."

# Install Nginx if not already installed
if ! dpkg -s nginx >/dev/null 2>&1; then
    echo "Installing Nginx..."
    sudo apt update
    sudo apt install -y nginx
    echo "Nginx installed."
else
    echo "Nginx is already installed."
fi

# Configure Nginx for Proxy Management and Wildcard Domains
echo "Configuring Nginx..."
NGINX_CONF="/etc/nginx/sites-available/default"
sudo bash -c "cat > $NGINX_CONF" <<EOL
server {
    listen 80 default_server;
    server_name ~^(?<subdomain>.+)\.$DOMAIN$;

    location / {
        proxy_pass http://localhost:\$subdomain;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL
sudo ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
sudo systemctl restart nginx
echo "Nginx configured and restarted."

echo "Setup completed successfully."
