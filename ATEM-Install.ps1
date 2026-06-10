# ================================
# CONFIG
# ================================
$ZipUrl        = "https://swr.cloud.blackmagicdesign.com/ATEM/v10.2.1/Blackmagic_ATEM_Switchers_Windows_10.2.1.zip?verify=1781101100-pm%2BWeqxcMEKY0ofq48JEdBUhKO5YxeuJXyCnQRbC%2Bwk%3D"
$WorkDir       = "C:\DanceBUG\ESETDeploy"
$ZipPath       = "$WorkDir\Blackmagic_ATEM_Switchers_Windows_10.2.1.zip"
$InstallerPath = "$WorkDir\Blackmagic_ATEM_Switchers\Install ATEM v10.2.1.exe"
$LogFile       = "$WorkDir\logs\ATEM_install.log"


# ================================
# LOG FUNCTION
# ================================
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
}

New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
Write-Log "===== PHASE 1: UNINSTALL START ====="

# ================================
# CLEANUP FUNCTION
# ================================
function Remove-InstallerFiles {
    Write-Log "Starting cleanup..."

    foreach ($file in @($ZipPath, $InstallerPath)) {
        if (Test-Path $file) {
            try {
                Remove-Item -Path $file -Force -ErrorAction Stop
                Write-Log "Deleted: $file"
            } catch {
                Write-Log "WARNING: Could not delete $file"
            }
        } else {
            Write-Log "File not found (already removed): $file"
        }
    }

    Write-Log "Cleanup complete"
}


# ================================
# DOWNLOAD ZIP
# ================================
try {
    Write-Log "Downloading ZIP..."
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
} catch {
    Write-Log "ERROR: Download failed"
    exit 1
}

# ================================
# VALIDATE ZIP (NOT HTML)
# ================================
$header = Get-Content $ZipPath -TotalCount 1
if ($header -match "<!DOCTYPE html>|<html") {
    Write-Log "ERROR: Downloaded file is HTML, not ZIP"
    Remove-InstallerFiles
    exit 2
}

Write-Log "ZIP download validated"

# ================================
# EXTRACT ZIP
# ================================
try {
    Write-Log "Extracting ZIP..."
    Expand-Archive -Path $ZipPath -DestinationPath $WorkDir -Force
} catch {
    Write-Log "ERROR: ZIP extraction failed"
    Remove-InstallerFiles
    exit 3
}

# ================================
# VERIFY INSTALLER
# ================================
if (-not (Test-Path $InstallerPath)) {
    Write-Log "ERROR: Install ATEM v10.2.1.exe not found after extraction"
    Remove-InstallerFiles
    exit 4
}

Write-Log "Installer found"

# ================================
# RUN INSTALLER SILENTLY
# ================================
Write-Log "Running ATEM Live Installer silently..."
$process = Start-Process -FilePath $InstallerPath `
    -ArgumentList "--silent --accepteula" `
    -Wait -PassThru

Write-Log "Installer exited with code $($process.ExitCode)"
