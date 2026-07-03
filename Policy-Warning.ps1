# ============================
# DanceBUG IT Policy Warning
# ============================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Log location
$LogFolder = "C:\ProgramData\IT-Admin\logs"
$LogFile = "$LogFolder\PolicyAcknowledgement.log"

if (!(Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'DanceBUG IT Policy Warning'
$form.Size = New-Object System.Drawing.Size(520,300)
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

# Warning Icon
$icon = New-Object System.Windows.Forms.PictureBox
$icon.Image = [System.Drawing.SystemIcons]::Warning.ToBitmap()
$icon.SizeMode = 'AutoSize'
$icon.Location = New-Object System.Drawing.Point(20,20)
$form.Controls.Add($icon)

# Message
$label = New-Object System.Windows.Forms.Label
$label.Text = "One or more unauthorized programs have been detected `non this device. `n`nPlease uninstall the program(s) as soon as possible. `n`nContact it-support@dancebug.com if you have any questions.`n"
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(80,20)
$form.Controls.Add($label)

# Link
$link = New-Object System.Windows.Forms.LinkLabel
$link.Text = "Click here to review the Computer Usage Policy"
$link.AutoSize = $true
$link.Location = New-Object System.Drawing.Point(80,140)
$link.Add_Click({
    Start-Process "https://drcvid-my.sharepoint.com/:w:/g/personal/chrishanr_dancebug_com/IQBuBCvX4_TiSrOpFAKRmxVgAVY2XAFGZ0VBSK1wFkvKTpc?e=57Wt8c"})
$form.Controls.Add($link)

# OK Button
$button = New-Object System.Windows.Forms.Button
$button.Text = "Acknowledge"
$button.Width = 100
$button.Height = 30
$button.Location = New-Object System.Drawing.Point(200,200)

$button.Add_Click({

    $User = $env:USERNAME
    $Computer = $env:COMPUTERNAME
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $LogEntry = "$Time | User: $User | Computer: $Computer | Acknowledged IT Policy Warning"

    Add-Content -Path $LogFile -Value $LogEntry

    $form.Close()
})

$form.Controls.Add($button)

$form.ShowDialog()