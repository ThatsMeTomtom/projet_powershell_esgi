# --- Identite du domaine ---------------------------------------------------
$Global:DomainName    = "louise-michel.edu"
$Global:DomainNetBIOS = "LMICHEL"
$Global:SchoolName    = "Louise Michel"

# --- Plan d'adressage (demo) ------------------------------------------------
# Ecole = VLAN 15 (15 classes). A adapter pour les 6 autres ecoles
# (Jules Ferry = VLAN 1, Simone Veil = VLAN 2, etc.)
$Global:Subnet         = "10.15.0.0"
$Global:PrefixLength   = 24
$Global:SubnetMask     = "255.255.255.0"
$Global:Gateway        = "10.15.0.1"

$Global:SrvWinName     = "SRV-WIN01"
$Global:SrvWinIP       = "10.15.0.10"
$Global:SrvLinuxName   = "SRV-LNX01"
$Global:SrvLinuxIP     = "10.15.0.11"
$Global:ClientTestIP   = "10.15.0.50"   # IP fixe optionnelle du poste de test

# Reservations :
#   .1        routeur / passerelle
#   .2-.9     reserve infra (futurs serveurs / hyperviseur)
#   .10-.19   serveurs (WIN01=.10, LNX01=.11)
#   .20-.49   imprimantes / equipements reseau
#   .100-.250 pool DHCP clients (split 80/20 Windows/Linux, cf script 09)
#   .251-.254 reserve

$Global:DhcpPoolStart      = "10.15.0.100"
$Global:DhcpPoolEnd        = "10.15.0.250"
$Global:DhcpLinuxRangeStart = "10.15.0.100"   # 20% -> Linux (isc-dhcp-server)
$Global:DhcpLinuxRangeEnd   = "10.15.0.130"
$Global:DhcpWinRangeStart   = "10.15.0.131"   # 80% -> Windows DHCP
$Global:DhcpWinRangeEnd     = "10.15.0.250"

$Global:DNSServers     = @($SrvWinIP)

# --- Arborescence disque sur SRV-WIN01 --------------------------------------
$Global:PartagesRoot   = "D:\Partages"
$Global:DirDirection   = "$PartagesRoot\Direction"
$Global:DirEnseignants = "$PartagesRoot\Enseignants"
$Global:DirClasses     = "$PartagesRoot\Classes"
$Global:PersoRoot      = "D:\Perso"
$Global:BackupDrive    = "E:"

# --- Noms des groupes integres (DEPEND DE LA LANGUE DE L'ISO WINDOWS SERVER) --
# Sur une version FR de Windows Server, Install-ADDSForest cree les groupes
# integres avec des noms DEJA en francais (ce n'est pas juste l'affichage
# GUI qui est traduit, le SamAccountName reel change). Verifiez avec :
#   Get-ADGroup -Filter * | Where-Object {$_.GroupScope -eq 'Global' -and $_.GroupCategory -eq 'Security'} | Select Name
# et ajustez les 2 lignes ci-dessous si besoin (valeurs FR en commentaire).
$Global:GrpDomainAdmins = "Domain Admins"   # FR : "Admins du domaine"
$Global:GrpDomainUsers  = "Domain Users"    # FR : "Utilisateurs du domaine"

# --- Comptes ------------------------------------------------------------
# Mot de passe provisoire commun, changement OBLIGATOIRE a la 1ere connexion.
# En production reelle, prevoir un mot de passe genere aleatoirement par
# utilisateur (voir la remarque dans 06-Import-Utilisateurs.ps1).
$Global:DefaultTempPassword = "Ecole2026!"

# --- Fichier source des comptes a importer -----------------------------
# Chemin relatif : gardez le dossier "data\" a cote du dossier "windows\"
# (structure livree telle quelle) et ca fonctionne sans rien modifier.
$Global:CsvUtilisateurs = Join-Path (Split-Path $PSScriptRoot -Parent) "data\LouiseMichel_Utilisateurs.csv"

# --- Quota espace personnel P: -------------------------------------------
$Global:QuotaPersoMo        = 1024   # 1 Go
$Global:QuotaAlertPercent   = 90     # alerte a 90% (soit 10% restant)

Write-Host "Variables chargees pour l'ecole : $SchoolName ($DomainName)" -ForegroundColor Cyan
