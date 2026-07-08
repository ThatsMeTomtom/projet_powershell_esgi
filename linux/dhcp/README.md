# Linux DHCP Server

Lightweight DHCP server running in Docker using `networkboot/dhcpd`.

## Fresh Debian 13 Setup

On a brand new Debian 13 server with SSH enabled and nothing else installed, run:

```bash
cd /opt
sudo git clone <your-repo-url> projet_powershell_esgi
cd projet_powershell_esgi/linux/dhcp
bash install.sh
bash start.sh
```

If Docker is already installed, you can skip `install.sh` and just run `bash start.sh`.

## Quick Start

### Pull and Run

```bash
cd linux/dhcp
bash start.sh
```

### Check Status

```bash
docker compose ps
docker compose logs -f dhcp
```

### Stop

```bash
docker compose down
```

## Configuration

Edit `dhcpd.conf` to customize:
- **IP Range**: Modify the `range` directive in the subnet block (currently 10.10.1.0 - 10.10.254.254)
- **Gateway**: Change `option routers 10.10.0.1`
- **DNS Servers**: Update `option domain-name-servers`
- **Static IPs**: Uncomment and add `host` blocks for MAC-to-IP mapping

Changes to `dhcpd.conf` require a container restart:

```bash
docker compose restart dhcp
```

## Network Details

- **Subnet**: 10.10.0.0/16
- **Default Lease Time**: 600 seconds
- **Max Lease Time**: 7200 seconds
- **Container Mode**: Host (direct network access)

## Docker Compose Features

- Mounts DHCP config from `dhcpd.conf`
- Persistent volume for DHCP leases (`dhcp-data`)
- Auto-restart on failure
- Runs with `NET_ADMIN` capability for network operations
