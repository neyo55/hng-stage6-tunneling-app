#!/usr/bin/env python3

import subprocess
import sys


def fetch_port(ip):
    try:
        # Make the curl request and capture the output
        result = subprocess.run(['curl', '-s', f'http://{ip}:5000/'], capture_output=True, text=True, check=True)
        response = result.stdout.strip()
        
        # Ensure the response is a valid port number
        if response.isdigit():
            return response
        else:
            raise ValueError("Invalid response received.")
    except subprocess.CalledProcessError as e:
        print(f"Error during curl request: {e}")
        sys.exit(1)
    except ValueError as e:
        print(e)
        sys.exit(1)


def run_ssh_command(port, argument):
    # Construct the SSH command with remote port forwarding
    command = f"ssh -R {port}:localhost:{argument} host@<your-domain-name>"
    print(f"Executing command: {command}")
    # Optionally, run the command
    subprocess.run(command, shell=True)


def main():
    if len(sys.argv) != 2:
        print("Usage: substream <port>")
        sys.exit(1)

    argument = sys.argv[1]
    ip = '<your-domain-name/ip>' 

    port = fetch_port(ip)
    run_ssh_command(port, argument)


if __name__ == "__main__":
    main()
