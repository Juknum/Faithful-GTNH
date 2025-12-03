<#
.SYNOPSIS
	Processes multiple image layers based on configuration from a JSON file.

.DESCRIPTION
	This script reads a JSON configuration file containing layer definitions and processes each entry by calling the layer.ps1 script.
	Each JSON entry must contain layer0Path, layer1Path, and outPath properties. The script validates the JSON file existence
	and required properties before processing. The JSON file should be located in the ../configs/layers directory relative to
	the script location.

.PARAMETER file
	The name of the JSON configuration file located in the ../configs/layers directory relative to the script location.
	This parameter is mandatory and should include the .json extension.

.EXAMPLE
	.\layered.ps1 -file "textures.json"
	Processes all layer combinations defined in the textures.json configuration file.

.EXAMPLE
	.\layered.ps1 -file "blocks.json"
	Processes all layer combinations defined in the blocks.json configuration file located in ../configs/layers.

.NOTES
	File Name      : layered.ps1
	Prerequisite   : Requires layer.ps1 script in the same directory
	Dependencies   : JSON configuration files in ../configs/layers directory

.INPUTS
	None. This script does not accept pipeline input.

.OUTPUTS
	System.String
	Progress messages indicating the processing status of each layer combination.
#>

# Define paths
$configDir    = Join-Path -Path $PSScriptRoot -ChildPath "../configs/layers"
$layerScript  = Join-Path -Path $PSScriptRoot -ChildPath "layer.ps1"
$jsonFilePath = Join-Path -Path $configDir -ChildPath $file

# Check if the JSON file exists
if (-not (Test-Path -Path $jsonFilePath)) {
	Write-Error "JSON file not found: $jsonFilePath"
	exit 1
}

try {
	# Parse the JSON content
	$jsonData = Get-Content $jsonFilePath -Raw | ConvertFrom-Json

	# Process each object in the array
	foreach ($item in $jsonData) {
		# Ensure the required properties exist
		if (-not ($item.PSObject.Properties.Name -contains 'layer0Path' -and 
				$item.PSObject.Properties.Name -contains 'layer1Path' -and 
				$item.PSObject.Properties.Name -contains 'outPath')
		) {
			Write-Warning "Skipping item: Missing required properties (layer0Path, layer1Path, or outPath)"
			continue
		}

		Write-Host "Processing layers:`n  $($item.layer0Path)`n+ $($item.layer1Path)`n= $($item.outPath)" -ForegroundColor Green
		Write-Host ""

		# Call the layer script with the extracted parameters
		& $layerScript -layer0Path $item.layer0Path -layer1Path $item.layer1Path -outPath $item.outPath
		Write-Host ""
	}
}
catch {
	Write-Error "An error occurred: $_"
	exit 1
}