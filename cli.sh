#!/bin/bash

# Check if the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

sudo chmod +x substream.py
sudo mv substream.py /usr/local/bin/substream
