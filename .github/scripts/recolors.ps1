<#
.SYNOPSIS
	Processes recolor configuration files to extract and apply color palettes from texture files.

.DESCRIPTION
	This script reads JSON configuration files from the recolors directory and processes them to apply
	color palette transformations to texture files. It can process either specific JSON files or all
	JSON files in the recolors directory. The script delegates the actual recoloring work to the
	recolor.ps1 script.

.PARAMETER files
	Optional comma-separated list of JSON file names to process. If not provided, all .jsonc files
	in the recolors directory will be processed.

.PARAMETER forceRecolor
	Switch parameter that forces recoloring even if target files already exist. Default is false.

.EXAMPLE
	.\recolors.ps1
	Processes all .jsonc files in the recolors directory.

.EXAMPLE
	.\recolors.ps1 -files "config1.jsonc", "config2.jsonc"
	Processes only the specified JSON configuration files.

.EXAMPLE
	.\recolors.ps1 -forceRecolor
	Processes all .jsonc files and forces recoloring even if target files exist.

.EXAMPLE
	.\recolors.ps1 -files "config1.jsonc" -forceRecolor
	Processes a specific configuration file and forces recoloring.

.NOTES
	The script expects configuration files to be in JSONC format with 'origin' and 'targets' properties.
	Configuration files should be located in the '../configs/recolors' directory relative to the script location.
	Requires recolor.ps1 script to be present in the same directory.

.OUTPUTS
	None. The script outputs informational messages to the console.

.INPUTS
	None. This script does not accept pipeline input.
#>

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