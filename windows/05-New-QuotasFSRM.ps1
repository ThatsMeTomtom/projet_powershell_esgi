. "$PSScriptRoot\00-Variables.ps1"

Write-Host "Installation du role File Server Resource Manager ..." -ForegroundColor Cyan
Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools

Import-Module FileServerResourceManager

$templateName = "Quota-Perso-1Go"
$sizeBytes    = $QuotaPersoMo * 1MB

Write-Host "Creation du modele de quota '$templateName' ($QuotaPersoMo Mo, alerte a $QuotaAlertPercent%) ..." -ForegroundColor Cyan

# Action declenchee au seuil d'alerte : ecriture dans le journal d'evenements.
# Si un serveur SMTP est disponible, decommentez le bloc Email ci-dessous et
# ajoutez -Notification $mailAction,$eventAction a New-FsrmQuotaThreshold.
$eventAction = New-FsrmAction -Type Event -EventType Warning `
    -Body "L'utilisateur [Source Io Owner] a atteint [Quota Threshold]% de son quota personnel ([Quota Path])."

<# Exemple si un relais SMTP interne existe :
$mailAction = New-FsrmAction -Type Email `
    -MailTo "[Admin Email]" `
    -Subject "[Quota Threshold]% du quota atteint pour [Source Io Owner]" `
    -Body "Le dossier [Quota Path] a atteint [Quota Threshold]% de sa limite de [Quota Limit MB] Mo."
#>

$threshold90 = New-FsrmQuotaThreshold -Percentage $QuotaAlertPercent -Action $eventAction

if (-not (Get-FsrmQuotaTemplate -Name $templateName -ErrorAction SilentlyContinue)) {
    New-FsrmQuotaTemplate -Name $templateName `
        -Description "Quota dossier personnel eleve/enseignant/direction - $SchoolName" `
        -Size $sizeBytes `
        -SoftLimit:$false `
        -Threshold $threshold90
}

Write-Host "Application du quota en mode auto-apply sur $PersoRoot ..." -ForegroundColor Cyan
if (-not (Get-FsrmAutoQuota -Path $PersoRoot -ErrorAction SilentlyContinue)) {
    New-FsrmAutoQuota -Path $PersoRoot -Template $templateName
}

Write-Host "Quotas FSRM configures (chaque nouveau sous-dossier de $PersoRoot heritera automatiquement du quota)." -ForegroundColor Green
