# Ensure hibernate is available (required for some lid actions)
powercfg /hibernate off

# Get all power schemes
$schemes = powercfg /list | ForEach-Object {
    if ($_ -match "([A-F0-9\-]{36})") { $matches[1] }
}

foreach ($scheme in $schemes) {

    # AC = Shutdown (3)
    powercfg /setacvalueindex $scheme SUB_BUTTONS LIDACTION 3

    # DC = Shutdown (3)
    powercfg /setdcvalueindex $scheme SUB_BUTTONS LIDACTION 3
}

# Re-activate current scheme so Windows refreshes GUI
$current = (powercfg /getactivescheme) -replace ".*GUID:\s*([a-f0-9\-]+).*",'$1'
powercfg /setactive $current

# Refresh power policy
powercfg /qh > $null