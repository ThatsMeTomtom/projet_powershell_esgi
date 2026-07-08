. "$PSScriptRoot\00-Variables.ps1"
Import-Module DnsServer

Add-DnsServerResourceRecordA -ZoneName $DomainName -Name $SrvLinuxName -IPv4Address $SrvLinuxIP -ErrorAction SilentlyContinue
Add-DnsServerResourceRecordCName -ZoneName $DomainName -Name "intranet" -HostNameAlias "$SrvLinuxName.$DomainName" -ErrorAction SilentlyContinue
Add-DnsServerResourceRecordCName -ZoneName $DomainName -Name "www"      -HostNameAlias "$SrvLinuxName.$DomainName" -ErrorAction SilentlyContinue

Write-Host "Enregistrements DNS crees : $SrvLinuxName ($SrvLinuxIP), intranet.$DomainName, www.$DomainName" -ForegroundColor Green
