param(
    [string]$DsmrPassword = ""
)

. "$PSScriptRoot\00-Variables.ps1"

# 1) IP fixe + renommage
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

# 3) Mot de passe DSRM : parametre (mode Ansible) ou saisie interactive
if ($DsmrPassword -ne "") {
    $SafeModePwd = ConvertTo-SecureString $DsmrPassword -AsPlainText -Force
} else {
    $SafeModePwd = Read-Host -AsSecureString "Mot de passe DSRM (mode restauration services d'annuaire)"
}

# 4) Promotion en controleur de domaine (nouvelle foret)
Write-Host "Promotion en controleur de domaine : $DomainName" -ForegroundColor Cyan
Install-ADDSForest `
<<<<<<< HEAD
    -DomainName $DomainName `
    -DomainNetbiosName $DomainNetBIOS `
    -DomainMode WinThreshold `
    -ForestMode WinThreshold `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SysvolPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $SafeModePwd `
    -InstallDns:$true `
    -NoRebootOnCompletion:$false `
    -Force:$true
=======
    -DomainName $Doma
>>>>>>> 20f05ec (chore: nettoyage commentaires + vault Ansible)
