
# Script to extract color palettes from texture files defined in JSON files
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