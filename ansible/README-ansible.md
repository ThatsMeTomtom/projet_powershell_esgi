# Créer SRV-WIN01 avec Ansible + VirtualBox

## Pourquoi WSL2

Ansible ne tourne pas nativement sous Windows (il lui faut un OS
POSIX comme nœud de contrôle). On l'installe donc dans **WSL2**, et
WSL2 peut appeler directement `VBoxManage.exe` (le binaire Windows de
VirtualBox) grâce à l'interopérabilité WSL↔Windows. C'est ce qui permet
à ce playbook de piloter VirtualBox depuis Linux sans machine
intermédiaire.

## Installation (une seule fois)

Dans PowerShell (Windows), en administrateur :
```powershell
wsl --install -d Ubuntu
```
Redémarrez si demandé, puis ouvrez Ubuntu (menu Démarrer) et configurez
votre utilisateur Linux. Ensuite, **dans Ubuntu/WSL** :

```bash
sudo apt update
sudo apt install -y ansible genisoimage python3-pip
pip install pywinrm
ansible-galaxy collection install ansible.windows community.general
```

## Avant de lancer quoi que ce soit

Éditez **`vars/main.yml`** :
- `windows_iso_path_win` → le chemin **Windows** (pas WSL) de votre ISO,
  ex. `C:\\Users\\Enzo\\Downloads\\SERVER_EVAL_x64FRE_fr-fr.iso`
  (gardez les doubles antislashs `\\` en YAML)
- `admin_password` → changez le mot de passe par défaut

## Lancement

Depuis WSL/Ubuntu, dans le dossier `ansible/` :
```bash
ansible-playbook playbooks/99-run-all.yml
```

Ou étape par étape (utile pour déboguer) :
```bash
ansible-playbook playbooks/00-check-prereqs.yml
ansible-playbook playbooks/01-create-vm.yml       # cree + demarre la VM (fenetre VirtualBox visible)
ansible-playbook playbooks/02-wait-winrm.yml       # patiente pendant l'install Windows (15-30 min)
ansible-playbook playbooks/03-push-scripts.yml     # copie windows/ + data/ sur la VM
```

## Ce que ça fait

1. Vérifie VBoxManage, l'ISO, installe `genisoimage`, crée le réseau
   privé hôte VirtualBox (`vboxnet0`, hôte = 10.15.0.1).
2. Génère un `autounattend.xml` (langue fr-FR, édition Windows Server
   2022 Standard avec interface graphique, mot de passe Administrateur,
   activation de WinRM au 1er démarrage) et le grave sur un petit ISO.
3. Crée la VM (4 Go RAM, 2 vCPU, disque 60 Go), attache le disque + les
   2 ISO (installation + réponses), démarre la VM en mode fenêtré pour
   que vous puissiez suivre l'installation à l'écran.
4. Attend que Windows ait fini de s'installer et que WinRM réponde sur
   `10.15.0.10:5985` (jusqu'à 45 min), puis teste la connexion.
5. Copie `windows/` et `data/` (les scripts déjà livrés) dans
   `C:\deploiement` sur la VM.

## Deux points fragiles à vérifier si ça bloque

**L'installation de Windows ne demande jamais rien mais reste bloquée
sur un écran de sélection d'édition** → l'index d'édition
(`image_index` dans `vars/main.yml`) ne correspond pas à votre ISO.
Montez l'ISO sur Windows (double-clic) et lancez :
```powershell
Get-WindowsImage -ImagePath D:\sources\install.wim
```
(`D:` = lettre montée). Repérez l'index de "Windows Server 2022
Standard (Desktop Experience)", ajustez `image_index`, relancez
`01-create-vm.yml` (il faudra supprimer la VM et le disque existants
d'abord : `VBoxManage unregistervm SRV-WIN01 --delete`).

**`02-wait-winrm.yml` timeout après 45 minutes** → la commande
PowerShell qui configure l'IP statique n'a peut-être pas trouvé le bon
adaptateur réseau. Ouvrez la fenêtre VirtualBox de la VM (elle est
restée ouverte), connectez-vous en `Administrateur` avec le mot de
passe défini dans `vars/main.yml`, et vérifiez/corrigez à la main :
```powershell
Get-NetIPConfiguration
New-NetIPAddress -InterfaceIndex <index_du_bon_adaptateur> -IPAddress 10.15.0.10 -PrefixLength 24
winrm quickconfig -quiet
```
Relancez ensuite juste `02-wait-winrm.yml`.

## Après ça

`03-push-scripts.yml` copie les scripts mais **ne lance pas** le script
01 (`01-Install-ADDS-DNS.ps1`) : il demande le mot de passe DSRM en
saisie interactive et redémarre le serveur, ce qui ne marche pas bien
en exécution WinRM à distance. Connectez-vous à la VM (fenêtre
VirtualBox ou RDP) et lancez-le normalement, puis reconnectez-vous et
lancez `99-Deploy-All.ps1` comme prévu dans `doc/README.md`.
