<#
====================================================================
 08-New-ServeurImpression.ps1
 Etape 8/11 : serveur d'impression.

 Principe retenu pour la priorite "Direction/Enseignants d'abord" sur
 UNE seule imprimante physique : on cree DEUX files logiques qui
 pointent vers le MEME port (donc la meme imprimante physique), avec
 une priorite Windows differente (1-99, la plus haute est servie en
 premier en cas de file d'attente). C'est la technique standard cote
 serveur d'impression Windows pour prioriser des groupes d'utilisateurs
 sur un materiel partage, sans acheter une 2e imprimante.

   Impr-Ecole-Staff  (priorite 99) -> Direction + Enseignants
   Impr-Ecole-Eleves (priorite 1)  -> Eleves

 A ADAPTER : IP de l'imprimante et pilote (driver) reels une fois le
 materiel connu. Le pilote choisi ici (Microsoft PCL6 Class Driver)
 est un pilote generique inbox de Windows Server 2022, qui supporte le
 recto-verso ; remplacez-le par le pilote constructeur si besoin de
 fonctionnalites specifiques.
====================================================================
#>

. "$PSScriptRoot\00-Variables.ps1"

$PrinterIP     = "10.15.0.30"                          # IP reelle de l'imprimante a renseigner
$PrinterPort   = "IP_10.15.0.30"
$PrinterDriver = "Microsoft PCL6 Class Driver"           # pilote inbox generique, a remplacer si besoin

Write-Host "Installation du role Serveur d'impression ..." -ForegroundColor Cyan
Install-WindowsFeature -Name Print-Server -IncludeManagementTools
Import-Module PrintManagement

# 1) Port TCP/IP vers l'imprimante physique
if (-not (Get-PrinterPort -Name $PrinterPort -ErrorAction SilentlyContinue)) {
    Add-PrinterPort -Name $PrinterPort -PrinterHostAddress $PrinterIP
}

# 2) Pilote
if (-not (Get-PrinterDriver -Name $PrinterDriver -ErrorAction SilentlyContinue)) {
    Add-PrinterDriver -Name $PrinterDriver
}

# 3) Deux files logiques sur le meme port, priorite differente
function New-QueueIfMissing {
    param([string]$Name, [int]$Priority)
    if (-not (Get-Printer -Name $Name -ErrorAction SilentlyContinue)) {
        Add-Printer -Name $Name -DriverName $PrinterDriver -PortName $PrinterPort `
            -Shared $true -ShareName $Name -Priority $Priority
    }
    # Config par defaut : Noir & Blanc, recto-verso bord long
    Set-PrintConfiguration -PrinterName $Name -Color $false -DuplexingMode TwoSidedLongEdge
}

New-QueueIfMissing -Name "Impr-Ecole-Staff"  -Priority 99
New-QueueIfMissing -Name "Impr-Ecole-Eleves" -Priority 1

Write-Host "Files d'impression creees : Impr-Ecole-Staff (prio 99) / Impr-Ecole-Eleves (prio 1)." -ForegroundColor Green
Write-Host ""
Write-Host "A FAIRE MANUELLEMENT (pas de cmdlet natif fiable pour l'ACL imprimante) :" -ForegroundColor Yellow
Write-Host "  Gestion de l'impression > Imprimantes > [Impr-Ecole-Staff]  > Proprietes > Securite" -ForegroundColor Yellow
Write-Host "    -> Ajouter GG-Direction et GG-Enseignants : Imprimer = Autoriser" -ForegroundColor Yellow
Write-Host "  Meme ecran sur [Impr-Ecole-Eleves] -> GG-Eleves-Toutes : Imprimer = Autoriser" -ForegroundColor Yellow
Write-Host "  (Le deploiement automatique de la connexion sur les postes est gere par le script d'ouverture de session, cf LogonScript.ps1)" -ForegroundColor DarkGray
