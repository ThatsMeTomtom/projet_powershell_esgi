<#
====================================================================
 01-Install-ADDS-DNS.ps1
 A executer sur SRV-WIN01 (Windows Server 2022), en local, avec un
 compte Administrateur local.

 Etape 1/11 du deploiement : installation des roles ADDS + DNS et
 promotion en premier controleur de domaine de la foret
 "louise-michel.edu".

 ATTENTION : ce script provoque un REDEMARRAGE automatique du serveur.
 Les scripts suivants (02 et +) doivent etre executes APRES le reboot,
 une fois connecte avec un compte membre de "Domain Admins".
====================================================================
#>

. "$PSScriptRoot\00-Variables.ps1"

# 1) Renommage et IP fixe du serveur (a adapter si deja fait manuellement)
Write-Host "Configuration de l'adresse IP fixe de $SrvWinName ..." -ForegroundColor Cyan
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $SrvWinIP `
    -PrefixLength $PrefixLength -DefaultGateway $Gateway -ErrorAction SilentlyContinue
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses "127.0.0.1"

if ($env:COMPUTERNAME -ne $SrvWinName) {
    Rename-Computer -NewName $SrvWinName -Force
}

# 2) Installation des roles AD DS + DNS + outils d'administration
Write-Host "Installation des roles AD-Domain-Services et DNS ..." -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools

# 3) Promotion en controleur de domaine (nouvelle foret)
Write-Host "Promotion en controleur de domaine : $DomainName" -ForegroundColor Cyan
$SafeModePwd = Read-Host -AsSecureString "Mot de passe DSRM (mode restauration services d'annuaire)"

Install-ADDSForest `
    -DomainName $DomainName `
    -DomainNetbiosName $DomainNetBIOS `
    -SafeModeAdministratorPassword $SafeModePwd `
    -InstallDns:$true `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -NoRebootOnCompletion:$false `
    -Force:$true

# Le serveur redemarre automatiquement ici.
# -> Reconnectez-vous avec LMICHEL\Administrateur puis enchainez sur 02-New-OUsEtGroupes.ps1
