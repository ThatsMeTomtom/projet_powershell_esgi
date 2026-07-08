<#
====================================================================
 11-New-GPOs.ps1
 Etape 11/11 (derniere etape "attribution") :
   A. GPO-Restriction-Eleves    -> pas d'installation de logiciels
   B. GPO-AccesDistant          -> RDP + WinRM ouverts sur tous les postes
   C. GPO-ScriptOuverture       -> deploiement de LogonScript.ps1
                                   (mappage lecteurs + imprimante)

 Rappel important sur (A) : la vraie protection contre l'installation
 de logiciels, c'est que les comptes eleves NE SONT JAMAIS ajoutes au
 groupe local Administrateurs (ils sont crees comme utilisateurs
 standards au script 06 - rien de plus a faire pour ca). Ce script
 ajoute une couche defense-en-profondeur scriptable (Windows Installer
 desactive + Panneau de configuration masque). Le verrouillage du
 groupe Administrateurs local via "Groupes restreints" n'a pas de
 cmdlet PowerShell dedie fiable (il faut editer le modele de securite
 GptTmpl.inf de la GPO) : a faire en 2 clics via gpmc.msc si vous
 voulez une ceinture-bretelles totale (indique en bas de script).
====================================================================
#>

Import-Module GroupPolicy
Import-Module NetSecurity
. "$PSScriptRoot\00-Variables.ps1"

$DomainDN    = (Get-ADDomain).DistinguishedName
$ouEcoleDN   = "OU=LouiseMichel,$DomainDN"
$ouDirection = "OU=Direction,$ouEcoleDN"
$ouEnseign   = "OU=Enseignants,$ouEcoleDN"
$ouEleves    = "OU=Eleves,$ouEcoleDN"
$ouPostes    = "OU=Postes,$ouEcoleDN"

function New-GPOIfMissing {
    param([string]$Name)
    $gpo = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $gpo) { $gpo = New-GPO -Name $Name }
    return $gpo
}

# ------------------------------------------------------------------
# A) GPO-Restriction-Eleves (User Config, liee a OU=Eleves)
# ------------------------------------------------------------------
Write-Host "GPO A - Restriction eleves ..." -ForegroundColor Cyan
$gpoRestriction = New-GPOIfMissing -Name "GPO-Restriction-Eleves"
New-GPLink -Guid $gpoRestriction.Id -Target $ouEleves -ErrorAction SilentlyContinue | Out-Null

Set-GPRegistryValue -Guid $gpoRestriction.Id `
    -Key "HKCU\Software\Policies\Microsoft\Windows\Installer" `
    -ValueName "DisableMSI" -Type DWord -Value 1 | Out-Null

Set-GPRegistryValue -Guid $gpoRestriction.Id `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Uninstall" `
    -ValueName "NoRemovePage" -Type DWord -Value 1 | Out-Null

Set-GPRegistryValue -Guid $gpoRestriction.Id `
    -Key "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" `
    -ValueName "NoControlPanel" -Type DWord -Value 1 | Out-Null

# ------------------------------------------------------------------
# B) GPO-AccesDistant (Computer Config, liee a OU=Postes -> tous les postes,
#    toutes ecoles = admin a distance possible partout sans se deplacer)
# ------------------------------------------------------------------
Write-Host "GPO B - Acces a distance (RDP + WinRM) ..." -ForegroundColor Cyan
$gpoRemote = New-GPOIfMissing -Name "GPO-AccesDistant"
New-GPLink -Guid $gpoRemote.Id -Target $ouPostes -ErrorAction SilentlyContinue | Out-Null

# Activer le Bureau a distance
Set-GPRegistryValue -Guid $gpoRemote.Id `
    -Key "HKLM\System\CurrentControlSet\Control\Terminal Server" `
    -ValueName "fDenyTSConnections" -Type DWord -Value 0 | Out-Null

# Activer WinRM (PowerShell Remoting) pour l'administration en masse
Set-GPRegistryValue -Guid $gpoRemote.Id `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" `
    -ValueName "AllowAutoConfig" -Type DWord -Value 1 | Out-Null
