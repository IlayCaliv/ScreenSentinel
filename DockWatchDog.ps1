param (
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath
)


Import-Module PSFramework

# Device instance path from Device Manager


$config = Get-Content $ConfigPath | ConvertFrom-Json
$config.Default_Setup | Add-Member -NotePropertyName Name -NotePropertyValue "Default Setup"

$headers = 'Timestamp', 'Level', 'Message'
$paramSetPSFLoggingProvider = @{
    Name          = 'logfile'
    InstanceName  = 'DockWatchDog'
    FilePath      = "$($config.logging.LogDir)\DockWatchDog-%Date%.csv"
    Headers       = $headers
    Enabled       = $true
    Wait          = $true
    LogRotatePath = "$($config.logging.LogDir)\DockWatchDog-*.csv"
}

Set-PSFLoggingProvider @paramSetPSFLoggingProvider


function Get-AreListsEqual {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$ListA,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$ListB
    )

    $listASorted = $ListA | Sort-Object
    $listBSorted = $ListB | Sort-Object

    if (!$listASorted) 
    {
        $listASorted = @()
    }
    if(!$listBSorted)
    {
        $listBSorted = @()
    }
    return (($listASorted.Count -eq $listBSorted.Count) -and ($null -eq (Compare-Object $listASorted $listBSorted)))
}

function Get-Setup {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$ScreensWithoutLaptop
    )

    $setup = $null
    $config.Specific_Setups | ForEach-Object {if(Get-AreListsEqual -ListA $_.MonitorSerials -ListB $ScreensWithoutLaptop) {$setup = $_}}
    if($setup) {
        return $setup
    }
    $config.Generic_Setups | ForEach-Object {if($_.Num_of_external_screens -eq $ScreensWithoutLaptop.Count) {$setup = $_}}
    if($setup) {
        return $setup
    }
    else {
        return $config.Default_Setup
    }

}

function Configure-Setup {
    param (
    $setup, $screens
    )
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LidAction $setup.LidAction
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LidAction $setup.LidAction
    powercfg /SETACTIVE SCHEME_CURRENT
    if($config.LaptopScreenSerialId -iin $screens) {
        DisplaySwitch.exe $setup.LidOpenedDisplayMode
        Write-PSFMessage -Level Output -Message "Lid is open. Setting Display mode to $($setup.LidOpenedDisplayMode)"
    }
    else {
        DisplaySwitch.exe $setup.LidClosedDisplayMode
        Write-PSFMessage -Level Output -Message "Lid is closed. Setting Display mode to $($setup.LidClosedDisplayMode)"
    }

}


Write-PSFMessage -Level Output -Message "Dock watchdog service started"
$previousScreens = @()

while ($true) 
{
    $screens = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
    ($_.SerialNumberID | ForEach-Object { [char]$_ }) -join ''
    }

    if(! $screens) {
        $screens = @()
    }

    $changeInScreens = !(Get-AreListsEqual -ListA $screens -ListB $previousScreens)

    if($changeInScreens)
    {
        $screensWithoutLaptop = $screens | Where-Object {$_ -ne $config.LaptopScreenSerialId}
        if(! $screensWithoutLaptop ) {
            $screensWithoutLaptop = @()
        }
        $setup = Get-Setup -ScreensWithoutLaptop $screensWithoutLaptop
        Write-PSFMessage -Level Output -Message "Identifyied setup: $($setup.Name)"
        Configure-Setup -setup $setup -screens $screens
    }

    Start-Sleep -Seconds 5
    $previousScreens = $screens
}

