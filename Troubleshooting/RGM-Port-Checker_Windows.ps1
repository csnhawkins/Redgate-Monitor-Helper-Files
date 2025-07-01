# Simple Redgate Monitor Port Validator using Test-NetConnection (PowerShell)

# --- Introduction ---
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host "     Redgate Monitor Port Validator Tool" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "This script helps you validate whether the required network ports are open" -ForegroundColor White
Write-Host "between your Base Monitor VM and target servers for Redgate Monitor setup." -ForegroundColor White
Write-Host ""
Write-Host "🔍 It will test the following default ports:" -ForegroundColor White
Write-Host "   - 5985 : WinRM (Windows Remote Management)" -ForegroundColor Gray
Write-Host "   - 1433 : SQL Server (default instance)" -ForegroundColor Gray
Write-Host "   - 22   : SSH (for Linux servers)" -ForegroundColor Gray
Write-Host ""
Write-Host "You can also specify additional custom ports to test." -ForegroundColor White
Write-Host ""

# --- Input Section ---
$servers = Read-Host "Enter target server names or IPs (comma-separated)"
$serverList = $servers -split "," | ForEach-Object { $_.Trim() }

$defaultPorts = @(5985, 1433, 22)

$customPortInput = Read-Host "Enter any custom ports to test (comma-separated), or press Enter to skip"
$customPorts = @()
if ($customPortInput) {
    $customPorts = $customPortInput -split "," | ForEach-Object { [int]$_.Trim() }
}

$allPorts = $defaultPorts + $customPorts

# --- Logging Setup ---
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "SimplePortTestLog_$timestamp.txt"
$csvFile = "SimplePortTestResults_$timestamp.csv"
$results = @()

# --- Port Testing ---
foreach ($server in $serverList) {
    foreach ($port in $allPorts) {
        Write-Host "`nTesting $server on port $port..." -ForegroundColor Cyan
        $test = Test-NetConnection -ComputerName $server -Port $port -WarningAction SilentlyContinue
        $status = if ($test.TcpTestSucceeded) { "Open" } else { "Closed/Blocked" }

        $color = if ($status -eq "Open") { "Green" } else { "Red" }
        Write-Host ("{0}:{1} - {2}" -f $server, $port, $status) -ForegroundColor $color

        $results += [PSCustomObject]@{
            Timestamp = (Get-Date).ToString("s")
            Server    = $server
            Port      = $port
            Status    = $status
        }

        Add-Content -Path $logFile -Value ("{0} - {1}:{2} - {3}" -f (Get-Date -Format 's'), $server, $port, $status)
    }
}

# --- Export Results ---
$results | Export-Csv -Path $csvFile -NoTypeInformation

# --- Completion Message ---
Write-Host "`n✅ Port testing complete. Results saved to:" -ForegroundColor Green
Write-Host "   - Log file: $logFile"
Write-Host "   - CSV file: $csvFile"
