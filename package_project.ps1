# PowerShell script to package the FPV game project
$scriptPath = $MyInvocation.MyCommand.Path
$sourceDir = Split-Path $scriptPath

# Define target zip destination
$parentDir = Split-Path $sourceDir -Parent
$destinationZip = Join-Path $parentDir "godot_fpv_game.zip"

Write-Host "Zipping Godot Project from: $sourceDir"
Write-Host "Destination: $destinationZip"

# Clean up existing zip
if (Test-Path $destinationZip) {
    Remove-Item $destinationZip -Force
}

# Compress the folder, excluding the script itself to keep it neat if possible,
# or simply compress the directory.
Compress-Archive -Path $sourceDir -DestinationPath $destinationZip -Force

Write-Host "Success! The Godot project is packaged at $destinationZip"
