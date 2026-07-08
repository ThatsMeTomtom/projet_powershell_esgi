# Projet PowerShell ESGI

Infrastructure multi-serveurs pour DHCP (Linux) et Active Directory (Windows).

## Structure du Projet

```
├── linux/
│   └── dhcp/                  # DHCP Server (Docker)
│       ├── docker-compose.yml
│       ├── dhcpd.conf
│       ├── start.sh
│       └── README.md
├── windows/                   # Windows Server (PowerShell)
│   ├── ad/                    # Active Directory setup
│   └── (PowerShell scripts)
├── src/
└── README.md
```

## Démarrage Rapide

### Linux DHCP Server

Plug and play - pull and run:

```bash
# Option 1: Automated startup (pulls latest + starts)
bash linux/dhcp/start.sh

# Option 2: Manual startup
cd linux/dhcp
git pull
docker-compose up -d
```

### Windows Server

See `windows/README.md` for PowerShell-based setup.

## Configuration

- **Linux DHCP**: Edit `linux/dhcp/dhcpd.conf` for subnet/DNS configuration
- **Windows**: See Windows server documentation

## Logs & Monitoring

```bash
# View DHCP logs
docker-compose -f linux/dhcp/docker-compose.yml logs -f

# Stop DHCP
docker-compose -f linux/dhcp/docker-compose.yml down
```
