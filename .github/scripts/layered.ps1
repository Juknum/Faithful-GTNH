param(
	[Parameter(Mandatory = $true)]
	[string]$file
)

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