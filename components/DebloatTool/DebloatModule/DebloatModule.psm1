<#
.SYNOPSIS
    Get-Profile function is used to load a json debloat profile.
.PARAMETER ProfilePath
    Required. Path to the debloat profile file.
.OUTPUTS
    Returns the debloat profile.
#>
function Get-Profile {
    param(
        [Parameter(Mandatory)][string]$ProfilePath
    )

    if (-not (Test-Path $ProfilePath)) {
        return $null
    }

    $DebloatProfile = Get-Content -Path $ProfilePath -Raw | ConvertFrom-Json
    return $DebloatProfile
}

<#
.SYNOPSIS
    Reads the list of apps from the specified file. Trims the app names and removes any comments.
.PARAMETER Name
    Required. Name of the applist file.
.PARAMETER ListAll
    Optional. If specified, the function will return all apps, including the disabled ones.
.OUTPUTS
    Returns list of apps from the specified file.
#>
function Get-Applist {
    param (
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Name,
        [switch]$ListAll
    )
    
    $ApplistPath = ""
    switch ($Type) {
        uwp { $ApplistPath = ".\applists_uwp\$Name.txt" }
        win32 { $ApplistPath = ".\applists_win32\$Name.txt" }
        Default { throw "Invalid type: $Type, Only 'uwp' or 'win32' are permitted." }
    }

    if (-not (Test-Path $ApplistPath)) {
        throw "Applist file not found: $ApplistPath"
    }

    $applist = @()

    # Get list of apps from file at the path provided, and populate the applist array
    foreach ($app in (Get-Content -Path $ApplistPath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' })) {
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
        $appstring = $app.Trim('*')

        $applist += $appstring
    }
    return $applist
}

<#
.SYNOPSIS
    Based on provided profile, removes apps from the system.
.PARAMETER DebloatProfile
    Required. Debloat profile object.
#>
function Remove-Apps {
    param(
        [Parameter(Mandatory)][PSCustomObject]$DebloatProfile
    )

    # Loop through each uwp applist in the profile
    foreach ($applist in $DebloatProfile.applists_uwp) {
        Write-Output ""
        Write-Output "Removing UWP apps from applist: $applist"
        # Get the list of apps from the applist file
        $apps = Get-Applist -Type uwp -Name $applist
        foreach ($app in $apps) {
            # Use Remove-AppxPackage to remove all other apps
            $app = '*' + $app + '*'

            $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild
            # Remove installed app for all existing users
            if ($WinVersion -ge 22000){
                # Windows 11 build 22000 or later
                try {
                    Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
                }
                catch {
                    Write-Host "Unable to remove $app for all users" -ForegroundColor Yellow
                    Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                }
            }
            else {
                # Windows 10
                try {
                    Get-AppxPackage -Name $app | Remove-AppxPackage -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Host "Unable to remove $app for current user" -ForegroundColor Yellow
                    Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                }
                
                try {
                    Get-AppxPackage -Name $app -PackageTypeFilter Main, Bundle, Resource -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                }
                catch {
                    Write-Host "Unable to remove $app for all users" -ForegroundColor Yellow
                    Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
                }
            }

            # Remove provisioned app from OS image, so the app won't be installed for any new users
            try {
                Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
            }
            catch {
                Write-Host "Unable to remove $app from windows image" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        }
    }

    # Check if winget is installed and remove win32 apps
    if ($global:wingetInstalled) {
        foreach ($applist in $DebloatProfile.applists_win32) {
            Write-Output ""
            Write-Output "Removing Win32 apps from applist: $applist"
            $apps = Get-Applist -Type win32 -Name $applist
            foreach ($app in $apps) {
                # Use winget to remove win32 apps
                Strip-Progress -ScriptBlock { winget uninstall --accept-source-agreements --disable-interactivity --id $app } | Tee-Object -Variable wingetOutput 

                If (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "93")) {
                    Write-Host "Unable to uninstall Microsoft Edge via Winget" -ForegroundColor Red
                    Write-Output ""
                }
            }
        }
    } else {
        Write-Host "Error: WinGet is either not installed or is outdated, Win32 apps could not be removed" -ForegroundColor Red
    }
    Write-Output ""
}

Export-ModuleMember -Function Get-Profile, Get-Applist, Remove-Apps