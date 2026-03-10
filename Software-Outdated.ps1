# ============================
# Last Software Update Checker
# ============================

$WebhookUrl = "https://defaulteb6ac93710a44e86adf0ee412b4651.69.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/fbdbc04a4a6b466b912f6775ed0a021b/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=wibGRHpjHdWHWE50xS0_VdHtrrkdbjyeSdfKQseCpZU"
$LastUpdateFile = "C:\DB\FILES\SOFTWAREUPDATE-LASTRUN.TXT"
$LogPath = "C:\ProgramData\IT-Admin\logs\softwareupdate-lastrun.log"

# --- Logging Function ---
function Write-Log {
    param ($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "$timestamp - $Message"
}

Write-Log "Checking last software update..."

# --- Check if file exists ---
if (-not (Test-Path $LastUpdateFile)) {
    Write-Log "Last update file not found. Exiting."
    exit
}

# --- Read and parse the date ---
$LastUpdateText = (Get-Content $LastUpdateFile -Raw).Trim()

# Example format: "Mon 02/23/2026 23:35:49.00"
try {
    $LastUpdate = [datetime]::ParseExact($LastUpdateText, "ddd MM/dd/yyyy HH:mm:ss.ff", $null)
} catch {
    Write-Log "Failed to parse date from file: $LastUpdateText"
    exit
}

# --- Check if older than 7 days ---
$Now = Get-Date
$DaysSinceUpdate = ($Now - $LastUpdate).TotalDays

if ($DaysSinceUpdate -le 7) {
    Write-Log "Last update is recent ($DaysSinceUpdate days). No alert sent."
    exit
}

Write-Log "Last update is older than 7 days ($DaysSinceUpdate days). Sending alert..."

# --- Prepare Adaptive Card ---
$ComputerName = $env:COMPUTERNAME

$AdaptiveCard = @{
    type    = "AdaptiveCard"
    version = "1.2"
    body    = @(
        @{
            type  = "TextBlock"
            text  = "Software Update Alert"
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
            text = "Last software update was on $($LastUpdate.ToString('ddd MM/dd/yyyy HH:mm:ss')). It has been $([math]::Round($DaysSinceUpdate,2)) days since the last update."
            wrap = $true
        }
    )
} | ConvertTo-Json -Depth 5

# --- Send to Teams ---
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