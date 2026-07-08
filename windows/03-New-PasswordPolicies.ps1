<#
====================================================================
 03-New-PasswordPolicies.ps1
 Etape 3/11 : politique de mot de passe du domaine + strategies de mot
 de passe affinees (PSO) par population.
 A executer apres le script 02 (les groupes GG-* doivent exister).
====================================================================
#>

Import-Module ActiveDirectory
. "$PSScriptRoot\00-Variables.ps1"

# ------------------------------------------------------------------
# 1) Politique de mot de passe par defaut du domaine (filet de securite,
#    s'applique a tout compte non couvert par une PSO ci-dessous)
# ------------------------------------------------------------------
Write-Host "Configuration de la politique de mot de passe par defaut ..." -ForegroundColor Cyan
Set-ADDefaultDomainPasswordPolicy -Identity $DomainName `
    -MinPasswordLength 8 `
    -ComplexityEnabled $true `
    -PasswordHistoryCount 5 `
    -MaxPasswordAge "90.00:00:00" `
    -MinPasswordAge "1.00:00:00" `
    -LockoutThreshold 5 `
    -LockoutDuration "00:30:00" `
    -LockoutObservationWindow "00:30:00"

# ------------------------------------------------------------------
# 2) PSO renforcee : Direction + Enseignants + Service informatique
# ------------------------------------------------------------------
Write-Host "Creation de la PSO Personnel (Direction/Enseignants/SNTS) ..." -ForegroundColor Cyan
if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO-Personnel'" -ErrorAction SilentlyContinue)) {
    New-ADFineGrainedPasswordPolicy -Name "PSO-Personnel" `
        -Precedence 10 `
        -DisplayName "Politique renforcee - Personnel" `
        -Description "Direction, enseignants et service informatique" `
        -ComplexityEnabled $true `
        -MinPasswordLength 10 `
        -PasswordHistoryCount 10 `
        -MaxPasswordAge "60.00:00:00" `
        -MinPasswordAge "1.00:00:00" `
        -LockoutThreshold 5 `
        -LockoutDuration "00:30:00" `
        -LockoutObservationWindow "00:30:00" `
        -ReversibleEncryptionEnabled $false
}
Add-ADFineGrainedPasswordPolicySubject -Identity "PSO-Personnel" `
    -Subjects "GG-Direction", "GG-Enseignants", "GG-ServiceInformatique"

# ------------------------------------------------------------------
# 3) PSO adaptee aux eleves (mot de passe plus simple a retenir/saisir,
#    mais changement obligatoire a la 1ere connexion gere par 06-Import)
# ------------------------------------------------------------------
Write-Host "Creation de la PSO Eleves ..." -ForegroundColor Cyan
if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO-Eleves'" -ErrorAction SilentlyContinue)) {
    New-ADFineGrainedPasswordPolicy -Name "PSO-Eleves" `
        -Precedence 20 `
        -DisplayName "Politique - Eleves" `
        -Description "Comptes eleves" `
        -ComplexityEnabled $false `
        -MinPasswordLength 8 `
        -PasswordHistoryCount 3 `
        -MaxPasswordAge "180.00:00:00" `
        -MinPasswordAge "1.00:00:00" `
        -LockoutThreshold 10 `
        -LockoutDuration "00:15:00" `
        -LockoutObservationWindow "00:15:00" `
        -ReversibleEncryptionEnabled $false
}
Add-ADFineGrainedPasswordPolicySubject -Identity "PSO-Eleves" -Subjects "GG-Eleves-Toutes"

Write-Host "Politiques de mot de passe en place." -ForegroundColor Green
Write-Host "Verification : Get-ADUserResultantPasswordPolicy <utilisateur>" -ForegroundColor Yellow
