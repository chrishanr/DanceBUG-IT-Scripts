# ============================
# Training Mode Shortcut Script
# ============================

# -------- CONFIG --------
$OldShortcutName     = "Photo Manager - Training Mode.lnk"
$NewShortcutName     = "Photo Manager.lnk"
$NewShortcutSource   = "C:\Users\Production\Dropbox\Software Updates\Software\Shortcuts\Photo Manager.lnk"
$PublicDesktop       = "C:\Users\Production\Desktop"

$WebhookUrl = "https://defaulteb6ac93710a44e86adf0ee412b4651.69.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/fbdbc04a4a6b466b912f6775ed0a021b/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=wibGRHpjHdWHWE50xS0_VdHtrrkdbjyeSdfKQseCpZU"
$LogPath    = "C:\ProgramData\IT-Admin\logs\PMTrainingMode.log"

# -------- LOGGING FUNCTION --------
function Write-Log {
    param ($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "$timestamp - $Message"
}

Write-Log "========== Starting Training Mode Deployment =========="

function Stop-ProgramAndRenameFolders {

    # --- Program to close ---
    $ProcessName = "DanceBUGPhotoManager"   # example: obs64, chrome, etc (no .exe)

    # Close program if running
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Output "$ProcessName is running. Closing it..."
        Stop-Process -Name $ProcessName -Force
        Start-Sleep -Seconds 3
    }

    # --- Get all filesystem drives ---
    $Drives = Get-PSDrive -PSProvider FileSystem | Where-Object {$null -ne $_.Free }

    foreach ($Drive in $Drives) {

        Write-Output "Checking drive $($Drive.Name):\"

        $Folders = Get-ChildItem "$($Drive.Name):\" -Directory -Filter "E26*" -ErrorAction SilentlyContinue

        foreach ($Folder in $Folders) {
            $NewName = $Folder.Name -replace "^E26","T26"
            Rename-Item $Folder.FullName -NewName $NewName -Force
            Write-Output "Renamed $($Folder.FullName) to $NewName"
        }
    }
}
Stop-ProgramAndRenameFolders

# -------- VALIDATE Production DESKTOP --------
if (-not (Test-Path $PublicDesktop)) {
    Write-Log "Production Desktop path not found: $PublicDesktop"
    exit
}

$OldShortcutPath = Join-Path $PublicDesktop $OldShortcutName
$NewShortcutDest = Join-Path $PublicDesktop $NewShortcutName

# -------- REMOVE OLD SHORTCUT --------
if (Test-Path $OldShortcutPath) {
    try {
        Remove-Item $OldShortcutPath -Force
        Write-Log "Removed old shortcut: $OldShortcutPath"
    }
    catch {
        Write-Log "Failed to remove old shortcut: $_"
    }
}
else {
    Write-Log "Old shortcut not found. Skipping removal."
}

# -------- COPY NEW SHORTCUT --------
if (Test-Path $NewShortcutSource) {
    try {
        Copy-Item -Path $NewShortcutSource -Destination $NewShortcutDest -Force
        Write-Log "Copied new shortcut to: $NewShortcutDest"
    }
    catch {
        Write-Log "Failed to copy new shortcut: $_"
    }
}
else {
    Write-Log "New shortcut source not found: $NewShortcutSource"
    exit
}

# -------- GET DEVICE + USER INFO --------
$ComputerName = $env:COMPUTERNAME
$LoggedOnUser = (Get-CimInstance Win32_ComputerSystem).UserName

if (-not $LoggedOnUser) {
    $LoggedOnUser = "No interactive user logged in"
}

# --- Send Teams Adaptive Card ---
$ComputerName = $env:COMPUTERNAME
$UserName = (Get-CimInstance Win32_ComputerSystem).UserName

$AdaptiveCard = @{
    type    = "AdaptiveCard"
    version = "1.2"
    body    = @(
        @{
            type  = "TextBlock"
            text  = "Photo Manager Training Mode Disabled"
            weight= "Bolder"
            size  = "Medium"
            color = "Attention"
        },
        @{
            type = "TextBlock"
            text = "Device: $ComputerName"
            wrap = $true
        },
        @{
            type = "TextBlock"
            text = "User: $UserName"
            wrap = $true
        },
        @{
            type = "TextBlock"
            text = "The Photo Manager training mode shortcut has been removed. User has been switched to normal mode."
            wrap = $true
        }
    )
} | ConvertTo-Json -Depth 5

# --- Send the card ---
try {
    Invoke-RestMethod -Uri $WebhookUrl `
        -Method Post `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($AdaptiveCard)) `
        -ContentType 'application/json; charset=utf-8'
    Write-Log "Teams adaptive card sent successfully."
}
catch {
    Write-Log "Failed to send Teams adaptive card: $_"
}

Write-Log "Training mode script completed."