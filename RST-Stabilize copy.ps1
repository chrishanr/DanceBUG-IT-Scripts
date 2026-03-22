# ================================
# Storage Controller Health Script
# ================================

$LogPath = "C:\ProgramData\IT-Admin\Logs"
$LogFile = "$LogPath\storage_fix.log"

# Create log directory
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

# Logging function
function Write-Log {
    param ($Message)
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Time - $Message" | Out-File -Append -FilePath $LogFile
}

Write-Log "===== START ====="

# Detect driver states
function Get-DriverState {
    param ($Path)
    try {
        return (Get-ItemProperty -Path $Path -ErrorAction Stop).Start
    } catch {
        return "Missing"
    }
}

$storahci = Get-DriverState "HKLM:\SYSTEM\CurrentControlSet\Services\storahci"
$iaStorV  = Get-DriverState "HKLM:\SYSTEM\CurrentControlSet\Services\iaStorV"
$iaStorAVC = Get-DriverState "HKLM:\SYSTEM\CurrentControlSet\Services\iaStorAVC"

Write-Log "storahci Start value: $storahci"
Write-Log "iaStorV Start value: $iaStorV"
Write-Log "iaStorAVC Start value: $iaStorAVC"

# Detect controller
try {
    $controller = Get-WmiObject Win32_IDEController | Select-Object -ExpandProperty Name
    Write-Log "Detected Controller(s): $($controller -join ', ')"
} catch {
    Write-Log "Failed to detect controller"
}

# Risk evaluation
$AtRisk = $false

if ($storahci -ne 0 -or $iaStorAVC -ne 0) {
    $AtRisk = $true
}

Write-Log "At Risk Status: $AtRisk"

# ================================
# FIX SECTION (SAFE MODE)
# ================================

if ($AtRisk) {
    Write-Log "Applying fixes..."

    try {
        # Enable AHCI
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\storahci" /v Start /t REG_DWORD /d 0 /f | Out-Null
        
        # Enable RST
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\iaStorV" /v Start /t REG_DWORD /d 0 /f | Out-Null
        reg add "HKLM\SYSTEM\CurrentControlSet\Services\iaStorAVC" /v Start /t REG_DWORD /d 0 /f | Out-Null

        Write-Log "Driver registry values set to boot (Start=0)"

    } catch {
        Write-Log "ERROR applying registry fix: $_"
    }

} else {
    Write-Log "System not at risk. No changes made."
}

# ================================
# OPTIONAL: BLOCK DRIVER UPDATES
# ================================

try {
    reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f | Out-Null
    Write-Log "Driver updates blocked via policy"
} catch {
    Write-Log "Failed to set Windows Update policy"
}

Write-Log "===== END ====="

# Output summary (for RMM)
Write-Output "Storage Fix Completed | AtRisk=$AtRisk | Log=$LogFile"