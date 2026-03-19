# ===================== CONFIG =====================
$WebhookUrl = "https://defaulteb6ac93710a44e86adf0ee412b4651.69.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/fbdbc04a4a6b466b912f6775ed0a021b/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=wibGRHpjHdWHWE50xS0_VdHtrrkdbjyeSdfKQseCpZU"
$LogFile = "C:\ProgramData\IT-Admin\Logs\voicemeeter-check.log"

# --- Logging function ---
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding utf8
}

# --- Get logged-in user ---
$User = (Get-CimInstance Win32_ComputerSystem).UserName

if ($null -eq $User) {
    Write-Log "No logged-in user detected."
    exit
}

# Convert DOMAIN\user → SID
try {
    $SID = (New-Object System.Security.Principal.NTAccount($User)).Translate([System.Security.Principal.SecurityIdentifier]).Value
} catch {
    Write-Log "Failed to resolve SID for user: $User"
    exit
}

# --- Registry path ---
$RegPath = "Registry::HKEY_USERS\$SID\VB-Audio\Voicemeeter"
$RegName = "Serial"

# --- Check registry ---
$Serial = $null

if (Test-Path $RegPath) {
    try {
        $Serial = (Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction Stop).$RegName
    } catch {
        $Serial = $null
    }
}

# --- Check ID Type ---
$IdFile = "C:\DB\Files\ID-TYPE.txt"

if (!(Test-Path $IdFile)) {
    Write-Output "ID-TYPE.txt not found. Exiting script."
    Write-Log "ID-TYPE.txt not found. Exiting script."
    exit
}

$IdType = (Get-Content $IdFile -Raw).Trim()

if ($IdType -ne "Capture") {
    Write-Output "Device is not a Capture machine ($IdType). Exiting script."
    Write-Log "Device is not a Capture machine ($IdType). Exiting script."
    exit
}




# --- Result ---
if ($null -ne $Serial -and $Serial -ne "") {
    Write-Log "Voicemeeter is REGISTERED for $User"
}
else {
    Write-Log "Voicemeeter is NOT registered for $User"

    # --- Send Teams webhook ---
    $Body = @{
        type = "message"
        attachments = @(
            @{
                contentType = "application/vnd.microsoft.card.adaptive"
                content = @{
                    type = "AdaptiveCard"
                    version = "1.4"
                    body = @(
                        @{
                            type = "TextBlock"
                            size = "Large"
                            weight = "Bolder"
                            text = "Voicemeeter Registration Missing"
                        },
                        @{
                            type = "TextBlock"
                            text = "User: $User"
                            wrap = $true
                        },
                        @{
                            type = "TextBlock"
                            text = "Device: $env:COMPUTERNAME"
                            wrap = $true
                        },
                        @{
                            type = "TextBlock"
                            text = "Voicemeeter is NOT registered on this machine."
                            wrap = $true
                        }
                    )
                }
            }
        )
    } | ConvertTo-Json -Depth 5

    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $Body -ContentType "application/json"
    } catch {
        Write-Log "Failed to send Teams notification"
    }
}