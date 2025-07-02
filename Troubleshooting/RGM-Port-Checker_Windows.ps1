# Redgate Monitor Port Validator Tool

# --- Introduction ---
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host "     Redgate Monitor Port Validator Tool" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "This script helps you validate whether the required network ports are open" -ForegroundColor White
Write-Host "between your Base Monitor VM and target servers for Redgate Monitor setup." -ForegroundColor White
Write-Host ""
Write-Host "🔍 It supports checks for a variety of environments including:" -ForegroundColor White
Write-Host "   - Traditional Windows-based SQL Server setups" -ForegroundColor Gray
Write-Host "   - Linux-based RDBMS like PostgreSQL, MySQL, Oracle, and MongoDB" -ForegroundColor Gray
Write-Host ""
Write-Host "📌 The script will guide you through selecting:" -ForegroundColor White
Write-Host "   - The target RDBMS (e.g., SQL Server, PostgreSQL, etc.)" -ForegroundColor Gray
Write-Host "   - The operating system of the target servers (Windows or Linux)" -ForegroundColor Gray
Write-Host "   - The connection method (WinRM, HTTPS, or WMI over DCOM)" -ForegroundColor Gray
Write-Host "   - Any custom ports you wish to test" -ForegroundColor Gray
Write-Host ""
Write-Host "✅ Based on your answers, the script will test the appropriate default ports" -ForegroundColor White
Write-Host "   and generate a report showing which ports are open or blocked." -ForegroundColor White
Write-Host ""

# --- RDBMS Selection ---
Write-Host "`nSelect the RDBMS you are monitoring:"
Write-Host "1 = SQL Server"
Write-Host "2 = PostgreSQL"
Write-Host "3 = MySQL"
Write-Host "4 = Oracle"
Write-Host "5 = MongoDB"
$rdbmsChoice = Read-Host "Enter the number corresponding to your RDBMS"

switch ($rdbmsChoice) {
    '1' { $rdbmsPort = 1433; $rdbmsName = "SQL Server" }
    '2' { $rdbmsPort = 5432; $rdbmsName = "PostgreSQL" }
    '3' { $rdbmsPort = 3306; $rdbmsName = "MySQL" }
    '4' { $rdbmsPort = 1521; $rdbmsName = "Oracle" }
    '5' { $rdbmsPort = 27017; $rdbmsName = "MongoDB" }
    default {
        Write-Host "Invalid selection. Defaulting to SQL Server (1433)." -ForegroundColor Yellow
        $rdbmsPort = 1433
        $rdbmsName = "SQL Server"
    }
}

Write-Host "`nSelected RDBMS: $rdbmsName (Port $rdbmsPort)" -ForegroundColor Cyan

# --- Server Input ---
Write-Host "`nHow would you like to provide the list of target servers?"
Write-Host "1 = Manually enter server names"
Write-Host "2 = Load from a CSV file (must contain a column named 'ServerName')"
$serverInputMethod = Read-Host "Enter 1 or 2"

switch ($serverInputMethod) {
    '1' {
        $servers = Read-Host "Enter target server names or IPs (comma-separated)"
        $serverList = $servers -split "," | ForEach-Object { $_.Trim() }
    }
    '2' {
        $validCsv = $false
        while (-not $validCsv) {
            $csvPath = Read-Host "Enter the full path to the CSV file"
            $csvPath = $csvPath.Trim('"')  # Remove quotes if present
            if (Test-Path $csvPath) {
                try {
                    $csvData = Import-Csv -Path $csvPath
                    if ($csvData[0].PSObject.Properties.Name -contains "ServerName") {
                        $serverList = $csvData | ForEach-Object { $_.ServerName.Trim() }
                        $validCsv = $true
                    } else {
                        Write-Host "❌ CSV file must contain a column named 'ServerName'." -ForegroundColor Red
                        exit
                    }
                } catch {
                    Write-Host "❌ Failed to read CSV file: $($_.Exception.Message)" -ForegroundColor Red
                    exit
                }
            } else {
                Write-Host "❌ File not found: $csvPath" -ForegroundColor Red
                $tryAgain = Read-Host "Would you like to try another path? (Y/N)"
                if ($tryAgain -notin @('Y','y')) {
                    Write-Host "Exiting script." -ForegroundColor Yellow
                    exit
                }
            }
        }
    }
    default {
        Write-Host "Invalid selection. Exiting." -ForegroundColor Red
        exit
    }
}


# --- OS Selection ---
Write-Host "`nWhat operating system are the target servers running?"
Write-Host "1 = Windows"
Write-Host "2 = Linux"
$osChoice = Read-Host "Enter 1 or 2"

