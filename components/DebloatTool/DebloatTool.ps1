Import-Module -Name .\DebloatModule\DebloatModule.psm1 -Force

$appVersion = "0.0.0"
$profileFormat = "0"

# Show error if current powershell environment does not have LanguageMode set to FullLanguage 
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Host "Error: Win11Debloat is unable to run on your system, powershell execution is restricted by security policies" -ForegroundColor Red
    Write-Output ""
    Write-Output "Press enter to exit..."
    Read-Host | Out-Null
    exit
}

# Check if winget is installed & if it is, check if the version is at least v1.4
if ((Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*") -and ((winget -v) -replace 'v','' -gt 1.4)) {
    $global:wingetInstalled = $true
}
else {
    $global:wingetInstalled = $false

    # Show warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
    if (-not $Silent) {
        Write-Warning "Winget is not installed or outdated. This may prevent Win11Debloat from removing certain apps."
        Write-Output ""
        Write-Output "Press any key to continue anyway..."
        $null = [System.Console]::ReadKey()
    }
}

# Profile selection menu
function Invoke-ProfileSelection {
    $profiles = Get-ChildItem -Path ".\profiles" -Filter "*.json" | Select-Object -ExpandProperty BaseName
    do {
        $num = 1
        Clear-Host
        Write-Host "Select your profile:"
        foreach ($profile in $profiles) {
            Write-Host "  ($num) $profile"
            $num++
        }
        Write-Host ""
        Write-Host "(x) Back"
        Write-Host ""
        $selection = Read-Host "Your selection: "
        if ($selection -eq "x") {
            return $null
        }
    } while ($selection -notin 1..$profiles.Count)
    
    return $profiles[[int]$selection - 1]
}

Function Show-ProfileInfo {
    param(
        [Parameter(Mandatory)][string]$profileName
    )
    
    Clear-Host
    $selectedProfile = Get-Profile $profileName
    $profileInfo = @"
Profile information
-------------------

Name:           $($selectedProfile.Name)
Description:    $($selectedProfile.Description)
Version:        $($selectedProfile.Version) (Current version: $profileFormat)
UWP Applists:   $($selectedProfile.applists_uwp)
Win32 Applists: $($selectedProfile.applists_win32)
Regs:           $($selectedProfile.regs)

"@
    Write-Host $profileInfo
    Write-Host "Press any key to go back..."
    $null = [System.Console]::ReadKey()
}

###########################
# Main part of the script #
###########################

$modes = @('a', 'b', 'c')

$header = @"
# ------------------------------------- #
#           WAT: Debloat Tool           #
# App Version: $appVersion  Profile Format: $profileFormat #
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

Version: $appVersion
Profile Format: $profileFormat

Credits:
https://github.com/Raphire/Win11Debloat

"@

# Show menu and wait for user input, loops until valid input is provided
while ($true) {
    do { 
        Clear-Host
        Write-Host $mainMenu

        $mode = Read-Host "Please select an option (a/b/c/i/x)"

        if ($mode -eq 'x') {
            Write-Host "Thank you, bye!"
            exit
        } elseif ($mode -eq 'i') {
            Clear-Host
            Write-Host $infoCredits
            Write-Host "Press any key to go back..."
            $null = [System.Console]::ReadKey()
        }
    }
    while ($mode -notin $modes)

    # Switch statement to handle user input
    Switch ($mode) {
        'a' {
            Write-Host "Applying a profile"
            $selectedProfile = Invoke-ProfileSelection
            if ($null -ne $selectedProfile) {
                $prof = Get-Profile $selectedProfile
                Remove-UWPApps $prof
                Remove-Win32Apps $prof
                Import-Regs $prof
            }
            break
        }
        'b' {
            Write-Host "Creating a profile"
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