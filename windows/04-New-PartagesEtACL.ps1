Import-Module ActiveDirectory
. "$PSScriptRoot\00-Variables.ps1"

function Disable-Inheritance-And-Reset {
    param([string]$Path)
    icacls $Path /inheritance:d | Out-Null
    icacls $Path /remove "Utilisateurs authentifies" "Authenticated Users" "Users" "Utilisateurs" 2>$null | Out-Null
}

# ------------------------------------------------------------------
# 1) Arborescence disque
# ------------------------------------------------------------------
Write-Host "Creation de l'arborescence sur $PartagesRoot et $PersoRoot ..." -ForegroundColor Cyan

$folders = @($PartagesRoot, $DirDirection, $DirEnseignants, $DirClasses, $PersoRoot)
foreach ($f in $folders) {
    if (-not (Test-Path $f)) { New-Item -Path $f -ItemType Directory -Force | Out-Null }
}

$classes = Import-Csv -Path $CsvUtilisateurs -Encoding UTF8 |
    Where-Object { $_.Role -eq "Eleve" } |
    Select-Object -ExpandProperty Classe -Unique |
    ForEach-Object { "Classe" + ($_ -replace '[^0-9]', '') } | Sort-Object -Unique

foreach ($c in $classes) {
    $p = Join-Path $DirClasses $c
    if (-not (Test-Path $p)) { New-Item -Path $p -ItemType Directory -Force | Out-Null }
}

# ------------------------------------------------------------------
# 2) Partages reseau (partages "$" = masques, pas de decouverte reseau)
# ------------------------------------------------------------------
Write-Host "Creation des partages SMB ..." -ForegroundColor Cyan

function New-ShareIfMissing {
    param([string]$Name, [string]$Path)
    if (-not (Get-SmbShare -Name $Name -ErrorAction SilentlyContinue)) {
        # Permissions de partage larges : le verrouillage fin se fait au niveau NTFS
        New-SmbShare -Name $Name -Path $Path -FullAccess "$DomainNetBIOS\$GrpDomainAdmins" `
            -ChangeAccess "$DomainNetBIOS\$GrpDomainUsers" | Out-Null
    }
}

New-ShareIfMissing -Name "Direction$"   -Path $DirDirection
New-ShareIfMissing -Name "Enseignants$" -Path $DirEnseignants
New-ShareIfMissing -Name "Classes$"     -Path $DirClasses
New-ShareIfMissing -Name "Perso$"       -Path $PersoRoot

# ------------------------------------------------------------------
# 3) Permissions NTFS
# ------------------------------------------------------------------
Write-Host "Application des permissions NTFS ..." -ForegroundColor Cyan

# --- Direction : reserve a la direction ---
Disable-Inheritance-And-Reset -Path $DirDirection
icacls $DirDirection /grant "SYSTEM:(OI)(CI)F" "$DomainNetBIOS\$GrpDomainAdmins:(OI)(CI)F" `
    "$DomainNetBIOS\GG-Direction:(OI)(CI)M" | Out-Null

# --- Enseignants : Enseignants + Direction (lecture litterale du sujet, cf entete) ---
Disable-Inheritance-And-Reset -Path $DirEnseignants
icacls $DirEnseignants /grant "SYSTEM:(OI)(CI)F" "$DomainNetBIOS\$GrpDomainAdmins:(OI)(CI)F" `
    "$DomainNetBIOS\GG-Enseignants:(OI)(CI)M" "$DomainNetBIOS\GG-Direction:(OI)(CI)M" | Out-Null

# --- Classes (racine) : Enseignants + Direction voient toutes les classes ---
Disable-Inheritance-And-Reset -Path $DirClasses
icacls $DirClasses /grant "SYSTEM:(OI)(CI)F" "$DomainNetBIOS\$GrpDomainAdmins:(OI)(CI)F" `
    "$DomainNetBIOS\GG-Enseignants:(OI)(CI)M" "$DomainNetBIOS\GG-Direction:(OI)(CI)M" | Out-Null

# --- Chaque Classes\ClasseX : uniquement les eleves de CETTE classe (+ Enseignants/Direction via heritage racine) ---
foreach ($c in $classes) {
    $p = Join-Path $DirClasses $c
    icacls $p /inheritance:e | Out-Null   # on garde l'heritage de Classes$ (Enseignants/Direction)
    icacls $p /grant "$DomainNetBIOS\GG-Eleves-$c`:(OI)(CI)M" | Out-Null
}

# --- Perso (racine) : verrouillee, chaque sous-dossier utilisateur est traite
#     individuellement au moment de la creation du compte (script 06). Le
#     grant CREATOR OWNER ci-dessous est une securite pour la creation
#     auto cote client ; il est surtout complete par les ACL explicites
#     posees par le script 06 sur chaque sous-dossier.
Disable-Inheritance-And-Reset -Path $PersoRoot
icacls $PersoRoot /grant "SYSTEM:(OI)(CI)F" "$DomainNetBIOS\$GrpDomainAdmins:(OI)(CI)F" `
    "$DomainNetBIOS\GG-ServiceInformatique:(OI)(CI)M" | Out-Null
# CREATOR OWNER est un alias local traduit selon la langue de l'OS
# (ex: "CREATEUR PROPRIETAIRE" sur un Windows Server en francais) :
# on tente les deux formes, l'une des deux echouera silencieusement.
icacls $PersoRoot /grant "CREATOR OWNER:(OI)(CI)(IO)F" 2>$null | Out-Null
icacls $PersoRoot /grant "CREATEUR PROPRIETAIRE:(OI)(CI)(IO)F" 2>$null | Out-Null
icacls $PersoRoot /grant "$DomainNetBIOS\$GrpDomainUsers:(CI)(special : AD,CC)" 2>$null | Out-Null

Write-Host "Arborescence, partages et ACL de base en place." -ForegroundColor Green
