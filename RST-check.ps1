
# ================================
# Storage Controller Health Script
# ================================
$WebhookUrl = "https://defaulteb6ac93710a44e86adf0ee412b4651.69.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/fbdbc04a4a6b466b912f6775ed0a021b/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=wibGRHpjHdWHWE50xS0_VdHtrrkdbjyeSdfKQseCpZU"
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
$AtRisk = ($storahci -ne 0 -or $iaStorAVC -ne 0)

Write-Log "At Risk Status: $AtRisk"

# If NOT at risk, stop script
if (-not $AtRisk) {
    Write-Log "System is NOT at risk. Exiting."
    exit
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
            text  = "Stream Computer At Risk"
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
            text = "Status: $($AtRisk)"
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