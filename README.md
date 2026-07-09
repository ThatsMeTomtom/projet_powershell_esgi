# Projet PowerShell ESGI

Infrastructure multi-serveurs pour DHCP (Linux) et Active Directory (Windows).

## Structure du Projet

```
├── linux/
│   ├── dhcp/                  # DHCP Server (Docker)
│   │   ├── docker-compose.yml
│   │   ├── dhcpd.conf
│   │   ├── start.sh
│   │   └── README.md
│   └── web/                   # Public + intranet websites (Docker)
│       ├── docker-compose.yml # Port 80 exposed by reverse-proxy
│       ├── nginx/
│       ├── sites/
│       └── README.md
├── windows/                   # Windows Server (PowerShell)
│   ├── ad/                    # Active Directory setup
│   └── (PowerShell scripts)
├── src/
└── README.md
```

## Démarrage Rapide

### Linux (DHCP + Web) — déploiement en 1 clic

Depuis le serveur Debian où le dépôt a été cloné :

```bash
cd linux
bash deploy.sh
```

Ce script installe Docker si besoin, récupère la dernière version du code (`git pull`),
puis démarre le serveur DHCP et le stack web (sites public + intranet). Idempotent :
peut être relancé à tout moment pour redéployer les dernières modifications.

Pour ne déployer qu'un seul des deux services :

```bash
bash linux/dhcp/start.sh   # DHCP uniquement
bash linux/web/start.sh    # Web uniquement
```

### Windows Server — déploiement depuis Ansible (WSL2)

```bash
cd ansible
ansible-playbook playbooks/99-run-all.yml --ask-vault-pass
```

Ce playbook enchaîne automatiquement : création VM → installation Windows → promotion AD DS → configuration complète (OUs, comptes, partages, DHCP, DFS, impression, GPOs).

---

### Windows Server — déploiement manuel depuis l'intérieur de la VM

Si la VM tourne déjà avec AD DS configuré et que tu veux exécuter les scripts directement depuis une session PowerShell sur le serveur :

**1. Copier les scripts sur le serveur** (ou cloner le dépôt) :
```powershell
# Depuis PowerShell sur SRV-WIN01, copier le dossier windows\ et data\ au même niveau :
# C:\deploiement\
# ├── windows\   (tous les scripts .ps1)
# └── data\      (LouiseMichel_Utilisateurs.csv)
```

**2. Promouvoir le serveur en contrôleur de domaine :**
```powershell
cd C:\deploiement\windows
powershell.exe -ExecutionPolicy Bypass -File .\01-Install-ADDS-DNS.ps1
```
> La VM **redémarre automatiquement** à la fin de ce script. Les fichiers dans `C:\deploiement\` persistent après le redémarrage, mais Windows ne reprend pas l'installation tout seul — il faut se reconnecter et continuer manuellement.

**3. Après le redémarrage, se reconnecter en `LMICHEL\Administrateur` puis lancer le reste :**
```powershell
cd C:\deploiement\windows
powershell.exe -ExecutionPolicy Bypass -File .\99-Deploy-All.ps1
```

**4. Ou script par script (dans l'ordre) :**
```powershell
cd C:\deploiement\windows
powershell.exe -ExecutionPolicy Bypass -File .\02-New-OUsEtGroupes.ps1
powershell.exe -ExecutionPolicy Bypass -File .\03-New-PasswordPolicies.ps1
powershell.exe -ExecutionPolicy Bypass -File .\04-New-PartagesEtACL.ps1
powershell.exe -ExecutionPolicy Bypass -File .\05-New-QuotasFSRM.ps1
powershell.exe -ExecutionPolicy Bypass -File .\06-Import-Utilisateurs.ps1
powershell.exe -ExecutionPolicy Bypass -File .\07-New-DFSNamespace.ps1
powershell.exe -ExecutionPolicy Bypass -File .\08-New-ServeurImpression.ps1
powershell.exe -ExecutionPolicy Bypass -File .\09-New-DHCPScope.ps1
powershell.exe -ExecutionPolicy Bypass -File .\10-New-SauvegardeQuotidienne.ps1
powershell.exe -ExecutionPolicy Bypass -File .\11-New-GPOs.ps1
```

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
