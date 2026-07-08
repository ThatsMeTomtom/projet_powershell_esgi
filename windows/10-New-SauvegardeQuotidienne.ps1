. "$PSScriptRoot\00-Variables.ps1"

Write-Host "Installation de la fonctionnalite Windows Server Backup ..." -ForegroundColor Cyan
Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools

Write-Host "Configuration de la politique de sauvegarde quotidienne ..." -ForegroundColor Cyan

$policy = New-WBPolicy

# Volume de donnees (D: = Partages + Perso)
$volumeD = Get-WBVolume -VolumePath "D:"
Add-WBVolume -Policy $policy -Volume $volumeD

# Etat systeme (annuaire AD / SYSVOL / registre) - essentiel sur un DC
Add-WBSystemState -Policy $policy

# Destination de sauvegarde
$target = New-WBBackupTarget -VolumePath $BackupDrive
Add-WBBackupTarget -Policy $policy -Target $target

# Planification quotidienne a 22h00 (hors horaires scolaires)
Set-WBSchedule -Policy $policy -Schedule "22:00"

Set-WBPolicy -Policy $policy -Force

Write-Host "Sauvegarde quotidienne planifiee a 22h00 vers $BackupDrive (volume D: + etat systeme AD)." -ForegroundColor Green
Write-Host "Verification : Get-WBPolicy / Get-WBJob" -ForegroundColor Yellow
