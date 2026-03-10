# ================================
# DB Weekly Software Compliance Audit
# ================================

$WebhookUrl = "https://defaulteb6ac93710a44e86adf0ee412b4651.69.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/fbdbc04a4a6b466b912f6775ed0a021b/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=wibGRHpjHdWHWE50xS0_VdHtrrkdbjyeSdfKQseCpZU"
$ApprovedListPath = "C:\ProgramData\IT-Admin\Scripts\programs.txt"
$LogPath = "C:\ProgramData\IT-Admin\logs\SoftwareAudit.log"

# --- Logging Function ---
function Write-Log {
    param ($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "$timestamp - $Message"
}

Write-Log "Starting weekly software audit..."

# --- Validate Approved List ---
if (-not (Test-Path $ApprovedListPath)) {
    Write-Log "Approved software list not found. Exiting."
    exit
}

$ApprovedSoftware = Get-Content $ApprovedListPath | Where-Object { $_.Trim() -ne "" }

# --- Collect Installed Software (64-bit + 32-bit) ---
$InstalledSoftware = @()

$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($Path in $UninstallPaths) {
    $InstalledSoftware += Get-ItemProperty $Path -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName } |
        Select-Object -ExpandProperty DisplayName
}

$InstalledSoftware = $InstalledSoftware | Sort-Object -Unique

# --- Compare ---
$Unauthorized = $InstalledSoftware | Where-Object {
    $app = $_
    -not ($ApprovedSoftware | Where-Object { $app -like "*$_*" })
}

if ($Unauthorized.Count -eq 0) {
    Write-Log "No unauthorized software found."
    exit
}

Write-Log "Unauthorized software detected: $($Unauthorized -join ', ')"

# --- Prepare Adaptive Card ---
$ComputerName = $env:COMPUTERNAME
$UserName = (Get-CimInstance Win32_ComputerSystem).UserName

$UnauthorizedText = ($Unauthorized | ForEach-Object { "- $_" }) -join "`n"

$AdaptiveCard = @{
    type    = "AdaptiveCard"
    version = "1.2"
    body    = @(
        @{
            type  = "TextBlock"
            text  = "Unauthorized Software Detected"
            weight= "Bolder"
            size  = "Medium"
            color = "Attention"
        },
        @{
            type = "TextBlock"
            text = "Device: $ComputerName`nUser: $UserName"
            wrap = $true
        },
        @{
            type = "TextBlock"
            text = "Unapproved Applications Found:`n$UnauthorizedText"
            wrap = $true
        }
    )
} | ConvertTo-Json -Depth 5

# --- Send Adaptive Card to Teams ---
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