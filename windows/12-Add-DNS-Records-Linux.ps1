<#
====================================================================
 12-Add-DNS-Records-Linux.ps1
 A executer sur SRV-WIN01 apres avoir deploye SRV-LNX01 (linux/deploy-all.sh).
 Le DNS restant porte par Windows (choix valide ensemble), on cree ici
 les enregistrements pointant vers le serveur Linux.
====================================================================
#>

. "$PSScriptRoot\00-Variables.ps1"
Import-Module DnsServer

Add-DnsServerResourceRecordA -ZoneName $DomainName -Name $SrvLinuxName -IPv4Address $SrvLinuxIP -ErrorAction SilentlyContinue
Add-DnsServerResourceRecordCName -ZoneName $DomainName -Name "intranet" -HostNameAlias "$SrvLinuxName.$DomainName" -ErrorAction SilentlyContinue
Add-DnsServerResourceRecordCName -ZoneName $DomainName -Name "www"      -HostNameAlias "$SrvLinuxName.$DomainName" -ErrorAction SilentlyContinue

Write-Host "Enregistrements DNS crees : $SrvLinuxName ($SrvLinuxIP), intranet.$DomainName, www.$DomainName" -ForegroundColor Green
