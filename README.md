# Smart Proxy EfficientIP (plugin)

## Requirements
- `Ruby >= 2.7`
- `Smart Proxy >= 2.3`

## Docker

1. Copy example of settings
```bash
cp config/docker_smart-proxy_settings/settings.d/dhcp_efficient_ip.yml.example config/docker_smart-proxy_settings/settings.d/dhcp_efficient_ip.yml
```
2. Fill in 3 necessary settings in `dhcp_efficient_ip.yml`:
- username
- password
- server_ip

3. Build and run container:

```bash
$ docker build -t smart_proxy_efficient_ip:latest .
$ docker run --rm --name smart_proxy_efficient_ip -it -p 4567:4567 smart_proxy_efficient_ip:latest
```

4. Enter to the container (optionally if needed)
```bash
$ docker exec -it smart_proxy_efficient_ip bash
```

## Postman

### Import endpoints
File > Import (Ctrl + O)

file: `postman/smart_proxy.postman_collection.json`

### Automated tests

1. Install `newman`
```bash
npm install -g newman
```
2. Run tests
```bash
newname run postman/smart_proxy.postman_collection.json
```
