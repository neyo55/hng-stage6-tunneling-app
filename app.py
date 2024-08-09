from flask import Flask
import socket
import os

app = Flask(__name__)

def find_available_port():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("", 0))
    s.listen(1)
    port = s.getsockname()[1]
    s.close()
    return port

@app.route('/')
def get_port():
    # Find an available port
    port = find_available_port()

    # Log that a request was received and the port found
    print(f"Request received! Available port: {port}")

    directory = "/tmp"  # Specify the directory where you want to save port.txt
    if not os.path.exists(directory):
        os.makedirs(directory)

    file_path = os.path.join(directory, "port.txt")
    with open(file_path, "w") as file:
        file.write(str(port))

    # Return the response with the port number included in the message
    return f"{port}", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