Set-GPRegistryValue -Guid $gpoRemote.Id `
    -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" `
    -ValueName "IPv4Filter" -Type String -Value "*" | Out-Null

# Regles de pare-feu poussees directement dans la GPO (RDP 3389 + WinRM 5985)
$gpoSession = Open-NetGPO -PolicyStore "$DomainNetBIOS\GPO-AccesDistant"
New-NetFirewallRule -GPOSession $gpoSession -DisplayName "SNTS - Autoriser RDP" `
    -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow -Profile Domain -ErrorAction SilentlyContinue
New-NetFirewallRule -GPOSession $gpoSession -DisplayName "SNTS - Autoriser WinRM" `
    -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow -Profile Domain -ErrorAction SilentlyContinue
Save-NetGPO -GPOSession $gpoSession

# ------------------------------------------------------------------
# C) GPO-ScriptOuverture (User Config, liee a Direction+Enseignants+Eleves)
#    Depot du script + ecriture de scripts.ini + increment de version GPT.
# ------------------------------------------------------------------
Write-Host "GPO C - Script d'ouverture de session ..." -ForegroundColor Cyan
$gpoLogon = New-GPOIfMissing -Name "GPO-ScriptOuverture"
foreach ($ou in @($ouDirection, $ouEnseign, $ouEleves)) {
    New-GPLink -Guid $gpoLogon.Id -Target $ou -ErrorAction SilentlyContinue | Out-Null
}

$gpoGuid       = $gpoLogon.Id.ToString("B")   # format {xxxxxxxx-xxxx-...}
$sysvolGpoPath = "\\$DomainName\SYSVOL\$DomainName\Policies\$gpoGuid"
$logonScriptsDir = "$sysvolGpoPath\User\Scripts\Logon"

New-Item -Path $logonScriptsDir -ItemType Directory -Force | Out-Null
Copy-Item -Path "$PSScriptRoot\LogonScript.ps1" -Destination $logonScriptsDir -Force

$scriptsIniPath = "$sysvolGpoPath\User\Scripts\scripts.ini"
@"
[Logon]
0CmdLine=powershell.exe
0Parameters=-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "LogonScript.ps1"
"@ | Out-File -FilePath $scriptsIniPath -Encoding Unicode -Force

# Increment de la version utilisateur dans GPT.INI (necessaire pour que les
# clients detectent le changement au prochain gpupdate)
$gptIniPath = "$sysvolGpoPath\GPT.INI"
$gptContent = Get-Content $gptIniPath
$versionLine = $gptContent | Where-Object { $_ -match '^Version=' }
$currentVersion = [int]($versionLine -replace 'Version=', '')
$machineVersion = [math]::Floor($currentVersion / 65536)
$userVersion    = $currentVersion % 65536
$newVersion     = ($machineVersion * 65536) + ($userVersion + 1)
($gptContent -replace '^Version=.*', "Version=$newVersion") | Set-Content $gptIniPath

# Synchro cote AD (attribut versionNumber du conteneur de la GPO)
Set-ADObject -Identity "CN=$($gpoLogon.Id.ToString('B').ToUpper()),CN=Policies,CN=System,$DomainDN" `
    -Replace @{versionNumber = $newVersion}

Write-Host "GPO terminees." -ForegroundColor Green
Write-Host ""
Write-Host "A faire manuellement si vous voulez un verrouillage total du groupe" -ForegroundColor Yellow
Write-Host "Administrateurs local sur les postes eleves (optionnel, defense en profondeur) :" -ForegroundColor Yellow
Write-Host "  gpmc.msc > GPO-Restriction-Eleves > Parametres ordinateur > Parametres Windows >" -ForegroundColor Yellow
Write-Host "  Parametres de securite > Groupes restreints > Ajouter 'Administrateurs' ->" -ForegroundColor Yellow
Write-Host "  Membres : LMICHEL\$GrpDomainAdmins, LMICHEL\GG-ServiceInformatique" -ForegroundColor Yellow
Write-Host ""
Write-Host "Pour forcer l'application immediate sur un poste de test : gpupdate /force" -ForegroundColor DarkGray
