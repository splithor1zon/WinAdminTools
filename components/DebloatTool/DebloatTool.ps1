Set-Location $PSScriptRoot
Import-Module -Name .\DebloatModule\DebloatModule.psm1 -Force

$appVersion = "0.0.0"
$profFormat = "0"

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
    $profs = Get-ChildItem -Path ".\profiles" -Filter "*.json" | Select-Object -ExpandProperty BaseName
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
        $selection = Read-Host "Please select an option: "
        if ($selection -eq "x") {
            return $null
        }
    } while ($selection -notin 1..$profs.Count)
    
    return $profs[[int]$selection - 1]
}

Function Show-ProfileInfo {
    param(
        [Parameter(Mandatory)][string]$profName
    )
    
    Clear-Host
    $selectedProfile = Get-Profile $profName
    $profInfo = @"
Profile information
-------------------

Name:           $($selectedProfile.Name)
Description:    $($selectedProfile.Description)
Version:        $($selectedProfile.Version) (Current version: $profFormat)
UWP Applists:   $($selectedProfile.applists_uwp)
Win32 Applists: $($selectedProfile.applists_win32)
Regs:           $($selectedProfile.regs)

"@
    Write-Host $profInfo
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

Version: $appVersion
Profile Format: $profFormat

Credits:
https://github.com/Raphire/Win11Debloat

"@

# Show menu and wait for user input, loops until valid input is provided
while ($true) {
    do { 
        Clear-Host
        Write-Host $mainMenu

        $mode = Read-Host "Please select an option: "

        if ($mode -eq 'x') {
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

                Write-Host "Press any key to go back..."
                $null = [System.Console]::ReadKey()
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