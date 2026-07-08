. "$PSScriptRoot\00-Variables.ps1"

Write-Host "Installation de la fonctionnalite Windows Server Backup ..." -ForegroundColor Cyan
Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools

Write-Host "Configuration de la politique de sauvegarde quotidienne ..." -ForegroundColor Cyan

# Si le disque dedie est absent (demo un seul disque), creer un VHD dynamique et le monter.
if (-not (Test-Path "${BackupDrive}\")) {
    Write-Host "Volume $BackupDrive absent - creation d'un VHD 20 Go (demo) ..." -ForegroundColor Yellow
    $vhdDir  = "C:\BackupVHD"
    $vhdFile = "$vhdDir\BackupDisk.vhd"
    $letter  = ($BackupDrive -replace ':', '')

    New-Item -Path $vhdDir -ItemType Directory -Force | Out-Null

    if (-not (Test-Path $vhdFile)) {
        $dpCreate = @"
create vdisk file="$vhdFile" maximum=20480 type=expandable
select vdisk file="$vhdFile"
attach vdisk
create partition primary
format fs=ntfs label="Backup" quick
assign letter=$letter
"@
        $dpCreate | Out-File -FilePath "$env:TEMP\dp_backup.txt" -Encoding ASCII
        diskpart /s "$env:TEMP\dp_backup.txt" | Out-Null
    } else {
        $dpAttach = @"
select vdisk file="$vhdFile"
attach vdisk
"@
        $dpAttach | Out-File -FilePath "$env:TEMP\dp_backup.txt" -Encoding ASCII
        diskpart /s "$env:TEMP\dp_backup.txt" | Out-Null
    }
    Remove-Item "$env:TEMP\dp_backup.txt" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 4
}

try {
    $policy = New-WBPolicy
    Add-WBSystemState -Policy $policy
    $volumeC = Get-WBVolume -VolumePath "C:"
    Add-WBVolume -Policy $policy -Volume $volumeC

    if (Test-Path "${BackupDrive}\") {
        $target = New-WBBackupTarget -VolumePath $BackupDrive
        Add-WBBackupTarget -Policy $policy -Target $target
        Set-WBSchedule -Policy $policy -Schedule "22:00"
        Set-WBPolicy -Policy $policy -Force
        Write-Host "Sauvegarde quotidienne planifiee a 22h00 vers $BackupDrive." -ForegroundColor Green
    } else {
        Write-Warning "Volume $BackupDrive toujours introuvable apres tentative de creation VHD."
    }
} catch {
    Write-Warning "Configuration de la sauvegarde echouee : $_"
    Write-Host "A configurer manuellement via wbadmin ou l'interface graphique." -ForegroundColor Yellow
}
