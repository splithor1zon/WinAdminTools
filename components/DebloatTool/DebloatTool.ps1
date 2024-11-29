Set-Location $PSScriptRoot
Import-Module -Name .\DebloatModule\DebloatModule.psm1 -Force

$progressPreference = 'silentlyContinue'
$appVersion = "0.0.2"
$profFormat = "1"
$minWinGetVersion = 1.8

# Show error if current powershell environment does not have LanguageMode set to FullLanguage 
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Host "Error: Win11Debloat is unable to run on your system, powershell execution is restricted by security policies" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press enter to exit..."
    $null = [System.Console]::ReadKey()
    exit
}

# Check if winget is installed & if it is, check if the version is at least $minWinGetVersion
Write-Host "Checking winget version..."
$wingetVer = 0
try {
    $wingetVer = ((winget -v) -replace 'v','')
} catch {
    Write-Host "Winget missing" -ForegroundColor Red
}

if ($wingetVer -lt $minWinGetVersion) {
    Write-Host "Installed: $wingetVer, Required: >$minWinGetVersion"
    # Try to install winget
    try {
        Write-Host "Downloading WinGet..."
        Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
        Write-Host "Installing WinGet..."
        Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
        Remove-Item Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
    } catch {
        Write-Host "Winget installation was not successful, please install/update winget manually. After update, start the script again."
        Write-Host "Press any key to start Microsoft Store to update App Installer..."
        $null = [System.Console]::ReadKey()
        Start-Process ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1
        exit
    }
}

# Profile selection menu
function Invoke-ProfileSelection {
    $profs = @()
    Get-ChildItem -Path ".\profiles" -Filter "*.json" | ForEach-Object { $profs += $_.BaseName }

    do {
        $num = 1
        Clear-Host
        Write-Host "Select your profile:"
        foreach ($prof in $profs) {
            Write-Host "  ($num) $prof"
            $num++
        }
        Write-Host ""
        Write-Host "(x) Back"
        Write-Host ""
        $selection = Read-Host "Please select an option"
        if ($selection -eq "x") {
            return $null
        }
    } while ($selection -notin 1..$profs.Count)
    
    return $profs[[int]$selection - 1]
}

<#
.SYNOPSIS
    This function shows profile info based on provided profile name.
.PARAMETER Name
    Required. Profile name string.
#>
function Show-ProfileInfo {
    param(
        [Parameter(Mandatory)][string]$Name
    )
    
    Clear-Host
    $prof = Get-Profile $Name
    if ($null -eq $prof) {
        Write-Host @"
Profile '$Name' not found...

Press any key to go back...
"@ -ForegroundColor Red
        $null = [System.Console]::ReadKey()
    } else {
        Write-Host @"
Profile information
-------------------

Name:           $($prof.Name)
Description:    $($prof.Description)
Version:        $($prof.Version) (Current version: $profFormat)
UWP Applists:   $($prof.applists_uwp)
Win32 Applists: $($prof.applists_win32)
Regs:           $($prof.regs)

Press any key to go back...
"@
        $null = [System.Console]::ReadKey()
    }
}

# Main Menu

$modes = @('a', 'b', 'c')

$header = @"
# ------------------------------------- #
#           WAT: Debloat Tool           #
# App Version: $appVersion  Profile Format: $profFormat #
# ------------------------------------- #
"@

$mainMenu = @"
$header

(a) Apply a profile
(b) Create a profile
(c) List profile settings

(i) Show credits & information
(x) Exit

"@

$infoCredits = @"
$header

Developed by: Damian Filo
https://github.com/splithor1zon/WinAdminTools

Credits:
https://github.com/Raphire/Win11Debloat

"@

# Show menu and wait for user input, loops until valid input is provided
while ($true) {
    do { 
        Clear-Host
        Write-Host $mainMenu
        $mode = Read-Host "Please select an option"

        if ($mode -eq 'x') {
            exit
        } elseif ($mode -eq 'i') {
            Clear-Host
            Write-Host $infoCredits -ForegroundColor Magenta
            Write-Host "Press any key to go back..."
            $null = [System.Console]::ReadKey()
        }
    } while ($mode -notin $modes)

    # Switch statement to handle user input
    switch ($mode) {
        'a' {
            Write-Host "Applying a profile"
            $selectedProfile = Invoke-ProfileSelection
            if ($null -ne $selectedProfile) {
                Invoke-ProfileApplication $selectedProfile
            }
            break
        }
        'b' {
            Write-Host "Not implemented yet..."
            $null = [System.Console]::ReadKey()
            break
        }
        'c' {
            $selectedProfile = Invoke-ProfileSelection
            if ($null -ne $selectedProfile) {
                Show-ProfileInfo $selectedProfile
            }
            break
        }
    }
}