#powercfg /hibernate on
# Set Lid Close on Battery (DC) to Hibernate
powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 3
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 1

# Force write + refresh
powercfg /setactive SCHEME_CURRENT
powercfg /qh > $null