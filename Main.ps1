Set-Location $PSScriptRoot
# List components and show menu for user selection of which module to start
$components = Get-ChildItem -Path ".\components" -Directory | Select-Object -ExpandProperty BaseName

# Show menu and wait for user input, loops until valid input is provided
# Each component is enumerates with a number and the user can select the number to run the component
do { 
    Clear-Host
    Write-Host "Select a component to run:"
    $num = 1
    foreach ($component in $components) {
        Write-Host "  ($num) $component"
        $num++
    }
    Write-Host ""
    Write-Host "(x) Exit"
    Write-Host ""
    $mode = Read-Host "Please select an option: "

    if ($mode -eq 'x') {
        exit
    }
} while ($mode -notin 1..$components.Count)

# Run the selected component
$component = $components[$mode - 1]
. ".\components\$component\$component.ps1"