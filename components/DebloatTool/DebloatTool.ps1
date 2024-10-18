Import-Module $PSScriptRoot\DebloatModule

$AppVersion = "0.0.0"
$ProfileFormat = "0"

# Show error if current powershell environment does not have LanguageMode set to FullLanguage 
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Host "Error: Win11Debloat is unable to run on your system, powershell execution is restricted by security policies" -ForegroundColor Red
    Write-Output ""
    Write-Output "Press enter to exit..."
    Read-Host | Out-Null
    Exit
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

###########################
# Main part of the script #
###########################

$Modes = @('a', 'b', 'c')

$Header = @"
# ------------------------------------- #
#           WAT: Debloat Tool           #
# App Version: $AppVersion  Profile Format: $ProfileFormat #
# ------------------------------------- #
"@

$MainMenu = @"
$Header

(a) Apply a profile
(b) Create a profile
(c) List profile settings

(i) Show credits & information
(x) Exit

"@

$InfoCredits = @"
$Header

Developed by: Damian Filo

Version: $AppVersion
Profile Format: $ProfileFormat

Credits:
https://github.com/Raphire/Win11Debloat

"@

# Show menu and wait for user input, loops until valid input is provided
Do { 
    Clear-Host
    Write-Output $MainMenu

    $Mode = Read-Host "Please select an option (a/b/c/i/x)"

    if ($Mode -eq 'x') {
        Write-Output "Thank you, bye!"
        exit
    } elseif ($Mode -eq 'i') {
        Clear-Host
        Write-Output $InfoCredits
        Write-Output "Press any key to go back..."
        Read-Host | Out-Null
    }
}
while ($Mode -notin $Modes)

# Load list of profiles and show selection menu
function ProfileSelection {
    $profiles = Get-ChildItem -Path "$PSScriptRoot\profiles" -Filter "*.json" | Select-Object -ExpandProperty Name
#TODO: Implement profile selection
}

# Switch statement to handle user input
switch ($Mode) {
    'a' {
        Write-Output "Applying a profile"
        $selectedProfile = ProfileSelection
    }
    'b' {
        Write-Output "Creating a profile"
    }
    'c' {
        Write-Output "Listing profile settings"
    }
}