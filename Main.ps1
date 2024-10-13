# List components and show menu for user selection of which module to start
$components = @()
Get-ChildItem -Path $PSScriptRoot\components -Directory | ForEach-Object { $components += $_.BaseName }
$components

# Show menu and wait for user input, loops until valid input is provided
# Each component is enumerates with a number and the user can select the number to run the component
Do { 
    Clear-Host
    Write-Output "Select a component to run:"
    $num = 0
    $components | ForEach-Object { $num++; Write-Output " ($num) $_" }

    $Mode = Read-Host "Please select an option (1-$($components.Count)) or 'x' to exit"

    if ($Mode -eq 'x') {
        Write-Output "Thank you, bye!"
        exit
    }
} While ($Mode -lt 1 -or $Mode -gt $components.Count)

# Run the selected component
$component = $components[$Mode - 1]
. "$PSScriptRoot\components\$component\$component.ps1"