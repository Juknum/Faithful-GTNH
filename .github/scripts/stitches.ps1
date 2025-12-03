<#
.SYNOPSIS
	Processes stitch configuration files to combine multiple textures into single output files.

.DESCRIPTION
	This script reads JSONC configuration files from the stitches directory and processes them
	to stitch multiple texture files together. It can process all stitch configurations or
	only specific ones provided via the files parameter. Each configuration specifies input
	textures and an output location where the stitched result will be saved.

.PARAMETER files
	An array of specific JSONC configuration file names to process. If not provided or empty,
	all JSONC files in the stitches directory will be processed.

.EXAMPLE
	.\stitches.ps1
	Processes all JSONC stitch configuration files in the stitches directory.

.EXAMPLE
	.\stitches.ps1 -files "config1.jsonc", "config2.jsonc"
	Processes only the specified stitch configuration files.

.EXAMPLE
	.\stitches.ps1 -files "config1.jsonc config2.jsonc"
	Processes the specified stitch configuration files (space-separated string format).

.NOTES
	The script expects:
	- Stitch configuration files in JSONC format located in .github/configs/stitches/
	- Each config file must contain 'textures' and 'output' properties
	- The stitch.ps1 script must exist in the same directory as this script
	- Output files are saved to the assets directory
	
.OUTPUTS
	None. The script calls stitch.ps1 which generates image files in the assets directory.

.INPUTS
	None. This script does not accept pipeline input.
#>

param (
	[string[]] $files = @()
)

$stitchesDirectory = "$PSScriptRoot/../configs/stitches"
$assetsDirectory   = "$PSScriptRoot/../../assets"

# Get all jsonc files in the stitches directory

if ($files.Count -gt 0) {
	# If specific JSON files are provided, use them
	$stichFiles = @()
	$splitFiles = $files -split " " | ForEach-Object { $_.Trim() }

	foreach ($file in $splitFiles) {
		$fullPath = Join-Path -Path $stitchesDirectory -ChildPath $file
		if (Test-Path $fullPath) {
			$stichFiles += Get-Item -Path $fullPath
		}
		else {
			Write-Warning "Specified JSON file not found: $fullPath"
		}
	}

	Write-Host $stichFiles
}
else {
	# Otherwise, get all JSON files in the directory
	$stichFiles = Get-ChildItem -Path $stitchesDirectory -Filter "*.jsonc" -File
}

$stitchesConfigs = @()

foreach ($file in $stichFiles) {
	$config = Get-Content $file.FullName | ConvertFrom-Json
	$stitchesConfigs += $config
}

foreach ($config in $stitchesConfigs) {
	Write-Host "INFO: Loaded stich config for output: $($config.output)" -ForegroundColor Green

	# call recolor.ps1 with the parameters
	& "$PSScriptRoot/stitch.ps1" -texturePaths $config.textures -output "$assetsDirectory/$($config.output)"
}