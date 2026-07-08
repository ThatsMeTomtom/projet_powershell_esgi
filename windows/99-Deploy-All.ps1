<#
====================================================================
 99-Deploy-All.ps1
 Enchaine les etapes 02 a 11 dans l'ordre logique "creer -> attribuer".
 A lancer sur SRV-WIN01, apres coup :
   1. Script 01 execute manuellement (provoque un reboot + reconnexion
      avec un compte Domain Admins, donc impossible a automatiser dans
      la meme session)
   2. Le dossier "data\LouiseMichel_Utilisateurs.csv" present a cote
      du dossier "windows\" (structure livree telle quelle)

 Usage : powershell.exe -ExecutionPolicy Bypass -File .\99-Deploy-All.ps1
====================================================================
#>

$ErrorActionPreference = "Stop"
$scripts = @(
    "02-New-OUsEtGroupes.ps1",
    "03-New-PasswordPolicies.ps1",
    "04-New-PartagesEtACL.ps1",
    "05-New-QuotasFSRM.ps1",
    "06-Import-Utilisateurs.ps1",
    "07-New-DFSNamespace.ps1",
    "08-New-ServeurImpression.ps1",
    "09-New-DHCPScope.ps1",
    "10-New-SauvegardeQuotidienne.ps1",
    "11-New-GPOs.ps1"
)

foreach ($s in $scripts) {
    $path = Join-Path $PSScriptRoot $s
    Write-Host "`n================ $s ================" -ForegroundColor Magenta
    & $path
}

Write-Host "`nDeploiement complet termine pour l'ecole Louise Michel." -ForegroundColor Green
Write-Host "Pensez a lancer un gpupdate /force sur le poste client de test." -ForegroundColor Yellow
