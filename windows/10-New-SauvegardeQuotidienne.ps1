. "$PSScriptRoot\00-Variables.ps1"

Write-Host "Installation de la fonctionnalite Windows Server Backup ..." -ForegroundColor Cyan
Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools

Write-Host "Configuration de la politique de sauvegarde quotidienne ..." -ForegroundColor Cyan

try {
    $policy = New-WBPolicy

    # Etat systeme AD/SYSVOL/registre (indispensable sur un DC)
    Add-WBSystemState -Policy $policy

    # Volume de donnees C: (partages + perso)
    $volumeC = Get-WBVolume -VolumePath "C:"
    Add-WBVolume -Policy $policy -Volume $volumeC

    if (Test-Path "${BackupDrive}\") {
        $target = New-WBBackupTarget -VolumePath $BackupDrive
        Add-WBBackupTarget -Policy $policy -Target $target
        Set-WBSchedule -Policy $policy -Schedule "22:00"
        Set-WBPolicy -Policy $policy -Force
        Write-Host "Sauvegarde quotidienne planifiee a 22h00 vers $BackupDrive." -ForegroundColor Green
    } else {
        Write-Host "[AVERTISSEMENT] Volume $BackupDrive introuvable (demo sur disque unique)." -ForegroundColor Yellow
        Write-Host "Ajoutez un disque dedie puis relancez ce script pour activer la sauvegarde planifiee." -ForegroundColor Yellow
    }
} catch {
    Write-Warning "Configuration de la sauvegarde echouee : $_"
    Write-Host "A configurer manuellement via wbadmin ou l'interface graphique." -ForegroundColor Yellow
}
