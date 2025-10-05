##############################################################
# PowerShell script to recolor textures to multiple targets
#
# It reads JSON files in the .github/configs/recolors directory
# to determine which source textures to recolor and their target textures.	
# It then calls recolor.ps1 for each source-target pair.
#
# Usage:
#   .\recolors.ps1
#	  .\recolors.ps1 -files "example1.jsonc","example2.jsonc" # to process specific JSON files
##############################################################


# Script to extract color palettes from texture files defined in JSON files
param (
	[string] $files        = @(),   # Comma-separated list of JSON files names to process (optional)
	[switch] $forceRecolor = $false # Force recoloring even if target files exist
)

$recolorsDirectory = "$PSScriptRoot/../configs/recolors"

# Get all jsonc files in the recolors directory

if ($files) {
	# If specific JSON files are provided, use them
	$recolorFiles = @()
	$splitFiles = $files -split " " | ForEach-Object { $_.Trim() }

	foreach ($file in $splitFiles) {
		$fullPath = Join-Path -Path $recolorsDirectory -ChildPath $file
		if (Test-Path $fullPath) {
			$recolorFiles += Get-Item -Path $fullPath
		} else {
			Write-Warning "Specified JSON file not found: $fullPath"
		}
	}
} else {
	# Otherwise, get all JSON files in the directory
	$recolorFiles = Get-ChildItem -Path $recolorsDirectory -Filter "*.jsonc" -File
}

$recolorConfigs = @()

foreach ($file in $recolorFiles) {
	$config = Get-Content $file.FullName | ConvertFrom-Json
	$recolorConfigs += $config
}

foreach ($config in $recolorConfigs) {
	Write-Host "INFO: Loaded recolor config for source: $($config.origin)" -ForegroundColor Green

	# call recolor.ps1 with the parameters
	& "$PSScriptRoot/recolor.ps1" -src $config.origin -out $config.targets -commandLine -forceRecolor:$forceRecolor
}