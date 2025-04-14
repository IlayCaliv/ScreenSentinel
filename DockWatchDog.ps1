Import-Module PSFramework


# Device instance path from Device Manager
$monitorIds = "DISPLAY\MSI3BC0\4&2DF1E0B1&1&UID4163_0", "DISPLAY\MSI3BC0\4&2DF1E0B1&1&UID8515_0"
$laptopScreenId = "DISPLAY\SDC414B\4&2df1e0b1&1&UID8388688_0"

$headers = 'Timestamp', 'Level', 'Message'
$paramSetPSFLoggingProvider = @{
    Name          = 'logfile'
    InstanceName  = 'DockWatchDog'
    FilePath      = 'C:\Scripts\DockWatchDog-%Date%.csv'
    Headers       = $headers
    Enabled       = $true
    Wait          = $true
    LogRotatePath = 'C:\Scripts\DockWatchDog-*.csv'
}

Set-PSFLoggingProvider @paramSetPSFLoggingProvider
$perviousScreens = @()
Write-PSFMessage -Level Output -Message "Dock watchdog service started"
while ($true) 
{
    $screens = (Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams).InstanceName 
    if(! $screens) {
        $screens = @()
    }

    $screensSorted = $screens | Sort-Object
    $previousScreendSorted = $previousScreens | Sort-Object
    $changeInScreens = !(($screensSorted.Count -eq $previousScreendSorted.Count) -and ($null -eq (Compare-Object $screensSorted $previousScreendSorted)))

    $relevantSetupConnected = $monitorIds | Where-Object {$_ -iin $screens}


    if ($relevantSetupConnected) {
        if($changeInScreens)
        {
            Write-PSFMessage -Level Output -Message "Dock recognized"
            if($laptopScreenId -iin $screens) {
                DisplaySwitch.exe 4
                Write-PSFMessage -Level Output -Message "Recognized open lid, changed displayswitch mode to external."
            }
            else {
                DisplaySwitch.exe 3
                Write-PSFMessage -Level Output -Message "Recognized closed lid, changed displayswitch mode to extend."
            }

            # AC = plugged in, DC = on battery
            # Lid close action values:
            # 0 = Do nothing
            # 1 = Sleep
            # 2 = Hibernate
            # 3 = Shut down
            powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LidAction 0
            powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LidAction 0
            powercfg /SETACTIVE SCHEME_CURRENT
            Write-PSFMessage -Level Output -Message "changed lid action to 'do nothing'."

        }

        
    }
    else 
    {
        if($changeInScreens)
        {
            DisplaySwitch.exe 3
            powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LidAction 1
            powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LidAction 1
            powercfg /SETACTIVE SCHEME_CURRENT
            Write-PSFMessage -Level Output -Message "Dock isn't recognized, changed displayswitch mode to 'extend', and lid action to 'sleep'."
        }
    }

    Start-Sleep -Seconds 5
    $previousScreens = $screens
}