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
    
#>
function Get-Applist {
    param (
        [Parameter(Mandatory)][string]$ApplistPath
    )
    
    
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


}

Export-ModuleMember -Function Get-Profile