Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSTIC AD / RESEAU / SERVICES" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# --- 1. Identite machine ---
Write-Host "`n[1] IDENTITE MACHINE" -ForegroundColor Yellow
Write-Host "  Nom machine   : $env:COMPUTERNAME"
Write-Host "  Domaine       : $env:USERDNSDOMAIN"
Write-Host "  Utilisateur   : $env:USERNAME"

# --- 2. Services critiques ---
Write-Host "`n[2] SERVICES AD" -ForegroundColor Yellow
$services = @("NTDS", "Netlogon", "ADWS", "DNS", "DnsCache", "Kdc")
foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
        $color = if ($s.Status -eq "Running") { "Green" } else { "Red" }
        Write-Host ("  {0,-20} : {1}" -f $s.DisplayName, $s.Status) -ForegroundColor $color
    } else {
        Write-Host "  $svc : INTROUVABLE" -ForegroundColor Red
    }
}

# --- 3. Carte reseau ---
Write-Host "`n[3] RESEAU" -ForegroundColor Yellow
Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
    $ip = Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    $dns = Get-DnsClientServerAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    Write-Host "  Carte   : $($_.Name)"
    Write-Host "  IP      : $($ip.IPAddress)/$($ip.PrefixLength)"
    Write-Host "  DNS     : $($dns.ServerAddresses -join ', ')"
}

# --- 4. Resolution DNS ---
Write-Host "`n[4] RESOLUTION DNS" -ForegroundColor Yellow
$targets = @("localhost", "127.0.0.1", $env:COMPUTERNAME, $env:USERDNSDOMAIN)
foreach ($t in $targets | Where-Object { $_ }) {
    try {
        $r = Resolve-DnsName $t -ErrorAction Stop | Select-Object -First 1
        $addr = if ($r.IPAddress) { $r.IPAddress } else { $r.NameHost }
        Write-Host "  OK  $t -> $addr" -ForegroundColor Green
    } catch {
        Write-Host "  KO  $t : $_" -ForegroundColor Red
    }
}

# --- 5. Get-ADDomain ---
Write-Host "`n[5] GET-ADDOMAIN" -ForegroundColor Yellow
foreach ($srv in @("localhost", "127.0.0.1", $env:COMPUTERNAME)) {
    try {
        $d = Get-ADDomain -Server $srv -ErrorAction Stop
        Write-Host "  OK  -Server $srv -> $($d.DNSRoot)" -ForegroundColor Green
    } catch {
        Write-Host "  KO  -Server $srv : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- 6. SYSVOL partage ---
Write-Host "`n[6] SYSVOL / NETLOGON" -ForegroundColor Yellow
foreach ($share in @("SYSVOL", "NETLOGON")) {
    $s = Get-SmbShare -Name $share -ErrorAction SilentlyContinue
    if ($s) {
        Write-Host "  OK  Partage $share present ($($s.Path))" -ForegroundColor Green
    } else {
        Write-Host "  KO  Partage $share ABSENT" -ForegroundColor Red
    }
}

# --- 7. Test ADWS port ---
Write-Host "`n[7] PORT ADWS (9389)" -ForegroundColor Yellow
$tcp = Test-NetConnection -ComputerName localhost -Port 9389 -WarningAction SilentlyContinue
$color = if ($tcp.TcpTestSucceeded) { "Green" } else { "Red" }
Write-Host "  Port 9389 : $($tcp.TcpTestSucceeded)" -ForegroundColor $color

# --- 8. Replication AD ---
Write-Host "`n[8] REPLICATION / DC" -ForegroundColor Yellow
try {
    $dc = Get-ADDomainController -Server localhost -ErrorAction Stop
    Write-Host "  DC     : $($dc.HostName)" -ForegroundColor Green
    Write-Host "  Site   : $($dc.Site)"
    Write-Host "  Roles  : $($dc.OperationMasterRoles -join ', ')"
} catch {
    Write-Host "  KO : $($_.Exception.Message)" -ForegroundColor Red
}

# --- 9. Erreurs recentes EventLog ---
Write-Host "`n[9] ERREURS RECENTES (30 min)" -ForegroundColor Yellow
$since = (Get-Date).AddMinutes(-30)
$logs = @("System", "Directory Service", "DNS Server")
foreach ($log in $logs) {
    try {
        $errors = Get-EventLog -LogName $log -EntryType Error,Warning -After $since -Newest 3 -ErrorAction SilentlyContinue
        if ($errors) {
            Write-Host "  [$log]" -ForegroundColor DarkYellow
            $errors | ForEach-Object {
                Write-Host ("    {0} {1} ({2})" -f $_.TimeGenerated.ToString("HH:mm:ss"), $_.Source, $_.EventID) -ForegroundColor DarkGray
                Write-Host "    $($_.Message.Split("`n")[0])" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "  [$log] Aucune erreur recente" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [$log] Inaccessible" -ForegroundColor DarkGray
    }
}

Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "  FIN DU DIAGNOSTIC" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
