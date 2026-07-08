<#
====================================================================
 LogonScript.ps1
 Deploye automatiquement par la GPO "GPO-ScriptOuverture" (cf script
 11) sur Direction / Enseignants / Eleves. Ne necessite PAS le module
 ActiveDirectory cote client (pas garanti d'etre installe sur un
 poste) : l'appartenance aux groupes est lue directement depuis le
 jeton Windows de l'utilisateur connecte.

 Mappages :
   P: -> dossier personnel (tout le monde)
   Z: -> Direction uniquement
   S: -> Enseignants + Direction
   T: -> Classes (toutes) pour Enseignants/Direction,
         uniquement SA classe pour un eleve
   Imprimante par defaut -> file "Staff" (Direction/Enseignants) ou
         "Eleves", cf script 08 pour la logique de priorite.
====================================================================
#>

$Domain  = "louise-michel.edu"
$NetBIOS = "LMICHEL"
$Server  = "SRV-WIN01"

# Nettoyage prealable (relance idempotente du script)
"Z:", "S:", "T:", "P:" | ForEach-Object { net use $_ /delete /y 2>$null | Out-Null }

# Lecture des groupes de l'utilisateur directement depuis son jeton Windows
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$groups = $identity.Groups | ForEach-Object {
    try { $_.Translate([Security.Principal.NTAccount]).Value } catch { $null }
} | Where-Object { $_ }

$isDirection  = $groups -contains "$NetBIOS\GG-Direction"
$isEnseignant = $groups -contains "$NetBIOS\GG-Enseignants"
$classeGroup  = $groups | Where-Object { $_ -match "^$([regex]::Escape($NetBIOS))\\GG-Eleves-Classe\d+$" } |
    Select-Object -First 1

# P: dossier personnel - tout le monde
net use P: "\\$Server\Perso`$\$env:USERNAME" /persistent:yes | Out-Null

if ($isDirection) {
    net use Z: "\\$Domain\Partages\Direction"   /persistent:yes | Out-Null
    net use S: "\\$Domain\Partages\Enseignants" /persistent:yes | Out-Null
    net use T: "\\$Domain\Partages\Classes"     /persistent:yes | Out-Null
}
elseif ($isEnseignant) {
    net use S: "\\$Domain\Partages\Enseignants" /persistent:yes | Out-Null
    net use T: "\\$Domain\Partages\Classes"     /persistent:yes | Out-Null
}
elseif ($classeGroup) {
    $classeLabel = ($classeGroup -split "-")[-1]   # ex: "Classe4"
    net use T: "\\$Domain\Partages\Classes\$classeLabel" /persistent:yes | Out-Null
}

# Imprimante par defaut selon le profil (cf 08-New-ServeurImpression.ps1)
$printerQueue = if ($isDirection -or $isEnseignant) { "Impr-Ecole-Staff" } else { "Impr-Ecole-Eleves" }
$printerPath  = "\\$Server\$printerQueue"

try { Add-Printer -ConnectionName $printerPath -ErrorAction Stop } catch { }
try { (New-Object -ComObject WScript.Network).SetDefaultPrinter($printerPath) } catch { }
