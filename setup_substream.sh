#!/bin/bash

# Ensure Python is installed
sudo apt-get update

if ! command -v python3 > /dev/null 2>&1; then
    sudo apt-get install python3 -y
fi

if ! command -v pip3 > /dev/null 2>&1; then
    sudo apt-get install python3-pip -y
fi

if ! command -v nginx > /dev/null 2>&1; then
    sudo apt-get install nginx -y
fi

if ! command -v sshd > /dev/null 2>&1; then
    sudo apt-get install openssh-server -y
fi

if ! python3 -c "import flask" > /dev/null 2>&1; then
    sudo apt-get install python3-flask -y
fi

# Create the user 'host' without a home directory and with a disabled password
sudo adduser --disabled-password --no-create-home --shell /bin/bash host

# Make the password actually empty
sudo sed -i -re 's/^host:[^:]+:/host::/' /etc/passwd /etc/shadow

# Start and enable Nginx and SSH server at boot
sudo systemctl start nginx
sudo systemctl enable nginx

sudo systemctl start ssh
sudo systemctl enable ssh

# Allow blank passwords for SSH sessions in PAM
sudo sed -i -re 's/^@include common-auth$/auth [success=1 default=ignore] pam_unix.so nullok\nauth requisite pam_deny.so\nauth required pam_permit.so/' /etc/pam.d/sshd

# Add the host user to sudoers with NOPASSWD for setup_nginx.sh and cleanup.sh
sudo bash -c "echo 'host ALL=(ALL) NOPASSWD: /usr/local/bin/setup_nginx.sh, /usr/local/bin/cleanup.sh' >> /etc/sudoers"

# Create a Python script to be run by ForceCommand
cat << 'EOF' | sudo tee /usr/local/bin/host_login.py
#!/usr/bin/env python3

import random
import string
import os
import signal
import subprocess
import sys

# Function to handle the cleanup process
def cleanup():
    print("Cleaning up before logout...")
    subprocess.run(["sudo", "/usr/local/bin/cleanup.sh", subdomain])

# Trap SIGTERM signal and run cleanup function
signal.signal(signal.SIGTERM, lambda signum, frame: cleanup())

# Generate a random subdomain
subdomain = ''.join(random.choices(string.ascii_lowercase + string.digits, k=8))
fqdn = f"{subdomain}.rtmdemos.name.ng"

port_file_path = "/tmp/port.txt"  # Specify the path to port.txt
if os.path.exists(port_file_path):
    with open(port_file_path, "r") as file:
        port = file.read().strip()
else:
    print("port.txt not found. Exiting.")

# Nginx configuration content
nginx_config = f"""
server {{
    listen 80;
    server_name {fqdn};

    location / {{
        proxy_pass http://127.0.0.1:{port};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }}
}}
"""

# Write the Nginx configuration to a temporary location
temp_nginx_config_path = f"/tmp/{subdomain}"
with open(temp_nginx_config_path, "w") as file:
    file.write(nginx_config)

# Execute the privileged script as root
subprocess.run(["sudo", "/usr/local/bin/setup_nginx.sh", temp_nginx_config_path, subdomain])

# Output the fully qualified domain name (FQDN)
print(f"Subdomain created: {fqdn}")

# Keep the session alive until the user logs out
try:
    while True:
        pass
except KeyboardInterrupt:
    cleanup()
    sys.exit(0)

EOF

# Make the Python script executable
sudo chmod +x /usr/local/bin/host_login.py

# Create a helper shell script for Nginx setup with root permissions
cat << 'EOF' | sudo tee /usr/local/bin/setup_nginx.sh
#!/bin/bash

# Arguments
config_file_path="$1"
subdomain="$2"

# Move the Nginx config to the proper location
mv "$config_file_path" /etc/nginx/sites-available/"$subdomain"

# Create a symlink in sites-enabled
ln -s /etc/nginx/sites-available/"$subdomain" /etc/nginx/sites-enabled/"$subdomain"

# Reload Nginx to apply the new configuration
systemctl reload nginx

EOF

# Make the shell script executable
sudo chmod +x /usr/local/bin/setup_nginx.sh

# Create a cleanup shell script with root permissions
cat << 'EOF' | sudo tee /usr/local/bin/cleanup.sh
#!/bin/bash

# Arguments
subdomain="$1"

# Remove the Nginx config files
rm -f /etc/nginx/sites-available/"$subdomain"
rm -f /etc/nginx/sites-enabled/"$subdomain"
rm /tmp/port.txt

# Reload Nginx to apply changes
systemctl reload nginx

EOF

# Make the cleanup shell script executable
sudo chmod +x /usr/local/bin/cleanup.sh

# Allow blank passwords and set ForceCommand for the 'host' user in SSHD config
sudo bash -c "echo -e '\nMatch User host\n    PermitEmptyPasswords yes\n    ForceCommand /usr/local/bin/host_login.py' >> /etc/ssh/sshd_config"

# Restart SSH service to apply changes
sudo systemctl reload ssh.service
python3 app.py

echo "Setup complete: User 'host' created, Nginx and SSH installed and enabled, Python script configured to generate a random subdomain and proxy to port 8000."
