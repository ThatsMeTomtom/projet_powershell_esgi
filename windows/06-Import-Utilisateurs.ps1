Import-Module ActiveDirectory
. "$PSScriptRoot\00-Variables.ps1"

$DomainDN    = (Get-ADDomain).DistinguishedName
$ouEcoleDN   = "OU=LouiseMichel,$DomainDN"
$ouDirection = "OU=Direction,$ouEcoleDN"
$ouEnseign   = "OU=Enseignants,$ouEcoleDN"
$ouEleves    = "OU=Eleves,$ouEcoleDN"

function Remove-Diacritics {
    param([string]$Text)
    $normalized = $Text.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $normalized.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne
            [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString().Normalize([Text.NormalizationForm]::FormC)
}

function Format-ForLogin {
    param([string]$Text)
    $t = Remove-Diacritics $Text
    $t = $t -replace '[^a-zA-Z0-9]', ''
    return $t.ToLower()
}

function Format-NomAffichage {
    param([string]$Nom, [string]$Prenom)
    $prenomCap = (Get-Culture).TextInfo.ToTitleCase($Prenom.ToLower())
    $nomMaj    = $Nom.ToUpper()
    return "$prenomCap $nomMaj"
}

# Charge tous les SAMs existants pour eviter les doublons a la generation
$usedSams = @{}
Get-ADUser -Filter * -Properties SamAccountName |
    ForEach-Object { $usedSams[$_.SamAccountName.ToLower()] = $true }

function Get-UniqueSam {
    param([string]$Prenom, [string]$Nom)
    $prenomClean = Format-ForLogin $Prenom
    $nomClean    = Format-ForLogin $Nom
    if ([string]::IsNullOrEmpty($prenomClean)) { $prenomClean = "x" }
    $base = ($prenomClean.Substring(0,1) + $nomClean)
    if ($base.Length -gt 20) { $base = $base.Substring(0,20) }
    $candidate = $base
    $n = 1
    while ($usedSams.ContainsKey($candidate)) {
        $n++
        $suffix = "$n"
        $maxLen = 20 - $suffix.Length
        $candidate = $base.Substring(0, [Math]::Min($base.Length, $maxLen)) + $suffix
    }
    $usedSams[$candidate] = $true
    return $candidate
}

$usedUpns = @{}
function Get-UniqueUpn {
    param([string]$Prenom, [string]$Nom)
    $base = "$(Format-ForLogin $Prenom).$(Format-ForLogin $Nom)"
    $candidate = "$base@$DomainName"
    $n = 1
    while ($usedUpns.ContainsKey($candidate)) {
        $n++
        $candidate = "$base$n@$DomainName"
    }
    $usedUpns[$candidate] = $true
    return $candidate
}

function New-LogonHoursMask {
    param([int[]]$Jours, [int]$HeureDebut, [int]$HeureFinInclusive)
    $bits = New-Object bool[] 168
    foreach ($j in $Jours) {
        for ($h = $HeureDebut; $h -le $HeureFinInclusive; $h++) {
            $bits[$j * 24 + $h] = $true
        }
    }
    $bytes = New-Object byte[] 21
    for ($i = 0; $i -lt 168; $i++) {
        if ($bits[$i]) {
            $byteIdx = [Math]::Floor($i / 8)
            $bitIdx  = $i % 8
            $bytes[$byteIdx] = $bytes[$byteIdx] -bor (1 -shl $bitIdx)
        }
    }
    return $bytes
}

$HoursDirection   = New-LogonHoursMask -Jours 0,1,2,3,4,5,6 -HeureDebut 0 -HeureFinInclusive 23
$HoursEnseignants = New-LogonHoursMask -Jours 1,2,3,4,5     -HeureDebut 7 -HeureFinInclusive 19
$HoursEleves      = New-LogonHoursMask -Jours 1,2,3,4,5     -HeureDebut 9 -HeureFinInclusive 16

$securePwd = ConvertTo-SecureString $DefaultTempPassword -AsPlainText -Force

$rows = Import-Csv -Path $CsvUtilisateurs -Encoding UTF8
Write-Host "Import de $($rows.Count) comptes depuis $CsvUtilisateurs ..." -ForegroundColor Cyan

$compteur = 0
foreach ($row in $rows) {

    $prenom      = $row.Prenom.Trim()
    $nom         = $row.Nom.Trim()
    $role        = $row.Role.Trim()
    $classeLabel = if ($row.Classe) { "Classe" + ($row.Classe -replace '[^0-9]', '') } else { $null }
    $displayName = Format-NomAffichage -Nom $nom -Prenom $prenom

    switch ($role) {
        "Direction" {
            $targetOU   = $ouDirection
            $groupes    = @("GG-Direction")
            $logonHours = $HoursDirection
        }
        "Enseignant" {
            $targetOU   = $ouEnseign
            $groupes    = @("GG-Enseignants")
            $logonHours = $HoursEnseignants
        }
        "Eleve" {
            $targetOU   = "OU=$classeLabel,$ouEleves"
            $groupes    = @("GG-Eleves-$classeLabel", "GG-Eleves-Toutes")
            $logonHours = $HoursEleves
        }
        default {
            Write-Warning "Role inconnu pour $prenom $nom ($role) - ligne ignoree"
            continue
        }
    }

    # Idempotence : verifier par le nom d'affichage (CN).
    # LDAPFilter evite les erreurs de parsing sur les noms avec apostrophe.
    $escapedName  = $displayName -replace '\\','\5c' -replace '\(','\28' -replace '\)','\29' -replace '\*','\2a'
    $existingUser = Get-ADUser -LDAPFilter "(name=$escapedName)" -SearchBase $ouEcoleDN -ErrorAction SilentlyContinue

    if ($existingUser) {
        $sam = $existingUser.SamAccountName
    } else {
        $sam     = Get-UniqueSam -Prenom $prenom -Nom $nom
        $upn     = Get-UniqueUpn -Prenom $prenom -Nom $nom
        $homeDir = "\\$SrvWinName\Perso`$\$sam"

        New-ADUser `
            -Name $displayName `
            -GivenName $prenom `
            -Surname $nom `
            -DisplayName $displayName `
            -SamAccountName $sam `
            -UserPrincipalName $upn `
            -Path $targetOU `
            -AccountPassword $securePwd `
            -Enabled $true `
            -ChangePasswordAtLogon $true `
            -HomeDrive "P" `
            -HomeDirectory $homeDir `
            -Description "$role - $SchoolName (import lot)" | Out-Null
    }

    # Groupes (idempotent : ErrorAction SilentlyContinue si deja membre)
    foreach ($g in $groupes) {
        Add-ADGroupMember -Identity $g -Members $sam -ErrorAction SilentlyContinue
    }

    # Horaires de connexion (ADSI pour eviter les erreurs 8318/8317 du module AD)
    $dn = (Get-ADUser -Identity $sam).DistinguishedName
    $entry = [ADSI]"LDAP://$dn"
    $entry.Put("logonHours", [byte[]]$logonHours)
    $entry.SetInfo()

    # Dossier personnel P:
    $persoPath = Join-Path $PersoRoot $sam
    if (-not (Test-Path $persoPath)) {
        New-Item -Path $persoPath -ItemType Directory -Force | Out-Null
        icacls $persoPath /inheritance:d | Out-Null
        icacls $persoPath /grant "SYSTEM:(OI)(CI)F" "$DomainNetBIOS\${GrpDomainAdmins}:(OI)(CI)F" `
            "$DomainNetBIOS\GG-ServiceInformatique:(OI)(CI)M" `
            "$DomainNetBIOS\${sam}:(OI)(CI)M" | Out-Null
    }

    # Dossier nominatif enseignant dans Enseignants$
    if ($role -eq "Enseignant") {
        $ensPath = Join-Path $DirEnseignants $displayName
        if (-not (Test-Path $ensPath)) { New-Item -Path $ensPath -ItemType Directory -Force | Out-Null }
    }

    $compteur++
    if ($compteur % 50 -eq 0) { Write-Host "  ... $compteur comptes traites" -ForegroundColor DarkGray }
}

Write-Host "$compteur comptes crees/mis a jour (mot de passe : $DefaultTempPassword, changement oblig. 1ere connexion)." -ForegroundColor Green
Write-Host "Export de la liste des identifiants ..." -ForegroundColor Cyan

Get-ADUser -SearchBase $ouEcoleDN -Filter * -Properties SamAccountName,UserPrincipalName,DistinguishedName |
    Select-Object Name, SamAccountName, UserPrincipalName,
        @{N="OU";E={($_.DistinguishedName -split ',',2)[1]}} |
    Export-Csv -Path (Join-Path (Split-Path $PSScriptRoot -Parent) "data\Identifiants_Generes.csv") `
        -NoTypeInformation -Encoding UTF8

Write-Host "-> data\Identifiants_Generes.csv" -ForegroundColor Yellow
