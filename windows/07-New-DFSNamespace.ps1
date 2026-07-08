<#
====================================================================
 07-New-DFSNamespace.ps1
 Etape 7/11 : espace de noms DFS (\\louise-michel.edu\Partages).

 Avec un seul serveur de fichiers, DFS n'apporte pas encore de
 redondance (pas de 2e cible = pas de replication DFS-R possible),
 mais il decouple le CHEMIN vu par les clients (\\domaine\Partages\...)
 du SERVEUR physique qui l'heberge. C'est ce qui rend la solution
 evolutive : le jour ou un 2e serveur de fichiers est ajoute, on
 ajoute juste une 2e cible de dossier + la replication DFS-R, sans
 reconfigurer un seul poste client ni changer le script d'ouverture
 de session.
====================================================================
#>

. "$PSScriptRoot\00-Variables.ps1"

Write-Host "Installation du role DFS Namespaces ..." -ForegroundColor Cyan
Install-WindowsFeature -Name FS-DFS-Namespace -IncludeManagementTools
Import-Module DFSN

# Partage racine dedie a l'espace de noms (dossier vide, uniquement un point d'entree)
$dfsRootPath = "D:\DFSRoots\Partages"
if (-not (Test-Path $dfsRootPath)) { New-Item -Path $dfsRootPath -ItemType Directory -Force | Out-Null }

if (-not (Get-SmbShare -Name "Partages" -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name "Partages" -Path $dfsRootPath `
        -FullAccess "$DomainNetBIOS\$GrpDomainAdmins" `
        -ReadAccess "$DomainNetBIOS\$GrpDomainUsers" | Out-Null
}

$namespacePath = "\\$DomainName\Partages"

if (-not (Get-DfsnRoot -Path $namespacePath -ErrorAction SilentlyContinue)) {
    Write-Host "Creation de la racine DFS $namespacePath ..." -ForegroundColor Cyan
    New-DfsnRoot -TargetPath "\\$SrvWinName\Partages" -Type DomainV2 -Path $namespacePath
}

function New-DfsFolderIfMissing {
    param([string]$FolderName, [string]$TargetShare)
    $dfsFolderPath = "$namespacePath\$FolderName"
    if (-not (Get-DfsnFolder -Path $dfsFolderPath -ErrorAction SilentlyContinue)) {
        New-DfsnFolder -Path $dfsFolderPath -TargetPath "\\$SrvWinName\$TargetShare"
        Write-Host "  Dossier DFS cree : $dfsFolderPath -> \\$SrvWinName\$TargetShare"
    }
}

New-DfsFolderIfMissing -FolderName "Direction"   -TargetShare "Direction$"
New-DfsFolderIfMissing -FolderName "Enseignants" -TargetShare "Enseignants$"
New-DfsFolderIfMissing -FolderName "Classes"     -TargetShare "Classes$"

Write-Host "Espace de noms DFS pret : $namespacePath" -ForegroundColor Green
Write-Host "(P: reste mappe directement sur \\$SrvWinName\Perso`$\<utilisateur>, hors DFS, car c'est un chemin nominatif propre a chacun)" -ForegroundColor DarkGray
