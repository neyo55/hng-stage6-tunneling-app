# SubStream
A Self hosted Alternative Tunneling Service to ngrok or serveo

SubStream is a dynamic port forwarding service that enables users to expose their local services to the internet using randomly generated subdomains. The service is designed to be lightweight and efficient

Read the docs here for a more detailed overview of this service [here](https://github.com/rotimiAbiola/SubStream/wiki)

Other wise to set up this service clone this repository and cd into it
```
git clone https://github.com/rotimiAbiola/SubStream
cd SubStream
```
Run the set up file and follow any prompts that come up
```
chmod +x setup_substream.sh
sudo ./setup_substream
```
Thats it your hosted server  is running.

## Client Side Handling
On the `cli.sh` file remap <your-client-ip> to your actual ip or domain name
and send the file to your clients.

```
chmod +x cli.sh
sudo ./cli.sh
```


