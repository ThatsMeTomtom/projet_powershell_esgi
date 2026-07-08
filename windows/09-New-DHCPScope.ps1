. "$PSScriptRoot\00-Variables.ps1"

Write-Host "Installation du role DHCP ..." -ForegroundColor Cyan
Install-WindowsFeature -Name DHCP -IncludeManagementTools
Import-Module DhcpServer

# Autorisation du serveur DHCP dans l'annuaire (obligatoire pour qu'il distribue des baux)
Add-DhcpServerInDC -DnsName "$SrvWinName.$DomainName" -IPAddress $SrvWinIP -ErrorAction SilentlyContinue

# Groupes de securite locaux requis par le role DHCP
netsh dhcp add securitygroups 2>$null | Out-Null
Restart-Service dhcpserver -Force

$scopeId = $Subnet

if (-not (Get-DhcpServerv4Scope -ScopeId $scopeId -ErrorAction SilentlyContinue)) {
    Add-DhcpServerv4Scope -Name "$SchoolName" `
        -StartRange $DhcpPoolStart -EndRange $DhcpPoolEnd `
        -SubnetMask $SubnetMask -State Active `
        -LeaseDuration "0.08:00:00"   # bail de 8h, adapte a une journee d'ecole
}

Set-DhcpServerv4OptionValue -ScopeId $scopeId `
    -Router $Gateway `
    -DnsServer $SrvWinIP `
    -DnsDomain $DomainName

# Exclusion de la plage reservee au serveur Linux (20% du pool)
if (-not (Get-DhcpServerv4ExclusionRange -ScopeId $scopeId -ErrorAction SilentlyContinue |
        Where-Object { $_.StartRange -eq $DhcpLinuxRangeStart })) {
    Add-DhcpServerv4ExclusionRange -ScopeId $scopeId `
        -StartRange $DhcpLinuxRangeStart -EndRange $DhcpLinuxRangeEnd
}

# Reservation statique du poste de test (pratique pour la demo, evite de re-chercher son bail)
Add-DhcpServerv4Reservation -ScopeId $scopeId -IPAddress $ClientTestIP `
    -ClientId "AA-BB-CC-DD-EE-FF" -Description "Poste de test demo (a adapter avec la vraie MAC)" `
    -ErrorAction SilentlyContinue

Write-Host "Etendue DHCP $scopeId active. Plage Windows : $DhcpWinRangeStart-$DhcpWinRangeEnd (80%). Plage exclue/reservee au Linux : $DhcpLinuxRangeStart-$DhcpLinuxRangeEnd (20%)." -ForegroundColor Green