switch ($osChoice) {
    '1' { $targetIsLinux = $false; $osName = "Windows" }
    '2' { $targetIsLinux = $true;  $osName = "Linux" }
    default {
        Write-Host "Invalid selection. Defaulting to Windows." -ForegroundColor Yellow
        $targetIsLinux = $false
        $osName = "Windows"
    }
}

Write-Host "`nTarget OS: $osName" -ForegroundColor Cyan

# --- Connection Method Selection ---
Write-Host "`nSelect the connection method for WMI/SQL Server access:"
Write-Host "1 = WinRM HTTP (5985)"
Write-Host "2 = WinRM HTTPS (5986)"
Write-Host "3 = WMI over DCOM (135 + static RPC port)"
$method = Read-Host "Enter 1, 2, or 3"

switch ($method) {
    '1' {
        $defaultPorts = @(5985, $rdbmsPort)
        if ($targetIsLinux) { $defaultPorts += 22 }
        $methodName = "WinRM HTTP"
    }
    '2' {
        $defaultPorts = @(5986, $rdbmsPort)
        if ($targetIsLinux) { $defaultPorts += 22 }
        $methodName = "WinRM HTTPS"
    }
    '3' {
        $staticDcomPort = Read-Host "Enter the static RPC port configured for DCOM (e.g., 5000)"
        if (-not [int]::TryParse($staticDcomPort, [ref]$null)) {
            Write-Host "Invalid port. Defaulting to 5000." -ForegroundColor Yellow
            $staticDcomPort = 5000
        }
        $defaultPorts = @(135, [int]$staticDcomPort, $rdbmsPort)
        if ($targetIsLinux) { $defaultPorts += 22 }
        $methodName = "WMI over DCOM"
    }
    default {
        Write-Host "Invalid selection. Defaulting to WinRM HTTP (5985)." -ForegroundColor Yellow
        $defaultPorts = @(5985, $rdbmsPort)
        if ($targetIsLinux) { $defaultPorts += 22 }
        $methodName = "WinRM HTTP"
    }
}

Write-Host "`nSelected method: $methodName" -ForegroundColor Cyan
Write-Host "Default ports to be tested: $($defaultPorts -join ', ')" -ForegroundColor Gray

# --- Custom Ports ---
$customPortInput = Read-Host "Enter any custom ports to test (comma-separated), or press Enter to skip"
$customPorts = @()
if ($customPortInput) {
    $customPorts = $customPortInput -split "," | ForEach-Object { [int]$_.Trim() }
}

$allPorts = $defaultPorts + $customPorts

# --- Logging Setup ---
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "PortTestLog_$timestamp.txt"
$csvFile = "PortTestResults_$timestamp.csv"
$results = @()

# --- Port Testing ---
foreach ($server in $serverList) {
    foreach ($port in $allPorts) {
        Write-Host "`nTesting $server on port $port..." -ForegroundColor Cyan
        try {
            $test = Test-NetConnection -ComputerName $server -Port $port -WarningAction SilentlyContinue
            if ($test.TcpTestSucceeded) {
                $status = "Open"
                $diagnosis = "Connection successful"
            } elseif (-not $test.PingSucceeded) {
                $status = "Unreachable"
                $diagnosis = "Host unreachable or blocked ICMP"
            } elseif (-not $test.RemoteAddress) {
                $status = "DNS Failure"
                $diagnosis = "DNS resolution failed"
            } else {
                $status = "Closed/Blocked"
                $diagnosis = "Port likely blocked by firewall or service not listening"
            }
        } catch {
            $status = "Error"
            $diagnosis = $_.Exception.Message
        }

        $color = if ($status -eq "Open") { "Green" } else { "Red" }
        Write-Host ("{0}:{1} - {2} ({3})" -f $server, $port, $status, $diagnosis) -ForegroundColor $color

        $results += [PSCustomObject]@{
            Timestamp = (Get-Date).ToString("s")
            Server    = $server
            Port      = $port
            Status    = $status
            Diagnosis = $diagnosis
        }

        Add-Content -Path $logFile -Value ("{0} - {1}:{2} - {3} - {4}" -f (Get-Date -Format 's'), $server, $port, $status, $diagnosis)
    }
}

# --- Export Results ---
$results | Export-Csv -Path $csvFile -NoTypeInformation

# --- Completion Message ---
Write-Host "`n✅ Port testing complete. Results saved to:" -ForegroundColor Green
Write-Host "   - Log file: $logFile"
Write-Host "   - CSV file: $csvFile"
