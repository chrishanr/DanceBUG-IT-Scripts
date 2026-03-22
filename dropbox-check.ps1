# --- Config ---
$LogFile = "C:\ProgramData\IT-Admin\logs\dropbox-audit.log"

# --- Logging ---
function Write-Log {
    param ([string]$Message)
    if (!(Test-Path $LogFile)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

# --- Get logged-in user ---
$User = (Get-CimInstance Win32_ComputerSystem).UserName

if ($null -eq $User) {
    Write-Log "No logged-in user detected."
    exit
}

# Extract username only
$Username = $User.Split("\")[-1]

# --- Dropbox config path ---
$DropboxPath = "C:\Users\$Username\AppData\Local\Dropbox\info.json"

if (!(Test-Path $DropboxPath)) {
    Write-Log "$env:COMPUTERNAME - Dropbox not found for user $User"
    Write-Output "Dropbox not found for user $User"
    exit
}

# --- Read Dropbox email ---
try {
    $Json = Get-Content $DropboxPath -Raw | ConvertFrom-Json

    # Dropbox can have personal or business accounts
    $Email = $null

    if ($Json.personal.email) {
        $Email = $Json.personal.email
    }
    elseif ($Json.business.email) {
        $Email = $Json.business.email
    }

    if ($null -ne $Email) {
        Write-Log "$env:COMPUTERNAME - Dropbox logged in as $Email"
    }
    else {
        Write-Log "$env:COMPUTERNAME - Dropbox installed but email not found"
    }

} catch {
    Write-Log "$env:COMPUTERNAME - Failed to read Dropbox config"
}