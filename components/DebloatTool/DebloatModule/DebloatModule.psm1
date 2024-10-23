<#
.SYNOPSIS
    Get-Profile function is used to load a json debloat profile.
.PARAMETER Name
    Required. Name of the json file to load.
#>
function Get-Profile {
    param(
        [Parameter(Mandatory)][string]$Name
    )

    $profilePath = ".\profiles\$Name.json"
    if (-not (Test-Path $profilePath)) {
        return $null
    }

    $prof = Get-Content -Path $profilePath -Raw | ConvertFrom-Json
    # TODO: Validate the profile
    return $prof
}

<#
.SYNOPSIS
    Reads the list of apps from the specified file. Trims the app names and removes any comments.
.PARAMETER Type
    Required. Type of applist of interest. Either "uwp" or "win32" permitted.
.PARAMETER Name
    Required. Name of the applist file.
.PARAMETER ListAll
    Optional. If specified, the function will return all apps, including the disabled ones.
#>
function Get-Applist {
    param(
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Name,
        [switch]$ListAll
    )

    $applistPath = ""
    switch ($Type) {
        'uwp' {
            $applistPath = ".\applists_uwp\$Name.txt"
            break
        }
        'win32' {
            $applistPath = ".\applists_win32\$Name.txt"
            break
        }
        default {
            throw "Invalid type: $Type, Only 'uwp' or 'win32' are permitted."
        }
    }

    # Test if the file exists
    if (-not (Test-Path $applistPath)) {
        throw "Applist file not found: $applistPath"
    }

    # Get list of apps from file at the path provided, and populate the applist array
    $appList = @()
    foreach ($app in (Get-Content -Path $applistPath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' })) {
        # Remove any comments from the Appname
        if (-not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }

        # Process disabled apps
        if ($app.StartsWith('% ')) {
            if ($ListAll) {
                $app = $app.TrimStart('% ')
            } else {
                continue
            }
        }

        # Remove any spaces before and after the Appname
        $app = $app.Trim()
        $appString = $app.Trim('*')

        $appList += $appString
    }
    return $appList
}

<#
.SYNOPSIS
    Loops through provided app IDs and tries uninstalling them.
.PARAMETER Name
    Required. String or array of strings of UWP app IDs.
#>
function Remove-UWPApp {
    param(
        [Parameter(Mandatory)][array]$Name
    )

    $winVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild
    foreach ($app in $Name) {
        Write-Host "  <> $app"
        $app = '*' + $app + '*'

        # Remove installed app for all existing users
        if ($winVersion -ge 22000){
            # Windows 11
            try {
                Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
            } catch {
                Write-Host "Unable to remove $app for all users" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        } else {
            # Windows 10
            try {
                Get-AppxPackage -Name $app | Remove-AppxPackage -ErrorAction SilentlyContinue
            } catch {
                Write-Host "Unable to remove $app for current user" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
            try {
                Get-AppxPackage -Name $app -PackageTypeFilter Main, Bundle, Resource -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            } catch {
                Write-Host "Unable to remove $app for all users" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        }

        # Remove provisioned app from OS image, so the app won't be installed for any new users
        try {
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
        } catch {
            Write-Host "Unable to remove $app from windows image" -ForegroundColor Yellow
            Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
        }
    }
    Write-Host ""
}

<#
.SYNOPSIS
    Loops through provided list of winget app IDs and tries uninstalling them.
.PARAMETER Name
    Required. String or array of strings of winget app IDs.
#>
function Remove-Win32App {
    param(
        [Parameter(Mandatory)][array]$Name
    )

    foreach ($app in $Name) {
        # Use winget to remove win32 apps
        Write-Host "  <> $app"
        winget uninstall --accept-source-agreements --disable-interactivity --id $app

        if (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "93")) {
            Write-Host "Unable to uninstall Microsoft Edge via Winget" -ForegroundColor Red
        }
    }
    Write-Host ""
}

<#
.SYNOPSIS
    Loops throgh provided list of .reg file names and imports them.
.PARAMETER Name
    Required. String or array of strings of .reg filenames in .\regs directory.
.NOTES
    Do not include .reg extension in filenames.
#>
function Import-Reg {
    param(
        [Parameter(Mandatory)][array]$Name
    )

    $winVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild
    $regManifest = Import-Csv .\regs\manifest.csv

    taskkill /f /im explorer.exe
    foreach ($reg in $Name) {
        $regMeta = $regManifest | Where-Object -Property filename -EQ -Value $reg
        if ($null -eq $regMeta) {
            Write-Host "<!> Missing entry in manifest.csv for the file '$reg', please add a record and fill out compatibility information and strings. Skipping." -ForegroundColor Red
        }

        # Check compatibility of reg file
        if (($regMeta.from -eq '*' -or $winVersion -gt $regMeta.from) -and ($regMeta.to -eq '*' -or $winVersion -le $regMeta.to)) {
            Write-Host "  <> $($regMeta.applying)"
            reg import ".\regs\$reg.reg"
        } else {
            Write-Host "  <> Skipping '$reg' due to incompatible Windows version" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    Write-Host ""
    Write-Host "Restarting explorer.exe, if it did not start automatically:" -ForegroundColor Cyan
    Write-Host "    > Open Task Manager (Ctrl+Shift+Esc) > Start new task > explorer.exe" -ForegroundColor Cyan
    Start-Process explorer.exe
    Write-Host ""
}

function Invoke-ProfileApplication {
    param(
        [Parameter(Mandatory)][string]$Name
    )

    $prof = Get-Profile $Name

    Clear-Host
    Write-Host "Applying profile: $Name"
    Write-Host ""
    
    # Process UWP applists
    foreach ($applist in $prof.applists_uwp) {
        Write-Host "Removing UWP apps from applist: $applist..."
        $uwpApps = Get-Applist -Type uwp -Name $applist
        Remove-UWPApp $uwpApps
    }

    # Process Win32 applists
    foreach ($applist in $prof.applists_win32) {
        Write-Host "Removing Win32 apps from applist: $applist..."
        $win32Apps = Get-Applist -Type win32 -Name $applist
        Remove-Win32App $win32Apps
    }

    Write-Host "Importing registry keys:"
    Import-Reg $prof.regs

    Write-Host "Profile applied." -ForegroundColor Green
    Write-Host "Press any key to go back..."
    $null = [System.Console]::ReadKey()
}

Export-ModuleMember -Function Get-Profile, Get-Applist, Remove-UWPApp, Remove-Win32App, Import-Reg, Invoke-ProfileApplication