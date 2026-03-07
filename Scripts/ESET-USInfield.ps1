# ================================
# CONFIG
# ================================
$ZipUrl        = "https://drcvid-my.sharepoint.com/:u:/g/personal/chrishanr_dancebug_com/IQCxZ8U9xrlfRrEmtLJW2MWwAdVTnVws5MsBMfCMMr92dxY?e=sKjQYx&download=1"
$WorkDir       = "C:\DanceBUG\ESETDeploy"
$ZipPath       = "$WorkDir\epi_win_live_installer-US-Infield.zip"
$InstallerPath = "$WorkDir\epi_win_live_installer-US-Infield.exe"
$LogFile       = "$WorkDir\eset_install.log"

# ================================
# LOG FUNCTION
# ================================
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
}

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
# ESET Activation Check
# ================================

function Test-ESETActivated {

    $expectedLicense = "3BC-VDG-8HU"
    $regPath = "HKLM:\SOFTWARE\ESET\ESET Security\CurrentVersion\Info"

    if (-not (Test-Path $regPath)) {
        Write-Log "ESET not installed."
        return $false
    }

    $reg = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue

    if ($null -ne $reg.WebLicensePublicId -and 
        $reg.WebLicensePublicId -eq $expectedLicense) {

        Write-Log "ESET is activated with US license."
        return $true
    }

    Write-Log "ESET not activated or wrong license detected."
    return $false
}


if (Test-ESETActivated) {
    Write-Host "Activated ESET detected. Skipping install."
    Write-Log "Activated ESET detected. Skipping install."
    return
}
else {
    Write-Host "ESET not activated. Proceeding with install."
    Write-Log "ESET not detected or activated. Proceeding with install."
    # Run installer here
}

# ================================
# ATTEMPT ESET UNINSTALL (ROBUST)
# ================================
function Remove-ExistingESET {
    Write-Log "Scanning for existing ESET installations..."
    Write-Host "Scanning for existing ESET installations..."

    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $esetApps = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -and
            $_.DisplayName -match "ESET"
        }

    if (-not $esetApps) {
        Write-Log "No existing ESET products found"
        return
    }

    foreach ($app in $esetApps) {
        Write-Log "Found ESET product: $($app.DisplayName)"

        $uninstallCmd = $app.UninstallString

        if (-not $uninstallCmd) {
            Write-Log "WARNING: No uninstall string for $($app.DisplayName)"
            continue
        }

        # Normalize MSI uninstall
        if ($uninstallCmd -match "msiexec") {
            if ($uninstallCmd -notmatch "/x") {
                $uninstallCmd = $uninstallCmd -replace "/i", "/x"
            }
            $uninstallCmd += " /qn /norestart"
        }

        Write-Log "Running uninstall command: $uninstallCmd"
        Write-Host "Uninstalling old ESET"

        try {
            $process = Start-Process `
                -FilePath "cmd.exe" `
                -ArgumentList "/c $uninstallCmd" `
                -Wait -PassThru

            Write-Log "Uninstall exit code: $($process.ExitCode)"
        }
        catch {
            Write-Log "ERROR: Failed uninstalling $($app.DisplayName)"
        }
    }

    Write-Log "ESET uninstall phase complete"
}

# ================================
# PREP
# ================================
New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
Write-Log "===== ESET Live Installer START ====="
Write-Host "===== ESET Live Installer has STARTED...please wait ====="

Remove-ExistingESET
Start-Sleep -Seconds 10


# ================================
# DOWNLOAD ZIP
# ================================
try {
    Write-Log "Downloading ZIP from OneDrive..."
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
    Write-Log "ERROR: ESET_LiveInstaller.exe not found after extraction"
    Remove-InstallerFiles
    exit 4
}

Write-Log "Installer found"

# ================================
# RUN INSTALLER SILENTLY
# ================================
Write-Log "Running ESET Live Installer silently..."
$process = Start-Process -FilePath $InstallerPath `
    -ArgumentList "--silent --accepteula" `
    -Wait -PassThru

Write-Log "Installer exited with code $($process.ExitCode)"

# ================================
# POST-INSTALL CHECK
# ================================
Start-Sleep -Seconds 10
$service = Get-Service -Name "epfwwfp" -ErrorAction SilentlyContinue

if ($service) {
    Write-Log "SUCCESS: ESET Firewall service detected"
    Remove-InstallerFiles
    Write-Log "===== INSTALL COMPLETE ====="
    exit 0
} else {
    Write-Log "WARNING: ESET service not detected"
    Remove-InstallerFiles
    Write-Log "===== INSTALL MAY HAVE FAILED ====="
    exit 5
}