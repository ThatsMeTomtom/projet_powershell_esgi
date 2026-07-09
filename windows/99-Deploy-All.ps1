$ErrorActionPreference = "Stop"
. "$PSScriptRoot\00-Variables.ps1"

# Verification rapide que l'AD est operationnel avant de lancer les scripts
try {
    Get-ADDomain -Server localhost -ErrorAction Stop | Out-Null
} catch {
    Write-Host "Les services Active Directory ne sont pas encore prets." -ForegroundColor Red
    Write-Host "Patientez quelques instants apres le redemarrage puis relancez ce script." -ForegroundColor Yellow
    exit 1
}

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
