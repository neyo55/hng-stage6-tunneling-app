#!/bin/bash

# Install PAM script support
sudo apt install -y libpam-script

# Create PAM scripts directory if it doesn't exist
sudo mkdir -p /etc/security/pam_scripts

# Create the port forwarding script
sudo bash -c "cat > /etc/security/pam_scripts/port_forward.sh" <<EOL
#!/bin/bash

function get_free_port() {
    while true; do
        # Generate a random port number between 1000 and 9999
        PORT=\$(shuf -i 1000-9999 -n 1)

        # Check if the port is in use
        ss -ltn | grep -q ":$PORT " || break
    done
    echo \$PORT
}

if [ "\$PAM_TYPE" = "open_session" ]; then
    # Generate a free port number
    PORT=\$(get_free_port)

    # Store the port number in the user's home directory
    echo "\$PORT" > /home/\$PAM_USER/port_number

    # Set up port forwarding
    sudo iptables -t nat -A PREROUTING -p tcp --dport 8080 -j REDIRECT --to-port \$PORT

    # Start a service on the random port (e.g., a simple Python HTTP server)
    sudo -u \$PAM_USER nohup python3 -m http.server \$PORT > /dev/null 2>&1 &

    # Generate the URL and store it
    URL="http://\$HOSTNAME:\$PORT"
    echo "\$URL" > /home/\$PAM_USER/access_url

    # Output the URL to the user
    echo "Access your application at: \$URL"

    # Update Nginx configuration
    sudo sed -i "s/8081/\$PORT/" /etc/nginx/sites-available/default
    sudo systemctl reload nginx

elif [ "\$PAM_TYPE" = "close_session" ]; then
    # Get the port number from the user's home directory
    PORT=\$(cat /home/\$PAM_USER/port_number)

    # Remove port forwarding
    sudo iptables -t nat -D PREROUTING -p tcp --dport 8080 -j REDIRECT --to-port \$PORT

    # Kill the process running on the random port
    sudo pkill -f "python3 -m http.server \$PORT"

    # Clean up
    rm /home/\$PAM_USER/port_number
    rm /home/\$PAM_USER/access_url

    # Restore Nginx configuration
    sudo sed -i "s/\$PORT/8081/" /etc/nginx/sites-available/default
    sudo systemctl reload nginx
fi
EOL

# Make the port forwarding script executable
sudo chmod +x /etc/security/pam_scripts/port_forward.sh

# Configure PAM to use the port forwarding script
sudo bash -c "echo 'session optional pam_exec.so /etc/security/pam_scripts/port_forward.sh' >> /etc/pam.d/sshd"

# Configure Nginx for proxy management
sudo bash -c "cat > /etc/nginx/sites-available/default" <<EOL
server {
    listen 8080 default_server;  # Ensure Nginx listens on port 8080
    server_name _;

    location / {
        proxy_pass http://localhost:8081;  # Default port
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

# Restart Nginx
sudo systemctl restart nginx
