Import-Module ActiveDirectory
Import-Module DnsServer
. "$PSScriptRoot\00-Variables.ps1"

$DomainDN = (Get-ADDomain).DistinguishedName

# ------------------------------------------------------------------
# 1) Zone DNS inverse (la zone directe louise-michel.edu existe deja,
#    creee automatiquement par Install-ADDSForest -InstallDns)
# ------------------------------------------------------------------
Write-Host "Creation de la zone DNS inverse pour $Subnet/$PrefixLength ..." -ForegroundColor Cyan
$reverseZoneName = "0.15.10.in-addr.arpa"
if (-not (Get-DnsServerZone -Name $reverseZoneName -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -NetworkID "$Subnet/$PrefixLength" -ReplicationScope "Domain"
}
# Autoriser les mises a jour dynamiques securisees (postes joints au domaine)
Set-DnsServerPrimaryZone -Name $DomainName -DynamicUpdate Secure
Set-DnsServerPrimaryZone -Name $reverseZoneName -DynamicUpdate Secure

# ------------------------------------------------------------------
# 2) Unites d'organisation
# ------------------------------------------------------------------
Write-Host "Creation des unites d'organisation ..." -ForegroundColor Cyan

function New-OUIfMissing {
    param([string]$Name, [string]$ParentDN)
    $ouDN = "OU=$Name,$ParentDN"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $Name -Path $ParentDN -ProtectedFromAccidentalDeletion $true
        Write-Host "  OU creee : $ouDN"
    }
    return $ouDN
}

# OU racine de l'ecole (permet de reproduire la meme structure pour les
# 6 autres ecoles sans collision de noms sous le meme domaine si un jour
# le domaine est mutualise)
$ouEcoleDN       = New-OUIfMissing -Name "LouiseMichel"        -ParentDN $DomainDN
$ouDirectionDN   = New-OUIfMissing -Name "Direction"           -ParentDN $ouEcoleDN
$ouEnseignantsDN = New-OUIfMissing -Name "Enseignants"         -ParentDN $ouEcoleDN
$ouElevesDN      = New-OUIfMissing -Name "Eleves"              -ParentDN $ouEcoleDN
$ouGroupesDN     = New-OUIfMissing -Name "Groupes"              -ParentDN $ouEcoleDN
$ouOrdisDN       = New-OUIfMissing -Name "Postes"              -ParentDN $ouEcoleDN
$ouServeursDN    = New-OUIfMissing -Name "Serveurs"             -ParentDN $ouEcoleDN

# Sous-OU postes par population (utile pour cibler les GPO machine)
New-OUIfMissing -Name "Postes-Direction"   -ParentDN $ouOrdisDN | Out-Null
New-OUIfMissing -Name "Postes-Enseignants" -ParentDN $ouOrdisDN | Out-Null
New-OUIfMissing -Name "Postes-Eleves"      -ParentDN $ouOrdisDN | Out-Null

# Une sous-OU "Eleves\ClasseX" par classe presente dans le fichier source
$classes = Import-Csv -Path $CsvUtilisateurs -Encoding UTF8 |
    Where-Object { $_.Role -eq "Eleve" } |
    Select-Object -ExpandProperty Classe -Unique |
    ForEach-Object { $_.Trim().ToLower() } | Sort-Object -Unique

foreach ($classe in $classes) {
    # Normalise "classe1" -> "Classe1"
    $classeLabel = "Classe" + ($classe -replace '[^0-9]', '')
    New-OUIfMissing -Name $classeLabel -ParentDN $ouElevesDN | Out-Null
}

# ------------------------------------------------------------------
# 3) Groupes de securite globaux
# ------------------------------------------------------------------
Write-Host "Creation des groupes de securite ..." -ForegroundColor Cyan

function New-GroupIfMissing {
    param([string]$Name, [string]$Path, [string]$Description)
    if (-not (Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $Name -SamAccountName $Name -GroupScope Global -GroupCategory Security `
            -Path $Path -Description $Description
        Write-Host "  Groupe cree : $Name"
    }
}

New-GroupIfMissing -Name "GG-Direction"   -Path $ouGroupesDN -Description "Direction ecole $SchoolName"
New-GroupIfMissing -Name "GG-Enseignants" -Path $ouGroupesDN -Description "Enseignants ecole $SchoolName"

foreach ($classe in $classes) {
    $classeLabel = "Classe" + ($classe -replace '[^0-9]', '')
    New-GroupIfMissing -Name "GG-Eleves-$classeLabel" -Path $ouGroupesDN `
        -Description "Eleves $classeLabel - $SchoolName"
}

# Groupe transverse pratique pour les ACL/GPO qui s'appliquent a tous les eleves
New-GroupIfMissing -Name "GG-Eleves-Toutes" -Path $ouGroupesDN -Description "Tous les eleves - $SchoolName"

# Groupe "Service informatique" (SNTS) : acces support sur tous les postes
New-GroupIfMissing -Name "GG-ServiceInformatique" -Path $ouGroupesDN -Description "Techniciens SNTS"

Write-Host "Structure d'UO et groupes crees." -ForegroundColor Green
