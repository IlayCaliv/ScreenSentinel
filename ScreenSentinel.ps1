param (
    [string]$ConfigPath = ".\config.json"
)


Import-Module PSFramework

$displayModeMap = @{
    1 = 'Internal'
    2 = 'Clone'
    3 = 'Extend'
    4 = 'External'
}


$lidActionMap = @{
    0 = 'Do Nothing'
    1 = 'Sleep'
    2 = 'Hibernate'
    3 = 'Shutdown'
}

$config = Get-Content $ConfigPath | ConvertFrom-Json
$config.Default_Setup | Add-Member -NotePropertyName Name -NotePropertyValue "Default Setup"

$headers = 'Timestamp', 'Level', 'Message'
$paramSetPSFLoggingProvider = @{
    Name          = 'logfile'
    InstanceName  = 'DockWatchDog'
    FilePath      = "$($config.logging.LogDir)\ScreenSentinel-%Date%.csv"
    Headers       = $headers
    Enabled       = $true
    Wait          = $true
    LogRotatePath = "$($config.logging.LogDir)\ScreenSentinel-*.csv"
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

function Set-DisplayMode { 
    param (
        [Parameter(Mandatory = $true)]
        [int]$Mode
    )
    if($config.RunAsService)
    {
        $taskName = "ScreenSentinel_DisplaySwitch"
        $action = "DisplaySwitch.exe $($Mode)"
        schtasks /Create `
            /TN $taskName `
            /TR $action `
            /SC ONCE `
            /ST 00:00 `
            /RL HIGHEST `
            /F `
            /RU $env:USERNAME

        Start-Process schtasks -ArgumentList "/Run /TN ScreenSentinel_DisplaySwitch" -NoNewWindow
    }
    else 
    {
        DisplaySwitch.exe $Mode
    }

}


function Configure-Setup {
    param (
    $setup, $screens
    )
    powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LidAction $setup.LidAction
    powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LidAction $setup.LidAction
    powercfg /SETACTIVE SCHEME_CURRENT
    Write-PSFMessage -Level Output -Message "Setting Lid action to: '$($lidActionMap[$setup.LidAction])'"
    if($config.LaptopScreenSerialId -iin $screens) {
        Set-DisplayMode -Mode $setup.LidOpenedDisplayMode
        Write-PSFMessage -Level Output -Message "Lid is open. Setting Display mode to: '$($displayModeMap[$setup.LidOpenedDisplayMode])'"
    }
    else {
        Set-DisplayMode -Mode $setup.LidClosedDisplayMode
        Write-PSFMessage -Level Output -Message "Lid is closed. Setting Display mode to: '$($displayModeMap[$setup.LidClosedDisplayMode])'"
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
        Write-PSFMessage -Level Output -Message "Identifyied setup: '$($setup.Name)'"
        Configure-Setup -setup $setup -screens $screens
    }

    Start-Sleep -Seconds 5
    $previousScreens = $screens
}

