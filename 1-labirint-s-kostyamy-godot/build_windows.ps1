param([string]$OutputDirectory = "C:\games_dev\builds\HeartOfTide-Windows")
$ErrorActionPreference = 'Stop'
$projectDirectory = $PSScriptRoot
$enginePath = Join-Path (Split-Path $projectDirectory) 'godot\Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
& $enginePath --headless --path $projectDirectory --export-release 'Windows Portable' (Join-Path $OutputDirectory 'HeartOfTide.exe')
if ($LASTEXITCODE -ne 0) { throw 'Godot export failed' }
Copy-Item -LiteralPath (Join-Path $projectDirectory 'story') -Destination $OutputDirectory -Recurse -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory 'docs\portable.txt') -Destination (Join-Path $OutputDirectory 'README.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectDirectory 'docs\GODOT-LICENSE.txt') -Destination $OutputDirectory -Force
Compress-Archive -Path (Join-Path $OutputDirectory '*') -DestinationPath "$OutputDirectory.zip" -Force
Write-Host "Ready: $OutputDirectory.zip"
