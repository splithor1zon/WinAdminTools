<#
.SYNOPSIS
    Get-Profile function is used to load a json debloat profile.
.PARAMETER ProfilePath
    Path to the debloat profile file.
#>
function Get-Profile {
    param(
        [string]$ProfilePath
    )

    if (-not (Test-Path $ProfilePath)) {
        return $null
    }

    $DebloatProfile = Get-Content -Path $ProfilePath -Raw | ConvertFrom-Json
    return $DebloatProfile
}

#TODO: Implement the Remove-Apps function
function Remove-Apps {
    param(
        [string]$a
    )

    $DebloatProfile = Get-Profile -ProfilePath $ProfilePath

    if ($DebloatProfile -eq $null) {
        Write-Warning "Profile not found."
        return
    }

    $DebloatProfile.Apps | ForEach-Object {
        $App = $_
        $App | ForEach-Object {
            $AppName = $_
            Write-Host "Removing $AppName..."
            Get-AppxPackage -Name $AppName | Remove-AppxPackage
        }
    }
}

Export-ModuleMember -Function Get-Profile